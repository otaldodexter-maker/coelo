// Chat attachment envelope, reserved locally by R01-C05-I007.
//
// Three shapes, kept apart on purpose:
//
//   asset   — what is stored. Mirrors public.chat_attachment_metadata, whose
//             upload_status already carries the `deleted` tombstone, so discard
//             marks and never erases the row or its audit.
//   attempt — one upload intention. Two distinct request ids, prepare and
//             finalize, so a retry replays each step instead of creating a
//             second asset.
//   binding — linking a ready asset to a message. It is declared here and
//             refused at runtime: chat_attachment_metadata.message_id is NOT
//             NULL and no staging branch exists yet, and R01-C05-I007 keeps
//             that SQL without reservation. Nothing here relaxes that column.
//
// None of this authorises anything. The server re-derives actor, tenant,
// conversation membership and capability, and measures the stored bytes itself.

/** Per-purpose limits, mirroring the approved Circular envelope. Chat carries no
 * video: ADR 0032 does not require Stream for Chat in the MVP. */
const maximumBytesByMime = new Map<string, number>([
  ["image/jpeg", 10 * 1024 * 1024],
  ["image/png", 10 * 1024 * 1024],
  ["image/webp", 10 * 1024 * 1024],
  ["application/pdf", 5 * 1024 * 1024],
]);

/** One attachment per message while the batch limit is an open decision. The
 * conservative value is deliberate; unlimited was never an option. */
export const maximumAttachmentsPerMessage = 1;

const uuidPattern =
  /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/;
const sha256Pattern = /^[0-9a-f]{64}$/;

export type ChatMediaAttempt = Readonly<{
  conversationId: string;
  requestId: string;
  finalizeRequestId: string;
  name: string;
  mimeType: string;
  sizeBytes: number;
}>;

export type ChatMediaAssetRef = Readonly<{
  conversationId: string;
  assetId: string;
  requestId: string;
}>;

export type ChatMediaBinding = Readonly<{
  conversationId: string;
  assetId: string;
  messageRequestId: string;
}>;

function text(value: unknown, maximumLength: number) {
  return typeof value === "string" && value.trim().length >= 1 &&
    value.length <= maximumLength;
}

function uuid(value: unknown) {
  return typeof value === "string" && uuidPattern.test(value);
}

export function validateChatMediaAttempt(
  body: Record<string, unknown>,
): ChatMediaAttempt {
  const maximumBytes = typeof body.mime_type === "string"
    ? maximumBytesByMime.get(body.mime_type)
    : undefined;
  if (
    !uuid(body.conversation_id) ||
    !uuid(body.request_id) ||
    !uuid(body.finalize_request_id) ||
    body.request_id === body.finalize_request_id ||
    !text(body.name, 240) ||
    // A control character in a file name is never a display problem only.
    /[\x00-\x1f\x7f]/.test(body.name as string) ||
    maximumBytes === undefined ||
    typeof body.size_bytes !== "number" ||
    !Number.isSafeInteger(body.size_bytes) ||
    body.size_bytes < 1 ||
    body.size_bytes > maximumBytes
  ) {
    throw new Error("invalid_request");
  }
  return {
    conversationId: body.conversation_id as string,
    requestId: body.request_id as string,
    finalizeRequestId: body.finalize_request_id as string,
    name: (body.name as string).trim(),
    mimeType: body.mime_type as string,
    sizeBytes: body.size_bytes,
  };
}

export function validateChatMediaAssetRef(
  body: Record<string, unknown>,
): ChatMediaAssetRef {
  if (
    !uuid(body.conversation_id) || !uuid(body.asset_id) ||
    !uuid(body.request_id)
  ) {
    throw new Error("invalid_request");
  }
  return {
    conversationId: body.conversation_id as string,
    assetId: body.asset_id as string,
    requestId: body.request_id as string,
  };
}

export function validateChatMediaBinding(
  body: Record<string, unknown>,
): ChatMediaBinding {
  if (
    !uuid(body.conversation_id) || !uuid(body.asset_id) ||
    !uuid(body.message_request_id)
  ) {
    throw new Error("invalid_request");
  }
  return {
    conversationId: body.conversation_id as string,
    assetId: body.asset_id as string,
    messageRequestId: body.message_request_id as string,
  };
}

/** The declared checksum is only ever compared against what the server measured
 * from the stored object. It is never accepted as the truth. */
export function matchesMeasuredChecksum(
  declared: unknown,
  measured: string,
): boolean {
  return typeof declared === "string" && sha256Pattern.test(declared) &&
    sha256Pattern.test(measured) && declared === measured;
}

/** The stored object has to agree with what was declared before an asset may be
 * marked ready. A larger or differently typed object is a refusal, not a
 * correction. */
export function measuredObjectMatches(
  attempt: Pick<ChatMediaAttempt, "mimeType" | "sizeBytes">,
  measured: { contentType?: string | null; contentLength?: number | null },
): boolean {
  return measured.contentType === attempt.mimeType &&
    typeof measured.contentLength === "number" &&
    measured.contentLength === attempt.sizeBytes;
}
