import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { R2Client, type R2Config, validateR2Config } from "../_shared/r2_s3.ts";
import { imageDimensions } from "../_shared/image_dimensions.ts";
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
  createR2Writer?: (
    config: R2Config,
  ) => Pick<R2Client, "presignPut" | "presignGet" | "head" | "get" | "delete">;
}>;

// R05 realm-interno: uploads de resposta no R2 (ADR 0032) atras da chave
// COELO_FORMS_MEDIA_PROVIDER=r2. Sem a chave o fluxo legado (Supabase Storage)
// continua igual; com ela, prepare/finalize/download usam o catalogo privado
// (form_prepare_asset_upload_r2_v1, form_asset_r2_descriptor_v1,
// form_media_finalize_answer_r2_v1) e o bucket coelo-media-prod.
function r2Enabled(dependencies: FormMediaDependencies): boolean {
  return dependencies.envGet("COELO_FORMS_MEDIA_PROVIDER") === "r2";
}

function r2Writer(dependencies: FormMediaDependencies, bucket: string) {
  const config = validateR2Config({
    endpoint: dependencies.envGet("COELO_R2_ENDPOINT") ?? "",
    region: dependencies.envGet("COELO_R2_REGION") ?? "auto",
    accessKeyId: dependencies.envGet("COELO_R2_ACCESS_KEY_ID") ?? "",
    secretAccessKey: dependencies.envGet("COELO_R2_SECRET_ACCESS_KEY") ?? "",
    bucket,
  });
  return dependencies.createR2Writer?.(config) ?? new R2Client(config);
}

const R2_QUESTION_KEY =
  /^tenants\/[0-9a-f-]{36}\/forms\/form\/[0-9a-f-]{36}\/question-image\/[0-9a-f-]{36}\/original\/[0-9a-f-]{36}\.(jpg|png|webp)$/;

function r2QuestionKey(value: unknown): value is string {
  return typeof value === "string" && R2_QUESTION_KEY.test(value);
}

// Imagem de pergunta (Superadmin, realm interno): as RPCs do usuario ja
// autorizam por forms.manage/forms.read e escopo; o gateway so assina e mede.
async function questionMedia(
  origin: string | null,
  body: Extract<FormMediaEnvelope, { action: `question_${string}` }>,
  userClient: SupabaseClient,
  serviceClient: SupabaseClient,
  dependencies: FormMediaDependencies,
): Promise<Response> {
  try {
    if (body.action === "question_prepare") {
      const payload = body.payload;
      const prepared = await userClient.rpc("superadmin_form_media_prepare_v2", {
        p_request_id: body.request_id,
        p_form_id: payload.form_id,
        p_form_version_id: payload.form_version_id,
        p_item_id: payload.item_id,
        p_mime_type: payload.mime_type,
        p_byte_size: payload.byte_length,
        p_sha256: payload.checksum,
      });
      if (prepared.error) throw new Error("prepare_failed");
      const data = unwrapEnvelope(prepared.data);
      if (!r2QuestionKey(data.object_key)) throw new Error("prepare_failed");
      const signed = await r2Writer(dependencies, String(data.bucket)).presignPut(
        data.object_key,
        payload.mime_type,
        300,
      );
      return response(origin, 200, {
        asset_id: data.asset_id,
        upload_url: signed.url.toString(),
        required_headers: signed.requiredHeaders,
        expires_at: data.expires_at,
        storage_provider: "r2",
      });
    }
    if (body.action === "question_finalize") {
      const authorized = await userClient.rpc(
        "superadmin_form_media_authorize_finalize_v2",
        { p_asset_id: body.payload.asset_id },
      );
      if (authorized.error) throw new Error("asset_unavailable");
      const ticket = unwrapEnvelope(authorized.data);
      if (!r2QuestionKey(ticket.object_key)) throw new Error("asset_unavailable");
      const writer = r2Writer(dependencies, String(ticket.bucket));
      const stored = await writer.head(ticket.object_key);
      if (stored.byteSize < 1 || stored.byteSize > 4 * 1024 * 1024) {
        await writer.delete(ticket.object_key).catch(() => {});
        throw new Error("asset_unavailable");
      }
      const bytes = await writer.get(ticket.object_key, stored.byteSize);
      const expectedMime = String(ticket.mime_type);
      const dimensions = sniffImageMime(bytes) === expectedMime
        ? imageDimensions(bytes, expectedMime)
        : null;
      const finalized = await serviceClient.rpc("form_media_finalize_question_r2_v1", {
        p_asset_id: ticket.asset_id,
        p_finalize_ticket: ticket.finalize_ticket,
        p_byte_size: bytes.byteLength,
        p_checksum_sha256: await sha256(bytes),
        p_pixel_width: dimensions?.width ?? null,
        p_pixel_height: dimensions?.height ?? null,
      });
      if (finalized.error) throw new Error("verification_failed");
      const outcome = finalized.data as Record<string, unknown> | null;
      if (!outcome || outcome.ok !== true) {
        await writer.delete(ticket.object_key).catch(() => {});
        throw new Error("verification_failed");
      }
      return response(origin, 200, outcome.data as Json);
    }
    if (body.action === "question_resolve") {
      const resolved = await userClient.rpc("superadmin_form_media_resolve_v2", {
        p_asset_id: body.payload.asset_id,
      });
      if (resolved.error) throw new Error("asset_unavailable");
      const descriptor = unwrapEnvelope(resolved.data);
      if (!r2QuestionKey(descriptor.object_key)) throw new Error("asset_unavailable");
      const ttl = Math.min(300, Number(descriptor.ttl_seconds ?? 300));
      const signed = await r2Writer(dependencies, String(descriptor.bucket)).presignGet(
        descriptor.object_key,
        ttl,
      );
      return response(origin, 200, {
        asset_id: descriptor.asset_id,
        signed_url: signed.url.toString(),
        mime_type: descriptor.mime_type,
        expires_in: ttl,
      });
    }
    const deleted = await userClient.rpc("superadmin_form_media_delete_v2", {
      p_request_id: body.request_id,
      p_asset_id: body.payload.asset_id,
    });
    if (deleted.error) throw new Error("discard_failed");
    return response(origin, 200, unwrapEnvelope(deleted.data) as Json);
  } catch {
    return response(origin, 400, { error: "media_request_failed" });
  }
}

const R2_ANSWER_KEY =
  /^tenants\/[0-9a-f-]{36}\/forms\/form\/[0-9a-f-]{36}\/answer-image\/[0-9a-f-]{36}\/original\/[0-9a-f-]{36}\.(jpg|png|webp)$/;

function r2ObjectKey(value: unknown): value is string {
  return typeof value === "string" && R2_ANSWER_KEY.test(value);
}

function unwrapEnvelope(value: unknown): Record<string, unknown> {
  const envelope = value as Record<string, unknown> | null;
  if (!envelope || envelope.ok !== true || !envelope.data) {
    throw new Error("asset_unavailable");
  }
  return envelope.data as Record<string, unknown>;
}
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
  let body: FormMediaEnvelope;
  try {
    body = await readFormMediaEnvelope(request);
  } catch {
    return response(origin, 400, { error: "invalid_request" });
  }
  if (body.action === "expire") {
    // Cron (Vault forms_media_worker_secret) -> expira pendentes e apaga no R2 o
    // que a fila de limpeza entregar; sem JWT de usuario.
    const secret = dependencies.envGet("FORMS_MEDIA_WORKER_SECRET") ?? "";
    if (!url || !service || !secret || request.headers.get("x-worker-secret") !== secret) {
      return response(origin, 401, { error: "unauthorized" });
    }
    try {
      const serviceClient = dependencies.createClient(url, service, { auth: { persistSession: false } });
      const expired = await serviceClient.rpc("form_media_expire_question_r2_v1", { p_limit: 100 });
      const claimed = await serviceClient.rpc("form_media_claim_cleanup_r2_v1", { p_limit: 50 });
      if (expired.error || claimed.error) throw new Error("expire_failed");
      const items = (unwrapEnvelope(claimed.data).items ?? []) as Record<string, unknown>[];
      let purged = 0;
      for (const item of items) {
        const writer = r2Writer(dependencies, String(item.bucket));
        await writer.delete(String(item.object_key));
        const marked = await serviceClient.rpc("form_media_mark_purged_r2_v1", { p_cleanup_id: item.cleanup_id });
        if (marked.error) throw new Error("expire_failed");
        purged++;
      }
      return response(origin, 200, {
        expired: unwrapEnvelope(expired.data).expired ?? 0,
        purged,
      });
    } catch {
      return response(origin, 400, { error: "media_request_failed" });
    }
  }
  const authorization = request.headers.get("authorization") ?? "";
  if (!url || !anon || !service || !authorization.startsWith("Bearer ")) {
    return response(origin, 401, { error: "unauthorized" });
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
    if (
      body.action === "question_prepare" || body.action === "question_finalize" ||
      body.action === "question_resolve" || body.action === "question_delete"
    ) {
      return await questionMedia(origin, body, userClient, serviceClient, dependencies);
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
    if (!("expected_version" in body)) {
      return response(origin, 400, { error: "unknown_action" });
    }
    const legacy = body;
    const actorLookup = await serviceClient.from("person_auth_links").select(
      "person_id",
    )
      .eq("auth_user_id", userData.user.id).eq("status", "active")
      .maybeSingle();
    const actorPersonId = actorLookup.data?.person_id;
    if (actorLookup.error || typeof actorPersonId !== "string") {
      return response(origin, 401, { error: "unauthorized" });
    }

    const action = legacy.action;
    const requestId = legacy.request_id;
    const expectedVersion = legacy.expected_version;

    try {
      if (action === "prepare" && r2Enabled(dependencies)) {
        const payload = parsePrepareAsset(legacy.payload);
        const { data, error } = await userClient.rpc(
          "form_prepare_asset_upload_r2_v1",
          {
            p_request_id: requestId,
            p_expected_version: expectedVersion,
            p_payload: payload,
          },
        );
        if (
          error || !data || !r2ObjectKey(data.object_key) ||
          data.bucket !== "coelo-media-prod"
        ) throw new Error("prepare_failed");
        const signed = await r2Writer(dependencies, data.bucket).presignPut(
          data.object_key,
          payload.mime_type,
          300,
        );
        return response(origin, 200, {
          asset_id: data.asset_id,
          upload_url: signed.url.toString(),
          required_headers: signed.requiredHeaders,
          expires_at: data.expires_at,
          storage_provider: "r2",
        });
      }
      if (action === "prepare") {
        const payload = parsePrepareAsset(legacy.payload);
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
      if (action === "finalize" && r2Enabled(dependencies)) {
        const payload = parseAssetAccess(legacy.payload);
        // O usuario confirma o upload pelo legado (autoriza dono/segredo).
        const queued = await userClient.rpc("form_finalize_asset_upload", {
          p_request_id: requestId,
          p_expected_version: expectedVersion,
          p_payload: payload,
        });
        if (queued.error) throw new Error("finalize_failed");
        const described = await serviceClient.rpc("form_asset_r2_descriptor_v1", {
          p_asset_id: payload.asset_id,
        });
        if (described.error) throw new Error("asset_unavailable");
        const descriptor = unwrapEnvelope(described.data);
        if (!r2ObjectKey(descriptor.object_key)) throw new Error("asset_unavailable");
        if (descriptor.state === "finalized" && descriptor.media_status === "ready") {
          return response(origin, 200, { asset_id: payload.asset_id, state: "finalized" });
        }
        const expectedBytes = Number(descriptor.expected_byte_size);
        const expectedMime = String(descriptor.mime_type);
        const writer = r2Writer(dependencies, String(descriptor.bucket));
        const stored = await writer.head(descriptor.object_key);
        if (stored.byteSize !== expectedBytes || stored.byteSize > MAX_IMAGE_BYTES) {
          await writer.delete(descriptor.object_key).catch(() => {});
          throw new Error("asset_unavailable");
        }
        const bytes = await writer.get(descriptor.object_key, expectedBytes);
        const actualMimeType = sniffImageMime(bytes) ?? "application/octet-stream";
        const dimensions = actualMimeType === expectedMime
          ? imageDimensions(bytes, expectedMime)
          : null;
        const finalized = await serviceClient.rpc("form_media_finalize_answer_r2_v1", {
          p_asset_id: payload.asset_id,
          p_byte_size: bytes.byteLength,
          p_checksum_sha256: await sha256(bytes),
          p_pixel_width: dimensions?.width ?? null,
          p_pixel_height: dimensions?.height ?? null,
        });
        if (finalized.error) throw new Error("verification_failed");
        const outcome = finalized.data as Record<string, unknown> | null;
        if (!outcome || outcome.ok !== true) {
          // O banco ja descartou o legado e enfileirou a limpeza; o objeto sai.
          await writer.delete(descriptor.object_key).catch(() => {});
          throw new Error("verification_failed");
        }
        return response(origin, 200, {
          asset_id: payload.asset_id,
          state: "finalized",
          media_asset_id: (outcome.data as Record<string, unknown>).media_asset_id,
        });
      }
      if (action === "download" && r2Enabled(dependencies)) {
        const payload = parseAssetAccess(legacy.payload);
        const authorized = await serviceClient.rpc(
          "form_media_authorize_for_worker",
          {
            p_asset_id: payload.asset_id,
            p_actor_person_id: actorPersonId,
            p_edit_secret: payload.edit_secret,
          },
        );
        if (authorized.error || !authorized.data || authorized.data.state !== "finalized") {
          throw new Error("asset_unavailable");
        }
        const described = await serviceClient.rpc("form_asset_r2_descriptor_v1", {
          p_asset_id: payload.asset_id,
        });
        if (described.error) throw new Error("asset_unavailable");
        const descriptor = unwrapEnvelope(described.data);
        if (!r2ObjectKey(descriptor.object_key) || descriptor.media_status !== "ready") {
          throw new Error("asset_unavailable");
        }
        const signed = await r2Writer(dependencies, String(descriptor.bucket)).presignGet(
          descriptor.object_key,
          60,
        );
        return response(origin, 200, {
          signed_url: signed.url.toString(),
          expires_in: 60,
        });
      }
      if (action === "finalize") {
        const payload = parseAssetAccess(legacy.payload);
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
        const payload = parseAssetAccess(legacy.payload);
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
        const payload = parseAssetAccess(legacy.payload);
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
