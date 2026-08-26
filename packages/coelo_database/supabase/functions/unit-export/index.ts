import { createClient } from "@supabase/supabase-js";
import * as XLSX from "xlsx";

const BUCKET = "coelo-operations";
const MAX_ROWS = 50000;
const MAX_ARTIFACT_BYTES = 5242880;
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Json = Record<string, unknown>;
type RpcResult = { data: unknown; error: unknown };
type RpcClient = {
  rpc: (name: string, args: Json) => PromiseLike<RpcResult>;
};

export function captureCreatedJobId(result: RpcResult, errorCode: string) {
  if (result.error) throw new Error(errorCode);
  const jobId = String((result.data as Json).job_id ?? "");
  if (!UUID.test(jobId)) throw new Error(errorCode);
  return jobId;
}

export async function recordCreatedFailureBestEffort(
  jobId: string | null,
  record: (jobId: string) => Promise<void>,
) {
  if (!jobId) return;
  try {
    await record(jobId);
  } catch {
    // Best effort cleanup; the authorized job state remains auditable.
  }
}

export async function reauthorizeExportJob(client: RpcClient, jobId: string) {
  const result = await client.rpc("superadmin_get_unit_file_job", {
    p_import_job_id: jobId,
  });
  const payload = result.data as Json | null;
  if (
    result.error || !payload || payload.job_id !== jobId ||
    payload.domain !== "units_export"
  ) {
    throw new Error("export_reauthorization_failed");
  }
  return payload;
}

function cors(origin: string | null): HeadersInit {
  const configured = (Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "").split(",")
    .map((value) => value.trim()).filter(Boolean);
  const local = origin?.startsWith("http://127.0.0.1:") ||
    origin?.startsWith("http://localhost:");
  const allowed = origin && (configured.includes(origin) || local)
    ? origin
    : configured[0] ?? "https://superadmin.coelo.me";
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    Vary: "Origin",
  };
}

function reply(origin: string | null, status: number, body: Json) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...cors(origin),
      "Content-Type": "application/json",
      "Cache-Control": "no-store",
    },
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

export function neutralizeCsvFormula(value: unknown) {
  const text = String(value ?? "");
  return /^[ \t\r\n]*[=+\-@]/.test(text) ? "'" + text : text;
}

export function assertArtifactWithinLimit(bytes: Uint8Array) {
  if (bytes.length > MAX_ARTIFACT_BYTES) throw new Error("export_too_large");
}

export function validateExportArtifactPath(
  jobId: string,
  path: string,
  format: unknown,
) {
  if (!UUID.test(jobId) || (format !== "csv" && format !== "xlsx")) {
    return false;
  }
  const prefix = `exports/units/${jobId}/`;
  const suffix = `.${format}`;
  if (!path.startsWith(prefix) || !path.endsWith(suffix)) return false;
  const objectId = path.slice(prefix.length, -suffix.length);
  return UUID.test(objectId);
}

export function validateExportStatusPayload(jobId: string, payload: unknown) {
  if (!UUID.test(jobId) || !payload || typeof payload !== "object") {
    return false;
  }
  const value = payload as Json;
  return value.job_id === jobId && value.domain === "units_export";
}

export function successfulReplayArtifactPath(
  jobId: string,
  payload: unknown,
  format: unknown,
) {
  if (!validateExportStatusPayload(jobId, payload)) return null;
  const value = payload as Json;
  const summary = value.summary;
  const path = summary && typeof summary === "object"
    ? (summary as Json).storage_path
    : null;
  return value.state === "SUCESSO" && typeof path === "string" &&
      validateExportArtifactPath(jobId, path, format)
    ? path
    : null;
}

function safe(value: unknown) {
  const text = neutralizeCsvFormula(value);
  return '"' + text.replaceAll('"', '""') + '"';
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return [...new Uint8Array(digest)].map((value) =>
    value.toString(16).padStart(2, "0")
  ).join("");
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
  const sanitized = rows.map((row) =>
    Object.fromEntries(columns.map((column) => [column, row[column] ?? null]))
  );
  if (format === "csv") {
    const content = [
      columns.map(safe).join(","),
      ...sanitized.map((row) =>
        columns.map((column) => safe(row[column])).join(",")
      ),
    ].join("\r\n");
    return {
      bytes: new TextEncoder().encode(content),
      mime: "text/csv",
      extension: "csv",
    };
  }
  const book = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(
    book,
    XLSX.utils.json_to_sheet(sanitized, { header: columns }),
    "Unidades",
  );
  return {
    bytes: XLSX.write(book, {
      type: "array",
      bookType: "xlsx",
      compression: true,
    }) as Uint8Array,
    mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    extension: "xlsx",
  };
}

export async function handler(request: Request) {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors(origin) });
  }
  if (request.method !== "POST") {
    return reply(origin, 405, { error: "method_not_allowed" });
  }
  const workerSecret = Deno.env.get("COELO_UNIT_EXPORT_WORKER_SECRET")?.trim();
  if (
    !workerSecret ||
    request.headers.get("x-coelo-worker-secret") !== workerSecret
  ) {
    return reply(origin, 403, { error: "worker_delegation_required" });
  }
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return reply(origin, 401, { error: "authentication_required" });
  }

  let createdJobId: string | null = null;
  let path: string | null = null;
  let completionAttempted = false;
  try {
    const body = (await request.json()) as Json;
    const url = Deno.env.get("SUPABASE_URL")!;
    const anon = Deno.env.get("SUPABASE_ANON_KEY")!;
    const user = createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
    });
    const admin = createClient(url, secret(), {
      auth: { persistSession: false },
    });

    if (body.action === "status") {
      const requestedJobId =
        typeof body.job_id === "string" && UUID.test(body.job_id)
          ? body.job_id
          : null;
      if (!requestedJobId) {
        return reply(origin, 400, { error: "invalid_request" });
      }
      const status = await user.rpc("superadmin_get_unit_file_job", {
        p_import_job_id: requestedJobId,
      });
      if (status.error) throw new Error("status_failed");
      const payload = status.data as Json;
      if (!validateExportStatusPayload(requestedJobId, payload)) {
        return reply(origin, 404, { error: "artifact_unavailable" });
      }
      const stored = (payload.summary as Json | undefined)?.storage_path;
      if (payload.state === "SUCESSO" && typeof stored === "string") {
        if (
          !validateExportArtifactPath(requestedJobId, stored, payload.format)
        ) {
          return reply(origin, 404, { error: "artifact_unavailable" });
        }
        const signed = await admin.storage.from(BUCKET).createSignedUrl(
          stored,
          300,
          { download: true },
        );
        if (!signed.error) {
          return reply(origin, 200, {
            ...payload,
            download_url: signed.data.signedUrl,
            expires_in: 300,
          });
        }
      }
      return reply(origin, 200, payload);
    }

    if (
      body.action !== "generate" || typeof body.idempotency_key !== "string" ||
      !UUID.test(body.idempotency_key)
    ) {
      return reply(origin, 400, { error: "invalid_request" });
    }

    const format = body.format === "csv" ? "csv" : "xlsx";
    const created = await user.rpc("superadmin_request_unit_export", {
      p_format: format,
      p_filters: body.filters ?? {},
      p_current_view: body.current_view ?? {},
      p_idempotency_key: body.idempotency_key,
    });
    createdJobId = captureCreatedJobId(created, "export_request_failed");

    const replayPath = successfulReplayArtifactPath(
      createdJobId,
      created.data,
      format,
    );
    if (replayPath) {
      await reauthorizeExportJob(user, createdJobId);
      return reply(origin, 200, created.data as Json);
    }

    const materialized = await admin.rpc(
      "superadmin_materialize_unit_export_from_edge",
      {
        p_export_job_id: createdJobId,
      },
    );
    if (materialized.error) throw new Error("export_snapshot_failed");

    const rows: Json[] = [];
    let afterOrdinal: number | null = null;
    while (true) {
      const page = await user.rpc("superadmin_unit_export_page_v2", {
        p_export_job_id: createdJobId,
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

    if (rows.length === 0) throw new Error("empty_export");
    const generated = artifact(rows, format);
    assertArtifactWithinLimit(generated.bytes);
    await reauthorizeExportJob(user, createdJobId);
    path = "exports/units/" + createdJobId + "/" + crypto.randomUUID() + "." +
      generated.extension;
    const upload = await admin.storage.from(BUCKET).upload(
      path,
      generated.bytes,
      {
        contentType: generated.mime,
        upsert: false,
        cacheControl: "no-store",
      },
    );
    if (upload.error) throw new Error("storage_upload_failed");

    await reauthorizeExportJob(user, createdJobId);
    completionAttempted = true;
    const completed = await admin.rpc("superadmin_complete_unit_file_job", {
      p_import_job_id: createdJobId,
      p_storage_path: path,
      p_file_name: "unidades." + generated.extension,
      p_mime_type: generated.mime,
      p_size_bytes: generated.bytes.length,
      p_checksum_sha256: await checksum(generated.bytes),
      p_row_count: rows.length,
    });
    if (completed.error) {
      throw new Error("export_complete_failed");
    }

    await reauthorizeExportJob(user, createdJobId);
    const signed = await admin.storage.from(BUCKET).createSignedUrl(path, 300, {
      download: true,
    });
    if (signed.error) throw new Error("signed_url_failed");
    return reply(origin, 200, {
      ...(completed.data as Json),
      download_url: signed.data.signedUrl,
      expires_in: 300,
    });
  } catch (error) {
    const code = error instanceof Error
      ? error.message.split(":")[0]
      : "worker_error";
    if (!completionAttempted) {
      await recordCreatedFailureBestEffort(createdJobId, async (jobId) => {
        const admin = createClient(Deno.env.get("SUPABASE_URL")!, secret(), {
          auth: { persistSession: false },
        });
        if (path) await admin.storage.from(BUCKET).remove([path]);
        const scope = await admin.from("import_jobs").select("request_id").eq(
          "id",
          jobId,
        ).single();
        if (scope.error || !scope.data?.request_id) {
          throw new Error("job_scope_unavailable");
        }
        await admin.rpc("superadmin_fail_unit_file_job", {
          p_import_job_id: jobId,
          p_error_code: code.slice(0, 80),
          p_expected_request_id: scope.data.request_id,
        });
      });
    }
    return reply(origin, code === "empty_export" ? 409 : 422, { error: code });
  }
}

if (import.meta.main) Deno.serve(handler);
