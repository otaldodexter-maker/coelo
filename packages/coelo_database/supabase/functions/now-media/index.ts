import { createClient } from "@supabase/supabase-js";
import {
  R2Client,
  type R2Config,
  R2TransportError,
  validateR2Config,
} from "../_shared/r2_s3.ts";

/** Bucket legado do Supabase Storage. O ramo legado continua exigindo que o
 * descritor aponte exatamente para ele; o ramo R2 nao passa por aqui. */
const BUCKET = "coelo-now-mvp";
const DEFAULT_MAX_BYTES = 25 * 1024 * 1024;
const uploadTtlSeconds = 300;
const readTtlSeconds = 60;
const ALLOWED = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "video/mp4",
  "audio/mpeg",
  "audio/mp4",
  "audio/wav",
  "audio/aac",
]);
type Json = Record<string, unknown>;

export type NowMediaTransport = Pick<
  R2Client,
  "presignGet" | "presignPut" | "get" | "delete"
>;

export type NowMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
  createR2?: (config: R2Config) => NowMediaTransport;
}>;

const productionDependencies: NowMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

function maxBytes(dependencies: NowMediaDependencies) {
  const value = Number(
    dependencies.envGet("NOW_MEDIA_MAX_BYTES") ?? DEFAULT_MAX_BYTES,
  );
  return Number.isSafeInteger(value) && value > 0 ? value : DEFAULT_MAX_BYTES;
}

function allowedOrigins(dependencies: NowMediaDependencies) {
  return new Set(
    (dependencies.envGet("NOW_MEDIA_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

/** Credenciais R2 existem somente aqui, no servidor. Elas nunca entram em log,
 * em corpo de resposta ou em qualquer superficie cliente; a unica coisa que
 * atravessa a fronteira e uma URL assinada de vida curta. */
function transportFor(
  dependencies: NowMediaDependencies,
  bucket: string,
): NowMediaTransport {
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

/** No ramo legado o bucket do descritor tem de ser exatamente o do MVP. */
function legacyObjectKey(descriptor: Json, failure: string) {
  if (
    descriptor.bucket_id !== BUCKET ||
    typeof descriptor.object_key !== "string"
  ) throw new Error(failure);
  return descriptor.object_key;
}

function reply(
  dependencies: NowMediaDependencies,
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
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins(dependencies).has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), {
    status,
    headers,
  });
}

function secret(dependencies: NowMediaDependencies) {
  const value = dependencies.envGet("SUPABASE_SERVICE_ROLE_KEY");
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function uploadEnvelope(body: Json, dependencies: NowMediaDependencies) {
  if (
    typeof body.request_id !== "string" || body.request_id.length < 1 ||
    body.request_id.length > 240 ||
    typeof body.publication_id !== "string" ||
    typeof body.institution_id !== "string" ||
    typeof body.kind !== "string" ||
    !["media", "audio", "cover"].includes(body.kind) ||
    typeof body.name !== "string" || body.name.length < 1 ||
    typeof body.mime_type !== "string" || !ALLOWED.has(body.mime_type) ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 || body.size_bytes > maxBytes(dependencies)
  ) {
    throw new Error("invalid_request");
  }
  return {
    requestId: body.request_id,
    publicationId: body.publication_id,
    institutionId: body.institution_id,
    kind: body.kind,
    name: body.name,
    mimeType: body.mime_type,
    sizeBytes: body.size_bytes,
    durationSeconds: body.duration_seconds,
    rightsConfirmed: body.rights_confirmed === true,
  };
}

function text(bytes: Uint8Array, start: number, end: number) {
  return new TextDecoder().decode(bytes.slice(start, end));
}

function validSignature(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mime === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mime === "image/webp") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WEBP";
  }
  if (mime === "video/mp4" || mime === "audio/mp4") {
    return text(bytes, 4, 8) === "ftyp";
  }
  if (mime === "audio/mpeg") {
    return text(bytes, 0, 3) === "ID3" ||
      (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0);
  }
  if (mime === "audio/wav") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WAVE";
  }
  if (mime === "audio/aac") {
    return bytes[0] === 0xff && (bytes[1] & 0xf6) === 0xf0;
  }
  return false;
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

export async function handleNowMediaRequest(
  request: Request,
  dependencies: NowMediaDependencies = productionDependencies,
): Promise<Response> {
  const respond = (origin: string | null, status: number, body: Json) =>
    reply(dependencies, origin, status, body);
  const origin = request.headers.get("origin");
  if (origin !== null && !allowedOrigins(dependencies).has(origin)) {
    return respond(null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") {
    return respond(origin, 200, { ok: true });
  }
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

    const signedRead = async (descriptor: Json, failure: string) => {
      if (usesR2(descriptor)) {
        const signed = await transportFor(
          dependencies,
          descriptorBucket(descriptor),
        ).presignGet(String(descriptor.object_key), readTtlSeconds)
          .catch(opaqueTransport);
        return signed.url.toString();
      }
      const objectKey = legacyObjectKey(descriptor, failure);
      const signed = await admin.storage.from(BUCKET).createSignedUrl(
        objectKey,
        readTtlSeconds,
      );
      if (signed.error || !signed.data?.signedUrl) {
        throw new Error("asset_signing_failed");
      }
      return signed.data.signedUrl;
    };

    if (body.action === "read-draft") {
      if (
        typeof body.institution_id !== "string" ||
        typeof body.asset_id !== "string"
      ) return respond(origin, 400, { error: "invalid_request" });

      const authorized = await user.rpc("authorize_now_asset_read", {
        p_institution_id: body.institution_id,
        p_asset_id: body.asset_id,
      });
      if (authorized.error) throw new Error("asset_read_not_authorized");
      const descriptor = authorized.data as Json;
      return respond(origin, 200, {
        signed_url: await signedRead(descriptor, "asset_read_not_authorized"),
        mime_type: descriptor.mime_type,
        expires_in: readTtlSeconds,
      });
    }

    if (body.action === "read") {
      if (typeof body.read_ticket !== "string") {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const identity = await user.auth.getUser();
      if (identity.error || !identity.data.user) {
        return respond(origin, 401, { error: "authentication_required" });
      }
      const redeemed = await admin.rpc("redeem_now_media_read_ticket", {
        p_ticket: body.read_ticket,
        p_viewer_auth_user_id: identity.data.user.id,
      });
      if (redeemed.error) {
        return respond(origin, 403, { error: "media_read_denied" });
      }
      const descriptor = redeemed.data as Json;
      return respond(origin, 200, {
        signed_url: await signedRead(descriptor, "media_read_denied"),
        mime_type: descriptor.mime_type,
        expires_in: readTtlSeconds,
      });
    }

    if (body.action === "prepare") {
      const input = uploadEnvelope(body, dependencies);
      const prepared = await user.rpc("prepare_now_asset_upload", {
        p_institution_id: input.institutionId,
        p_publication_id: input.publicationId,
        p_kind: input.kind,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
        p_duration_seconds: input.durationSeconds,
        p_rights_confirmed: input.rightsConfirmed,
      });
      if (prepared.error) throw new Error("asset_prepare_failed");
      const descriptor = prepared.data as Json;
      if (typeof descriptor.asset_id !== "string") {
        throw new Error("asset_prepare_failed");
      }
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
      const objectKey = legacyObjectKey(descriptor, "asset_prepare_failed");
      const signed = await admin.storage.from(BUCKET).createSignedUploadUrl(
        objectKey,
        { upsert: true },
      );
      if (signed.error) throw new Error("asset_signing_failed");
      return respond(origin, 200, {
        asset_id: descriptor.asset_id,
        storage_provider: "supabase_mvp",
        object_key: objectKey,
        upload_token: signed.data.token,
      });
    }

    if (body.action === "finalize") {
      const input = uploadEnvelope(body, dependencies);
      if (typeof body.asset_id !== "string") {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const authorized = await user.rpc("prepare_now_asset_upload", {
        p_institution_id: input.institutionId,
        p_publication_id: input.publicationId,
        p_kind: input.kind,
        p_name: input.name,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
        p_duration_seconds: input.durationSeconds,
        p_rights_confirmed: input.rightsConfirmed,
      });
      if (authorized.error) throw new Error("asset_finalize_denied");
      const descriptor = authorized.data as Json;
      if (descriptor.asset_id !== body.asset_id) {
        throw new Error("asset_receipt_mismatch");
      }
      const onR2 = usesR2(descriptor);
      const objectKey = onR2
        ? String(descriptor.object_key)
        : legacyObjectKey(descriptor, "asset_receipt_mismatch");
      let bytes: Uint8Array;
      if (onR2) {
        bytes = await transportFor(dependencies, descriptorBucket(descriptor))
          .get(objectKey, input.sizeBytes).catch(() => {
            throw new Error("asset_upload_incomplete");
          });
      } else {
        const stored = await admin.storage.from(BUCKET).download(objectKey);
        if (stored.error) throw new Error("asset_upload_incomplete");
        bytes = new Uint8Array(await stored.data.arrayBuffer());
      }
      if (
        bytes.length !== input.sizeBytes ||
        !validSignature(bytes, String(input.mimeType))
      ) {
        if (onR2) {
          await transportFor(dependencies, descriptorBucket(descriptor))
            .delete(objectKey).catch(() => {});
        } else {
          await admin.storage.from(BUCKET).remove([objectKey]);
        }
        throw new Error("invalid_asset_signature");
      }
      const finalized = await user.rpc("finalize_now_asset_upload", {
        p_asset_id: body.asset_id,
        p_checksum_sha256: await checksum(bytes),
      });
      if (finalized.error) throw new Error("asset_finalize_failed");
      return respond(origin, 200, finalized.data as Json);
    }

    return respond(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return respond(origin, 422, {
      error: error instanceof Error ? error.message : "worker_error",
    });
  }
}

Deno.serve((request) => handleNowMediaRequest(request));
