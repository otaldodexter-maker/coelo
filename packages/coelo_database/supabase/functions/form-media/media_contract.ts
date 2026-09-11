export const FORMS_BUCKET = "coelo-forms-private";
export const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
export const ALLOWED_IMAGE_TYPES = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);

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
    const parsed = new URL(origin);
    return parsed.origin === origin ? origin : null;
  } catch {
    return null;
  }
}

export function corsHeaders(origin: string | null): Record<string, string> {
  return {
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
    headers: corsHeaders(origin),
  });
}

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA256 = /^[0-9a-f]{64}$/;

export type FormMediaRead = {
  asset_id: string;
  rendition: "original" | "preview";
};

export type FormMediaEnvelope =
  | { action: "read"; payload: FormMediaRead }
  | { action: "question_prepare"; request_id: string; payload: QuestionPrepare }
  | {
    action: "question_finalize" | "question_resolve" | "question_delete";
    request_id: string;
    payload: { asset_id: string };
  }
  | LegacyFormMediaEnvelope;

// R05 realm-interno: imagem de pergunta (autoria do Superadmin) no R2.
export type QuestionPrepare = {
  form_id: string;
  form_version_id: string;
  item_id: string;
  mime_type: string;
  byte_length: number;
  checksum: string;
};

export function parseQuestionPrepare(value: unknown): QuestionPrepare {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_payload");
  }
  const payload = value as Record<string, unknown>;
  const allowed = new Set([
    "form_id",
    "form_version_id",
    "item_id",
    "mime_type",
    "byte_length",
    "checksum",
  ]);
  if (Object.keys(payload).some((key) => !allowed.has(key))) {
    throw new Error("unknown_key");
  }
  if (
    typeof payload.form_id !== "string" || !UUID.test(payload.form_id) ||
    typeof payload.form_version_id !== "string" ||
    !UUID.test(payload.form_version_id) ||
    typeof payload.item_id !== "string" || !UUID.test(payload.item_id) ||
    typeof payload.mime_type !== "string" ||
    !ALLOWED_IMAGE_TYPES.has(payload.mime_type) ||
    typeof payload.byte_length !== "number" ||
    !Number.isSafeInteger(payload.byte_length) ||
    payload.byte_length < 1 || payload.byte_length > 4 * 1024 * 1024 ||
    typeof payload.checksum !== "string" || !SHA256.test(payload.checksum)
  ) throw new Error("invalid_payload");
  return payload as QuestionPrepare;
}

type LegacyFormMediaEnvelope =
  & {
    request_id: string;
    expected_version: number;
  }
  & (
    | { action: "prepare"; payload: PrepareAsset }
    | { action: "finalize" | "download" | "discard"; payload: AssetAccess }
  );

export function parseFormMediaEnvelope(value: unknown): FormMediaEnvelope {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_envelope");
  }
  const data = value as Record<string, unknown>;
  if (data.action === "read") {
    if (
      Object.keys(data).some((key) => key !== "action" && key !== "payload")
    ) {
      throw new Error("invalid_envelope");
    }
    const payload = data.payload;
    if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
      throw new Error("invalid_payload");
    }
    const read = payload as Record<string, unknown>;
    if (
      Object.keys(read).some((key) =>
        key !== "asset_id" && key !== "rendition"
      ) ||
      typeof read.asset_id !== "string" || !UUID.test(read.asset_id) ||
      (read.rendition !== "original" && read.rendition !== "preview")
    ) {
      throw new Error("invalid_payload");
    }
    return {
      action: "read",
      payload: {
        asset_id: read.asset_id.toLowerCase(),
        rendition: read.rendition,
      },
    };
  }
  if (
    data.action === "question_prepare" || data.action === "question_finalize" ||
    data.action === "question_resolve" || data.action === "question_delete"
  ) {
    if (
      Object.keys(data).some((key) =>
        key !== "action" && key !== "request_id" && key !== "payload"
      ) || typeof data.request_id !== "string" || !UUID.test(data.request_id)
    ) {
      throw new Error("invalid_envelope");
    }
    if (data.action === "question_prepare") {
      return {
        action: "question_prepare",
        request_id: data.request_id,
        payload: parseQuestionPrepare(data.payload),
      };
    }
    const payload = data.payload as Record<string, unknown> | null;
    if (
      !payload || typeof payload !== "object" || Array.isArray(payload) ||
      Object.keys(payload).some((key) => key !== "asset_id") ||
      typeof payload.asset_id !== "string" || !UUID.test(payload.asset_id)
    ) {
      throw new Error("invalid_payload");
    }
    return {
      action: data.action,
      request_id: data.request_id,
      payload: { asset_id: payload.asset_id.toLowerCase() },
    };
  }
  const keys = new Set(["action", "request_id", "expected_version", "payload"]);
  if (
    Object.keys(data).some((key) => !keys.has(key)) ||
    typeof data.request_id !== "string" || !UUID.test(data.request_id) ||
    typeof data.expected_version !== "number" ||
    !Number.isSafeInteger(data.expected_version) || data.expected_version < 0
  ) {
    throw new Error("invalid_envelope");
  }
  const common = {
    request_id: data.request_id,
    expected_version: data.expected_version,
  };
  if (data.action === "prepare") {
    return {
      ...common,
      action: data.action,
      payload: parsePrepareAsset(data.payload),
    };
  }
  if (
    data.action === "finalize" || data.action === "download" ||
    data.action === "discard"
  ) {
    return {
      ...common,
      action: data.action,
      payload: parseAssetAccess(data.payload),
    };
  }
  throw new Error("invalid_envelope");
}

function readReceipt(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_read_receipt");
  }
  return value as Record<string, unknown>;
}

function readExpiry(value: unknown): number {
  if (typeof value !== "string") throw new Error("invalid_read_expiry");
  const match =
    /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d{1,6})?(?:Z|[+-](\d{2}):(\d{2}))$/
      .exec(value);
  // JS $ can stop before a trailing newline; require the entire input.
  if (!match || match[0] !== value) throw new Error("invalid_read_expiry");
  const [year, month, day, hour, minute, second] = match.slice(1, 7).map(
    Number,
  );
  const leap = year % 4 === 0 && (year % 100 !== 0 || year % 400 === 0);
  const days = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  if (
    year < 1 || month < 1 || month > 12 || day < 1 || day > days[month - 1] ||
    hour > 23 || minute > 59 || second > 59 ||
    Number(match[7] ?? 0) > 23 || Number(match[8] ?? 0) > 59
  ) {
    throw new Error("invalid_read_expiry");
  }
  // Parse only after validating every component: Date.parse otherwise rolls
  // impossible calendar days and 24:00 into a different authorized expiry.
  const time = Date.parse(value);
  if (!Number.isFinite(time)) throw new Error("invalid_read_expiry");
  return time;
}

export function parseFormMediaReadGrant(
  value: unknown,
  request: FormMediaRead,
) {
  const envelope = readReceipt(value);
  if (envelope.ok !== true || envelope.error != null) {
    throw new Error("read_denied");
  }
  const data = readReceipt(envelope.data);
  if (
    data.asset_id !== request.asset_id ||
    data.rendition !== request.rendition ||
    typeof data.read_token !== "string" || !UUID.test(data.read_token)
  ) {
    throw new Error("invalid_read_grant");
  }
  return { readToken: data.read_token, expiresAt: readExpiry(data.expires_at) };
}

export function parseFormMediaReadDescriptor(
  value: unknown,
  request: FormMediaRead,
) {
  const data = readReceipt(value);
  if (
    data.asset_id !== request.asset_id ||
    data.rendition !== request.rendition ||
    typeof data.media_asset_id !== "string" ||
    !UUID.test(data.media_asset_id) ||
    typeof data.institution_id !== "string" ||
    !UUID.test(data.institution_id) ||
    typeof data.form_id !== "string" || !UUID.test(data.form_id) ||
    data.bucket !== "coelo-media-prod" || typeof data.object_key !== "string" ||
    data.object_key.split("").some((character) =>
      character.charCodeAt(0) <= 32 || character.charCodeAt(0) === 127
    )
  ) {
    throw new Error("invalid_read_descriptor");
  }
  // Match I003's canonical locator against every server-authorized context ID.
  const uuid = "[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}";
  const extension = data.mime_type === "image/jpeg"
    ? "jpg"
    : data.mime_type === "image/png"
    ? "png"
    : data.mime_type === "image/webp"
    ? "webp"
    : null;
  if (
    !extension || !new RegExp(
      `^tenants/${data.institution_id}/forms/form/${data.form_id}/answer-image/${data.media_asset_id}/${request.rendition}/${uuid}\\.${extension}$`,
    ).test(data.object_key)
  ) throw new Error("invalid_read_locator");
  return {
    bucket: data.bucket,
    objectKey: data.object_key,
    expiresAt: readExpiry(data.expires_at),
  };
}

/** A command contains metadata only. Bound actual bytes before parsing or
 * contacting Auth/RPC; Content-Length supplied by a caller is not trusted.
 */
export async function readFormMediaEnvelope(
  request: Request,
): Promise<FormMediaEnvelope> {
  if (!request.body) throw new Error("invalid_json");
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let length = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      length += value.byteLength;
      if (length > 32_768) throw new Error("payload_too_large");
      if (value.byteLength) chunks.push(value);
    }
  } finally {
    await reader.cancel().catch(() => {});
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  let value: unknown;
  try {
    value = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
  } catch {
    throw new Error("invalid_json");
  }
  return parseFormMediaEnvelope(value);
}

export type PrepareAsset = {
  occurrence_id: string;
  item_id: string;
  mime_type: string;
  byte_length: number;
  checksum: string;
  edit_secret?: string;
};

export type AssetAccess = { asset_id: string; edit_secret?: string };

function validOptionalSecret(value: unknown): boolean {
  return value === undefined ||
    (typeof value === "string" && value.length >= 32 && value.length <= 256);
}

export function parsePrepareAsset(value: unknown): PrepareAsset {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_payload");
  }
  const payload = value as Record<string, unknown>;
  const allowed = new Set([
    "occurrence_id",
    "item_id",
    "mime_type",
    "byte_length",
    "checksum",
    "edit_secret",
  ]);
  if (Object.keys(payload).some((key) => !allowed.has(key))) {
    throw new Error("unknown_key");
  }
  if (
    typeof payload.occurrence_id !== "string" ||
    !UUID.test(payload.occurrence_id) ||
    typeof payload.item_id !== "string" || !UUID.test(payload.item_id) ||
    typeof payload.mime_type !== "string" ||
    !ALLOWED_IMAGE_TYPES.has(payload.mime_type) ||
    typeof payload.byte_length !== "number" ||
    !Number.isSafeInteger(payload.byte_length) ||
    payload.byte_length < 1 || payload.byte_length > MAX_IMAGE_BYTES ||
    typeof payload.checksum !== "string" || !SHA256.test(payload.checksum) ||
    !validOptionalSecret(payload.edit_secret)
  ) throw new Error("invalid_payload");
  return payload as PrepareAsset;
}

export function parseAssetAccess(value: unknown): AssetAccess {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new Error("invalid_payload");
  }
  const payload = value as Record<string, unknown>;
  const allowed = new Set(["asset_id", "edit_secret"]);
  if (
    Object.keys(payload).some((key) => !allowed.has(key)) ||
    typeof payload.asset_id !== "string" || !UUID.test(payload.asset_id) ||
    !validOptionalSecret(payload.edit_secret)
  ) throw new Error("invalid_payload");
  return payload as AssetAccess;
}

export function opaqueStoragePath(path: unknown): path is string {
  return typeof path === "string" && /^[0-9a-f]{2}\/[0-9a-f-]{36}$/.test(path);
}

export function shouldVerifyFinalization(state: unknown): boolean {
  return state !== "finalized";
}

export function workerFinalizationSucceeded(value: unknown): boolean {
  return value != null && typeof value === "object" &&
    !Array.isArray(value) &&
    (value as Record<string, unknown>).state === "finalized";
}

export function sniffImageMime(bytes: Uint8Array): string | null {
  if (
    bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 &&
    bytes[2] === 0xff
  ) {
    return "image/jpeg";
  }
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return "image/png";
  }
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
    bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 &&
    bytes[11] === 0x50
  ) {
    return "image/webp";
  }
  return null;
}

export async function sha256(bytes: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    Uint8Array.from(bytes).buffer,
  );
  return [...new Uint8Array(digest)].map((byte) =>
    byte.toString(16).padStart(2, "0")
  ).join("");
}
