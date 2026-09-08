import { assertEquals } from "jsr:@std/assert@1.0.14";

import {
  handleMomentsMediaRequest,
  type MomentsMediaDependencies,
} from "./index.ts";

const viewerId = "55555555-5555-4555-8555-555555555555";
const ticket = "66666666-6666-4666-8666-666666666666";
const assetId = "77777777-7777-4777-8777-777777777777";

/// Records which RPC each read path reaches, without touching Supabase or R2.
function readDependencies() {
  const calls: string[] = [];
  const rpc = (name: string) => {
    calls.push(name);
    return Promise.resolve({
      data: { asset_id: assetId, object_key: "moments/key/original", mime_type: "image/png" },
      error: null,
    });
  };
  const dependencies: MomentsMediaDependencies = {
    envGet: (name) =>
      ({
        MOMENTS_MEDIA_ALLOWED_ORIGINS: "https://superadmin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        MOMENTS_MEDIA_WORKER_SECRET: "worker-secret",
        MOMENTS_R2_ENDPOINT: "https://account.r2.cloudflarestorage.com",
        MOMENTS_R2_REGION: "auto",
        MOMENTS_R2_ACCESS_KEY_ID: "access-key",
        MOMENTS_R2_SECRET_ACCESS_KEY: "secret-key",
        MOMENTS_R2_BUCKET: "coelo-media-prod",
      })[name],
    createClient: (() => ({
      rpc,
      auth: {
        getUser: () => Promise.resolve({ data: { user: { id: viewerId } }, error: null }),
      },
    })) as unknown as MomentsMediaDependencies["createClient"],
  };
  return { calls, dependencies };
}

function readRequest(body: unknown) {
  return new Request("https://functions.invalid/moments-media", {
    method: "POST",
    headers: {
      authorization: "Bearer token",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

Deno.test("a viewer ticket is redeemed, never resolved as an author asset", async () => {
  const { calls, dependencies } = readDependencies();
  const response = await handleMomentsMediaRequest(
    readRequest({ action: "read", read_ticket: ticket }),
    dependencies,
  );

  assertEquals(response.status, 200);
  assertEquals(calls.includes("redeem_moments_media_read_ticket"), true);
  assertEquals(calls.includes("authorize_moments_media_read"), false);
  const payload = await response.json() as Record<string, unknown>;
  assertEquals(typeof payload.signed_url, "string");
  assertEquals(payload.expires_in, 120);
  // The gateway signs, so the caller gets a URL and never a addressable field
  // it could reuse. The key does appear inside the presigned path, as it does
  // for any S3-style signature, so asserting its absence would be a claim the
  // scheme cannot honour; what must not leak is a separate object_key field.
  assertEquals("object_key" in payload, false);
  assertEquals("bucket_id" in payload, false);
});

Deno.test("an author asset id keeps using the author authorisation", async () => {
  const { calls, dependencies } = readDependencies();
  const response = await handleMomentsMediaRequest(
    readRequest({ action: "read", asset_id: assetId }),
    dependencies,
  );

  assertEquals(response.status, 200);
  assertEquals(calls.includes("authorize_moments_media_read"), true);
  assertEquals(calls.includes("redeem_moments_media_read_ticket"), false);
});

Deno.test("the two read paths are mutually exclusive", async () => {
  for (
    const body of [
      { action: "read", read_ticket: ticket, asset_id: assetId },
      { action: "read" },
      { action: "read", read_ticket: "", asset_id: "" },
    ]
  ) {
    const { calls, dependencies } = readDependencies();
    const response = await handleMomentsMediaRequest(readRequest(body), dependencies);
    // Neither path may be used to probe the other.
    assertEquals(response.status, 422);
    assertEquals(calls.length, 0, `no RPC may run for ${JSON.stringify(body)}`);
  }
});



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
    Deno.readTextFile(new URL("../_shared/r2_s3.ts", import.meta.url)),
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
