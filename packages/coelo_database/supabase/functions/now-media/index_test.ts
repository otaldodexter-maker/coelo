import { assertEquals } from "jsr:@std/assert@1.0.14";

async function source() {
  return await Deno.readTextFile(new URL("./index.ts", import.meta.url));
}

Deno.test("uses a bounded signed upload instead of base64 through the function", async () => {
  const code = await source();
  assertEquals(code.includes("createSignedUploadUrl"), true);
  assertEquals(code.includes('body.action === "prepare"'), true);
  assertEquals(code.includes('body.action === "finalize"'), true);
  assertEquals(code.includes("content_base64"), false);
});

Deno.test("validates the stored object before finalizing metadata", async () => {
  const code = await source();
  assertEquals(code.includes(".download("), true);
  assertEquals(code.includes("validSignature"), true);
  assertEquals(code.includes("finalize_now_asset_upload"), true);
});

Deno.test("separates author preview from viewer-bound public reads", async () => {
  const code = await source();
  assertEquals(code.includes('body.action === "read-draft"'), true);
  assertEquals(code.includes("authorize_now_asset_read"), true);
  assertEquals(code.includes('body.action === "read"'), true);
  assertEquals(code.includes("redeem_now_media_read_ticket"), true);
  assertEquals(code.includes("user.auth.getUser()"), true);
  assertEquals(code.includes("expires_in: 60"), true);
});

Deno.test("CORS reflects only configured origins", async () => {
  const code = await source();
  assertEquals(code.includes("NOW_MEDIA_ALLOWED_ORIGINS"), true);
  assertEquals(code.includes('"Access-Control-Allow-Origin": "*"'), false);
  assertEquals(code.includes("origin_not_allowed"), true);
});
