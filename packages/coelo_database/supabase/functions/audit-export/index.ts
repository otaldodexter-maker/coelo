import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { type AuditRow, buildAuditArtifact } from "./artifact.ts";

const BUCKET = "coelo-operations";
const MAX_ROWS = 50_000;
const MAX_BYTES = 5 * 1024 * 1024;
const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
type Json = Record<string, unknown>;

function cors(origin: string | null): HeadersInit {
  const configured = (Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "").split(",")
    .map((v) => v.trim()).filter(Boolean);
  const localEnabled = Deno.env.get("COELO_ALLOW_LOCAL_ORIGINS") === "true";
  const local = localEnabled &&
    (origin?.startsWith("http://127.0.0.1:") ||
      origin?.startsWith("http://localhost:"));
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

function serverSecret() {
  const set = Deno.env.get("SUPABASE_SECRET_KEYS");
  if (set) {
    const parsed = JSON.parse(set) as Record<string, string>;
    if (parsed.default) return parsed.default;
  }
  const legacy = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!legacy) throw new Error("server_secret_unavailable");
  return legacy;
}

async function sha256(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return [...new Uint8Array(digest)].map((value) =>
    value.toString(16).padStart(2, "0")
  ).join("");
}

async function cleanupExpired(admin: SupabaseClient) {
  const candidates = await admin.rpc("audit_expired_artifacts_for_worker", {
    p_limit: 10,
  });
  if (candidates.error || !Array.isArray(candidates.data)) return;
  for (const candidate of candidates.data as Json[]) {
    const jobId = candidate.job_id;
    const path = candidate.storage_path;
    if (
      typeof jobId !== "string" || !UUID.test(jobId) || typeof path !== "string"
    ) continue;
    const removed = await admin.storage.from(BUCKET).remove([path]);
    if (!removed.error) {
      await admin.rpc("audit_expire_export_for_worker", {
        p_export_job_id: jobId,
        p_storage_path: path,
      });
    }
  }
}

async function authorizeDownload(user: SupabaseClient, jobId: string) {
  const authorized = await user.rpc(
    "audit_authorize_export_download_for_superadmin",
    { p_export_job_id: jobId },
  );
  if (authorized.error || !authorized.data) {
    throw new Error("export_unavailable");
  }
  const payload = authorized.data as Json;
  if (typeof payload.storage_path !== "string") {
    throw new Error("export_unavailable");
  }
  return payload;
}

async function signedDownload(
  user: SupabaseClient,
  admin: SupabaseClient,
  jobId: string,
) {
  const artifact = await authorizeDownload(user, jobId);
  const signed = await admin.storage.from(BUCKET).createSignedUrl(
    String(artifact.storage_path),
    300,
    { download: true },
  );
  if (signed.error) throw new Error("signed_url_failed");
  return { artifact, url: signed.data.signedUrl };
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: cors(origin) });
  }
  if (request.method !== "POST") {
    return reply(origin, 405, { error: "method_not_allowed" });
  }
  const contentLength = Number(request.headers.get("content-length") ?? "0");
  if (!Number.isFinite(contentLength) || contentLength > 32_768) {
    return reply(origin, 413, { error: "request_too_large" });
  }
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return reply(origin, 401, { error: "authentication_required" });
  }

  let jobId: string | null = null;
  let storagePath: string | null = null;
  let workerToken: string | null = null;
  let generating = false;
  let completedSuccessfully = false;
  try {
    const rawBody = await request.text();
    if (new TextEncoder().encode(rawBody).length > 32_768) {
      return reply(origin, 413, { error: "request_too_large" });
    }
    const body = JSON.parse(rawBody) as Json;
    const url = Deno.env.get("SUPABASE_URL")!;
    const publishable = Deno.env.get("SUPABASE_ANON_KEY")!;
    const user = createClient(url, publishable, {
      global: { headers: { Authorization: authorization } },
    });
    const admin = createClient(url, serverSecret(), {
      auth: { persistSession: false },
    });

    if (body.action === "status") {
      jobId = typeof body.job_id === "string" && UUID.test(body.job_id)
        ? body.job_id
        : null;
      if (!jobId) return reply(origin, 400, { error: "invalid_request" });
      const status = await user.rpc("audit_get_export_job_for_superadmin", {
        p_export_job_id: jobId,
      });
      if (status.error || !status.data) {
        return reply(origin, 404, { error: "export_unavailable" });
      }
      await cleanupExpired(admin);
      const payload = status.data as Json;
      if (payload.state !== "SUCESSO") return reply(origin, 200, payload);
      const download = await signedDownload(user, admin, jobId);
      return reply(origin, 200, {
        ...payload,
        download_url: download.url,
        expires_in: 300,
      });
    }

    if (
      body.action !== "generate" || typeof body.idempotency_key !== "string" ||
      !UUID.test(body.idempotency_key) ||
      (body.format !== "csv" && body.format !== "xlsx") ||
      typeof body.filters !== "object" || body.filters === null ||
      Array.isArray(body.filters)
    ) {
      return reply(origin, 400, { error: "invalid_request" });
    }
    generating = true;
    const created = await user.rpc("audit_start_export_for_superadmin", {
      p_format: body.format,
      p_filters: body.filters,
      p_idempotency_key: body.idempotency_key,
    });
    if (created.error) throw new Error("export_request_failed");
    jobId = String((created.data as Json).job_id);
    await cleanupExpired(admin);

    if ((created.data as Json).state === "SUCESSO") {
      const download = await signedDownload(user, admin, jobId);
      return reply(origin, 200, {
        ...(created.data as Json),
        row_count: download.artifact.row_count,
        download_url: download.url,
        expires_in: 300,
      });
    }

    workerToken = crypto.randomUUID();
    const materialized = await admin.rpc(
      "audit_materialize_export_for_worker",
      { p_export_job_id: jobId, p_worker_token: workerToken },
    );
    if (materialized.error) throw new Error("export_snapshot_failed");
    if ((materialized.data as Json).state === "SUCESSO") {
      const download = await signedDownload(user, admin, jobId);
      return reply(origin, 200, {
        ...(created.data as Json),
        state: "SUCESSO",
        row_count: download.artifact.row_count,
        download_url: download.url,
        expires_in: 300,
      });
    }
    if ((materialized.data as Json).claimed !== true) {
      return reply(origin, 202, {
        ...(created.data as Json),
        state: "PROCESSANDO",
      });
    }
    if (Number((materialized.data as Json).row_count ?? 0) === 0) {
      throw new Error("empty_export");
    }

    const rows: AuditRow[] = [];
    let afterOrdinal: number | null = null;
    while (true) {
      const page = await admin.rpc("audit_export_page_for_worker", {
        p_export_job_id: jobId,
        p_worker_token: workerToken,
        p_after_ordinal: afterOrdinal,
        p_page_size: 500,
      });
      if (page.error) throw new Error("export_page_failed");
      const payload = page.data as Json;
      const items = Array.isArray(payload.items)
        ? payload.items as AuditRow[]
        : [];
      rows.push(...items);
      if (rows.length > MAX_ROWS) throw new Error("export_too_large");
      const next = payload.next_cursor as Json | undefined;
      if (payload.has_more !== true || typeof next?.ordinal !== "number") break;
      afterOrdinal = next.ordinal;
    }

    const generated = buildAuditArtifact(rows, body.format);
    if (generated.bytes.length > MAX_BYTES) throw new Error("export_too_large");
    storagePath =
      `exports/audit/${jobId}/${crypto.randomUUID()}.${generated.extension}`;
    const upload = await admin.storage.from(BUCKET).upload(
      storagePath,
      generated.bytes,
      {
        contentType: generated.mime,
        cacheControl: "no-store",
        upsert: false,
      },
    );
    if (upload.error) throw new Error("storage_upload_failed");
    const completed = await admin.rpc("audit_complete_export_for_worker", {
      p_export_job_id: jobId,
      p_worker_token: workerToken,
      p_storage_path: storagePath,
      p_file_name: `auditoria.${generated.extension}`,
      p_mime_type: generated.mime,
      p_size_bytes: generated.bytes.length,
      p_checksum_sha256: await sha256(generated.bytes),
      p_row_count: rows.length,
    });
    if (completed.error) throw new Error("export_complete_failed");
    completedSuccessfully = true;
    const download = await signedDownload(user, admin, jobId);
    return reply(origin, 200, {
      ...(completed.data as Json),
      download_url: download.url,
      expires_in: 300,
    });
  } catch (error) {
    const code = error instanceof Error
      ? error.message.split(":")[0].replace(/[^a-z0-9_]/g, "_").slice(0, 80)
      : "worker_error";
    if (generating && jobId && workerToken) {
      try {
        const admin = createClient(
          Deno.env.get("SUPABASE_URL")!,
          serverSecret(),
          { auth: { persistSession: false } },
        );
        if (!completedSuccessfully) {
          const durable = await admin.rpc("audit_export_artifact_for_worker", {
            p_export_job_id: jobId,
          });
          completedSuccessfully = !durable.error && durable.data !== null;
        }
        if (!completedSuccessfully) {
          if (storagePath) {
            await admin.storage.from(BUCKET).remove([storagePath]);
          }
          await admin.rpc("audit_fail_export_for_worker", {
            p_export_job_id: jobId,
            p_worker_token: workerToken,
            p_error_code: code,
          });
        }
      } catch {
        // Best-effort cleanup; the pending job remains visible instead of claiming success.
      }
    }
    const status = code === "empty_export"
      ? 409
      : code === "export_unavailable" || code === "artifact_expired"
      ? 404
      : 422;
    return reply(origin, status, { error: code });
  }
});
