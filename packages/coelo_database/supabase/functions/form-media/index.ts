import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { R2Client, type R2Config, validateR2Config } from "../_shared/r2_s3.ts";
import {
  allowedOrigin,
  corsHeaders,
  type FormMediaEnvelope,
  type FormMediaRead,
  FORMS_BUCKET,
  handleCorsPreflight,
  MAX_IMAGE_BYTES,
  opaqueStoragePath,
  parseAssetAccess,
  parseFormMediaReadDescriptor,
  parseFormMediaReadGrant,
  parsePrepareAsset,
  readFormMediaEnvelope,
  sha256,
  shouldVerifyFinalization,
  sniffImageMime,
  workerFinalizationSucceeded,
} from "./media_contract.ts";

type Json = Record<string, unknown>;

export type FormMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
  now?: () => Date;
  createR2?: (config: R2Config) => Pick<R2Client, "presignGet">;
}>;
const productionDependencies: FormMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

function response(origin: string | null, status: number, body: Json): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "content-type": "application/json; charset=utf-8",
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
      ...corsHeaders(origin),
    },
  });
}

function serviceKey(dependencies: FormMediaDependencies): string {
  const configured = dependencies.envGet("SUPABASE_SECRET_KEYS") ?? "";
  if (configured.startsWith("{")) {
    try {
      const values = JSON.parse(configured) as Record<string, string>;
      if (values.default) return values.default;
    } catch {
      return "";
    }
  }
  return configured.split(",").map((value) => value.trim()).find(Boolean) ??
    dependencies.envGet("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

async function readInternalMedia(
  origin: string | null,
  payload: FormMediaRead,
  userClient: SupabaseClient,
  serviceClient: SupabaseClient,
  dependencies: FormMediaDependencies,
): Promise<Response> {
  try {
    const now = dependencies.now ?? (() => new Date());
    const authorized = await userClient.rpc(
      "superadmin_form_authorize_media_read_v2",
      { p_query: payload },
    );
    if (authorized.error) throw new Error("read_denied");
    const grant = parseFormMediaReadGrant(authorized.data, payload);
    if (!(grant.expiresAt > now().getTime())) throw new Error("read_expired");
    const redeemed = await serviceClient.rpc("form_redeem_media_read_r2_v1", {
      p_read_token: grant.readToken,
    });
    if (redeemed.error) throw new Error("read_denied");
    const descriptor = parseFormMediaReadDescriptor(redeemed.data, payload);
    const signingAt = now().getTime();
    const ttl = Math.min(
      120,
      Math.floor(
        (Math.min(grant.expiresAt, descriptor.expiresAt) - signingAt) / 1000,
      ),
    );
    if (!Number.isSafeInteger(ttl) || ttl < 1) throw new Error("read_expired");
    const config = validateR2Config({
      endpoint: dependencies.envGet("COELO_R2_ENDPOINT") ?? "",
      region: dependencies.envGet("COELO_R2_REGION") ?? "auto",
      accessKeyId: dependencies.envGet("COELO_R2_ACCESS_KEY_ID") ?? "",
      secretAccessKey: dependencies.envGet("COELO_R2_SECRET_ACCESS_KEY") ?? "",
      bucket: descriptor.bucket,
    });
    // S3 timestamps have second precision. Freeze the signing clock so the URL
    // and client ticket cannot outlive either independently authorized receipt.
    const expiresAt = Math.floor(signingAt / 1000) * 1000 + ttl * 1000;
    const r2 = dependencies.createR2?.(config) ??
      new R2Client(config, { now: () => new Date(signingAt) });
    const signed = await r2.presignGet(descriptor.objectKey, ttl);
    if (
      !(expiresAt > now().getTime()) || signed.url.protocol !== "https:" ||
      signed.url.username || signed.url.password || signed.url.hash
    ) throw new Error("read_unavailable");
    return response(origin, 200, {
      asset_id: payload.asset_id,
      state: "available",
      ticket: {
        url: signed.url.toString(),
        expires_at: new Date(expiresAt).toISOString(),
        headers: {},
      },
    });
  } catch {
    return response(origin, 404, { error: "media_unavailable" });
  }
}

export async function handleFormMediaRequest(
  request: Request,
  dependencies: FormMediaDependencies = productionDependencies,
): Promise<Response> {
  const origin = allowedOrigin(
    request,
    dependencies.envGet("COELO_ALLOWED_ORIGINS") ?? "",
  );
  const preflight = handleCorsPreflight(request, origin);
  if (preflight) return preflight;
  if (request.headers.has("origin") && !origin) {
    return response(origin, 403, { error: "request_denied" });
  }
  if (request.method !== "POST") {
    return response(origin, 405, { error: "method_not_allowed" });
  }
  const url = dependencies.envGet("SUPABASE_URL") ?? "";
  const anon = dependencies.envGet("SUPABASE_ANON_KEY") ?? "";
  const service = serviceKey(dependencies);
  const authorization = request.headers.get("authorization") ?? "";
  if (!url || !anon || !service || !authorization.startsWith("Bearer ")) {
    return response(origin, 401, { error: "unauthorized" });
  }
  let body: FormMediaEnvelope;
  try {
    body = await readFormMediaEnvelope(request);
  } catch {
    return response(origin, 400, { error: "invalid_request" });
  }
  try {
    const userClient = dependencies.createClient(url, anon, {
      global: { headers: { Authorization: authorization } },
    });
    const serviceClient = dependencies.createClient(url, service, {
      auth: { persistSession: false },
    });
    const { data: userData, error: userError } = await userClient.auth
      .getUser();
    if (userError || !userData.user) {
      return response(origin, 401, { error: "unauthorized" });
    }
    if (body.action === "read") {
      return await readInternalMedia(
        origin,
        body.payload,
        userClient,
        serviceClient,
        dependencies,
      );
    }
    const actorLookup = await serviceClient.from("person_auth_links").select(
      "person_id",
    )
      .eq("auth_user_id", userData.user.id).eq("status", "active")
      .maybeSingle();
    const actorPersonId = actorLookup.data?.person_id;
    if (actorLookup.error || typeof actorPersonId !== "string") {
      return response(origin, 401, { error: "unauthorized" });
    }

    const action = body.action;
    const requestId = body.request_id;
    const expectedVersion = body.expected_version;

    try {
      if (action === "prepare") {
        const payload = parsePrepareAsset(body.payload);
        const { data, error } = await userClient.rpc(
          "form_prepare_asset_upload",
          {
            p_request_id: requestId,
            p_expected_version: expectedVersion,
            p_payload: payload,
          },
        );
        if (error || !data || !opaqueStoragePath(data.storage_path)) {
          throw new Error("prepare_failed");
        }
        const signed = await serviceClient.storage.from(FORMS_BUCKET)
          .createSignedUploadUrl(data.storage_path);
        if (signed.error || !signed.data) throw new Error("sign_failed");
        return response(origin, 200, {
          asset_id: data.asset_id,
          signed_upload_url: signed.data.signedUrl,
          upload_token: signed.data.token,
          expires_at: data.expires_at,
        });
      }
      if (action === "finalize") {
        const payload = parseAssetAccess(body.payload);
        const queued = await userClient.rpc("form_finalize_asset_upload", {
          p_request_id: requestId,
          p_expected_version: expectedVersion,
          p_payload: payload,
        });
        if (queued.error) throw new Error("finalize_failed");
        const { data: metadata, error: authError } = await serviceClient.rpc(
          "form_media_authorize_for_worker",
          {
            p_asset_id: payload.asset_id,
            p_actor_person_id: actorPersonId,
            p_edit_secret: payload.edit_secret,
          },
        );
        if (
          authError || !metadata || !opaqueStoragePath(metadata.storage_path)
        ) {
          throw new Error("asset_unavailable");
        }
        if (!shouldVerifyFinalization(metadata.state)) {
          return response(origin, 200, {
            asset_id: payload.asset_id,
            state: "finalized",
          });
        }
        const downloaded = await serviceClient.storage.from(FORMS_BUCKET)
          .download(metadata.storage_path);
        if (
          downloaded.error || !downloaded.data ||
          downloaded.data.size > MAX_IMAGE_BYTES
        ) {
          throw new Error("asset_unavailable");
        }
        const bytes = new Uint8Array(await downloaded.data.arrayBuffer());
        const actualMimeType = sniffImageMime(bytes) ??
          "application/octet-stream";
        const finalized = await serviceClient.rpc(
          "form_worker_finalize_asset",
          {
            p_asset_id: payload.asset_id,
            p_actual_byte_length: bytes.byteLength,
            p_actual_mime_type: actualMimeType,
            p_actual_checksum_sha256: await sha256(bytes),
          },
        );
        if (finalized.error) throw new Error("verification_failed");
        if (!workerFinalizationSucceeded(finalized.data)) {
          throw new Error("verification_failed");
        }
        return response(origin, 200, finalized.data as Json);
      }
      if (action === "download") {
        const payload = parseAssetAccess(body.payload);
        const authorized = await serviceClient.rpc(
          "form_media_authorize_for_worker",
          {
            p_asset_id: payload.asset_id,
            p_actor_person_id: actorPersonId,
            p_edit_secret: payload.edit_secret,
          },
        );
        if (
          authorized.error || !authorized.data ||
          !opaqueStoragePath(authorized.data.storage_path)
        ) {
          throw new Error("asset_unavailable");
        }
        if (authorized.data.state !== "finalized") {
          throw new Error("asset_unavailable");
        }
        const signed = await serviceClient.storage.from(FORMS_BUCKET)
          .createSignedUrl(
            authorized.data.storage_path,
            60,
          );
        if (signed.error || !signed.data) throw new Error("sign_failed");
        return response(origin, 200, {
          signed_url: signed.data.signedUrl,
          expires_in: 60,
        });
      }
      if (action === "discard") {
        const payload = parseAssetAccess(body.payload);
        const discarded = await userClient.rpc("form_discard_asset", {
          p_request_id: requestId,
          p_expected_version: expectedVersion,
          p_payload: payload,
        });
        if (discarded.error) throw new Error("discard_failed");
        return response(origin, 200, discarded.data as Json);
      }
      return response(origin, 400, { error: "unknown_action" });
    } catch {
      return response(origin, 400, {
        error: "media_request_failed",
      });
    }
  } catch {
    return response(origin, 503, { error: "media_unavailable" });
  }
}

if (import.meta.main) Deno.serve((request) => handleFormMediaRequest(request));
