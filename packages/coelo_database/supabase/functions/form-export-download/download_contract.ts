export const DOWNLOAD_TTL_SECONDS = 300;
export const FORMS_EXPORT_BUCKET = "coelo-transient-prod";

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export function allowedOrigin(
  request: Request,
  configuredOrigins: string,
): string | null {
  const origin = request.headers.get("origin");
  if (!origin) return null;
  const allowed = configuredOrigins.split(",").map((value) => value.trim())
    .filter(Boolean);
  if (!allowed.includes(origin)) return null;
  try {
    return new URL(origin).origin === origin ? origin : null;
  } catch {
    return null;
  }
}

export function downloadHeaders(
  origin: string | null = null,
): Record<string, string> {
  return {
    "content-type": "application/json; charset=utf-8",
    "cache-control": "no-store",
    "x-content-type-options": "nosniff",
    "referrer-policy": "no-referrer",
    "access-control-allow-origin": origin ?? "null",
    "access-control-allow-headers":
      "authorization, x-client-info, apikey, content-type",
    "access-control-allow-methods": "POST, OPTIONS",
    "vary": "Origin",
  };
}

export function handleCorsPreflight(
  request: Request,
  origin: string | null,
): Response | null {
  if (request.method !== "OPTIONS") return null;
  return new Response(null, {
    status: origin ? 204 : 403,
    headers: downloadHeaders(origin),
  });
}

export function parseDownloadRequest(value: unknown): { job_id: string } {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_request");
  }
  const payload = value as Record<string, unknown>;
  if (
    Object.keys(payload).length !== 1 || typeof payload.job_id !== "string" ||
    !UUID.test(payload.job_id)
  ) {
    throw new Error("invalid_request");
  }
  return { job_id: payload.job_id };
}

export function validSignedDownload(value: unknown): value is string {
  if (typeof value !== "string") return false;
  try {
    const url = new URL(value);
    return url.protocol === "https:" && !!url.hostname && !url.username &&
      !url.password && !url.hash && !value.includes("#");
  } catch {
    return false;
  }
}

export function effectiveDownloadTtl(
  expiresAt: unknown,
  nowMs = Date.now(),
): number | null {
  if (typeof expiresAt !== "string") return null;
  const expiresMs = Date.parse(expiresAt);
  if (!Number.isFinite(expiresMs) || !Number.isFinite(nowMs)) return null;
  const remainingSeconds = Math.floor((expiresMs - nowMs) / 1000);
  if (remainingSeconds <= 0) return null;
  return Math.min(DOWNLOAD_TTL_SECONDS, remainingSeconds);
}

export function downloadToken(value: unknown): string | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const token = (value as Record<string, unknown>).download_token;
  return typeof token === "string" && UUID.test(token) ? token : null;
}

export function storagePath(value: unknown): string | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const path = (value as Record<string, unknown>).storage_path;
  return typeof path === "string" && /^[0-9a-f]{2}\/[0-9a-f-]{36}$/.test(path)
    ? path
    : null;
}

export type R2ExportArtifact = Readonly<{
  job_id: string;
  institution_id: string;
  asset_id: string;
  object_key: string;
  expires_at: string;
}>;

export function r2ExportArtifact(
  value: unknown,
  jobId: string,
): R2ExportArtifact | null {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const artifact = value as Record<string, unknown>;
  if (
    artifact.job_id !== jobId || !UUID.test(jobId) ||
    typeof artifact.institution_id !== "string" ||
    !UUID.test(artifact.institution_id) ||
    typeof artifact.asset_id !== "string" || !UUID.test(artifact.asset_id) ||
    artifact.provider !== "r2" || artifact.bucket !== FORMS_EXPORT_BUCKET ||
    artifact.export_kind !== "xlsx" ||
    artifact.purpose !== "forms-responses-export" ||
    artifact.state !== "ready" ||
    artifact.object_key !==
      `tenants/${artifact.institution_id}/exports/forms/${jobId}/responses.xlsx` ||
    typeof artifact.expires_at !== "string"
  ) return null;
  return {
    job_id: jobId,
    institution_id: artifact.institution_id,
    asset_id: artifact.asset_id,
    object_key: artifact.object_key as string,
    expires_at: artifact.expires_at,
  };
}

export async function readDownloadRequest(
  request: Request,
): Promise<{ job_id: string }> {
  const reader = request.body?.getReader();
  if (!reader) throw new Error("invalid_request");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 4096) throw new Error("invalid_request");
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    return parseDownloadRequest(
      JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)),
    );
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
