import { createClient } from "@supabase/supabase-js";
import {
  R2Client,
  type R2Config,
  R2TransportError,
  validateR2Config,
} from "../_shared/r2_s3.ts";

const DEFAULT_MAX_BYTES = 10 * 1024 * 1024;
const ALLOWED = new Set(["image/jpeg", "image/png", "image/webp", "video/mp4"]);
const uploadTtlSeconds = 300;
const readTtlSeconds = 60;
type Json = Record<string, unknown>;

export type HappensMediaTransport = Pick<
  R2Client,
  "presignGet" | "presignPut" | "get" | "delete"
>;

export type HappensMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
  createR2?: (config: R2Config) => HappensMediaTransport;
}>;

const productionDependencies: HappensMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

function maxBytes(dependencies: HappensMediaDependencies) {
  const value = Number(
    dependencies.envGet("HAPPENS_MEDIA_MAX_BYTES") ?? DEFAULT_MAX_BYTES,
  );
  return Number.isSafeInteger(value) && value > 0 ? value : DEFAULT_MAX_BYTES;
}

function allowedOrigins(dependencies: HappensMediaDependencies) {
  return new Set(
    (dependencies.envGet("HAPPENS_MEDIA_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

/** Credenciais R2 existem somente aqui, no servidor. Elas nunca entram em log,
 * em corpo de resposta ou em qualquer superficie cliente; a unica coisa que
 * atravessa a fronteira e uma URL assinada de vida curta. */
function transportFor(
  dependencies: HappensMediaDependencies,
  bucket: string,
): HappensMediaTransport {
  const config = validateR2Config({
    endpoint: dependencies.envGet("COELO_R2_ENDPOINT") ?? "",
    region: dependencies.envGet("COELO_R2_REGION") ?? "auto",
    accessKeyId: dependencies.envGet("COELO_R2_ACCESS_KEY_ID") ?? "",
    secretAccessKey: dependencies.envGet("COELO_R2_SECRET_ACCESS_KEY") ?? "",
    bucket,
  });
  return dependencies.createR2?.(config) ?? new R2Client(config);
}

/** Falha de transporte nunca revela bucket, chave, provedor ou existencia. */
function opaqueTransport(error: unknown): never {
  if (error instanceof R2TransportError) {
    throw new Error("media_transport_failed");
  }
  throw error;
}

/** O servidor escolhe o provedor; o cliente apenas obedece ao envelope. */
function usesR2(descriptor: Json) {
  return descriptor.storage_provider === "r2";
}

function descriptorBucket(descriptor: Json) {
  const bucket = descriptor.bucket_id;
  if (typeof bucket !== "string" || !bucket) {
    throw new Error("media_descriptor_invalid");
  }
  return bucket;
}

function reply(
  dependencies: HappensMediaDependencies,
  origin: string | null,
  status: number,
  body: Json,
) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins(dependencies).has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function secret(dependencies: HappensMediaDependencies) {
  const value = dependencies.envGet("SUPABASE_SERVICE_ROLE_KEY");
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function validSignature(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mime === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mime === "image/webp") {
    return new TextDecoder().decode(bytes.slice(0, 4)) === "RIFF" &&
      new TextDecoder().decode(bytes.slice(8, 12)) === "WEBP";
  }
  return mime === "video/mp4" &&
    new TextDecoder().decode(bytes.slice(4, 8)) === "ftyp";
}

async function checksum(bytes: Uint8Array) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return [...new Uint8Array(digest)]
    .map((value) => value.toString(16).padStart(2, "0"))
    .join("");
}

function uploadEnvelope(body: Json, dependencies: HappensMediaDependencies) {
  if (
    typeof body.request_id !== "string" || body.request_id.length < 1 ||
    body.request_id.length > 240 ||
    typeof body.institution_id !== "string" ||
    typeof body.post_id !== "string" ||
    typeof body.name !== "string" || body.name.length < 1 ||
    typeof body.mime_type !== "string" || !ALLOWED.has(body.mime_type) ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 || body.size_bytes > maxBytes(dependencies)
  ) throw new Error("invalid_request");
  return {
    requestId: body.request_id,
    institutionId: body.institution_id,
    postId: body.post_id,
    name: body.name,
    mimeType: body.mime_type,
    sizeBytes: body.size_bytes,
  };
}

export async function handleHappensMediaRequest(
  request: Request,
  dependencies: HappensMediaDependencies = productionDependencies,
): Promise<Response> {
  const respond = (origin: string | null, status: number, body: Json) =>
    reply(dependencies, origin, status, body);
  const origin = request.headers.get("origin");
  if (origin !== null && !allowedOrigins(dependencies).has(origin)) {
    return respond(null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") return respond(origin, 200, { ok: true });
  if (request.method !== "POST") {
    return respond(origin, 405, { error: "method_not_allowed" });
  }
  const authorization = request.headers.get("authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return respond(origin, 401, { error: "authentication_required" });
  }

  try {
    const body = await request.json() as Json;
    const url = dependencies.envGet("SUPABASE_URL")!;
    const user = dependencies.createClient(
      url,
      dependencies.envGet("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authorization } } },
    );
    const admin = dependencies.createClient(url, secret(dependencies), {
      auth: { persistSession: false },
    });

    if (body.action === "read") {
      if (typeof body.read_ticket !== "string") {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const identity = await user.auth.getUser();
      if (identity.error || !identity.data.user) {
        return respond(origin, 401, { error: "authentication_required" });
      }
      const redeemed = await admin.rpc("redeem_happens_media_read_ticket", {
        p_ticket: body.read_ticket,
        p_viewer_auth_user_id: identity.data.user.id,
      });
      if (redeemed.error) {
        return respond(origin, 403, { error: "media_read_denied" });
      }
      const descriptor = redeemed.data as Json;
      if (usesR2(descriptor)) {
        const signed = await transportFor(
          dependencies,
          descriptorBucket(descriptor),
        ).presignGet(String(descriptor.object_key), readTtlSeconds)
          .catch(opaqueTransport);
        return respond(origin, 200, {
          signed_url: signed.url.toString(),
          mime_type: descriptor.mime_type,
          expires_in: readTtlSeconds,
        });
      }
      const signed = await admin.storage
        .from(String(descriptor.bucket_id))
        .createSignedUrl(String(descriptor.object_key), readTtlSeconds);
      if (signed.error) throw new Error("media_sign_failed");
      return respond(origin, 200, {
        signed_url: signed.data.signedUrl,
        mime_type: descriptor.mime_type,
        expires_in: readTtlSeconds,
      });
    }

    if (body.action === "prepare") {
      const input = uploadEnvelope(body, dependencies);
      const prepared = await user.rpc("prepare_happens_media_upload", {
        p_request_id: input.requestId,
        p_institution_id: input.institutionId,
        p_post_id: input.postId,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
      });
      if (prepared.error) throw new Error("media_prepare_failed");
      const descriptor = prepared.data as Json;
      if (usesR2(descriptor)) {
        const signed = await transportFor(
          dependencies,
          descriptorBucket(descriptor),
        ).presignPut(
          String(descriptor.object_key),
          input.mimeType,
          uploadTtlSeconds,
        ).catch(opaqueTransport);
        // O ramo R2 nao devolve bucket nem chave: o cliente recebe uma janela
        // PUT assinada, os cabecalhos exigidos e nada mais.
        return respond(origin, 200, {
          asset_id: descriptor.asset_id,
          storage_provider: "r2",
          upload_url: signed.url.toString(),
          required_headers: signed.requiredHeaders,
          expires_at: new Date(Date.now() + uploadTtlSeconds * 1000)
            .toISOString(),
        });
      }
      const signed = await admin.storage
        .from(String(descriptor.bucket_id))
        .createSignedUploadUrl(String(descriptor.object_key), { upsert: true });
      if (signed.error) throw new Error("media_sign_failed");
      return respond(origin, 200, {
        asset_id: descriptor.asset_id,
        storage_provider: "supabase_mvp",
        object_key: descriptor.object_key,
        upload_token: signed.data.token,
      });
    }

    if (body.action === "finalize") {
      const input = uploadEnvelope(body, dependencies);
      if (
        typeof body.asset_id !== "string" ||
        typeof body.display_order !== "number" ||
        !Number.isInteger(body.display_order) || body.display_order < 0 ||
        body.display_order > 5
      ) return respond(origin, 400, { error: "invalid_request" });
      const authorized = await user.rpc("prepare_happens_media_upload", {
        p_request_id: input.requestId,
        p_institution_id: input.institutionId,
        p_post_id: input.postId,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
      });
      if (authorized.error) throw new Error("media_finalize_denied");
      const descriptor = authorized.data as Json;
      if (descriptor.asset_id !== body.asset_id) {
        throw new Error("media_receipt_mismatch");
      }
      const objectKey = String(descriptor.object_key);
      const onR2 = usesR2(descriptor);
      const bucket = onR2
        ? descriptorBucket(descriptor)
        : String(descriptor.bucket_id);
      let bytes: Uint8Array;
      if (onR2) {
        bytes = await transportFor(dependencies, bucket)
          .get(objectKey, input.sizeBytes).catch(() => {
            throw new Error("media_upload_incomplete");
          });
      } else {
        const stored = await admin.storage.from(bucket).download(objectKey);
        if (stored.error) throw new Error("media_upload_incomplete");
        bytes = new Uint8Array(await stored.data.arrayBuffer());
      }
      if (
        bytes.length !== input.sizeBytes ||
        !validSignature(bytes, input.mimeType)
      ) {
        if (onR2) {
          await transportFor(dependencies, bucket).delete(objectKey)
            .catch(() => {});
        } else {
          await admin.storage.from(bucket).remove([objectKey]);
        }
        throw new Error("invalid_media_signature");
      }
      const finalized = await user.rpc("finalize_happens_media_upload", {
        p_asset_id: body.asset_id,
        p_post_id: input.postId,
        p_checksum_sha256: await checksum(bytes),
        p_display_order: body.display_order,
      });
      if (finalized.error) throw new Error("media_finalize_failed");
      return respond(origin, 200, finalized.data as Json);
    }

    if (body.action === "delete") {
      if (typeof body.asset_id !== "string") {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const removed = await user.rpc("remove_happens_media", {
        p_asset_id: body.asset_id,
      });
      if (removed.error) throw new Error("media_delete_denied");
      const descriptor = removed.data as Json;
      if (usesR2(descriptor)) {
        await transportFor(dependencies, descriptorBucket(descriptor))
          .delete(String(descriptor.object_key)).catch(opaqueTransport);
      } else {
        const deletion = await admin.storage
          .from(String(descriptor.bucket_id))
          .remove([String(descriptor.object_key)]);
        if (deletion.error) throw new Error("media_delete_failed");
      }
      return respond(origin, 200, { deleted: true });
    }
    return respond(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return respond(origin, 422, {
      error: error instanceof Error ? error.message : "worker_error",
    });
  }
}

Deno.serve((request) => handleHappensMediaRequest(request));
