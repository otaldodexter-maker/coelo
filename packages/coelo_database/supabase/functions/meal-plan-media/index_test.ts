import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.env.set("MEAL_PLAN_MEDIA_NO_SERVE", "1");
const { handleMealPlanMediaRequest, validSignature } = await import("./index.ts");
type Dependencies = NonNullable<Parameters<typeof handleMealPlanMediaRequest>[1]>;

async function source() {
  return await Deno.readTextFile(new URL("./index.ts", import.meta.url));
}

Deno.test("only R2 with signed PUT/GET; v2 RPCs; never legacy storage or base64", async () => {
  const code = await source();
  assertEquals(code.includes("meal_plan_prepare_image_upload_v2"), true);
  assertEquals(code.includes("meal_plan_authorize_image_finalize_v2"), true);
  assertEquals(code.includes("meal_plan_finalize_image_upload_v2"), true);
  assertEquals(code.includes("meal_plan_image_read_descriptor_v2"), true);
  assertEquals(code.includes("createSignedUploadUrl"), false);
  assertEquals(code.includes("content_base64"), false);
  assertEquals(code.includes('"Access-Control-Allow-Origin": "*"'), false);
});

Deno.test("signature detection covers the three allowed image types", () => {
  assertEquals(validSignature(new Uint8Array([0xff, 0xd8, 0xff]), "image/jpeg"), true);
  assertEquals(validSignature(new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]), "image/png"), true);
  assertEquals(validSignature(new TextEncoder().encode("RIFF....WEBPVP8 "), "image/webp"), true);
  assertEquals(validSignature(new TextEncoder().encode("%PDF-1.7"), "application/pdf"), false);
});

function dependencies(rpcOverrides: Record<string, Json> = {}): Dependencies {
  const env: Record<string, string> = {
    SUPABASE_URL: "http://supabase.local",
    SUPABASE_ANON_KEY: "anon",
    SUPABASE_SERVICE_ROLE_KEY: "service",
    COELO_ALLOWED_ORIGINS: "http://127.0.0.1:3017",
    COELO_R2_ENDPOINT: "https://r2.local",
    COELO_R2_ACCESS_KEY_ID: "key",
    COELO_R2_SECRET_ACCESS_KEY: "secret",
  };
  const rpcs: Record<string, Json> = {
    meal_plan_prepare_image_upload_v2: {
      asset_id: "a0b00000-0000-4000-8000-000000000001",
      storage_provider: "r2",
      bucket_id: "coelo-media-prod",
      object_key: "tenants/t/meal_plans/meal_plan/p/image/a/original/o.png",
      mime_type: "image/png",
      max_bytes: 2097152,
    },
    meal_plan_authorize_image_finalize_v2: {
      finalize_ticket: "f1e00000-0000-4000-8000-000000000001",
      asset_id: "a0b00000-0000-4000-8000-000000000001",
      storage_provider: "r2",
      bucket_id: "coelo-media-prod",
      object_key: "tenants/t/meal_plans/meal_plan/p/image/a/original/o.png",
      mime_type: "image/png",
      byte_size: 8,
    },
    meal_plan_finalize_image_upload_v2: {
      id: "a0b00000-0000-4000-8000-000000000001",
      status: "active",
      revision: 1,
      storage_provider: "r2",
    },
    ...rpcOverrides,
  };
  const finalizeCalls: Json[] = [];
  return {
    envGet: (name: string) => env[name],
    createClient: (() => ({
      auth: { getUser: async () => ({ data: { user: { id: "u" } }, error: null }) },
      rpc: async (name: string, args: Json) => {
        if (name === "meal_plan_finalize_image_upload_v2") finalizeCalls.push(args);
        const data = rpcs[name];
        return data ? { data, error: null } : { data: null, error: { message: "denied" } };
      },
    })) as unknown as Dependencies["createClient"],
    createR2: () => ({
      presignPut: async (key: string, mime: string) => ({
        url: new URL(`https://signed.local/${key}`),
        requiredHeaders: { "content-type": mime },
      }),
      presignGet: async (key: string) => ({ url: new URL(`https://signed.local/${key}`), requiredHeaders: {} }),
      get: async () => new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]),
      head: async () => ({ byteSize: 8, mimeType: "image/png", etag: null }),
      delete: async () => {},
    }),
  };
}
type Json = Record<string, unknown>;

function post(body: Json) {
  return new Request("http://edge.local/meal-plan-media", {
    method: "POST",
    headers: { authorization: "Bearer jwt", origin: "http://127.0.0.1:3017", "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

Deno.test("prepare returns only the signed window", async () => {
  const response = await handleMealPlanMediaRequest(
    post({
      action: "prepare",
      request_id: "5f1e2d3c-4b5a-4c6d-8e7f-0123456789ab",
      resource_kind: "meal_plan",
      resource_id: "9c300000-0000-4000-8000-000000000001",
      file_name: "capa.png",
      mime_type: "image/png",
      size_bytes: 8,
    }),
    dependencies(),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.asset_id, "a0b00000-0000-4000-8000-000000000001");
  assertEquals(body.required_headers["content-type"], "image/png");
  assertEquals("object_key" in body, false);
  assertEquals("bucket_id" in body, false);
});

Deno.test("finalize verifies the stored bytes and calls the service_role finalize", async () => {
  const response = await handleMealPlanMediaRequest(
    post({ action: "finalize", request_id: "5f1e2d3c-4b5a-4c6d-8e7f-0123456789ab", alt_text: "Capa" }),
    dependencies(),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.status, "active");
});

Deno.test("legacy asset read is refused by the gateway (client keeps v1 path)", async () => {
  const response = await handleMealPlanMediaRequest(
    post({ action: "read", asset_id: "a0b00000-0000-4000-8000-000000000001" }),
    dependencies({
      meal_plan_image_read_descriptor_v2: {
        storage_provider: "supabase_mvp",
        bucket_id: "coelo-meal-plans-private",
        object_key: "meal-plans/p/a.jpg",
        mime_type: "image/jpeg",
      },
    }),
  );
  assertEquals(response.status, 409);
});

Deno.test("read on an R2 asset returns a short signed URL", async () => {
  const response = await handleMealPlanMediaRequest(
    post({ action: "read", asset_id: "a0b00000-0000-4000-8000-000000000001" }),
    dependencies({
      meal_plan_image_read_descriptor_v2: {
        storage_provider: "r2",
        bucket_id: "coelo-media-prod",
        object_key: "tenants/t/meal_plans/meal_plan/p/image/a/original/o.png",
        mime_type: "image/png",
        alt_text: "Capa",
      },
    }),
  );
  assertEquals(response.status, 200);
  const body = await response.json();
  assertEquals(body.expires_in, 300);
  assertEquals(typeof body.signed_url, "string");
});

Deno.test("unknown origin and missing bearer are rejected", async () => {
  const foreign = await handleMealPlanMediaRequest(
    new Request("http://edge.local/meal-plan-media", {
      method: "POST",
      headers: { origin: "https://evil.example", authorization: "Bearer jwt" },
      body: "{}",
    }),
    dependencies(),
  );
  assertEquals(foreign.status, 403);
  const anonymous = await handleMealPlanMediaRequest(
    new Request("http://edge.local/meal-plan-media", { method: "POST", body: "{}" }),
    dependencies(),
  );
  assertEquals(anonymous.status, 401);
});
