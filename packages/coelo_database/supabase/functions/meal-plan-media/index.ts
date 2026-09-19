import { createClient } from "@supabase/supabase-js";
import {
  R2Client,
  type R2Config,
  R2TransportError,
  validateR2Config,
} from "../_shared/r2_s3.ts";
import { bytesResponse, decodeEnvelope, isBinaryUpload, readUploadBytes } from "../_shared/edge_bytes.ts";

/** Imagens de Cardapios em R2 privado (owner.r12-38, spec 063, ADR 0032):
 * prepare -> PUT assinado -> finalize (bytes relidos e assinatura real) ->
 * leitura por URL assinada curta. Nunca URL publica nem base64 pela funcao. */
const DEFAULT_MAX_BYTES = 2 * 1024 * 1024;
const uploadTtlSeconds = 300;
const readTtlSeconds = 300;
const ALLOWED = new Set(["image/jpeg", "image/png", "image/webp"]);
const RESOURCE_KINDS = new Set(["meal_plan", "template", "meal", "meal_item"]);
type Json = Record<string, unknown>;

export type MealPlanMediaTransport = Pick<
  R2Client,
  "presignGet" | "presignPut" | "get" | "put" | "head" | "delete"
>;

export type MealPlanMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
  createR2?: (config: R2Config) => MealPlanMediaTransport;
}>;

const productionDependencies: MealPlanMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

function maxBytes(dependencies: MealPlanMediaDependencies) {
  const value = Number(
    dependencies.envGet("MEAL_PLAN_MEDIA_MAX_BYTES") ?? DEFAULT_MAX_BYTES,
  );
  return Number.isSafeInteger(value) && value > 0 ? value : DEFAULT_MAX_BYTES;
}

function allowedOrigins(dependencies: MealPlanMediaDependencies) {
  return new Set(
    (dependencies.envGet("MEAL_PLAN_MEDIA_ALLOWED_ORIGINS") ??
      dependencies.envGet("COELO_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

function transportFor(
  dependencies: MealPlanMediaDependencies,
  bucket: string,
): MealPlanMediaTransport {
  const config = validateR2Config({
    endpoint: dependencies.envGet("COELO_R2_ENDPOINT") ?? "",
    region: dependencies.envGet("COELO_R2_REGION") ?? "auto",
    accessKeyId: dependencies.envGet("COELO_R2_ACCESS_KEY_ID") ?? "",
    secretAccessKey: dependencies.envGet("COELO_R2_SECRET_ACCESS_KEY") ?? "",
    bucket,
  });
  return dependencies.createR2?.(config) ?? new R2Client(config);
}

function opaqueTransport(error: unknown): never {
  if (error instanceof R2TransportError) {
    throw new Error("media_transport_failed");
  }
  throw error;
}

function descriptorBucket(descriptor: Json) {
  const bucket = descriptor.bucket_id;
  if (
    descriptor.storage_provider !== "r2" || typeof bucket !== "string" ||
    !bucket || typeof descriptor.object_key !== "string"
  ) {
    throw new Error("media_descriptor_invalid");
  }
  return bucket;
}

function corsHeaders(dependencies: MealPlanMediaDependencies, origin: string | null) {
  const headers: Record<string, string> = {
    "Cache-Control": "no-store",
    "X-Content-Type-Options": "nosniff",
    "Referrer-Policy": "no-referrer",
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info, x-coelo-media-envelope, x-coelo-surface",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins(dependencies).has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

function reply(
  dependencies: MealPlanMediaDependencies,
  origin: string | null,
  status: number,
  body: Json,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(dependencies, origin), "Content-Type": "application/json" },
  });
}

function secret(dependencies: MealPlanMediaDependencies) {
  const value = dependencies.envGet("SUPABASE_SERVICE_ROLE_KEY");
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function prepareEnvelope(body: Json, dependencies: MealPlanMediaDependencies) {
  if (
    typeof body.request_id !== "string" || !uuid.test(body.request_id) ||
    typeof body.resource_kind !== "string" ||
    !RESOURCE_KINDS.has(body.resource_kind) ||
    typeof body.resource_id !== "string" || !uuid.test(body.resource_id) ||
    typeof body.file_name !== "string" || body.file_name.length < 1 ||
    body.file_name.length > 180 ||
    typeof body.mime_type !== "string" || !ALLOWED.has(body.mime_type) ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 || body.size_bytes > maxBytes(dependencies) ||
    (body.alt_text !== undefined && body.alt_text !== null &&
      (typeof body.alt_text !== "string" || body.alt_text.length > 500))
  ) {
    throw new Error("invalid_request");
  }
  return {
    requestId: body.request_id,
    resourceKind: body.resource_kind,
    resourceId: body.resource_id,
    fileName: body.file_name,
    mimeType: body.mime_type,
    sizeBytes: body.size_bytes,
    altText: typeof body.alt_text === "string" ? body.alt_text : null,
  };
}

function text(bytes: Uint8Array, start: number, end: number) {
  return new TextDecoder().decode(bytes.slice(start, end));
}

export function validSignature(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mime === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mime === "image/webp") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WEBP";
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

export async function handleMealPlanMediaRequest(
  request: Request,
  dependencies: MealPlanMediaDependencies = productionDependencies,
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
    // Upload binário: envelope no cabeçalho, bytes no corpo (_shared/edge_bytes.ts).
    const body = isBinaryUpload(request) ? decodeEnvelope(request) : await request.json() as Json;
    const url = dependencies.envGet("SUPABASE_URL")!;
    const user = dependencies.createClient(
      url,
      dependencies.envGet("SUPABASE_ANON_KEY")!,
      {
        global: { headers: { Authorization: authorization } },
        auth: { persistSession: false },
      },
    );
    const identity = await user.auth.getUser();
    if (identity.error || !identity.data.user) {
      return respond(origin, 401, { error: "authentication_required" });
    }

    if (body.action === "prepare") {
      const input = prepareEnvelope(body, dependencies);
      const prepared = await user.rpc("meal_plan_prepare_image_upload_v2", {
        p_resource_kind: input.resourceKind,
        p_resource_id: input.resourceId,
        p_file_name: input.fileName,
        p_mime_type: input.mimeType,
        p_size_bytes: input.sizeBytes,
        p_alt_text: input.altText,
        p_idempotency_key: input.requestId,
      });
      if (prepared.error) {
        return respond(origin, 403, { error: "image_prepare_denied" });
      }
      const descriptor = prepared.data as Json;
      if (typeof descriptor.asset_id !== "string") {
        throw new Error("image_prepare_failed");
      }
      const signed = await transportFor(dependencies, descriptorBucket(descriptor))
        .presignPut(String(descriptor.object_key), input.mimeType, uploadTtlSeconds)
        .catch(opaqueTransport);
      return respond(origin, 200, {
        asset_id: descriptor.asset_id,
        storage_provider: "r2",
        upload_url: signed.url.toString(),
        required_headers: signed.requiredHeaders,
        max_bytes: descriptor.max_bytes,
        expires_at: new Date(Date.now() + uploadTtlSeconds * 1000).toISOString(),
      });
    }

    if (body.action === "upload") {
      // O bilhete do dono autoriza o upload; a Edge grava no R2 e segue para o
      // finalize normal (releitura + assinatura + sha256 medido).
      if (typeof body.request_id !== "string" || !uuid.test(body.request_id)) {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const ticketed = await user.rpc("meal_plan_authorize_image_finalize_v2", {
        p_request_id: body.request_id,
      });
      if (ticketed.error) {
        return respond(origin, 403, { error: "image_upload_denied" });
      }
      const descriptor = ticketed.data as Json;
      const bytes = await readUploadBytes(request, Number(descriptor.byte_size));
      if (!validSignature(bytes, String(descriptor.mime_type))) {
        throw new Error("invalid_image_signature");
      }
      await transportFor(dependencies, descriptorBucket(descriptor))
        .put(String(descriptor.object_key), bytes, String(descriptor.mime_type))
        .catch(opaqueTransport);
      body.action = "finalize";
    }

    if (body.action === "finalize") {
      if (
        typeof body.request_id !== "string" || !uuid.test(body.request_id) ||
        (body.replace_asset_id !== undefined && body.replace_asset_id !== null &&
          (typeof body.replace_asset_id !== "string" ||
            !uuid.test(body.replace_asset_id))) ||
        (body.alt_text !== undefined && body.alt_text !== null &&
          (typeof body.alt_text !== "string" || body.alt_text.length > 500))
      ) {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const ticketed = await user.rpc("meal_plan_authorize_image_finalize_v2", {
        p_request_id: body.request_id,
      });
      if (ticketed.error) {
        return respond(origin, 403, { error: "image_finalize_denied" });
      }
      const descriptor = ticketed.data as Json;
      const expectedSize = Number(descriptor.byte_size);
      const expectedMime = String(descriptor.mime_type);
      const transport = transportFor(dependencies, descriptorBucket(descriptor));
      const objectKey = String(descriptor.object_key);
      const bytes = await transport.get(objectKey, expectedSize).catch(() => {
        throw new Error("image_upload_incomplete");
      });
      if (bytes.length !== expectedSize || !validSignature(bytes, expectedMime)) {
        await transport.delete(objectKey).catch(() => {});
        throw new Error("invalid_image_signature");
      }
      const admin = dependencies.createClient(url, secret(dependencies), {
        auth: { persistSession: false },
      });
      const finalized = await admin.rpc("meal_plan_finalize_image_upload_v2", {
        p_request_id: body.request_id,
        p_finalize_ticket: descriptor.finalize_ticket,
        p_byte_size: bytes.length,
        p_mime_type: expectedMime,
        p_checksum_sha256: await checksum(bytes),
        p_alt_text: typeof body.alt_text === "string" ? body.alt_text : null,
        p_replace_asset_id: typeof body.replace_asset_id === "string"
          ? body.replace_asset_id
          : null,
      });
      if (finalized.error) throw new Error("image_finalize_failed");
      return respond(origin, 200, finalized.data as Json);
    }

    if (body.action === "read") {
      if (typeof body.asset_id !== "string" || !uuid.test(body.asset_id)) {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const authorized = await user.rpc("meal_plan_image_read_descriptor_v2", {
        p_asset_id: body.asset_id,
      });
      if (authorized.error) {
        return respond(origin, 403, { error: "image_read_denied" });
      }
      const descriptor = authorized.data as Json;
      if (descriptor.storage_provider !== "r2") {
        // Ativo legado (Supabase Storage): leitura pelo caminho v1 do cliente.
        return respond(origin, 409, { error: "legacy_storage_asset" });
      }
      if (body.inline === true) {
        // Bytes pela Edge: nenhuma URL assinada chega ao navegador.
        const bytes = await transportFor(dependencies, descriptorBucket(descriptor))
          .get(String(descriptor.object_key), maxBytes(dependencies)).catch(opaqueTransport);
        return bytesResponse(corsHeaders(dependencies, origin), bytes, String(descriptor.mime_type));
      }
      const signed = await transportFor(dependencies, descriptorBucket(descriptor))
        .presignGet(String(descriptor.object_key), readTtlSeconds)
        .catch(opaqueTransport);
      return respond(origin, 200, {
        signed_url: signed.url.toString(),
        mime_type: descriptor.mime_type,
        alt_text: descriptor.alt_text ?? null,
        expires_in: readTtlSeconds,
      });
    }

    return respond(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return respond(origin, 422, {
      error: error instanceof Error ? error.message : "worker_error",
    });
  }
}

// Em teste local o modulo e importado sem subir o servidor.
if (Deno.env.get("MEAL_PLAN_MEDIA_NO_SERVE") !== "1") {
  Deno.serve((request) => handleMealPlanMediaRequest(request));
}
