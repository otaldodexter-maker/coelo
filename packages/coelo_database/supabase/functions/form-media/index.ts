import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import {
  R2Client,
  type R2Config,
  R2TransportError,
  validateR2Config,
} from "../_shared/r2_s3.ts";
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
  type QuestionImageEnvelope,
  readFormMediaEnvelope,
  sha256,
  shouldVerifyFinalization,
  sniffImageMime,
  workerFinalizationSucceeded,
} from "./media_contract.ts";
import {
  authorizedWorkerRequest,
  imageDimensions,
  QUESTION_IMAGE_BUCKET,
  QUESTION_IMAGE_MAX_BYTES,
  QUESTION_IMAGE_READ_TTL_SECONDS,
  QUESTION_IMAGE_UPLOAD_TTL_SECONDS,
  questionImageObjectKey,
  rpcOutcome,
} from "./question_image.ts";

type Json = Record<string, unknown>;

/** Superficie do R2 usada pelo ramo question-image e pelo worker. */
export type FormMediaTransport = Pick<
  R2Client,
  "presignGet" | "presignPut" | "head" | "get" | "delete"
>;

export type FormMediaDependencies = Readonly<{
  envGet: (name: string) => string | undefined;
  createClient: typeof createClient;
  now?: () => Date;
  createR2?: (config: R2Config) => Pick<R2Client, "presignGet">;
  /** Transporte completo do ramo question-image (testes injetam um falso). */
  createTransport?: (config: R2Config) => FormMediaTransport;
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

function questionImageTransport(
  dependencies: FormMediaDependencies,
  bucket: string,
  signingAt?: number,
): FormMediaTransport {
  const config = validateR2Config({
    endpoint: dependencies.envGet("COELO_R2_ENDPOINT") ?? "",
    region: dependencies.envGet("COELO_R2_REGION") ?? "auto",
    accessKeyId: dependencies.envGet("COELO_R2_ACCESS_KEY_ID") ?? "",
    secretAccessKey: dependencies.envGet("COELO_R2_SECRET_ACCESS_KEY") ?? "",
    bucket,
  });
  return dependencies.createTransport?.(config) ??
    new R2Client(
      config,
      signingAt === undefined ? {} : { now: () => new Date(signingAt) },
    );
}

function rpcFailure(
  origin: string | null,
  outcome: Exclude<ReturnType<typeof rpcOutcome>, { ok: true }>,
): Response {
  const body: Json = { error: outcome.code };
  if (outcome.message) body.message = outcome.message;
  if (outcome.correlationId) body.correlation_id = outcome.correlationId;
  return response(origin, outcome.status, body);
}


// R05 realm-interno: uploads de RESPOSTA (answer-image) no R2 (ADR 0032) atras
// da chave COELO_FORMS_MEDIA_PROVIDER=r2. Sem a chave o fluxo legado (Supabase
// Storage) segue igual; com ela, prepare/finalize/download usam o espelho do
// catalogo privado (20260911210800: form_prepare_asset_upload_r2_v1,
// form_asset_r2_descriptor_v1, form_media_finalize_answer_r2_v1) e o bucket
// coelo-media-prod, reutilizando o transporte do ramo question-image.
function answerR2Enabled(dependencies: FormMediaDependencies): boolean {
  return dependencies.envGet("COELO_FORMS_MEDIA_PROVIDER") === "r2";
}

const R2_ANSWER_KEY =
  /^tenants\/[0-9a-f-]{36}\/forms\/form\/[0-9a-f-]{36}\/answer-image\/[0-9a-f-]{36}\/original\/[0-9a-f-]{36}\.(jpg|png|webp)$/;

function answerR2Key(value: unknown): value is string {
  return typeof value === "string" && R2_ANSWER_KEY.test(value);
}

function answerEnvelope(value: unknown): Json {
  const envelope = value as Json | null;
  if (!envelope || envelope.ok !== true || !envelope.data) {
    throw new Error("asset_unavailable");
  }
  return envelope.data as Json;
}

async function handleAnswerR2(
  origin: string | null,
  action: "prepare" | "finalize" | "download",
  requestId: string,
  expectedVersion: number,
  payload: unknown,
  actorPersonId: string,
  userClient: SupabaseClient,
  serviceClient: SupabaseClient,
  dependencies: FormMediaDependencies,
): Promise<Response> {
  if (action === "prepare") {
    const input = parsePrepareAsset(payload);
    const { data, error } = await userClient.rpc("form_prepare_asset_upload_r2_v1", {
      p_request_id: requestId,
      p_expected_version: expectedVersion,
      p_payload: input,
    });
    if (
      error || !data || !answerR2Key(data.object_key) ||
      data.bucket !== QUESTION_IMAGE_BUCKET
    ) throw new Error("prepare_failed");
    const signed = await questionImageTransport(dependencies, data.bucket).presignPut(
      data.object_key,
      input.mime_type,
      QUESTION_IMAGE_UPLOAD_TTL_SECONDS,
    );
    return response(origin, 200, {
      asset_id: data.asset_id,
      upload_url: signed.url.toString(),
      required_headers: signed.requiredHeaders,
      expires_at: data.expires_at,
      storage_provider: "r2",
    });
  }
  const access = parseAssetAccess(payload);
  if (action === "finalize") {
    // O usuario confirma o upload pelo legado (autoriza dono/segredo anonimo).
    const queued = await userClient.rpc("form_finalize_asset_upload", {
      p_request_id: requestId,
      p_expected_version: expectedVersion,
      p_payload: access,
    });
    if (queued.error) throw new Error("finalize_failed");
    const described = await serviceClient.rpc("form_asset_r2_descriptor_v1", {
      p_asset_id: access.asset_id,
    });
    if (described.error) throw new Error("asset_unavailable");
    const descriptor = answerEnvelope(described.data);
    if (!answerR2Key(descriptor.object_key)) throw new Error("asset_unavailable");
    if (descriptor.state === "finalized" && descriptor.media_status === "ready") {
      return response(origin, 200, { asset_id: access.asset_id, state: "finalized" });
    }
    const expectedBytes = Number(descriptor.expected_byte_size);
    const expectedMime = String(descriptor.mime_type);
    const transport = questionImageTransport(dependencies, String(descriptor.bucket));
    const stored = await transport.head(descriptor.object_key);
    if (stored.byteSize !== expectedBytes || stored.byteSize > MAX_IMAGE_BYTES) {
      await transport.delete(descriptor.object_key).catch(() => {});
      throw new Error("asset_unavailable");
    }
    const bytes = await transport.get(descriptor.object_key, expectedBytes);
    const dimensions = sniffImageMime(bytes) === expectedMime
      ? imageDimensions(bytes, expectedMime)
      : null;
    const finalized = await serviceClient.rpc("form_media_finalize_answer_r2_v1", {
      p_asset_id: access.asset_id,
      p_byte_size: bytes.byteLength,
      p_checksum_sha256: await sha256(bytes),
      p_pixel_width: dimensions?.width ?? null,
      p_pixel_height: dimensions?.height ?? null,
    });
    if (finalized.error) throw new Error("verification_failed");
    const outcome = finalized.data as Json | null;
    if (!outcome || outcome.ok !== true) {
      // O banco ja descartou o legado e enfileirou a limpeza; o objeto sai.
      await transport.delete(descriptor.object_key).catch(() => {});
      throw new Error("verification_failed");
    }
    return response(origin, 200, {
      asset_id: access.asset_id,
      state: "finalized",
      media_asset_id: (outcome.data as Json).media_asset_id,
    });
  }
  const authorized = await serviceClient.rpc("form_media_authorize_for_worker", {
    p_asset_id: access.asset_id,
    p_actor_person_id: actorPersonId,
    p_edit_secret: access.edit_secret,
  });
  if (authorized.error || !authorized.data || authorized.data.state !== "finalized") {
    throw new Error("asset_unavailable");
  }
  const described = await serviceClient.rpc("form_asset_r2_descriptor_v1", {
    p_asset_id: access.asset_id,
  });
  if (described.error) throw new Error("asset_unavailable");
  const descriptor = answerEnvelope(described.data);
  if (!answerR2Key(descriptor.object_key) || descriptor.media_status !== "ready") {
    throw new Error("asset_unavailable");
  }
  const signed = await questionImageTransport(dependencies, String(descriptor.bucket))
    .presignGet(descriptor.object_key, 60);
  return response(origin, 200, { signed_url: signed.url.toString(), expires_in: 60 });
}

/** Ramo question-image (R2, lote 33). O ator e reautorizado pelo JWT em cada
 * RPC `superadmin_form_media_*_v2`; somente a finalizacao medida usa
 * service_role, e apenas com o ticket que a propria autora acabou de liberar.
 * Nenhuma credencial, bucket ou chave sai daqui: o cliente recebe URLs
 * assinadas de vida curta e os codigos FORM_MEDIA_* / SAI_* do banco. */
async function handleQuestionImage(
  origin: string | null,
  envelope: QuestionImageEnvelope,
  userClient: SupabaseClient,
  serviceClient: SupabaseClient,
  dependencies: FormMediaDependencies,
): Promise<Response> {
  const now = dependencies.now ?? (() => new Date());
  try {
    if (envelope.action === "prepare") {
      const input = envelope.payload;
      const prepared = rpcOutcome(
        await userClient.rpc("superadmin_form_media_prepare_v2", {
          p_request_id: envelope.request_id,
          p_form_id: input.form_id,
          p_form_version_id: input.form_version_id,
          p_item_id: input.item_id,
          p_mime_type: input.mime_type,
          p_byte_size: input.byte_size,
          p_sha256: input.sha256,
        }),
      );
      if (!prepared.ok) return rpcFailure(origin, prepared);
      const assetId = String(prepared.data.asset_id ?? "");
      const objectKey = questionImageObjectKey(prepared.data, assetId);
      if (prepared.data.mime_type !== input.mime_type) {
        throw new Error("invalid_descriptor");
      }
      const signingAt = now().getTime();
      const signed = await questionImageTransport(
        dependencies,
        QUESTION_IMAGE_BUCKET,
        signingAt,
      ).presignPut(
        objectKey,
        input.mime_type,
        QUESTION_IMAGE_UPLOAD_TTL_SECONDS,
      );
      const expiresAt = Math.floor(signingAt / 1000) * 1000 +
        QUESTION_IMAGE_UPLOAD_TTL_SECONDS * 1000;
      return response(origin, 200, {
        asset_id: assetId,
        // `signed_upload_url` e o nome que o cliente Dart legado le;
        // `upload_url` e o das demais funcoes de midia do R2.
        signed_upload_url: signed.url.toString(),
        upload_url: signed.url.toString(),
        required_headers: signed.requiredHeaders,
        finalize_ticket: prepared.data.finalize_ticket ?? null,
        expires_at: new Date(expiresAt).toISOString(),
        replayed: prepared.data.replayed === true,
      });
    }
    if (envelope.action === "finalize") {
      const assetId = envelope.payload.asset_id;
      const authorized = rpcOutcome(
        await userClient.rpc("superadmin_form_media_authorize_finalize_v2", {
          p_asset_id: assetId,
        }),
      );
      if (!authorized.ok) return rpcFailure(origin, authorized);
      const objectKey = questionImageObjectKey(authorized.data, assetId);
      const ticket = authorized.data.finalize_ticket;
      const mimeType = String(authorized.data.mime_type);
      if (typeof ticket !== "string") throw new Error("invalid_descriptor");
      const transport = questionImageTransport(
        dependencies,
        QUESTION_IMAGE_BUCKET,
      );
      let stored;
      try {
        stored = await transport.head(objectKey);
      } catch (error) {
        if (error instanceof R2TransportError && error.code === "http_404") {
          // O PUT ainda nao aconteceu: o ticket segue valido para repetir.
          return response(origin, 409, { error: "FORM_MEDIA_NOT_READY" });
        }
        throw error;
      }
      // Medicao real: bytes relidos, SHA-256 calculado aqui e dimensoes do
      // cabecalho. Content-Type e Content-Length do objeto sao o que o cliente
      // declarou no PUT e nao provam nada. Quando o objeto excede o limite do
      // catalogo ou nao decodifica como o tipo declarado, as medidas vao ao
      // banco com dimensoes nulas para ele registrar a divergencia, apagar o
      // ativo e enfileirar a limpeza (FORM_MEDIA_MISMATCH 422).
      let byteSize = stored.byteSize;
      let checksum = "";
      let width: number | null = null;
      let height: number | null = null;
      if (byteSize <= QUESTION_IMAGE_MAX_BYTES) {
        const bytes = await transport.get(objectKey, QUESTION_IMAGE_MAX_BYTES);
        byteSize = bytes.byteLength;
        checksum = await sha256(bytes);
        if (sniffImageMime(bytes) === mimeType) {
          const dimensions = imageDimensions(bytes, mimeType);
          width = dimensions?.width ?? null;
          height = dimensions?.height ?? null;
        }
      }
      const finalized = rpcOutcome(
        await serviceClient.rpc("form_media_finalize_question_r2_v1", {
          p_asset_id: assetId,
          p_finalize_ticket: ticket,
          p_byte_size: byteSize,
          p_checksum_sha256: checksum,
          p_pixel_width: width,
          p_pixel_height: height,
        }),
      );
      if (!finalized.ok) return rpcFailure(origin, finalized);
      return response(origin, 200, {
        asset_id: assetId,
        status: finalized.data.status ?? "ready",
        finalized_at: finalized.data.finalized_at ?? null,
        mime_type: mimeType,
        byte_size: byteSize,
        pixel_width: width,
        pixel_height: height,
      });
    }
    if (envelope.action === "resolve") {
      const assetId = envelope.payload.asset_id;
      const resolved = rpcOutcome(
        await userClient.rpc("superadmin_form_media_resolve_v2", {
          p_asset_id: assetId,
        }),
      );
      if (!resolved.ok) return rpcFailure(origin, resolved);
      const objectKey = questionImageObjectKey(resolved.data, assetId);
      const granted = resolved.data.ttl_seconds;
      const ttl = Math.min(
        QUESTION_IMAGE_READ_TTL_SECONDS,
        typeof granted === "number" && Number.isSafeInteger(granted)
          ? granted
          : 0,
      );
      if (ttl < 1) throw new Error("invalid_descriptor");
      const signingAt = now().getTime();
      const signed = await questionImageTransport(
        dependencies,
        QUESTION_IMAGE_BUCKET,
        signingAt,
      ).presignGet(objectKey, ttl);
      const expiresAt = Math.floor(signingAt / 1000) * 1000 + ttl * 1000;
      return response(origin, 200, {
        asset_id: assetId,
        signed_url: signed.url.toString(),
        expires_in: ttl,
        expires_at: new Date(expiresAt).toISOString(),
        mime_type: resolved.data.mime_type,
        byte_size: resolved.data.byte_size,
        pixel_width: resolved.data.pixel_width,
        pixel_height: resolved.data.pixel_height,
      });
    }
    if (envelope.action !== "delete") throw new Error("invalid_request");
    const deleted = rpcOutcome(
      await userClient.rpc("superadmin_form_media_delete_v2", {
        p_request_id: envelope.request_id,
        p_asset_id: envelope.payload.asset_id,
      }),
    );
    if (!deleted.ok) return rpcFailure(origin, deleted);
    return response(origin, 200, {
      asset_id: envelope.payload.asset_id,
      status: "deleted",
      replayed: deleted.data.replayed === true,
    });
  } catch {
    return response(origin, 400, { error: "media_request_failed" });
  }
}

/** Worker do cron: expira tickets vencidos, reivindica a fila de limpeza,
 * apaga cada chave no R2 e da baixa. Uma chave que falhar no DELETE fica
 * reivindicada e volta a fila depois de 10 minutos (regra do banco). */
async function handleWorker(
  origin: string | null,
  action: "expire" | "cleanup",
  serviceClient: SupabaseClient,
  dependencies: FormMediaDependencies,
): Promise<Response> {
  try {
    const expired = rpcOutcome(
      await serviceClient.rpc("form_media_expire_question_r2_v1", {
        p_limit: 100,
      }),
    );
    if (!expired.ok) return rpcFailure(origin, expired);
    const summary: Json = { expired: expired.data.expired ?? 0 };
    if (action === "expire") return response(origin, 200, summary);
    const claimed = rpcOutcome(
      await serviceClient.rpc("form_media_claim_cleanup_r2_v1", {
        p_limit: 100,
      }),
    );
    if (!claimed.ok) return rpcFailure(origin, claimed);
    const items = Array.isArray(claimed.data.items) ? claimed.data.items : [];
    const transports = new Map<string, FormMediaTransport>();
    let purged = 0;
    let failed = 0;
    for (const raw of items) {
      const item = raw && typeof raw === "object" ? raw as Json : {};
      const bucket = item.bucket;
      const key = item.object_key;
      const cleanupId = item.cleanup_id;
      if (
        typeof bucket !== "string" || typeof key !== "string" ||
        typeof cleanupId !== "string"
      ) {
        failed++;
        continue;
      }
      try {
        let transport = transports.get(bucket);
        if (!transport) {
          transport = questionImageTransport(dependencies, bucket);
          transports.set(bucket, transport);
        }
        await transport.delete(key);
        const marked = rpcOutcome(
          await serviceClient.rpc("form_media_mark_purged_r2_v1", {
            p_cleanup_id: cleanupId,
          }),
        );
        if (!marked.ok) throw new Error(marked.code);
        purged++;
      } catch {
        failed++;
      }
    }
    return response(origin, 200, {
      ...summary,
      claimed: items.length,
      purged,
      failed,
    });
  } catch {
    return response(origin, 503, { error: "media_unavailable" });
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
  if (body.action === "expire" || body.action === "cleanup") {
    // Caminho do cron: bearer compartilhado do worker de Formularios, nunca
    // um JWT de usuario. Comparacao em tempo constante; falha e 401 opaco.
    if (
      !authorizedWorkerRequest(
        authorization,
        dependencies.envGet("FORMS_OPERATIONS_BEARER_TOKEN"),
      )
    ) {
      return response(origin, 401, { error: "unauthorized" });
    }
    try {
      const serviceClient = dependencies.createClient(url, service, {
        auth: { persistSession: false },
      });
      return await handleWorker(
        origin,
        body.action,
        serviceClient,
        dependencies,
      );
    } catch {
      return response(origin, 503, { error: "media_unavailable" });
    }
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
    if ("purpose" in body) {
      return await handleQuestionImage(
        origin,
        body,
        userClient,
        serviceClient,
        dependencies,
      );
    }
    if (!("request_id" in body)) {
      // Worker ja atendido antes da autenticacao de usuario; nunca chega aqui.
      return response(origin, 400, { error: "invalid_request" });
    }
    // Daqui para baixo e o fluxo legado de answer-image (Supabase Storage,
    // bucket coelo-forms-private): respostas continuam nele por contrato.
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
      if (
        answerR2Enabled(dependencies) &&
        (action === "prepare" || action === "finalize" || action === "download")
      ) {
        return await handleAnswerR2(
          origin,
          action,
          requestId,
          expectedVersion,
          body.payload,
          actorPersonId,
          userClient,
          serviceClient,
          dependencies,
        );
      }
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
