import { assertEquals, assertThrows } from "jsr:@std/assert";

import {
  matchesMeasuredChecksum,
  maximumAttachmentsPerMessage,
  measuredObjectMatches,
  validateChatMediaAssetRef,
  validateChatMediaAttempt,
  validateChatMediaBinding,
} from "./media_contract.ts";

const conversation = "11111111-1111-4111-8111-111111111111";
const request = "22222222-2222-4222-8222-222222222222";
const finalize = "33333333-3333-4333-8333-333333333333";
const asset = "44444444-4444-4444-8444-444444444444";

function attempt(overrides: Record<string, unknown> = {}) {
  return {
    conversation_id: conversation,
    request_id: request,
    finalize_request_id: finalize,
    name: "registro.png",
    mime_type: "image/png",
    size_bytes: 1024,
    ...overrides,
  };
}

Deno.test("accepts the approved Chat media types and their limits", () => {
  assertEquals(validateChatMediaAttempt(attempt()).mimeType, "image/png");
  assertEquals(
    validateChatMediaAttempt(attempt({ size_bytes: 10 * 1024 * 1024 })).sizeBytes,
    10 * 1024 * 1024,
  );
  assertEquals(
    validateChatMediaAttempt(
      attempt({ mime_type: "application/pdf", size_bytes: 5 * 1024 * 1024 }),
    ).mimeType,
    "application/pdf",
  );
});

Deno.test("refuses a type outside the Chat allowlist", () => {
  for (
    const mimeType of [
      "video/mp4",
      "application/vnd.ms-excel",
      "text/html",
      "image/svg+xml",
      "",
    ]
  ) {
    assertThrows(
      () => validateChatMediaAttempt(attempt({ mime_type: mimeType })),
      Error,
      "invalid_request",
    );
  }
});

Deno.test("refuses a size above the limit of its own type", () => {
  assertThrows(
    () => validateChatMediaAttempt(attempt({ size_bytes: 10 * 1024 * 1024 + 1 })),
    Error,
    "invalid_request",
  );
  // A PDF may not borrow the image allowance.
  assertThrows(
    () =>
      validateChatMediaAttempt(
        attempt({ mime_type: "application/pdf", size_bytes: 5 * 1024 * 1024 + 1 }),
      ),
    Error,
    "invalid_request",
  );
  for (const size of [0, -1, 1.5, Number.MAX_SAFE_INTEGER + 2]) {
    assertThrows(
      () => validateChatMediaAttempt(attempt({ size_bytes: size })),
      Error,
      "invalid_request",
    );
  }
});

Deno.test("requires two distinct intent ids", () => {
  assertThrows(
    () => validateChatMediaAttempt(attempt({ finalize_request_id: request })),
    Error,
    "invalid_request",
  );
  for (const value of ["", "not-a-uuid", `${request}-finalize`, null, 42]) {
    assertThrows(
      () => validateChatMediaAttempt(attempt({ request_id: value })),
      Error,
      "invalid_request",
    );
    assertThrows(
      () => validateChatMediaAttempt(attempt({ finalize_request_id: value })),
      Error,
      "invalid_request",
    );
  }
});

Deno.test("refuses a name that is blank, oversized or carries control characters", () => {
  for (
    const name of [
      "",
      "   ",
      "a".repeat(241),
      "registro\x00.png",
      "registro\x1f.png",
      "registro\x7f.png",
    ]
  ) {
    assertThrows(
      () => validateChatMediaAttempt(attempt({ name })),
      Error,
      "invalid_request",
    );
  }
  assertEquals(validateChatMediaAttempt(attempt({ name: "  foto.png  " })).name, "foto.png");
});

Deno.test("an asset reference needs the conversation, the asset and the intent", () => {
  assertEquals(
    validateChatMediaAssetRef({
      conversation_id: conversation,
      asset_id: asset,
      request_id: request,
    }).assetId,
    asset,
  );
  assertThrows(
    () =>
      validateChatMediaAssetRef({
        conversation_id: conversation,
        asset_id: "asset",
        request_id: request,
      }),
    Error,
    "invalid_request",
  );
});

Deno.test("a binding needs the message intent it will be linked to", () => {
  assertEquals(
    validateChatMediaBinding({
      conversation_id: conversation,
      asset_id: asset,
      message_request_id: request,
    }).messageRequestId,
    request,
  );
  assertThrows(
    () =>
      validateChatMediaBinding({
        conversation_id: conversation,
        asset_id: asset,
      }),
    Error,
    "invalid_request",
  );
});

Deno.test("the declared checksum only ever matches a measured one", () => {
  const measured = "a".repeat(64);
  assertEquals(matchesMeasuredChecksum(measured, measured), true);
  assertEquals(matchesMeasuredChecksum("b".repeat(64), measured), false);
  assertEquals(matchesMeasuredChecksum("A".repeat(64), measured), false);
  assertEquals(matchesMeasuredChecksum("abc", measured), false);
  assertEquals(matchesMeasuredChecksum(null, measured), false);
  assertEquals(matchesMeasuredChecksum(measured, "not-a-digest"), false);
});

Deno.test("the stored object has to agree with what was declared", () => {
  const declared = { mimeType: "image/png", sizeBytes: 1024 };
  assertEquals(
    measuredObjectMatches(declared, { contentType: "image/png", contentLength: 1024 }),
    true,
  );
  // A smaller or larger object is a refusal, not a correction.
  assertEquals(
    measuredObjectMatches(declared, { contentType: "image/png", contentLength: 1023 }),
    false,
  );
  assertEquals(
    measuredObjectMatches(declared, { contentType: "image/jpeg", contentLength: 1024 }),
    false,
  );
  assertEquals(
    measuredObjectMatches(declared, { contentType: null, contentLength: 1024 }),
    false,
  );
  assertEquals(
    measuredObjectMatches(declared, { contentType: "image/png", contentLength: null }),
    false,
  );
});

Deno.test("the batch limit stays at the conservative value", () => {
  assertEquals(maximumAttachmentsPerMessage, 1);
});
