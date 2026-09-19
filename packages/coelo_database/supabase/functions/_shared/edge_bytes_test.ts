import { assertEquals, assertThrows } from "jsr:@std/assert@1.0.14";

import { bytesResponse, contentTypeHeader, decodeEnvelope, encodeEnvelope, envelopeHeader, isBinaryUpload } from "./edge_bytes.ts";

Deno.test("envelope: base64url no cabecalho vira o corpo do upload", () => {
  const envelope = { action: "prepare", request_id: "abc", name: "foto ç.png", size_bytes: 12 };
  const request = new Request("https://edge.test", {
    method: "POST",
    headers: { "content-type": "application/octet-stream", [envelopeHeader]: encodeEnvelope(envelope) },
    body: new Uint8Array(12),
  });
  assertEquals(isBinaryUpload(request), true);
  assertEquals(decodeEnvelope(request), { ...envelope, action: "upload" }, "action e sempre upload");
});

Deno.test("envelope: ausente, invalido ou nao-objeto e recusado", () => {
  const make = (value?: string) =>
    new Request("https://edge.test", { method: "POST", headers: value === undefined ? {} : { [envelopeHeader]: value } });
  assertThrows(() => decodeEnvelope(make()), Error, "invalid_request");
  assertThrows(() => decodeEnvelope(make("%%%")), Error, "invalid_request");
  assertThrows(() => decodeEnvelope(make(encodeEnvelope([1, 2] as unknown as Record<string, unknown>))), Error, "invalid_request");
  assertEquals(isBinaryUpload(new Request("https://edge.test", { method: "POST", headers: { "content-type": "application/json" } })), false);
});

Deno.test("leitura inline: octet-stream com o MIME real exposto no cabecalho", async () => {
  const response = bytesResponse({ "Access-Control-Allow-Origin": "https://app.test" }, new Uint8Array([1, 2, 3]), "video/mp4");
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("content-type"), "application/octet-stream");
  assertEquals(response.headers.get(contentTypeHeader), "video/mp4");
  assertEquals(response.headers.get("access-control-expose-headers"), contentTypeHeader);
  assertEquals(new Uint8Array(await response.arrayBuffer()), new Uint8Array([1, 2, 3]));
});
