import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.env.set("CHILD_SAFETY_MEDIA_NO_SERVE", "1");
const { handleChildSafetyMediaRequest, validSignature } = await import("./index.ts");
type ChildSafetyMediaDependencies = Parameters<typeof handleChildSafetyMediaRequest>[1] extends infer D | undefined ? D : never;

async function source() {
  return await Deno.readTextFile(new URL("./index.ts", import.meta.url));
}

Deno.test("only R2 with signed PUT/GET; never base64 nor legacy storage", async () => {
  const code = await source();
  assertEquals(code.includes("presignPut"), true);
  assertEquals(code.includes("presignGet"), true);
  assertEquals(code.includes("createSignedUploadUrl"), false);
  assertEquals(code.includes("content_base64"), false);
  assertEquals(code.includes('"Access-Control-Allow-Origin": "*"'), false);
});

Deno.test("finalize reads the stored bytes, checks the real signature and uses a ticket", async () => {
  const code = await source();
  assertEquals(code.includes("child_safety_person_document_authorize_finalize_v1"), true);
  assertEquals(code.includes("child_safety_person_document_finalize_v1"), true);
  assertEquals(code.includes("validSignature"), true);
  assertEquals(code.includes("p_finalize_ticket"), true);
});

Deno.test("signature detection covers the four allowed types", () => {
  assertEquals(validSignature(new Uint8Array([0xff, 0xd8, 0xff]), "image/jpeg"), true);
  assertEquals(validSignature(new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10]), "image/png"), true);
  const webp = new TextEncoder().encode("RIFF....WEBPVP8 ");
  assertEquals(validSignature(webp, "image/webp"), true);
  assertEquals(validSignature(new TextEncoder().encode("%PDF-1.7"), "application/pdf"), true);
  assertEquals(validSignature(new TextEncoder().encode("%PDF-1.7"), "image/png"), false);
  assertEquals(validSignature(new Uint8Array([0, 0]), "text/plain"), false);
});

function dependencies(overrides: Partial<ChildSafetyMediaDependencies> = {}) {
  const env: Record<string, string> = {
    SUPABASE_URL: "http://supabase.local",
    SUPABASE_ANON_KEY: "anon",
    SUPABASE_SERVICE_ROLE_KEY: "service",
    COELO_ALLOWED_ORIGINS: "http://127.0.0.1:3017",
    COELO_R2_ENDPOINT: "https://r2.local",
    COELO_R2_ACCESS_KEY_ID: "key",
    COELO_R2_SECRET_ACCESS_KEY: "secret",
  };
  return {
    envGet: (name: string) => env[name],
    createClient: (() => ({
      auth: { getUser: async () => ({ data: { user: { id: "u" } }, error: null }) },
      rpc: async (name: string) => {
        if (name === "child_safety_person_document_prepare_v1") {
          return {
            data: {
              document_id: "d0c00000-0000-4000-8000-000000000001",
              storage_provider: "r2",
              bucket_id: "coelo-documents-prod",
              object_key: "tenants/x/child_safety/authorized_person/y/identity-document/d/original/o.jpg",
              mime_type: "image/jpeg",
              byte_size: 3,
            },
            error: null,
          };
        }
        return { data: null, error: { message: "denied" } };
      },
    })) as unknown as ChildSafetyMediaDependencies["createClient"],
    createR2: () => ({
      presignPut: async (key: string, mime: string) => ({
        url: new URL(`https://signed.local/${key}`),
        requiredHeaders: { "content-type": mime },
      }),
      presignGet: async (key: string) => ({ url: new URL(`https://signed.local/${key}`), requiredHeaders: {} }),
      get: async () => new Uint8Array([0xff, 0xd8, 0xff]),
      head: async () => ({ byteSize: 3, mimeType: "image/jpeg", etag: null }),
      delete: async () => {},
    }),
    ...overrides,
  } as ChildSafetyMediaDependencies;
}

Deno.test("prepare returns only the signed window, never bucket or object key", async () => {
  const response = await handleChildSafetyMediaRequest(
    new Request("http://edge.local/child-safety-media", {
      method: "POST",
      headers: { authorization: "Bearer jwt", origin: "http://127.0.0.1:3017", "content-type": "application/json" },
      body: JSON.stringify({
        action: "prepare",
        request_id: "5f1e2d3c-4b5a-4c6d-8e7f-0123456789ab",
        authorized_person_id: "a0b00000-0000-4000-8000-000000000001",
        mime_type: "image/jpeg",
        size_bytes: 3,
      }),
    }),
    dependencies(),
  );
  assertEquals(response.status, 200);
  assertEquals(response.headers.get("Access-Control-Allow-Origin"), "http://127.0.0.1:3017");
  const body = await response.json();
  assertEquals(body.document_id, "d0c00000-0000-4000-8000-000000000001");
  assertEquals(typeof body.upload_url, "string");
  assertEquals(body.required_headers["content-type"], "image/jpeg");
  assertEquals("bucket_id" in body, false);
  assertEquals("object_key" in body, false);
});

Deno.test("finalize accepts the ticket descriptor without storage_provider (documents are always R2)", async () => {
  // Regressao da rota real de 17/09: authorize_finalize nao devolve
  // storage_provider e o gateway respondia media_descriptor_invalid.
  const deps = dependencies();
  const base = deps.createClient as unknown as () => { rpc: (name: string) => Promise<{ data: unknown; error: unknown }> };
  const client = base();
  const withFinalize = {
    ...deps,
    createClient: (() => ({
      auth: { getUser: async () => ({ data: { user: { id: "u" } }, error: null }) },
      rpc: async (name: string) => {
        if (name === "child_safety_person_document_authorize_finalize_v1") {
          return {
            data: {
              finalize_ticket: "f1e00000-0000-4000-8000-000000000001",
              document_id: "d0c00000-0000-4000-8000-000000000001",
              bucket_id: "coelo-documents-prod",
              object_key: "tenants/x/child_safety/authorized_person/y/identity-document/d/original/o.jpg",
              mime_type: "image/jpeg",
              byte_size: 3,
            },
            error: null,
          };
        }
        if (name === "child_safety_person_document_finalize_v1") {
          return { data: { document_id: "d0c00000-0000-4000-8000-000000000001", status: "ready" }, error: null };
        }
        return client.rpc(name);
      },
    })) as unknown as ChildSafetyMediaDependencies["createClient"],
  } as ChildSafetyMediaDependencies;
  const response = await handleChildSafetyMediaRequest(
    new Request("http://edge.local/child-safety-media", {
      method: "POST",
      headers: { authorization: "Bearer jwt", "content-type": "application/json" },
      body: JSON.stringify({ action: "finalize", document_id: "d0c00000-0000-4000-8000-000000000001" }),
    }),
    withFinalize,
  );
  assertEquals(response.status, 200);
  assertEquals((await response.json()).status, "ready");
});

Deno.test("unknown origin and missing bearer are rejected before any RPC", async () => {
  const foreign = await handleChildSafetyMediaRequest(
    new Request("http://edge.local/child-safety-media", {
      method: "POST",
      headers: { origin: "https://evil.example", authorization: "Bearer jwt" },
      body: "{}",
    }),
    dependencies(),
  );
  assertEquals(foreign.status, 403);
  const anonymous = await handleChildSafetyMediaRequest(
    new Request("http://edge.local/child-safety-media", { method: "POST", body: "{}" }),
    dependencies(),
  );
  assertEquals(anonymous.status, 401);
});

Deno.test("read denied by the RPC becomes 403 without leaking a descriptor", async () => {
  const response = await handleChildSafetyMediaRequest(
    new Request("http://edge.local/child-safety-media", {
      method: "POST",
      headers: { authorization: "Bearer jwt", "content-type": "application/json" },
      body: JSON.stringify({ action: "read", document_id: "d0c00000-0000-4000-8000-000000000001" }),
    }),
    dependencies(),
  );
  assertEquals(response.status, 403);
  assertEquals((await response.json()).error, "document_read_denied");
});
