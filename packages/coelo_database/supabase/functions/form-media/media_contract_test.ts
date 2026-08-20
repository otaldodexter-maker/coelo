import { assertEquals, assertThrows } from "@std/assert";
import {
  allowedOrigin,
  corsHeaders,
  handleCorsPreflight,
  MAX_IMAGE_BYTES,
  opaqueStoragePath,
  parseAssetAccess,
  parsePrepareAsset,
  sha256,
  shouldVerifyFinalization,
  sniffImageMime,
  workerFinalizationSucceeded,
} from "./media_contract.ts";

const allowed = "https://superadmin.coelo.me,http://127.0.0.1:8765";

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
