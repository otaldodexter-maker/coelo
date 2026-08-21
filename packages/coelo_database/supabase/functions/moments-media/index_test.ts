import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.test("media gateway authenticates users and never uses Supabase Storage", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );

  assertEquals(source.includes("user.auth.getUser()"), true);
  assertEquals(source.includes("prepare_moments_media_upload"), true);
  assertEquals(source.includes("finalize_moments_media_upload"), true);
  assertEquals(source.includes(".storage.from("), false);
  assertEquals(source.includes("presignPut"), true);
  assertEquals(source.includes("r2.head("), true);
});

Deno.test("media gateway keeps CORS allowlisted and cleanup server-only", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );

  assertEquals(source.includes("MOMENTS_MEDIA_ALLOWED_ORIGINS"), true);
  assertEquals(source.includes('"Access-Control-Allow-Origin": "*"'), false);
  assertEquals(source.includes("MOMENTS_MEDIA_WORKER_SECRET"), true);
  assertEquals(source.includes("claim_stale_moments_media"), true);
  assertEquals(source.includes('body.action === "cleanup"'), true);
});

Deno.test("media gateway validates final object metadata before linking", async () => {
  const sources = await Promise.all([
    Deno.readTextFile(new URL("./index.ts", import.meta.url)),
    Deno.readTextFile(new URL("./r2_s3.ts", import.meta.url)),
  ]);
  const source = sources.join("\n");

  assertEquals(source.includes("content-length"), true);
  assertEquals(source.includes("content-type"), true);
  assertEquals(source.includes("expected_byte_size"), true);
  assertEquals(source.includes("expected_mime_type"), true);
});

Deno.test("finalize uses a short-lived user ticket and service-role RPC", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );

  assertEquals(source.includes("authorize_moments_media_finalize"), true);
  assertEquals(source.includes("p_finalize_ticket"), true);
  assertEquals(source.includes("p_actor_auth_user_id"), false);
  assertEquals(source.includes('.schema("app_private")'), false);
});
