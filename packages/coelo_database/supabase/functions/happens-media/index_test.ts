import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.test("uses bounded signed storage upload instead of base64 through the function", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("createSignedUploadUrl"), true);
  assertEquals(source.includes('body.action === "prepare"'), true);
  assertEquals(source.includes('body.action === "finalize"'), true);
  assertEquals(source.includes("content_base64"), false);
});

Deno.test("finalization validates the stored object before linking it", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes(".download("), true);
  assertEquals(source.includes("validSignature"), true);
  assertEquals(source.includes("finalize_happens_media_upload"), true);
});

Deno.test("private reads redeem a viewer-bound ticket into a sixty-second URL", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes('body.action === "read"'), true);
  assertEquals(source.includes("user.auth.getUser()"), true);
  assertEquals(source.includes("redeem_happens_media_read_ticket"), true);
  // A janela de sessenta segundos deixou de ser afirmada por texto-fonte: ela e
  // provada por comportamento nos dois provedores em `r2_branch_test.ts`, que
  // exercita o handler de verdade em vez de procurar um literal no arquivo.
});

Deno.test("CORS reflects only configured origins", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes("HAPPENS_MEDIA_ALLOWED_ORIGINS"), true);
  assertEquals(source.includes('"Access-Control-Allow-Origin": "*"'), false);
  assertEquals(source.includes("origin_not_allowed"), true);
});
