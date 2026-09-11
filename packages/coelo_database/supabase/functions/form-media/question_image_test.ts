import { assertEquals, assertThrows } from "@std/assert";
import { parseFormMediaEnvelope } from "./media_contract.ts";
import {
  authorizedWorkerRequest,
  imageDimensions,
  isQuestionImagePayload,
  parseQuestionImageAccess,
  parseQuestionImagePrepare,
  QUESTION_IMAGE_MAX_BYTES,
  questionImageObjectKey,
  rpcOutcome,
} from "./question_image.ts";

const id = "11111111-1111-4111-8111-111111111111";
const other = "22222222-2222-4222-8222-222222222222";
const sha = "a".repeat(64);
const prepare = {
  form_id: id,
  form_version_id: id,
  item_id: id,
  mime_type: "image/png",
  byte_length: 128,
  checksum: sha,
};
const expected = {
  form_id: id,
  form_version_id: id,
  item_id: id,
  mime_type: "image/png",
  byte_size: 128,
  sha256: sha,
};

Deno.test("question-image prepare accepts legacy and contract field names", () => {
  assertEquals(parseQuestionImagePrepare(prepare), expected);
  assertEquals(
    parseQuestionImagePrepare({
      purpose: "question-image",
      form_id: id,
      form_version_id: id,
      item_id: id,
      mime_type: "image/png",
      byte_size: 128,
      sha256: sha.toUpperCase(),
      edit_secret: "s".repeat(43),
    }),
    expected,
  );
  for (
    const input of [
      { ...prepare, mime_type: "image/gif" },
      { ...prepare, byte_length: 0 },
      { ...prepare, byte_length: QUESTION_IMAGE_MAX_BYTES + 1 },
      { ...prepare, byte_length: 128, byte_size: 128 },
      { ...prepare, checksum: sha, sha256: sha },
      { ...prepare, checksum: "x".repeat(64) },
      { ...prepare, form_id: "not-a-uuid" },
      { ...prepare, purpose: "answer-image" },
      { ...prepare, occurrence_id: id },
      { ...prepare, person_id: id },
      null,
      [],
    ]
  ) {
    assertThrows(() => parseQuestionImagePrepare(input));
  }
});

Deno.test("question-image access keeps only the asset id", () => {
  assertEquals(
    parseQuestionImageAccess({
      purpose: "question-image",
      asset_id: id.toUpperCase(),
      edit_secret: "s".repeat(43),
    }),
    { asset_id: id },
  );
  assertThrows(() => parseQuestionImageAccess({ asset_id: id, form_id: id }));
  assertThrows(() =>
    parseQuestionImageAccess({ asset_id: id, purpose: "answer-image" })
  );
  assertThrows(() => parseQuestionImageAccess({ asset_id: "x" }));
});

Deno.test("envelope routes question-image by purpose, form ids or contract action names", () => {
  assertEquals(isQuestionImagePayload(prepare), true);
  assertEquals(isQuestionImagePayload({ occurrence_id: id }), false);
  const base = { request_id: id, expected_version: 3 };
  assertEquals(
    parseFormMediaEnvelope({ ...base, action: "prepare", payload: prepare }),
    {
      action: "prepare",
      purpose: "question-image",
      request_id: id,
      payload: expected,
    },
  );
  for (
    const [action, mapped] of [
      ["finalize", "finalize"],
      ["download", "resolve"],
      ["discard", "delete"],
    ] as const
  ) {
    const parsed = parseFormMediaEnvelope({
      ...base,
      action,
      payload: { purpose: "question-image", asset_id: id },
    });
    assertEquals(parsed.action, mapped);
    assertEquals("purpose" in parsed, true);
  }
  assertEquals(
    parseFormMediaEnvelope({
      action: "resolve",
      payload: { asset_id: id },
    }),
    { action: "resolve", purpose: "question-image", payload: { asset_id: id } },
  );
  assertEquals(
    parseFormMediaEnvelope({
      action: "delete",
      request_id: id,
      payload: { asset_id: id },
    }),
    {
      action: "delete",
      purpose: "question-image",
      request_id: id,
      payload: { asset_id: id },
    },
  );
  // Sem purpose e sem form ids, o fluxo legado (answer-image) e preservado.
  const legacy = parseFormMediaEnvelope({
    ...base,
    action: "finalize",
    payload: { asset_id: id },
  });
  assertEquals("purpose" in legacy, false);
  assertEquals(parseFormMediaEnvelope({ action: "cleanup" }), {
    action: "cleanup",
  });
  for (
    const input of [
      { action: "delete", payload: { asset_id: id } },
      { action: "prepare", payload: prepare },
      { action: "resolve", request_id: "x", payload: { asset_id: id } },
      { action: "resolve", payload: { asset_id: id }, actor: "forged" },
      { action: "resolve", expected_version: -1, payload: { asset_id: id } },
      { action: "cleanup", limit: 10 },
    ]
  ) {
    assertThrows(() => parseFormMediaEnvelope(input));
  }
});

Deno.test("rpc envelope passes FORM_MEDIA and SAI codes with the database status", () => {
  assertEquals(
    rpcOutcome({ data: { ok: true, data: { a: 1 }, error: null } }),
    {
      ok: true,
      data: { a: 1 },
    },
  );
  assertEquals(
    rpcOutcome({
      data: {
        ok: false,
        data: null,
        error: {
          code: "FORM_MEDIA_MISMATCH",
          message: "O arquivo recebido não confere com o anunciado.",
          http_status: 422,
          correlation_id: id,
        },
      },
    }),
    {
      ok: false,
      status: 422,
      code: "FORM_MEDIA_MISMATCH",
      message: "O arquivo recebido não confere com o anunciado.",
      correlationId: id,
    },
  );
  const denied = rpcOutcome({
    data: {
      ok: false,
      error: { code: "SAI_PERMISSION_DENIED", http_status: 403 },
    },
  });
  assertEquals(denied.ok, false);
  if (!denied.ok) assertEquals(denied.status, 403);
  for (
    const response of [
      { error: { message: "private upstream" } },
      { data: null },
      { data: "text" },
      { data: { ok: true, data: null } },
      { data: { ok: false, error: { code: "DROP TABLE", http_status: 200 } } },
      { data: { ok: true, data: {}, error: { code: "FORM_MEDIA_INVALID" } } },
    ]
  ) {
    const outcome = rpcOutcome(response);
    assertEquals(outcome.ok, false);
    if (!outcome.ok) {
      assertEquals(outcome.code, "media_request_failed");
      assertEquals(outcome.status, 400);
      assertEquals(outcome.message, null);
    }
  }
});

Deno.test("only the canonical question-image key of the same asset is signed", () => {
  const key =
    `tenants/${id}/forms/form/${id}/question-image/${other}/original/${id}.png`;
  const data = {
    asset_id: other,
    bucket: "coelo-media-prod",
    object_key: key,
    mime_type: "image/png",
  };
  assertEquals(questionImageObjectKey(data, other), key);
  for (
    const forged of [
      { ...data, asset_id: id },
      { ...data, bucket: "coelo-transient-prod" },
      { ...data, mime_type: "image/webp" },
      { ...data, object_key: key.replace("question-image", "answer-image") },
      { ...data, object_key: key.replace("/original/", "/preview/") },
      { ...data, object_key: key + "?x=1" },
      { ...data, object_key: "https://private.example.test/" + key },
    ]
  ) {
    assertThrows(() => questionImageObjectKey(forged, other));
  }
});

function png(width: number, height: number) {
  const bytes = new Uint8Array(33);
  bytes.set([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82]);
  new DataView(bytes.buffer).setUint32(16, width);
  new DataView(bytes.buffer).setUint32(20, height);
  return bytes;
}

function jpeg(width: number, height: number) {
  // SOI, APP0 (comprimento 16), SOF0 com altura/largura.
  const bytes = new Uint8Array(2 + 18 + 2 + 2 + 5 + 2);
  bytes.set([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
  bytes.set([0xff, 0xc0, 0x00, 0x0b, 0x08], 20);
  new DataView(bytes.buffer).setUint16(25, height);
  new DataView(bytes.buffer).setUint16(27, width);
  return bytes;
}

function webpLossy(width: number, height: number) {
  const bytes = new Uint8Array(30);
  bytes.set([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]);
  bytes.set([0x56, 0x50, 0x38, 0x20], 12);
  bytes.set([0x9d, 0x01, 0x2a], 23);
  new DataView(bytes.buffer).setUint16(26, width, true);
  new DataView(bytes.buffer).setUint16(28, height, true);
  return bytes;
}

function webpLossless(width: number, height: number) {
  const bytes = new Uint8Array(30);
  bytes.set([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]);
  bytes.set([0x56, 0x50, 0x38, 0x4c], 12);
  bytes[20] = 0x2f;
  const bits = (width - 1) | ((height - 1) << 14);
  new DataView(bytes.buffer).setUint32(21, bits >>> 0, true);
  return bytes;
}

function webpExtended(width: number, height: number) {
  const bytes = new Uint8Array(30);
  bytes.set([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]);
  bytes.set([0x56, 0x50, 0x38, 0x58], 12);
  const w = width - 1, h = height - 1;
  bytes.set([w & 0xff, (w >> 8) & 0xff, (w >> 16) & 0xff], 24);
  bytes.set([h & 0xff, (h >> 8) & 0xff, (h >> 16) & 0xff], 27);
  return bytes;
}

Deno.test("image dimensions come from the real headers of the three approved types", () => {
  assertEquals(imageDimensions(png(640, 480), "image/png"), {
    width: 640,
    height: 480,
  });
  assertEquals(imageDimensions(jpeg(1024, 768), "image/jpeg"), {
    width: 1024,
    height: 768,
  });
  assertEquals(imageDimensions(webpLossy(300, 200), "image/webp"), {
    width: 300,
    height: 200,
  });
  assertEquals(imageDimensions(webpLossless(2560, 7), "image/webp"), {
    width: 2560,
    height: 7,
  });
  assertEquals(imageDimensions(webpExtended(4000, 3000), "image/webp"), {
    width: 4000,
    height: 3000,
  });
  // Tipo declarado diferente do cabecalho, cabecalho truncado ou zero.
  assertEquals(imageDimensions(png(640, 480), "image/jpeg"), null);
  assertEquals(imageDimensions(png(0, 480), "image/png"), null);
  assertEquals(imageDimensions(png(640, 480).slice(0, 20), "image/png"), null);
  assertEquals(
    imageDimensions(
      new Uint8Array([0xff, 0xd8, 0xff, 0xda, 0, 4]),
      "image/jpeg",
    ),
    null,
  );
  assertEquals(imageDimensions(new Uint8Array(40), "image/webp"), null);
  assertEquals(imageDimensions(png(640, 480), "image/gif"), null);
});

Deno.test("worker bearer requires a configured token and constant-time equality", () => {
  const token = "w".repeat(40);
  assertEquals(authorizedWorkerRequest(`Bearer ${token}`, token), true);
  assertEquals(authorizedWorkerRequest(`Bearer ${token}x`, token), false);
  assertEquals(authorizedWorkerRequest(`Bearer ${token}`, "short"), false);
  assertEquals(authorizedWorkerRequest(`Bearer ${token}`, undefined), false);
  assertEquals(authorizedWorkerRequest(null, token), false);
  assertEquals(authorizedWorkerRequest(token, token), false);
});
