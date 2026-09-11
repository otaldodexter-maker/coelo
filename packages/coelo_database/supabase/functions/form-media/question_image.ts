/**
 * Ramo `question-image` (imagem de pergunta na autoria do Superadmin) da
 * Edge Function form-media, sobre o R2 privado (ADR 0032) e o catalogo
 * private_media_catalog, conforme o lote 33
 * (20260911210300_forms_question_media_r2_v1.sql) e o contratoFormsFiles
 * rev 19 do realm interno.
 *
 * Este modulo nao fala com rede nem com banco: ele valida o envelope que o
 * cliente envia, traduz o envelope `{ok, data, error}` das RPCs para a
 * resposta HTTP e mede as dimensoes reais dos bytes ja armazenados. As
 * respostas (answer-image) continuam no fluxo legado de media_contract.ts.
 */

export const QUESTION_IMAGE_PURPOSE = "question-image";
export const QUESTION_IMAGE_BUCKET = "coelo-media-prod";
/** Limite do catalogo (constraint de media_assets para form-image). */
export const QUESTION_IMAGE_MAX_BYTES = 4 * 1024 * 1024;
export const QUESTION_IMAGE_MAX_PIXELS = 2560;
/** PUT assinado curto: o ticket do banco dura 30 min, a URL nao precisa. */
export const QUESTION_IMAGE_UPLOAD_TTL_SECONDS = 300;
/** Teto local do GET assinado; o banco ainda manda o `ttl_seconds` menor. */
export const QUESTION_IMAGE_READ_TTL_SECONDS = 300;
export const QUESTION_IMAGE_MIME_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256 = /^[0-9a-f]{64}$/i;

export type QuestionImagePrepare = Readonly<{
  form_id: string;
  form_version_id: string;
  item_id: string;
  mime_type: string;
  byte_size: number;
  sha256: string;
}>;

export type QuestionImageAccess = Readonly<{ asset_id: string }>;

function record(value: unknown, code: string): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error(code);
  }
  return value as Record<string, unknown>;
}

function uuid(value: unknown): string {
  if (typeof value !== "string" || !UUID.test(value)) {
    throw new Error("invalid_payload");
  }
  return value.toLowerCase();
}

/** O payload de prepare e reconhecido como question-image quando traz
 * `purpose: "question-image"` ou quando identifica o formulario
 * (`form_id` + `form_version_id`) em vez da ocorrencia do fluxo legado. */
export function isQuestionImagePayload(value: unknown): boolean {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const payload = value as Record<string, unknown>;
  return payload.purpose === QUESTION_IMAGE_PURPOSE ||
    ("form_id" in payload && "form_version_id" in payload);
}

/** Aceita os nomes do cliente Dart legado (`byte_length`, `checksum`) e os do
 * contrato do banco (`byte_size`, `sha256`). `edit_secret` e ignorado: a
 * autoria de pergunta e sempre identificada pelo JWT do Superadmin. */
export function parseQuestionImagePrepare(
  value: unknown,
): QuestionImagePrepare {
  const payload = record(value, "invalid_payload");
  const allowed = new Set([
    "purpose",
    "form_id",
    "form_version_id",
    "item_id",
    "mime_type",
    "byte_length",
    "byte_size",
    "checksum",
    "sha256",
    "edit_secret", // ignorado no ramo question-image
  ]);
  if (Object.keys(payload).some((key) => !allowed.has(key))) {
    throw new Error("unknown_key");
  }
  if (
    payload.purpose !== undefined && payload.purpose !== QUESTION_IMAGE_PURPOSE
  ) {
    throw new Error("invalid_payload");
  }
  const byteSize = payload.byte_size ?? payload.byte_length;
  const sha = payload.sha256 ?? payload.checksum;
  if (
    ("byte_size" in payload && "byte_length" in payload) ||
    ("sha256" in payload && "checksum" in payload) ||
    typeof payload.mime_type !== "string" ||
    !QUESTION_IMAGE_MIME_TYPES.has(payload.mime_type) ||
    typeof byteSize !== "number" || !Number.isSafeInteger(byteSize) ||
    byteSize < 1 || byteSize > QUESTION_IMAGE_MAX_BYTES ||
    typeof sha !== "string" || !SHA256.test(sha)
  ) throw new Error("invalid_payload");
  return Object.freeze({
    form_id: uuid(payload.form_id),
    form_version_id: uuid(payload.form_version_id),
    item_id: uuid(payload.item_id),
    mime_type: payload.mime_type,
    byte_size: byteSize,
    sha256: sha.toLowerCase(),
  });
}

export function parseQuestionImageAccess(value: unknown): QuestionImageAccess {
  const payload = record(value, "invalid_payload");
  // `edit_secret` chega do cliente legado e e ignorado neste ramo.
  const allowed = new Set(["purpose", "asset_id", "edit_secret"]);
  if (
    Object.keys(payload).some((key) => !allowed.has(key)) ||
    (payload.purpose !== undefined &&
      payload.purpose !== QUESTION_IMAGE_PURPOSE)
  ) throw new Error("invalid_payload");
  return Object.freeze({ asset_id: uuid(payload.asset_id) });
}

// ---------------------------------------------------------------------------
// Envelope {ok, data, error} das RPCs do lote 33
// ---------------------------------------------------------------------------

export type RpcOutcome =
  | { ok: true; data: Record<string, unknown> }
  | {
    ok: false;
    status: number;
    code: string;
    message: string | null;
    correlationId: string | null;
  };

const CLIENT_CODE = /^(FORM_MEDIA|SAI)_[A-Z_]{1,64}$/;

/** Traduz o retorno de uma RPC do lote 33. Um erro de transporte/PostgREST
 * (`error` do supabase-js) ou um envelope malformado viram
 * `media_request_failed`; codigos `FORM_MEDIA_*` e `SAI_*` passam ao cliente
 * com o `http_status` que o banco escolheu, sem texto livre alem da mensagem
 * curta do proprio envelope. */
export function rpcOutcome(
  response: { data?: unknown; error?: unknown },
): RpcOutcome {
  if (response.error) {
    return {
      ok: false,
      status: 400,
      code: "media_request_failed",
      message: null,
      correlationId: null,
    };
  }
  let envelope: Record<string, unknown>;
  try {
    envelope = record(response.data, "invalid_envelope");
  } catch {
    return {
      ok: false,
      status: 400,
      code: "media_request_failed",
      message: null,
      correlationId: null,
    };
  }
  if (envelope.ok === true && envelope.error == null) {
    try {
      return { ok: true, data: record(envelope.data, "invalid_envelope") };
    } catch {
      return {
        ok: false,
        status: 400,
        code: "media_request_failed",
        message: null,
        correlationId: null,
      };
    }
  }
  // Envelope contraditorio (ok sem ser false, ou erro sem objeto) nao e
  // interpretado: vira falha opaca em vez de passar um codigo do banco.
  const error = envelope.ok === false && envelope.error &&
      typeof envelope.error === "object" && !Array.isArray(envelope.error)
    ? envelope.error as Record<string, unknown>
    : {};
  const code = typeof error.code === "string" && CLIENT_CODE.test(error.code)
    ? error.code
    : "media_request_failed";
  const status = typeof error.http_status === "number" &&
      Number.isInteger(error.http_status) && error.http_status >= 400 &&
      error.http_status <= 599
    ? error.http_status
    : code === "media_request_failed"
    ? 400
    : 409;
  return {
    ok: false,
    status,
    code,
    message: typeof error.message === "string" && error.message.length <= 240
      ? error.message
      : null,
    correlationId: typeof error.correlation_id === "string" &&
        UUID.test(error.correlation_id)
      ? error.correlation_id
      : null,
  };
}

/** A chave devolvida pelo banco tem que ser a canonica de question-image do
 * proprio ativo; nada fora disso e assinado. */
export function questionImageObjectKey(
  data: Record<string, unknown>,
  assetId: string,
): string {
  const key = data.object_key;
  const mime = data.mime_type;
  const extension = mime === "image/jpeg"
    ? "jpg"
    : mime === "image/png"
    ? "png"
    : mime === "image/webp"
    ? "webp"
    : null;
  const uuid = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
  if (
    data.asset_id !== assetId || data.bucket !== QUESTION_IMAGE_BUCKET ||
    !extension || typeof key !== "string" ||
    !new RegExp(
      `^tenants/${uuid}/forms/form/${uuid}/question-image/${assetId}/original/${uuid}\\.${extension}$`,
    ).test(key)
  ) throw new Error("invalid_descriptor");
  return key;
}

// ---------------------------------------------------------------------------
// Medicao dos bytes armazenados
// ---------------------------------------------------------------------------

export type ImageDimensions = Readonly<{ width: number; height: number }>;

const u16be = (bytes: Uint8Array, at: number) =>
  (bytes[at] << 8) | bytes[at + 1];
const u16le = (bytes: Uint8Array, at: number) =>
  bytes[at] | (bytes[at + 1] << 8);
const u24le = (bytes: Uint8Array, at: number) =>
  bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16);
const u32be = (bytes: Uint8Array, at: number) =>
  ((bytes[at] << 24) >>> 0) + ((bytes[at + 1] << 16) | (bytes[at + 2] << 8) |
    bytes[at + 3]);
const u32le = (bytes: Uint8Array, at: number) =>
  (bytes[at] | (bytes[at + 1] << 8) | (bytes[at + 2] << 16)) +
  bytes[at + 3] * 0x1000000;
const ascii = (bytes: Uint8Array, start: number, end: number) =>
  String.fromCharCode(...bytes.subarray(start, end));

function pngDimensions(bytes: Uint8Array): ImageDimensions | null {
  if (bytes.length < 24 || ascii(bytes, 12, 16) !== "IHDR") return null;
  return { width: u32be(bytes, 16), height: u32be(bytes, 20) };
}

function jpegDimensions(bytes: Uint8Array): ImageDimensions | null {
  let offset = 2;
  while (offset + 4 <= bytes.length) {
    if (bytes[offset] !== 0xff) return null;
    const marker = bytes[offset + 1];
    if (marker === 0xff) {
      offset++;
      continue;
    }
    // Marcadores sem carga (RSTn, SOI, EOI, TEM).
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd9)) {
      offset += 2;
      continue;
    }
    const length = u16be(bytes, offset + 2);
    if (length < 2) return null;
    const startOfFrame = marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 &&
      marker !== 0xc8 && marker !== 0xcc;
    if (startOfFrame) {
      if (offset + 9 > bytes.length) return null;
      return {
        height: u16be(bytes, offset + 5),
        width: u16be(bytes, offset + 7),
      };
    }
    if (marker === 0xda) return null; // Start of Scan sem SOF antes: invalido.
    offset += 2 + length;
  }
  return null;
}

function webpDimensions(bytes: Uint8Array): ImageDimensions | null {
  if (bytes.length < 30) return null;
  const chunk = ascii(bytes, 12, 16);
  if (chunk === "VP8 ") {
    if (bytes[23] !== 0x9d || bytes[24] !== 0x01 || bytes[25] !== 0x2a) {
      return null;
    }
    return {
      width: u16le(bytes, 26) & 0x3fff,
      height: u16le(bytes, 28) & 0x3fff,
    };
  }
  if (chunk === "VP8L") {
    if (bytes[20] !== 0x2f) return null;
    const bits = u32le(bytes, 21);
    return {
      width: (bits & 0x3fff) + 1,
      height: ((bits >>> 14) & 0x3fff) + 1,
    };
  }
  if (chunk === "VP8X") {
    return { width: u24le(bytes, 24) + 1, height: u24le(bytes, 27) + 1 };
  }
  return null;
}

/** Dimensoes lidas do cabecalho real. `null` quando os bytes nao sao do tipo
 * declarado ou nao trazem cabecalho decodificavel; o banco trata `null` como
 * divergencia (FORM_MEDIA_MISMATCH) e enfileira a limpeza. Nao e um
 * decodificador completo: nao prova que a imagem renderiza. */
export function imageDimensions(
  bytes: Uint8Array,
  mimeType: string,
): ImageDimensions | null {
  let dimensions: ImageDimensions | null = null;
  if (mimeType === "image/png") dimensions = pngDimensions(bytes);
  else if (mimeType === "image/jpeg") dimensions = jpegDimensions(bytes);
  else if (mimeType === "image/webp") dimensions = webpDimensions(bytes);
  if (
    !dimensions || !Number.isSafeInteger(dimensions.width) ||
    !Number.isSafeInteger(dimensions.height) || dimensions.width < 1 ||
    dimensions.height < 1
  ) return null;
  return dimensions;
}

// ---------------------------------------------------------------------------
// Bearer do worker (expire/cleanup por cron)
// ---------------------------------------------------------------------------

const WORKER_TOKEN = /^[\x21-\x7e]{32,256}$/;

function constantTimeEqual(left: string, right: string): boolean {
  const length = Math.max(left.length, right.length);
  let difference = left.length ^ right.length;
  for (let index = 0; index < length; index++) {
    difference |= (left.charCodeAt(index) || 0) ^
      (right.charCodeAt(index) || 0);
  }
  return difference === 0;
}

/** O cron chama `expire`/`cleanup` com o mesmo bearer do worker de Formularios
 * (`FORMS_OPERATIONS_BEARER_TOKEN`, Vault `forms_worker_bearer_token`), como
 * form-operations. Um token ausente ou fora do formato nega tudo. */
export function authorizedWorkerRequest(
  authorization: string | null,
  configuredToken: string | undefined,
): boolean {
  const expected = configuredToken ?? "";
  if (!WORKER_TOKEN.test(expected)) return false;
  if (!authorization?.startsWith("Bearer ")) return false;
  return constantTimeEqual(authorization.slice(7), expected);
}
