import { assertEquals, assertRejects, assertThrows } from "@std/assert";
import {
  allowedOrigin,
  corsHeaders,
  handleCorsPreflight,
  MAX_IMAGE_BYTES,
  opaqueStoragePath,
  parseAssetAccess,
  parseFormMediaEnvelope,
  parseFormMediaReadDescriptor,
  parseFormMediaReadGrant,
  parsePrepareAsset,
  readFormMediaEnvelope,
  sha256,
  shouldVerifyFinalization,
  sniffImageMime,
  workerFinalizationSucceeded,
} from "./media_contract.ts";

const allowed = "https://superadmin.coelo.me,http://127.0.0.1:8765";

Deno.test("read receipts reject normalized calendars, clocks, offsets and trailing characters", () => {
  const id = "11111111-1111-4111-8111-111111111111";
  const request = { asset_id: id, rendition: "preview" as const };
  const grant = { ...request, read_token: id };
  const descriptor = {
    ...request,
    media_asset_id: id,
    institution_id: id,
    form_id: id,
    bucket: "coelo-media-prod",
    mime_type: "image/webp",
    object_key:
      `tenants/${id}/forms/form/${id}/answer-image/${id}/preview/${id}.webp`,
  };
  for (
    const expiry of [
      "2026-02-30T16:01:00Z",
      "1900-02-29T16:01:00Z",
      "2026-02-29T16:01:00Z",
      "2026-04-31T16:01:00Z",
      "2026-00-01T16:01:00Z",
      "2026-13-01T16:01:00Z",
      "2026-09-00T16:01:00Z",
      "2026-09-08T24:00:00Z",
      "2026-09-08T16:60:00Z",
      "2026-09-08T16:01:60Z",
      "2026-09-08T16:01:00+24:00",
      "2026-09-08T16:01:00-00:60",
      "2026-09-08T16:01:00Z\n",
      "2026-09-08T16:01:00Z\r\n",
      "2026-09-08T16:01:00.1234567Z",
      "2026-09-08T16:01:00",
    ]
  ) {
    assertThrows(
      () =>
        parseFormMediaReadGrant({
          ok: true,
          data: { ...grant, expires_at: expiry },
        }, request),
      Error,
      undefined,
      expiry,
    );
    assertThrows(
      () =>
        parseFormMediaReadDescriptor(
          { ...descriptor, expires_at: expiry },
          request,
        ),
      Error,
      undefined,
      expiry,
    );
  }
  for (
    const expiry of [
      "2000-02-29T16:01:00Z",
      "2024-02-29T16:01:00.123456Z",
      "2026-09-08T19:01:00.123456+03:00",
      "2026-09-08T13:01:00.1-03:00",
    ]
  ) {
    assertEquals(
      parseFormMediaReadGrant({
        ok: true,
        data: { ...grant, expires_at: expiry },
      }, request).expiresAt,
      Date.parse(expiry),
    );
    assertEquals(
      parseFormMediaReadDescriptor(
        { ...descriptor, expires_at: expiry },
        request,
      ).expiresAt,
      Date.parse(expiry),
    );
  }
});

Deno.test("read grant rejects contradictory success envelopes", () => {
  const id = "11111111-1111-4111-8111-111111111111";
  const request = { asset_id: id, rendition: "preview" as const };
  const data = {
    ...request,
    read_token: id,
    expires_at: "2026-09-08T16:01:00Z",
  };
  for (const error of [{ code: "SAI_PERMISSION_DENIED" }, false, 0, ""]) {
    assertThrows(() =>
      parseFormMediaReadGrant({ ok: true, data, error }, request)
    );
  }
  for (const error of [null, undefined]) {
    assertEquals(
      parseFormMediaReadGrant({ ok: true, data, error }, request).readToken,
      id,
    );
  }
});

Deno.test("read envelope accepts only the isolated asset and rendition contract", () => {
  const payload = {
    asset_id: "11111111-1111-4111-8111-111111111111",
    rendition: "preview",
  };
  for (const rendition of ["preview", "original"] as const) {
    const input = {
      action: "read" as const,
      payload: { ...payload, rendition },
    };
    assertEquals(parseFormMediaEnvelope(input), input);
  }
  for (
    const input of [
      { action: "read", payload, request_id: payload.asset_id },
      { action: "read", payload, expected_version: 0 },
      { action: "read", payload, actor_id: payload.asset_id },
      { action: "read", payload: { ...payload, asset_id: "bad" } },
      { action: "read", payload: { ...payload, rendition: "master" } },
      { action: "read", payload: { asset_id: payload.asset_id } },
      { action: "read", payload: { ...payload, edit_secret: "s".repeat(43) } },
      { action: "read", payload: { ...payload, object_key: "private" } },
      { action: "read", payload: null },
      { action: "read", payload: [] },
    ]
  ) assertThrows(() => parseFormMediaEnvelope(input));
});

Deno.test("answers only allowlisted browser preflights", async () => {
  const request = new Request("https://example.test/form-media", {
    method: "OPTIONS",
    headers: { origin: "https://superadmin.coelo.me" },
  });
  const origin = allowedOrigin(request, allowed);
  const response = handleCorsPreflight(
    request,
    origin,
  );

  assertEquals(origin, "https://superadmin.coelo.me");
  assertEquals(response?.status, 204);
  assertEquals(
    response?.headers.get("access-control-allow-origin"),
    "https://superadmin.coelo.me",
  );
  assertEquals(
    response?.headers.get("access-control-allow-headers"),
    "authorization, x-client-info, apikey, content-type",
  );
  assertEquals(response?.headers.get("vary"), "Origin");
  assertEquals(await response?.text(), "");
  assertEquals(
    handleCorsPreflight(
      new Request("https://example.test/form-media", { method: "POST" }),
      null,
    ),
    null,
  );
  assertEquals(
    corsHeaders(origin)["access-control-allow-methods"],
    "POST, OPTIONS",
  );
});

Deno.test("denies unlisted or malformed browser origins", () => {
  for (const origin of ["https://evil.test", "not an origin"]) {
    const request = new Request("https://example.test/form-media", {
      method: "OPTIONS",
      headers: { origin },
    });
    const accepted = allowedOrigin(request, allowed);
    assertEquals(accepted, null);
    assertEquals(handleCorsPreflight(request, accepted)?.status, 403);
  }
});

const valid = {
  occurrence_id: "11111111-1111-4111-8111-111111111111",
  item_id: "22222222-2222-4222-8222-222222222222",
  mime_type: "image/webp",
  byte_length: MAX_IMAGE_BYTES,
  checksum: "a".repeat(64),
};

const envelope = {
  action: "prepare",
  request_id: "33333333-3333-4333-8333-333333333333",
  expected_version: 0,
  payload: valid,
} as const;

Deno.test("media envelope validates every action and preserves anonymous payload", () => {
  assertEquals(parseFormMediaEnvelope(envelope), envelope);
  for (const action of ["finalize", "discard", "download"] as const) {
    const input = {
      ...envelope,
      action,
      payload: { asset_id: valid.item_id, edit_secret: "s".repeat(43) },
    };
    assertEquals(parseFormMediaEnvelope(input), input);
  }
});

Deno.test("media envelope rejects forged shape, action, IDs and versions safely", () => {
  for (
    const input of [
      null,
      [],
      true,
      7,
      "private input",
      { ...envelope, actor_id: "forged" },
      { ...envelope, action: "delete-all" },
      { ...envelope, request_id: "not-a-uuid" },
      ...[-1, 0.5, NaN, Infinity, Number.MAX_SAFE_INTEGER + 1, "0", null].map(
        (expected_version) => ({ ...envelope, expected_version }),
      ),
      { ...envelope, payload: null },
      { ...envelope, payload: { ...valid, edit_secret: null } },
    ]
  ) {
    const error = assertThrows(() => parseFormMediaEnvelope(input), Error);
    assertEquals(error.message.includes("private input"), false);
  }
});

Deno.test("reads only bounded UTF8 JSON before requesting authorization", async () => {
  assertEquals(
    await readFormMediaEnvelope(
      new Request("https://example.test", {
        method: "POST",
        body: JSON.stringify(envelope),
      }),
    ),
    envelope,
  );
  for (const body of ["null", "[]", "not json", "", new Uint8Array([0xff])]) {
    await assertRejects(() =>
      readFormMediaEnvelope(
        new Request("https://example.test", {
          method: "POST",
          body,
        }),
      )
    );
  }
});

Deno.test("cancels oversized request even with forged Content-Length", async () => {
  let cancelled = false;
  const request = new Request("https://example.test", {
    method: "POST",
    headers: { "content-length": "1" },
    body: new ReadableStream<Uint8Array>({
      start(controller) {
        controller.enqueue(new Uint8Array(32_769));
      },
      cancel() {
        cancelled = true;
      },
    }),
  });
  await assertRejects(
    () => readFormMediaEnvelope(request),
    Error,
    "payload_too_large",
  );
  assertEquals(cancelled, true);
});

Deno.test("accepts only the approved MIME types and ten megabyte limit", () => {
  assertEquals(parsePrepareAsset(valid), valid);
  assertThrows(() => parsePrepareAsset({ ...valid, mime_type: "image/gif" }));
  assertThrows(() =>
    parsePrepareAsset({ ...valid, byte_length: MAX_IMAGE_BYTES + 1 })
  );
});

Deno.test("rejects unknown keys and personally identifying paths", () => {
  assertThrows(() => parsePrepareAsset({ ...valid, person_id: "forged" }));
  assertEquals(
    opaqueStoragePath("ab/11111111-1111-4111-8111-111111111111"),
    true,
  );
  assertEquals(opaqueStoragePath("institution/person/photo.jpg"), false);
});

Deno.test("accepts an opaque anonymous edit secret without exposing extra keys", () => {
  const editSecret = "s".repeat(43);
  assertEquals(parsePrepareAsset({ ...valid, edit_secret: editSecret }), {
    ...valid,
    edit_secret: editSecret,
  });
  assertEquals(
    parseAssetAccess({
      asset_id: valid.item_id,
      edit_secret: editSecret,
    }),
    { asset_id: valid.item_id, edit_secret: editSecret },
  );
  assertThrows(() =>
    parseAssetAccess({
      asset_id: valid.item_id,
      edit_secret: "short",
    })
  );
  assertThrows(() =>
    parseAssetAccess({
      asset_id: valid.item_id,
      person_id: valid.occurrence_id,
    })
  );
});

Deno.test("computes a stable SHA-256 checksum", async () => {
  assertEquals(
    await sha256(new TextEncoder().encode("coelo")),
    "150698bdf49cbab353add45c786ad671b728a4e9ae9a4ea20740e003ec21d719",
  );
});

Deno.test("does not verify an asset that the server already finalized", () => {
  assertEquals(shouldVerifyFinalization("uploaded"), true);
  assertEquals(shouldVerifyFinalization("finalized"), false);
});

Deno.test("treats a committed discarded verification result as failure", () => {
  assertEquals(workerFinalizationSucceeded({ state: "finalized" }), true);
  assertEquals(
    workerFinalizationSucceeded({
      state: "discarded",
      error_code: "form_asset_verification_mismatch",
    }),
    false,
  );
});

Deno.test("detects only the approved image formats from their binary signatures", () => {
  assertEquals(
    sniffImageMime(new Uint8Array([0xff, 0xd8, 0xff, 0x00])),
    "image/jpeg",
  );
  assertEquals(
    sniffImageMime(
      new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    ),
    "image/png",
  );
  assertEquals(
    sniffImageMime(
      new Uint8Array([
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
      ]),
    ),
    "image/webp",
  );
  assertEquals(sniffImageMime(new Uint8Array([0x3c, 0x68, 0x74, 0x6d])), null);
});
