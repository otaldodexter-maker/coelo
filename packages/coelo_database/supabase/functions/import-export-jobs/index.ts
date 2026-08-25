import { createClient } from "@supabase/supabase-js";
import * as XLSX from "xlsx";
import { validateXlsxArchive, validateXlsxWorkbook } from "./xlsx_guard.ts";

const BUCKET = "coelo-operations";
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_ROWS = 5000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Json = Record<string, unknown>;

function cors(origin: string | null): HeadersInit {
  const configured = (Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "").split(",").map((item) => item.trim()).filter(Boolean);
  const local = origin?.startsWith("http://127.0.0.1:") || origin?.startsWith("http://localhost:");
  const allowed = origin && (local || configured.includes(origin)) ? origin : configured[0] ?? "https://superadmin.coelo.me";
  return { "Access-Control-Allow-Origin": allowed, "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-coelo-import-action, x-coelo-import-job-id", "Access-Control-Allow-Methods": "POST, OPTIONS", "Cache-Control": "no-store", Vary: "Origin" };
}

function response(origin: string | null, status: number, body: Json) {
  return new Response(JSON.stringify(body), { status, headers: { ...cors(origin), "Content-Type": "application/json" } });
}

function secret() {
  const keys = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (keys) { const parsed = JSON.parse(keys) as Record<string, string>; if (parsed.default) return parsed.default; }
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!legacy) throw new Error("server_secret_unavailable");
  return legacy;
}

function column(value: unknown) {
  const normalized = String(value ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
  return ({ instituicao: "institution_id", instituicao_id: "institution_id", nome: "name", tipo_da_unidade: "unit_type_id", tipo: "unit_type_id", outros: "unit_type_other_text", status_da_unidade: "status" } as Record<string, string>)[normalized] ?? normalized;
}

function rowsFromMatrix(matrix: unknown[][]): Json[] {
  if (matrix.length < 2) throw new Error("empty_import");
  const headers = matrix.shift()!.map(column);
  const allowed = new Set(["institution_id", "name", "slug", "unit_type_id", "unit_type_other_text", "status"]);
  if (headers.some((item) => !item || !allowed.has(item)) || new Set(headers).size !== headers.length) throw new Error("invalid_headers");
  return matrix.filter((row) => row.some((item) => String(item ?? "").trim())).map((row) => Object.fromEntries(headers.map((header, index) => [header, String(row[index] ?? "").trim()])));
}

function csv(bytes: Uint8Array) {
  const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes).replace(/^\uFEFF/, "");
  if (text.includes("\0")) throw new Error("invalid_csv_encoding");
  const matrix: string[][] = [];
  let row: string[] = [], cell = "", quoted = false;
  for (let index = 0; index < text.length; index++) {
    const char = text[index];
    if (quoted) { if (char === '"' && text[index + 1] === '"') { cell += '"'; index++; } else if (char === '"') quoted = false; else cell += char; }
    else if (char === '"') quoted = true;
    else if (char === "," || char === ";") { row.push(cell); cell = ""; }
    else if (char === "\n") { row.push(cell.replace(/\r$/, "")); matrix.push(row); row = []; cell = ""; }
    else cell += char;
  }
  if (quoted) throw new Error("invalid_csv_quotes");
  if (cell.length || row.length) { row.push(cell.replace(/\r$/, "")); matrix.push(row); }
  return rowsFromMatrix(matrix);
}

function xlsx(bytes: Uint8Array) {
  validateXlsxArchive(bytes);
  const book = XLSX.read(bytes, { type: "array", cellDates: false, dense: true });
  validateXlsxWorkbook(book);
  const first = book.SheetNames[0];
  if (!first) throw new Error("empty_import");
  return rowsFromMatrix(XLSX.utils.sheet_to_json<unknown[]>(book.Sheets[first], { header: 1, defval: "", raw: false, blankrows: false }));
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest("SHA-256", Uint8Array.from(bytes).buffer);
  return [...new Uint8Array(digest)].map((item) => item.toString(16).padStart(2, "0")).join("");
}

async function unitExport(url: string, authorization: string, body: Json) {
  const delegated = await fetch(`${url}/functions/v1/unit-export`, { method: "POST", headers: { Authorization: authorization, "Content-Type": "application/json" }, body: JSON.stringify(body) });
  const payload = await delegated.json() as Json;
  if (!delegated.ok) throw new Error(String(payload.error ?? "unit_export_failed"));
  return payload;
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origin) });
  if (request.method !== "POST") return response(origin, 405, { error: "method_not_allowed" });
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) return response(origin, 401, { error: "authentication_required" });
  let jobId: string | null = null;
  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const user = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
    const admin = createClient(url, secret(), { auth: { persistSession: false } });
    const action = request.headers.get("x-coelo-import-action");
    if (action === "upload") {
      jobId = request.headers.get("x-coelo-import-job-id");
      if (!jobId || !UUID.test(jobId)) return response(origin, 400, { error: "invalid_request" });
      const contract = await user.rpc("superadmin_import_export_upload_contract", { p_import_job_id: jobId });
      if (contract.error) throw new Error("upload_unauthorized");
      const upload = contract.data as Json;
      const mime = String(upload.mime_type ?? "");
      if (request.headers.get("content-type")?.split(";", 1)[0] !== mime) return response(origin, 400, { error: "invalid_file_contract" });
      const bytes = new Uint8Array(await request.arrayBuffer());
      if (!bytes.length || bytes.length > Number(upload.max_bytes)) return response(origin, 400, { error: "invalid_file_size" });
      const path = String(upload.path ?? "");
      const stored = await admin.storage.from(BUCKET).upload(path, bytes, { contentType: mime, upsert: false, cacheControl: "no-store" });
      if (stored.error) {
        if (!stored.error.message.toLowerCase().includes("already exists")) throw new Error("storage_upload_failed");
        const current = await admin.storage.from(BUCKET).download(path);
        if (current.error || await checksum(new Uint8Array(await current.data.arrayBuffer())) !== await checksum(bytes)) throw new Error("idempotency_file_mismatch");
      }
      const format = mime === "text/csv" ? "csv" : "xlsx";
      const rows = format === "csv" ? csv(bytes) : xlsx(bytes);
      if (!rows.length || rows.length > MAX_ROWS) return response(origin, 400, { error: "invalid_row_count" });
      const preview = await admin.rpc("superadmin_preview_unit_import_from_edge", { p_request_id: crypto.randomUUID(), p_import_job_id: jobId, p_rows: rows, p_mapping_columns: {}, p_checksum_sha256: await checksum(bytes), p_size_bytes: bytes.length, p_mime_type: mime, p_parser_version: "units-v2" });
      if (preview.error) throw new Error("preview_failed");
      return response(origin, 200, preview.data as Json);
    }
    const body = await request.json() as Json;
    if (body.action === "create_import") {
      const result = await user.rpc("superadmin_create_import_export_job", { p_domain: body.domain, p_file_name: body.file_name, p_mime_type: body.mime_type, p_source_format: body.source_format, p_idempotency_key: body.idempotency_key });
      if (result.error) throw new Error("job_create_failed");
      return response(origin, 200, result.data as Json);
    }
    if (body.action === "confirm_import" || body.action === "retry_import") {
      if (typeof body.job_id !== "string" || !UUID.test(body.job_id) || typeof body.request_id !== "string" || !UUID.test(body.request_id)) return response(origin, 400, { error: "invalid_request" });
      const result = await user.rpc(body.action === "confirm_import" ? "superadmin_confirm_import_export_job" : "superadmin_retry_import_export_job", { p_import_job_id: body.job_id, p_request_id: body.request_id });
      if (result.error) throw new Error("job_transition_failed");
      return response(origin, 200, result.data as Json);
    }
    if (body.action === "request_export") {
      const created = await user.rpc("superadmin_request_import_export", { p_domain: body.domain, p_format: body.format, p_filters: body.filters ?? {}, p_current_view: body.current_view ?? {}, p_idempotency_key: body.idempotency_key });
      if (created.error) throw new Error("export_request_failed");
      return response(origin, 200, await unitExport(url, authorization, { action: "generate", format: body.format, filters: body.filters ?? {}, current_view: body.current_view ?? {}, idempotency_key: body.idempotency_key }));
    }
    if (body.action === "status" || body.action === "download") {
      if (typeof body.job_id !== "string" || !UUID.test(body.job_id)) return response(origin, 400, { error: "invalid_request" });
      const result = await user.rpc("superadmin_get_import_export_job", { p_import_job_id: body.job_id });
      if (result.error) throw new Error("job_unavailable");
      if (body.action === "download") return response(origin, 200, await unitExport(url, authorization, { action: "status", job_id: body.job_id }));
      return response(origin, 200, result.data as Json);
    }
    return response(origin, 400, { error: "invalid_request" });
  } catch (error) {
    const code = error instanceof Error ? error.message.split(":")[0] : "worker_error";
    if (jobId) {
      try {
        const admin = createClient(Deno.env.get("SUPABASE_URL")!, secret(), { auth: { persistSession: false } });
        const scope = await admin.from("import_jobs").select("request_id").eq("id", jobId).single();
        if (scope.error || !scope.data?.request_id) throw new Error("job_scope_unavailable");
        await admin.rpc("superadmin_fail_unit_file_job", {
          p_import_job_id: jobId,
          p_error_code: code.slice(0, 80),
          p_expected_request_id: scope.data.request_id,
        });
      } catch { /* job remains auditable if failure recording is unavailable */ }
    }
    return response(origin, 422, { error: code });
  }
});
