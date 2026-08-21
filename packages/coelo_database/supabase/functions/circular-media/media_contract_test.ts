import { assertEquals, assertThrows } from "jsr:@std/assert";

import { validateCircularMediaEnvelope } from "./media_contract.ts";

Deno.test("accepts only approved Circular media sizes", () => {
  assertEquals(
    validateCircularMediaEnvelope({
      institution_id: "institution",
      circular_id: "circular",
      name: "documento.pdf",
      mime_type: "application/pdf",
      size_bytes: 5 * 1024 * 1024,
      display_order: 3,
    }).mimeType,
    "application/pdf",
  );

  assertThrows(() =>
    validateCircularMediaEnvelope({
      institution_id: "institution",
      circular_id: "circular",
      name: "documento.pdf",
      mime_type: "application/pdf",
      size_bytes: 5 * 1024 * 1024 + 1,
      display_order: 0,
    })
  );
});

Deno.test("rejects a fifth attachment and unapproved MIME", () => {
  for (
    const input of [
      {
        institution_id: "institution",
        circular_id: "circular",
        name: "imagem.gif",
        mime_type: "image/gif",
        size_bytes: 100,
        display_order: 0,
      },
      {
        institution_id: "institution",
        circular_id: "circular",
        name: "imagem.jpg",
        mime_type: "image/jpeg",
        size_bytes: 100,
        display_order: 4,
      },
    ]
  ) {
    assertThrows(() => validateCircularMediaEnvelope(input));
  }
});
