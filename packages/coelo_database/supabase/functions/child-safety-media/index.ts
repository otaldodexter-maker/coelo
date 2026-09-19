import { createClient } from "@supabase/supabase-js";
import {
  R2Client,
  type R2Config,
  R2TransportError,
  validateR2Config,
} from "../_shared/r2_s3.ts";
import { bytesResponse, decodeEnvelope, isBinaryUpload, readUploadBytes } from "../_shared/edge_bytes.ts";

/** Documento de identidade da pessoa autorizada sem conta (ADR 0041 B6,
 * spec 062). So R2 privado (coelo-documents-prod): nunca URL publica, nunca
 * base64 pela funcao, nunca chave R2 no cliente alem do document_id. */
const DEFAULT_MAX_BYTES = 10 * 1024 * 1024;
const uploadTtlSeconds = 300;
const readTtlSeconds = 60;
const ALLOWED = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
]);
type Json = Record<string, unknown>;

export type ChildSafetyMediaTransport = Pick<
  R2Client,
  "presignGet" | "presignPut" | "get" | "put" | "head" | "delete"
>;

export type ChildSafetyMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
  createR2?: (config: R2Config) => ChildSafetyMediaTransport;
}>;

const productionDependencies: ChildSafetyMediaDependencies = {
  envGet: (name) => Deno.env.get(name),
  createClient,
};

function maxBytes(dependencies: ChildSafetyMediaDependencies) {
  const value = Number(
    dependencies.envGet("CHILD_SAFETY_MEDIA_MAX_BYTES") ?? DEFAULT_MAX_BYTES,
  );
  return Number.isSafeInteger(value) && value > 0 ? value : DEFAULT_MAX_BYTES;
}

/** CORS: lista propria ou a lista unica de midia (COELO_ALLOWED_ORIGINS). */
function allowedOrigins(dependencies: ChildSafetyMediaDependencies) {
  return new Set(
    (dependencies.envGet("CHILD_SAFETY_MEDIA_ALLOWED_ORIGINS") ??
      dependencies.envGet("COELO_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

/** Credenciais R2 existem somente aqui; a unica coisa que atravessa a
 * fronteira e uma URL assinada de vida curta. */
function transportFor(
  dependencies: ChildSafetyMediaDependencies,
  bucket: string,
): ChildSafetyMediaTransport {
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

function corsHeaders(dependencies: ChildSafetyMediaDependencies, origin: string | null) {
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
  dependencies: ChildSafetyMediaDependencies,
  origin: string | null,
  status: number,
  body: Json,
) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(dependencies, origin), "Content-Type": "application/json" },
  });
}

function secret(dependencies: ChildSafetyMediaDependencies) {
  const value = dependencies.envGet("SUPABASE_SERVICE_ROLE_KEY");
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

const uuid =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function requestId(value: unknown) {
  if (typeof value !== "string" || !uuid.test(value)) {
    throw new Error("invalid_request");
  }
  return value;
}

function prepareEnvelope(body: Json, dependencies: ChildSafetyMediaDependencies) {
  if (
    typeof body.authorized_person_id !== "string" ||
    !uuid.test(body.authorized_person_id) ||
    typeof body.mime_type !== "string" || !ALLOWED.has(body.mime_type) ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 || body.size_bytes > maxBytes(dependencies)
  ) {
    throw new Error("invalid_request");
  }
  return {
    requestId: requestId(body.request_id),
    authorizedPersonId: body.authorized_person_id,
    mimeType: body.mime_type,
    sizeBytes: body.size_bytes,
  };
}

function text(bytes: Uint8Array, start: number, end: number) {
  return new TextDecoder().decode(bytes.slice(start, end));
}

/** Assinatura real do conteudo: o Content-Type do PUT e declarado pelo
 * cliente e nao prova nada. */
export function validSignature(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return bytes[0] === 0xff && bytes[1] === 0xd8;
  if (mime === "image/png") {
    return bytes.slice(0, 8).join(",") === "137,80,78,71,13,10,26,10";
  }
  if (mime === "image/webp") {
    return text(bytes, 0, 4) === "RIFF" && text(bytes, 8, 12) === "WEBP";
  }
  if (mime === "application/pdf") return text(bytes, 0, 5) === "%PDF-";
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

export async function handleChildSafetyMediaRequest(
  request: Request,
  dependencies: ChildSafetyMediaDependencies = productionDependencies,
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
      const prepared = await user.rpc("child_safety_person_document_prepare_v1", {
        p_request_id: input.requestId,
        p_authorized_person_id: input.authorizedPersonId,
        p_mime_type: input.mimeType,
        p_byte_size: input.sizeBytes,
      });
      if (prepared.error) {
        return respond(origin, 403, { error: "document_prepare_denied" });
      }
      const descriptor = prepared.data as Json;
      if (typeof descriptor.document_id !== "string") {
        throw new Error("document_prepare_failed");
      }
      const signed = await transportFor(dependencies, descriptorBucket(descriptor))
        .presignPut(String(descriptor.object_key), input.mimeType, uploadTtlSeconds)
        .catch(opaqueTransport);
      // O cliente recebe a janela PUT assinada e os cabecalhos exigidos; nada
      // de bucket ou chave.
      return respond(origin, 200, {
        document_id: descriptor.document_id,
        storage_provider: "r2",
        upload_url: signed.url.toString(),
        required_headers: signed.requiredHeaders,
        expires_at: new Date(Date.now() + uploadTtlSeconds * 1000).toISOString(),
      });
    }

    if (body.action === "upload") {
      // O bilhete do dono autoriza o upload; a Edge grava no R2 e segue para o
      // finalize normal (releitura + assinatura + sha256 medido).
      if (typeof body.document_id !== "string" || !uuid.test(body.document_id)) {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const ticketed = await user.rpc(
        "child_safety_person_document_authorize_finalize_v1",
        { p_document_id: body.document_id },
      );
      if (ticketed.error) {
        return respond(origin, 403, { error: "document_upload_denied" });
      }
      const descriptor: Json = { storage_provider: "r2", ...(ticketed.data as Json) };
      const bytes = await readUploadBytes(request, Number(descriptor.byte_size));
      if (!validSignature(bytes, String(descriptor.mime_type))) {
        throw new Error("invalid_document_signature");
      }
      await transportFor(dependencies, descriptorBucket(descriptor))
        .put(String(descriptor.object_key), bytes, String(descriptor.mime_type))
        .catch(opaqueTransport);
      body.action = "finalize";
    }

    if (body.action === "finalize") {
      if (typeof body.document_id !== "string" || !uuid.test(body.document_id)) {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const ticketed = await user.rpc(
        "child_safety_person_document_authorize_finalize_v1",
        { p_document_id: body.document_id },
      );
      if (ticketed.error) {
        return respond(origin, 403, { error: "document_finalize_denied" });
      }
      // O bilhete de finalize nao repete storage_provider: documentos sao
      // sempre R2 (constraint authorized_person_documents_provider_ck).
      const descriptor: Json = { storage_provider: "r2", ...(ticketed.data as Json) };
      const expectedSize = Number(descriptor.byte_size);
      const expectedMime = String(descriptor.mime_type);
      const transport = transportFor(dependencies, descriptorBucket(descriptor));
      const objectKey = String(descriptor.object_key);
      const bytes = await transport.get(objectKey, expectedSize).catch(() => {
        throw new Error("document_upload_incomplete");
      });
      if (bytes.length !== expectedSize || !validSignature(bytes, expectedMime)) {
        await transport.delete(objectKey).catch(() => {});
        throw new Error("invalid_document_signature");
      }
      const admin = dependencies.createClient(url, secret(dependencies), {
        auth: { persistSession: false },
      });
      const finalized = await admin.rpc("child_safety_person_document_finalize_v1", {
        p_document_id: body.document_id,
        p_finalize_ticket: descriptor.finalize_ticket,
        p_byte_size: bytes.length,
        p_mime_type: expectedMime,
        p_checksum_sha256: await checksum(bytes),
      });
      if (finalized.error) throw new Error("document_finalize_failed");
      return respond(origin, 200, finalized.data as Json);
    }

    if (body.action === "read") {
      if (typeof body.document_id !== "string" || !uuid.test(body.document_id)) {
        return respond(origin, 400, { error: "invalid_request" });
      }
      const authorized = await user.rpc("child_safety_person_document_read_v1", {
        p_document_id: body.document_id,
      });
      if (authorized.error) {
        return respond(origin, 403, { error: "document_read_denied" });
      }
      const descriptor = authorized.data as Json;
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
if (Deno.env.get("CHILD_SAFETY_MEDIA_NO_SERVE") !== "1") {
  Deno.serve((request) => handleChildSafetyMediaRequest(request));
}
