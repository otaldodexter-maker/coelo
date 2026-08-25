import { createClient } from "@supabase/supabase-js";
import * as XLSX from "xlsx";

const BUCKET = "coelo-operations";
const MAX_ROWS = 50000;
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

function safe(value: unknown) {
  let text = String(value ?? "");
  if (/^[=+\-@]/.test(text)) text = "'" + text;
  return '"' + text.replaceAll('"', '""') + '"';
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest("SHA-256", Uint8Array.from(bytes).buffer);
  return [...new Uint8Array(digest)].map((value) => value.toString(16).padStart(2, "0")).join("");
}

function artifact(rows: Json[], format: string) {
  const columns = [
    "id",
    "institution_id",
    "institution_name",
    "institution_type_name",
    "name",
    "unit_type_name",
    "unit_type_other_text",
    "unit_status",
    "effective_plan_name",
    "groups_count",
    "activities_count",
    "updated_at",
  ];
  const sanitized = rows.map((row) => Object.fromEntries(columns.map((column) => [column, row[column] ?? null])));
  if (format === "csv") {
    const content = [
      columns.map(safe).join(","),
      ...sanitized.map((row) => columns.map((column) => safe(row[column])).join(",")),
    ].join("\r\n");
    return { bytes: new TextEncoder().encode(content), mime: "text/csv", extension: "csv" };
  }
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(book, XLSX.utils.json_to_sheet(sanitized, { header: columns }), "Unidades");
  return {
    bytes: XLSX.write(book, { type: "array", bookType: "xlsx", compression: true }) as Uint8Array,
    mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    extension: "xlsx",
  };
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors(origin) });
  if (request.method !== "POST") return reply(origin, 405, { error: "method_not_allowed" });
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) return reply(origin, 401, { error: "authentication_required" });

  let jobId: string | null = null;
  let path: string | null = null;
  try {
    const body = (await request.json()) as Json;
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const user = createClient(url, anon, { global: { headers: { Authorization: authorization } } });
    const admin = createClient(url, secret(), { auth: { persistSession: false } });

    if (body.action === "status") {
      jobId = typeof body.job_id === "string" && UUID.test(body.job_id) ? body.job_id : null;
      if (!jobId) return reply(origin, 400, { error: "invalid_request" });
      const status = await user.rpc("superadmin_get_unit_file_job", { p_import_job_id: jobId });
      if (status.error) throw new Error("status_failed");
      const payload = status.data as Json;
      const stored = (payload.summary as Json | undefined)?.storage_path;
      if (typeof stored === "string") {
        const signed = await admin.storage.from(BUCKET).createSignedUrl(stored, 300, { download: true });
        if (!signed.error) return reply(origin, 200, { ...payload, download_url: signed.data.signedUrl, expires_in: 300 });
      }
      return reply(origin, 200, payload);
    }

    if (body.action !== "generate" || typeof body.idempotency_key !== "string" || !UUID.test(body.idempotency_key)) {
      return reply(origin, 400, { error: "invalid_request" });
    }

    const format = body.format === "csv" ? "csv" : "xlsx";
    const created = await user.rpc("superadmin_request_unit_export", {
      p_format: format,
      p_filters: body.filters ?? {},
      p_current_view: body.current_view ?? {},
      p_idempotency_key: body.idempotency_key,
    });
    if (created.error) throw new Error("export_request_failed");
    jobId = String((created.data as Json).job_id);

    const materialized = await admin.rpc("superadmin_materialize_unit_export_from_edge", {
      p_export_job_id: jobId,
    });
    if (materialized.error) throw new Error("export_snapshot_failed");

    const rows: Json[] = [];
    let afterOrdinal: number | null = null;
    while (true) {
      const page = await user.rpc("superadmin_unit_export_page_v2", {
        p_export_job_id: jobId,
        p_after_ordinal: afterOrdinal,
        p_page_size: 500,
      });
      if (page.error) throw new Error("export_page_failed");
      const payload = page.data as Json;
      const items = Array.isArray(payload.items) ? payload.items as Json[] : [];
      rows.push(...items);
      if (rows.length > MAX_ROWS) throw new Error("export_too_large");
      const next = payload.next_cursor as Json | undefined;
      if (payload.has_more !== true || typeof next?.ordinal !== "number") break;
      afterOrdinal = next.ordinal;
    }

    if (rows.length === 0) return reply(origin, 409, { error: "empty_export" });
    const generated = artifact(rows, format);
    path = "exports/units/" + jobId + "/" + crypto.randomUUID() + "." + generated.extension;
    const upload = await admin.storage.from(BUCKET).upload(path, generated.bytes, {
      contentType: generated.mime,
      upsert: false,
      cacheControl: "no-store",
    });
    if (upload.error) throw new Error("storage_upload_failed");

    const completed = await admin.rpc("superadmin_complete_unit_file_job", {
      p_import_job_id: jobId,
      p_storage_path: path,
      p_file_name: "unidades." + generated.extension,
      p_mime_type: generated.mime,
      p_size_bytes: generated.bytes.length,
      p_checksum_sha256: await checksum(generated.bytes),
      p_row_count: rows.length,
    });
    if (completed.error) {
      await admin.storage.from(BUCKET).remove([path]);
      throw new Error("export_complete_failed");
    }

    const signed = await admin.storage.from(BUCKET).createSignedUrl(path, 300, { download: true });
    if (signed.error) throw new Error("signed_url_failed");
    return reply(origin, 200, {
      ...(completed.data as Json),
      download_url: signed.data.signedUrl,
      expires_in: 300,
    });
  } catch (error) {
    const code = error instanceof Error ? error.message.split(":")[0] : "worker_error";
    if (jobId) {
      try {
        const admin = createClient(Deno.env.get("SUPABASE_URL")!, secret(), { auth: { persistSession: false } });
        if (path) await admin.storage.from(BUCKET).remove([path]);
        const scope = await admin.from("import_jobs").select("request_id").eq("id", jobId).single();
        if (scope.error || !scope.data?.request_id) throw new Error("job_scope_unavailable");
        await admin.rpc("superadmin_fail_unit_file_job", {
          p_import_job_id: jobId,
          p_error_code: code.slice(0, 80),
          p_expected_request_id: scope.data.request_id,
        });
      } catch {
        // Best effort cleanup; job state remains auditable.
      }
    }
    return reply(origin, 422, { error: code });
  }
});
