import { createClient } from "@supabase/supabase-js";
import * as XLSX from "xlsx";

const BUCKET = "coelo-operations";
const MAX_BYTES = 5 * 1024 * 1024;
const MAX_ROWS = 5000;
const PARSER_VERSION = "units-v2";
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Json = Record<string, unknown>;

function cors(origin: string | null): HeadersInit {
  const configured = (Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "").split(",").map((value) => value.trim()).filter(Boolean);
  const local = origin?.startsWith("http://127.0.0.1:") || origin?.startsWith("http://localhost:");
  const allowed = origin && (configured.includes(origin) || local) ? origin : configured[0] ?? "https://superadmin.coelo.me";
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

function reply(origin: string | null, status: number, body: Json) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors(origin), "Content-Type": "application/json", "Cache-Control": "no-store" },
  });
}

function secret() {
  const set = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (set) {
    const parsed = JSON.parse(set) as Record<string, string>;
    if (parsed.default) return parsed.default;
  }
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!legacy) throw new Error("server_secret_unavailable");
  return legacy;
}

function decode(value: unknown) {
  if (typeof value !== "string" || value.length > Math.ceil(MAX_BYTES * 4 / 3) + 16) throw new Error("invalid_file_payload");
  const binary = atob(value);
  if (!binary.length || binary.length > MAX_BYTES) throw new Error("invalid_file_size");
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest("SHA-256", Uint8Array.from(bytes).buffer);
  return [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, "0")).join("");
}

function key(value: unknown) {
  const normalized = String(value ?? "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").trim().toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "");
  const aliases: Record<string, string> = {
    instituicao: "institution_id",
    instituicao_id: "institution_id",
    nome: "name",
    tipo_da_unidade: "unit_type_id",
    tipo: "unit_type_id",
    outros: "unit_type_other_text",
    status_da_unidade: "status",
  };
  return aliases[normalized] ?? normalized;
}

function matrixRows(matrix: unknown[][]): Json[] {
  if (matrix.length < 2) throw new Error("empty_import");
  const columns = matrix.shift()!.map(key);
  const allowed = new Set(["institution_id", "name", "slug", "unit_type_id", "unit_type_other_text", "status"]);
  if (columns.some((value) => !value || !allowed.has(value)) || new Set(columns).size !== columns.length) throw new Error("invalid_headers");
  return matrix
    .filter((row) => row.some((value) => String(value ?? "").trim()))
    .map((row) => Object.fromEntries(columns.map((column, index) => [column, String(row[index] ?? "").trim()])));
}

function csv(bytes: Uint8Array) {
  const text = new TextDecoder("utf-8", { fatal: true }).decode(bytes).replace(/^\uFEFF/, "");
  if (text.includes("\0")) throw new Error("invalid_csv_encoding");
  const matrix: string[][] = [];
  let row: string[] = [];
  let cell = "";
  let quoted = false;
  for (let index = 0; index < text.length; index++) {
    const character = text[index];
    if (quoted) {
      if (character === '"' && text[index + 1] === '"') {
        cell += '"';
        index++;
      } else if (character === '"') quoted = false;
      else cell += character;
    } else if (character === '"') quoted = true;
    else if (character === "," || character === ";") {
      row.push(cell);
      cell = "";
    } else if (character === "\n") {
      row.push(cell.replace(/\r$/, ""));
      matrix.push(row);
      row = [];
      cell = "";
    } else cell += character;
  }
  if (quoted) throw new Error("invalid_csv_quotes");
  if (cell.length || row.length) {
    row.push(cell.replace(/\r$/, ""));
    matrix.push(row);
  }
  return matrixRows(matrix);
}

function xlsx(bytes: Uint8Array) {
  if (bytes[0] !== 0x50 || bytes[1] !== 0x4b) throw new Error("invalid_xlsx_signature");
  const book = XLSX.read(bytes, { type: "array", cellDates: false, dense: true });
  const sheet = book.SheetNames[0];
  if (!sheet) throw new Error("empty_import");
  return matrixRows(XLSX.utils.sheet_to_json<unknown[]>(book.Sheets[sheet], {
    header: 1,
    defval: "",
    raw: false,
    blankrows: false,
  }));
}

function template(format: string) {
  const columns = ["institution_id", "name", "slug", "unit_type_id", "unit_type_other_text", "status"];
  if (format === "csv") {
    return {
      bytes: new TextEncoder().encode(columns.join(",") + "\r\n"),
      mime: "text/csv",
      name: "modelo-unidades.csv",
    };
  }
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book, XLSX.utils.aoa_to_sheet([columns]), "Unidades");
  return {
    bytes: XLSX.write(book, { type: "array", bookType: "xlsx", compression: true }) as Uint8Array,
    mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    name: "modelo-unidades.xlsx",
  };
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origin) });
  if (request.method !== "POST") return reply(origin, 405, { error: "method_not_allowed" });
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) return reply(origin, 401, { error: "authentication_required" });

  let jobId: string | null = null;
  try {
    const body = (await request.json()) as Json;
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const user = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
    const admin = createClient(url, secret(), { auth: { persistSession: false } });
    const action = body.action;

    if (action === "template") {
      const auth = await user.rpc("superadmin_unit_import_template");
      if (auth.error) throw new Error("authorization_failed");
      const generated = template(body.format === "csv" ? "csv" : "xlsx");
      let binary = "";
      for (const byte of generated.bytes) binary += String.fromCharCode(byte);
      return reply(origin, 200, {
        ...(auth.data as Json),
        file_name: generated.name,
        mime_type: generated.mime,
        content_base64: btoa(binary),
      });
    }

    jobId = typeof body.job_id === "string" && UUID.test(body.job_id) ? body.job_id : null;
    if (action === "status") {
      if (!jobId) return reply(origin, 400, { error: "invalid_request" });
      const result = await user.rpc("superadmin_get_unit_file_job", { p_import_job_id: jobId });
      if (result.error) throw new Error("status_failed");
      return reply(origin, 200, result.data as Json);
    }

    if (action === "confirm" || action === "retry") {
      if (!jobId || typeof body.request_id !== "string" || !UUID.test(body.request_id)) {
        return reply(origin, 400, { error: "invalid_request" });
      }
      const result = await user.rpc(
        action === "confirm" ? "superadmin_confirm_unit_import" : "superadmin_retry_unit_import",
        { p_request_id: body.request_id, p_import_job_id: jobId },
      );
      if (result.error) throw new Error(action + "_failed");
      return reply(origin, 200, result.data as Json);
    }

    if (action !== "upload_preview") return reply(origin, 400, { error: "invalid_request" });
    const fileName = typeof body.file_name === "string" ? body.file_name.trim() : "";
    const format = fileName.toLowerCase().endsWith(".csv") ? "csv" : fileName.toLowerCase().endsWith(".xlsx") ? "xlsx" : "";
    const mime = format === "csv" ? "text/csv" : "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    if (!format || body.mime_type !== mime || typeof body.idempotency_key !== "string" || !UUID.test(body.idempotency_key)) {
      return reply(origin, 400, { error: "invalid_file_contract" });
    }

    const bytes = decode(body.content_base64);
    const digest = await checksum(bytes);
    const rows = format === "csv" ? csv(bytes) : xlsx(bytes);
    if (!rows.length || rows.length > MAX_ROWS) return reply(origin, 400, { error: "invalid_row_count" });

    const created = await user.rpc("superadmin_create_unit_import_job", {
      p_file_name: fileName,
      p_mime_type: mime,
      p_source_format: format,
      p_idempotency_key: body.idempotency_key,
    });
    if (created.error) throw new Error("job_create_failed");
    const job = created.data as Json;
    jobId = String(job.job_id);
    const path = String(job.upload_path);

    const upload = await admin.storage.from(BUCKET).upload(path, bytes, {
      contentType: mime,
      upsert: false,
      cacheControl: "no-store",
    });
    if (upload.error) {
      if (!upload.error.message.toLowerCase().includes("already exists")) throw new Error("storage_upload_failed");
      const existing = await admin.storage.from(BUCKET).download(path);
      if (existing.error || await checksum(new Uint8Array(await existing.data.arrayBuffer())) !== digest) {
        throw new Error("idempotency_file_mismatch");
      }
    }

    const preview = await admin.rpc("superadmin_preview_unit_import_from_edge", {
      p_request_id: crypto.randomUUID(),
      p_import_job_id: jobId,
      p_rows: rows,
      p_mapping_columns: body.mapping ?? {},
      p_checksum_sha256: digest,
      p_size_bytes: bytes.length,
      p_mime_type: mime,
      p_parser_version: PARSER_VERSION,
    });
    if (preview.error) {
      if (!upload.error) await admin.storage.from(BUCKET).remove([path]);
      throw new Error("preview_failed");
    }
    return reply(origin, 200, preview.data as Json);
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
      } catch {
        // Best effort state transition; the job remains auditable.
      }
    }
    return reply(origin, 422, { error: code });
  }
});
