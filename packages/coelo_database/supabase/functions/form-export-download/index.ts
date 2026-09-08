import { createClient } from "@supabase/supabase-js";
import { R2Client } from "../_shared/r2_s3.ts";
import {
  allowedOrigin,
  downloadHeaders,
  downloadToken,
  effectiveDownloadTtl,
  FORMS_EXPORT_BUCKET,
  handleCorsPreflight,
  r2ExportArtifact,
  readDownloadRequest,
  validSignedDownload,
} from "./download_contract.ts";

type Environment = Record<string, string | undefined>;
type Json = Record<string, unknown>;
export type FormExportDownloadDependencies = Readonly<{
  environment: () => Environment;
  createClient: typeof createClient;
  now: () => Date;
  createR2: (
    environment: Environment,
    signedAt: Date,
  ) => Pick<R2Client, "presignGet">;
}>;
const productionDependencies: FormExportDownloadDependencies = {
  environment: () => Deno.env.toObject(),
  createClient,
  now: () => new Date(),
  createR2: (environment, signedAt) =>
    new R2Client({
      endpoint: environment.COELO_R2_ENDPOINT ?? "",
      region: environment.COELO_R2_REGION ?? "auto",
      accessKeyId: environment.COELO_R2_ACCESS_KEY_ID ?? "",
      secretAccessKey: environment.COELO_R2_SECRET_ACCESS_KEY ?? "",
      bucket: FORMS_EXPORT_BUCKET,
    }, { now: () => signedAt }),
};
const reply = (origin: string | null, status: number, body: Json) =>
  new Response(JSON.stringify(body), {
    status,
    headers: downloadHeaders(origin),
  });

function serviceKey(environment: Environment): string {
  const configured = environment.SUPABASE_SECRET_KEYS ?? "";
  if (configured.startsWith("{")) {
    try {
      return (JSON.parse(configured) as Record<string, string>).default ?? "";
    } catch {
      return "";
    }
  }
  return configured.split(",").map((value) => value.trim()).find(Boolean) ??
    environment.SUPABASE_SERVICE_ROLE_KEY ?? "";
}

export async function handleFormExportDownloadRequest(
  request: Request,
  dependencies: FormExportDownloadDependencies = productionDependencies,
): Promise<Response> {
  let origin: string | null = null;
  try {
    const environment = dependencies.environment();
    origin = allowedOrigin(request, environment.COELO_ALLOWED_ORIGINS ?? "");
    const preflight = handleCorsPreflight(request, origin);
    if (preflight) return preflight;
    if (request.headers.has("origin") && !origin) {
      return reply(origin, 403, { error: "request_denied" });
    }
    if (request.method !== "POST") {
      return reply(origin, 405, { error: "method_not_allowed" });
    }
    const authorization = request.headers.get("authorization") ?? "";
    const url = environment.SUPABASE_URL ?? "",
      anon = environment.SUPABASE_ANON_KEY ?? "",
      service = serviceKey(environment);
    if (!/^Bearer \S+$/.test(authorization) || !url || !anon || !service) {
      return reply(origin, 401, { error: "unauthorized" });
    }
    let jobId: string;
    try {
      jobId = (await readDownloadRequest(request)).job_id.toLowerCase();
    } catch {
      return reply(origin, 400, { error: "invalid_request" });
    }

    const user = dependencies.createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const authorized = await user.rpc(
      "superadmin_form_authorize_xlsx_download_v2",
      { p_file_job_id: jobId },
    );
    const envelope = authorized.data as { ok?: unknown; data?: Json } | null;
    const grant = !authorized.error && envelope?.ok === true
      ? envelope.data
      : null;
    const token = grant?.job_id === jobId ? downloadToken(grant) : null;
    if (
      !token || !grant ||
      effectiveDownloadTtl(grant.expires_at, dependencies.now().getTime()) ===
        null
    ) {
      return reply(origin, 404, { error: "export_unavailable" });
    }
    const admin = dependencies.createClient(url, service, {
      auth: { persistSession: false },
    });
    const redeemed = await admin.rpc("form_redeem_xlsx_download_r2_v1", {
      p_download_token: token,
    });
    const artifact = redeemed.error
      ? null
      : r2ExportArtifact(redeemed.data, jobId);
    const signedAt = dependencies.now();
    const expiry = artifact
      ? Math.min(
        Date.parse(artifact.expires_at),
        Date.parse(grant.expires_at as string),
      )
      : NaN;
    const ttl = Number.isFinite(expiry)
      ? effectiveDownloadTtl(new Date(expiry).toISOString(), signedAt.getTime())
      : null;
    if (!artifact || ttl === null) {
      return reply(origin, 404, { error: "export_unavailable" });
    }
    const signed = await dependencies.createR2(environment, signedAt)
      .presignGet(artifact.object_key, ttl);
    const expiresAt = new Date(signedAt.getTime() + ttl * 1000);
    if (
      !validSignedDownload(signed.url.toString()) ||
      expiresAt.getTime() <= dependencies.now().getTime()
    ) {
      return reply(origin, 404, { error: "export_unavailable" });
    }
    return reply(origin, 200, {
      job_id: jobId,
      download_url: signed.url.toString(),
      expires_at: expiresAt.toISOString(),
    });
  } catch {
    return reply(origin, 503, { error: "service_unavailable" });
  }
}

if (import.meta.main) {
  Deno.serve((request) => handleFormExportDownloadRequest(request));
}
