import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.test("chat gateway autentica o usuario, nunca usa Supabase Storage nem Stream", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("user.auth.getUser()"), true);
  assertEquals(source.includes("superadmin_chat_attachment_prepare_v1"), true);
  assertEquals(source.includes("superadmin_chat_attachment_authorize_finalize_v1"), true);
  assertEquals(source.includes("superadmin_chat_attachment_finalize_v1"), true);
  assertEquals(source.includes("superadmin_chat_attachment_authorize_read_v1"), true);
  assertEquals(source.includes(".storage.from("), false);
  assertEquals(source.includes("COELO_STREAM_API_TOKEN"), false);
  assertEquals(source.includes("video/mp4"), false);
  assertEquals(source.includes("presignPut"), true);
  assertEquals(source.includes("r2.head("), true);
});

Deno.test("CORS por allowlist e expire so com segredo do worker", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("CHAT_MEDIA_ALLOWED_ORIGINS"), true);
  assertEquals(source.includes('"Access-Control-Allow-Origin": "*"'), false);
  assertEquals(source.includes("CHAT_MEDIA_WORKER_SECRET"), true);
  assertEquals(source.includes("superadmin_chat_attachment_expire_v1"), true);
  assertEquals(source.includes('body.action === "expire"'), true);
});

Deno.test("finalize mede os bytes e usa ticket do usuario com RPC service_role", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("readStoredBytes"), true);
  assertEquals(source.includes("p_finalize_ticket"), true);
  assertEquals(source.includes("p_checksum_sha256: measured.sha256"), true);
  assertEquals(source.includes('.schema("app_private")'), false);
});

Deno.test("prepare preserva o status autoritativo do anexo", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("upload_status: prepared.upload_status"), true);
});
