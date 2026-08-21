import { assertEquals } from "jsr:@std/assert";

Deno.test("uses private signed Supabase Storage upload without base64", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("createSignedUploadUrl"), true);
  assertEquals(source.includes("createSignedUrl"), true);
  assertEquals(source.includes("content_base64"), false);
  assertEquals(source.includes('body.action === "prepare"'), true);
  assertEquals(source.includes('body.action === "finalize"'), true);
});

Deno.test("validates stored bytes before finalizing metadata", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes(".download("), true);
  assertEquals(source.includes("validSignature"), true);
  assertEquals(source.includes("finalize_circular_media_upload"), true);
  assertEquals(source.includes("authorize_circular_media_read"), true);
  assertEquals(
    source.includes("createSignedUrl(String(descriptor.object_key), 120)"),
    true,
  );
});

Deno.test("CORS reflects only configured origins", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("CIRCULAR_MEDIA_ALLOWED_ORIGINS"), true);
  assertEquals(source.includes('"Access-Control-Allow-Origin": "*"'), false);
});

Deno.test("reports provider upload expiry and preserves idempotent finalize", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("2 * 60 * 60 * 1000"), true);
  assertEquals(source.includes('descriptor.status === "ready"'), true);
  assertEquals(source.includes("already_uploaded: true"), true);
});
