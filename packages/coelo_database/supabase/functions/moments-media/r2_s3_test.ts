import {
  assertEquals,
  assertRejects,
  assertThrows,
} from "jsr:@std/assert@1.0.14";

import { MomentsR2Client, momentsR2Config } from "./r2_s3.ts";

const environment = {
  MOMENTS_R2_ENDPOINT: "https://account.r2.cloudflarestorage.com",
  MOMENTS_R2_REGION: "auto",
  MOMENTS_R2_ACCESS_KEY_ID: "access-key",
  MOMENTS_R2_SECRET_ACCESS_KEY: "secret-key",
  MOMENTS_R2_BUCKET: "coelo-moments-private",
};

Deno.test("R2 configuration fails closed without every server-side secret", () => {
  assertThrows(() => momentsR2Config({}));
  assertEquals(momentsR2Config(environment).bucket, "coelo-moments-private");
});

Deno.test("presigns a bounded PUT without exposing credentials outside the query", async () => {
  const client = new MomentsR2Client(momentsR2Config(environment), {
    now: () => new Date("2026-08-21T12:00:00.000Z"),
  });

  const signed = await client.presignPut(
    "institution/asset/original",
    "image/webp",
    300,
  );

  assertEquals(signed.url.hostname, "account.r2.cloudflarestorage.com");
  assertEquals(
    signed.url.pathname,
    "/coelo-moments-private/institution/asset/original",
  );
  assertEquals(signed.url.searchParams.get("X-Amz-Expires"), "300");
  assertEquals(
    signed.url.searchParams.get("X-Amz-Algorithm"),
    "AWS4-HMAC-SHA256",
  );
  assertEquals(signed.requiredHeaders, { "content-type": "image/webp" });
  assertEquals(signed.url.toString().includes("secret-key"), false);
});

Deno.test("HEAD and DELETE fail closed on R2 errors", async () => {
  const client = new MomentsR2Client(momentsR2Config(environment), {
    fetch: () => Promise.resolve(new Response(null, { status: 403 })),
  });

  await assertRejects(
    () => client.head("institution/asset/original"),
    Error,
    "moments_r2_http_403",
  );
  await assertRejects(
    () => client.delete("institution/asset/original"),
    Error,
    "moments_r2_http_403",
  );
});
