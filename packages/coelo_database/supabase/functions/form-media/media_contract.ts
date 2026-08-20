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
