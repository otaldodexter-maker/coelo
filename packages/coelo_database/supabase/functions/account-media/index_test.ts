import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.test("account gateway autentica, usa R2 privado e controla o avatar no Postgres", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("user.auth.getUser()"), true);
  assertEquals(source.includes("superadmin_account_avatar_prepare_v1"), true);
  assertEquals(source.includes("superadmin_account_avatar_authorize_finalize_v1"), true);
  assertEquals(source.includes("superadmin_account_avatar_finalize_v1"), true);
  assertEquals(source.includes("superadmin_account_avatar_authorize_read_v1"), true);
  assertEquals(source.includes("superadmin_account_avatar_remove_v1"), true);
  assertEquals(source.includes("presignPut"), true);
  assertEquals(source.includes("presignGet"), true);
  assertEquals(source.includes("readStoredBytes"), true);
  assertEquals(source.includes(".storage.from("), false);
  assertEquals(source.includes("COELO_STREAM_API_TOKEN"), false);
});

Deno.test("account gateway fecha CORS, ticket e origem sem segredo no cliente", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("ACCOUNT_MEDIA_ALLOWED_ORIGINS"), true);
  assertEquals(source.includes('"Access-Control-Allow-Origin": "*"'), false);
  assertEquals(source.includes("p_finalize_ticket"), true);
  assertEquals(source.includes("ACCOUNT_MEDIA_WORKER_SECRET"), true);
  assertEquals(source.includes("upload_url"), true);
  assertEquals(source.includes("signed_url"), true);
});
