import { assertEquals } from "jsr:@std/assert";

import {
  type CircularMediaDependencies,
  handleCircularMediaRequest,
} from "./index.ts";
import { R2TransportError } from "../_shared/r2_s3.ts";

function earlyRejectionDependencies() {
  let clientCalls = 0;
  const dependencies = {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
      })[name],
    createClient: () => {
      clientCalls++;
      throw new Error("client_must_not_be_created");
    },
  } as unknown as CircularMediaDependencies;
  return { dependencies, clientCalls: () => clientCalls };
}

function withJsonSpy(request: Request) {
  let calls = 0;
  Object.defineProperty(request, "json", {
    configurable: true,
    value: () => {
      calls++;
      return Promise.resolve({});
    },
  });
  return () => calls;
}

Deno.test("rejects an unauthenticated POST before parsing or creating clients", async () => {
  const tracked = earlyRejectionDependencies();
  const request = new Request(
    "https://project.functions.supabase.co/circular-media",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ action: "prepare" }),
    },
  );

  const response = await handleCircularMediaRequest(
    request,
    tracked.dependencies,
  );

  assertEquals(response.status, 401);
  assertEquals(request.bodyUsed, false);
  assertEquals(tracked.clientCalls(), 0);
});

Deno.test("rejects an oversized declared body before parsing or creating clients", async () => {
  const tracked = earlyRejectionDependencies();
  const request = new Request(
    "https://project.functions.supabase.co/circular-media",
    {
      method: "POST",
      headers: {
        authorization: "Bearer user-jwt",
        "content-length": "32769",
        "content-type": "application/json",
      },
      body: "{}",
    },
  );

  const response = await handleCircularMediaRequest(
    request,
    tracked.dependencies,
  );

  assertEquals(response.status, 413);
  assertEquals(request.bodyUsed, false);
  assertEquals(tracked.clientCalls(), 0);
});

Deno.test("rejects oversized bytes without calling request.json or creating clients", async () => {
  const tracked = earlyRejectionDependencies();
  const request = new Request(
    "https://project.functions.supabase.co/circular-media",
    {
      method: "POST",
      headers: {
        authorization: "Bearer user-jwt",
        "content-type": "application/json",
      },
      body: "x".repeat(32_769),
    },
  );
  const jsonCalls = withJsonSpy(request);

  const response = await handleCircularMediaRequest(
    request,
    tracked.dependencies,
  );

  assertEquals(response.status, 413);
  assertEquals(jsonCalls(), 0);
  assertEquals(tracked.clientCalls(), 0);
});

Deno.test("rejects a non-JSON POST before parsing or creating clients", async () => {
  const tracked = earlyRejectionDependencies();
  const request = new Request(
    "https://project.functions.supabase.co/circular-media",
    {
      method: "POST",
      headers: {
        authorization: "Bearer user-jwt",
        "content-type": "text/plain",
      },
      body: "{}",
    },
  );

  const response = await handleCircularMediaRequest(
    request,
    tracked.dependencies,
  );

  assertEquals(response.status, 415);
  assertEquals(request.bodyUsed, false);
  assertEquals(tracked.clientCalls(), 0);
});

Deno.test("rejects an invalid cleanup worker secret before parsing", async () => {
  const tracked = earlyRejectionDependencies();
  const request = new Request(
    "https://project.functions.supabase.co/circular-media",
    {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-worker-secret": "wrong-secret",
      },
      body: JSON.stringify({ action: "cleanup" }),
    },
  );

  const response = await handleCircularMediaRequest(
    request,
    tracked.dependencies,
  );

  assertEquals(response.status, 401);
  assertEquals(request.bodyUsed, false);
  assertEquals(tracked.clientCalls(), 0);
});

Deno.test("rejects an invalid Bearer JWT before parsing or privileged work", async () => {
  const clientKeys: string[] = [];
  let rpcCalls = 0;
  const dependencies = {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
      })[name],
    createClient: (_url: string, key: string) => {
      clientKeys.push(key);
      return {
        auth: {
          getUser: () =>
            Promise.resolve({
              data: { user: null },
              error: { message: "invalid" },
            }),
        },
        rpc: () => {
          rpcCalls++;
          throw new Error("rpc_must_not_run");
        },
      };
    },
  } as unknown as CircularMediaDependencies;
  const request = new Request(
    "https://project.functions.supabase.co/circular-media",
    {
      method: "POST",
      headers: {
        authorization: "Bearer invalid-jwt",
        "content-type": "application/json",
      },
      body: JSON.stringify({ action: "prepare" }),
    },
  );
  const jsonCalls = withJsonSpy(request);

  const response = await handleCircularMediaRequest(request, dependencies);

  assertEquals(response.status, 401);
  assertEquals(jsonCalls(), 0);
  assertEquals(clientKeys, ["anon-key"]);
  assertEquals(rpcCalls, 0);
});

Deno.test("browser CORS does not advertise the worker secret", async () => {
  const tracked = earlyRejectionDependencies();
  const response = await handleCircularMediaRequest(
    new Request("https://project.functions.supabase.co/circular-media", {
      method: "OPTIONS",
      headers: { origin: "https://admin.coelo.test" },
    }),
    tracked.dependencies,
  );

  assertEquals(response.status, 200);
  assertEquals(
    response.headers.get("access-control-allow-origin"),
    "https://admin.coelo.test",
  );
  assertEquals(
    response.headers.get("access-control-allow-headers")?.includes(
      "x-worker-secret",
    ),
    false,
  );
  assertEquals(tracked.clientCalls(), 0);
});

Deno.test("accepts a valid cleanup worker and claims stale media", async () => {
  const rpcCalls: string[] = [];
  let clientCalls = 0;
  const dependencies = {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
      })[name],
    createClient: () => {
      clientCalls++;
      return {
        rpc: (name: string) => {
          rpcCalls.push(name);
          return Promise.resolve({ data: [], error: null });
        },
      };
    },
  } as unknown as CircularMediaDependencies;
  const response = await handleCircularMediaRequest(
    new Request("https://project.functions.supabase.co/circular-media", {
      method: "POST",
      headers: {
        "content-type": "application/json; charset=utf-8",
        "x-worker-secret": "worker-secret",
      },
      body: JSON.stringify({ action: "cleanup" }),
    }),
    dependencies,
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { deleted: 0 });
  assertEquals(clientCalls, 1);
  assertEquals(rpcCalls, ["claim_stale_circular_media"]);
});

Deno.test("keeps user POST on Bearer JWT and the RLS-scoped client", async () => {
  const clientCalls: Array<{ key: string; options: unknown }> = [];
  const userRpcCalls: string[] = [];
  const dependencies = {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
      })[name],
    createClient: (_url: string, key: string, options: unknown) => {
      clientCalls.push({ key, options });
      if (key === "service-role") {
        return {
          storage: {
            from: () => ({
              createSignedUploadUrl: () =>
                Promise.resolve({
                  data: {
                    signedUrl: "https://storage.test/upload",
                    token: "upload-token",
                  },
                  error: null,
                }),
            }),
          },
        };
      }
      return {
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "user-1" } }, error: null }),
        },
        rpc: (name: string) => {
          userRpcCalls.push(name);
          return Promise.resolve({
            data: {
              asset_id: "asset-1",
              bucket_id: "coelo-circulars-private",
              object_key: "institution/circular/asset.png",
              status: "pending",
            },
            error: null,
          });
        },
      };
    },
  } as unknown as CircularMediaDependencies;
  const response = await handleCircularMediaRequest(
    new Request("https://project.functions.supabase.co/circular-media", {
      method: "POST",
      headers: {
        authorization: "Bearer user-jwt",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "prepare",
        request_id: "11111111-1111-4111-8111-111111111111",
        institution_id: "institution-1",
        circular_id: "circular-1",
        name: "asset.png",
        mime_type: "image/png",
        size_bytes: 1024,
        display_order: 0,
      }),
    }),
    dependencies,
  );

  assertEquals(response.status, 200);
  assertEquals(
    (await response.json()).upload_url,
    "https://storage.test/upload",
  );
  assertEquals(clientCalls.map(({ key }) => key), ["anon-key", "service-role"]);
  assertEquals(
    (clientCalls[0].options as {
      global: { headers: { Authorization: string } };
    })
      .global.headers.Authorization,
    "Bearer user-jwt",
  );
  assertEquals(userRpcCalls, ["prepare_circular_media_upload"]);
});

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
  assertEquals(source.includes("presignGet("), true);
  assertEquals(source.includes("readTtlSeconds"), true);
  assertEquals(
    source.includes(
      ".createSignedUrl(String(descriptor.object_key), readTtlSeconds)",
    ),
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

// --- ADR 0032: transporte privado em Cloudflare R2 ---------------------------
// As chaves abaixo sao sinteticas e existem apenas no processo de teste. Nenhum
// segredo real do Coelo entra em codigo, log ou fixture.
const syntheticR2Environment = {
  COELO_R2_ENDPOINT: "https://account.r2.cloudflarestorage.com",
  COELO_R2_REGION: "auto",
  COELO_R2_ACCESS_KEY_ID: "synthetic-access-key-id",
  COELO_R2_SECRET_ACCESS_KEY: "synthetic-secret-access-key",
};

function r2Descriptor(overrides: Record<string, unknown> = {}) {
  return {
    asset_id: "11111111-1111-4111-8111-111111111111",
    storage_provider: "r2",
    bucket_id: "coelo-media-prod",
    object_key:
      "tenants/22222222-2222-4222-8222-222222222222/circulars/circular/" +
      "33333333-3333-4333-8333-333333333333/attachment/" +
      "11111111-1111-4111-8111-111111111111/original/" +
      "44444444-4444-4444-4444-444444444444.png",
    expected_mime_type: "image/png",
    expected_byte_size: 1024,
    status: "pending",
    ...overrides,
  };
}

type StorageProbe = { calls: string[] };

function r2Dependencies(
  descriptor: Record<string, unknown>,
  probe: StorageProbe,
  rpcNames: string[],
) {
  return {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
        ...syntheticR2Environment,
      })[name],
    createClient: (_url: string, key: string) => {
      if (key === "service-role") {
        return {
          storage: {
            from: (bucket: string) => ({
              createSignedUploadUrl: () => {
                probe.calls.push(`upload:${bucket}`);
                return Promise.resolve({
                  data: {
                    signedUrl: "https://storage.test/upload",
                    token: "upload-token",
                  },
                  error: null,
                });
              },
              createSignedUrl: () => {
                probe.calls.push(`read:${bucket}`);
                return Promise.resolve({
                  data: { signedUrl: "https://storage.test/read" },
                  error: null,
                });
              },
              remove: () => {
                probe.calls.push(`remove:${bucket}`);
                return Promise.resolve({ data: null, error: null });
              },
            }),
          },
          rpc: (name: string) => {
            rpcNames.push(`admin:${name}`);
            return Promise.resolve({ data: null, error: null });
          },
        };
      }
      return {
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "user-1" } }, error: null }),
        },
        rpc: (name: string) => {
          rpcNames.push(name);
          return Promise.resolve({ data: descriptor, error: null });
        },
      };
    },
  } as unknown as CircularMediaDependencies;
}

function prepareRequest(overrides: Record<string, unknown> = {}) {
  return new Request("https://project.functions.supabase.co/circular-media", {
    method: "POST",
    headers: {
      authorization: "Bearer user-jwt",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      action: "prepare",
      request_id: "11111111-1111-4111-8111-111111111111",
      institution_id: "22222222-2222-4222-8222-222222222222",
      circular_id: "33333333-3333-4333-8333-333333333333",
      name: "asset.png",
      mime_type: "image/png",
      size_bytes: 1024,
      display_order: 0,
      ...overrides,
    }),
  });
}

Deno.test("prepares an R2 upload with a short-lived SigV4 PUT", async () => {
  const probe: StorageProbe = { calls: [] };
  const rpcNames: string[] = [];
  const response = await handleCircularMediaRequest(
    prepareRequest(),
    r2Dependencies(r2Descriptor(), probe, rpcNames),
  );

  assertEquals(response.status, 200);
  const payload = await response.json();
  const uploadUrl = new URL(payload.upload_url);
  assertEquals(uploadUrl.protocol, "https:");
  assertEquals(uploadUrl.host, "account.r2.cloudflarestorage.com");
  assertEquals(
    uploadUrl.pathname.startsWith("/coelo-media-prod/tenants/"),
    true,
  );
  assertEquals(
    uploadUrl.searchParams.get("X-Amz-Algorithm"),
    "AWS4-HMAC-SHA256",
  );
  assertEquals(uploadUrl.searchParams.get("X-Amz-Expires"), "300");
  assertEquals(
    (uploadUrl.searchParams.get("X-Amz-Signature") ?? "").length,
    64,
  );
  assertEquals(payload.required_headers, { "content-type": "image/png" });
  // Supabase Storage nao e tocado por um ativo R2.
  assertEquals(probe.calls, []);
  assertEquals(rpcNames, ["prepare_circular_media_upload"]);
});

Deno.test("never returns the R2 secret or the bucket credentials", async () => {
  const probe: StorageProbe = { calls: [] };
  const response = await handleCircularMediaRequest(
    prepareRequest(),
    r2Dependencies(r2Descriptor(), probe, []),
  );
  const body = await response.text();

  assertEquals(response.status, 200);
  assertEquals(body.includes("synthetic-secret-access-key"), false);
  assertEquals(body.includes("service-role"), false);
  assertEquals(body.includes("worker-secret"), false);
  assertEquals(body.includes("anon-key"), false);
  assertEquals(body.includes("X-Amz-Signature"), true);
});

Deno.test("signs an R2 read and leaves legacy Supabase reads alone", async () => {
  const r2Probe: StorageProbe = { calls: [] };
  const r2Response = await handleCircularMediaRequest(
    new Request("https://project.functions.supabase.co/circular-media", {
      method: "POST",
      headers: {
        authorization: "Bearer user-jwt",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "read",
        asset_id: "11111111-1111-4111-8111-111111111111",
      }),
    }),
    r2Dependencies(
      r2Descriptor({ mime_type: "image/png", status: "ready" }),
      r2Probe,
      [],
    ),
  );
  const r2Payload = await r2Response.json();

  assertEquals(r2Response.status, 200);
  assertEquals(r2Payload.expires_in, 120);
  assertEquals(
    new URL(r2Payload.signed_url).searchParams.get("X-Amz-Expires"),
    "120",
  );
  assertEquals(r2Probe.calls, []);

  const legacyProbe: StorageProbe = { calls: [] };
  const legacyResponse = await handleCircularMediaRequest(
    new Request("https://project.functions.supabase.co/circular-media", {
      method: "POST",
      headers: {
        authorization: "Bearer user-jwt",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "read",
        asset_id: "11111111-1111-4111-8111-111111111111",
      }),
    }),
    r2Dependencies(
      {
        storage_provider: "supabase",
        bucket_id: "coelo-circulars-private",
        object_key: "institution/circulars/circular/legacy.png",
        mime_type: "image/png",
      },
      legacyProbe,
      [],
    ),
  );

  assertEquals(legacyResponse.status, 200);
  assertEquals(
    (await legacyResponse.json()).signed_url,
    "https://storage.test/read",
  );
  assertEquals(legacyProbe.calls, ["read:coelo-circulars-private"]);
});

Deno.test("keeps a legacy Supabase asset on the legacy delete path", async () => {
  const probe: StorageProbe = { calls: [] };
  const rpcNames: string[] = [];
  const response = await handleCircularMediaRequest(
    new Request("https://project.functions.supabase.co/circular-media", {
      method: "POST",
      headers: {
        authorization: "Bearer user-jwt",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        action: "delete",
        asset_id: "11111111-1111-4111-8111-111111111111",
      }),
    }),
    r2Dependencies(
      {
        asset_id: "11111111-1111-4111-8111-111111111111",
        storage_provider: "supabase",
        bucket_id: "coelo-circulars-private",
        object_key: "institution/circulars/circular/legacy.png",
      },
      probe,
      rpcNames,
    ),
  );

  assertEquals(response.status, 200);
  assertEquals(probe.calls, ["remove:coelo-circulars-private"]);
  assertEquals(rpcNames, [
    "remove_circular_media",
    "admin:mark_circular_media_deleted",
  ]);
});

Deno.test("reports an opaque failure when the R2 transport fails", async () => {
  const probe: StorageProbe = { calls: [] };
  const dependencies = {
    ...r2Dependencies(r2Descriptor(), probe, []),
    createR2: () => ({
      presignPut: () => Promise.reject(new R2TransportError("http_403")),
      presignGet: () => Promise.reject(new R2TransportError("http_403")),
      get: () => Promise.reject(new R2TransportError("http_404")),
      delete: () => Promise.reject(new R2TransportError("http_403")),
    }),
  } as unknown as CircularMediaDependencies;

  const response = await handleCircularMediaRequest(
    prepareRequest(),
    dependencies,
  );
  const body = await response.text();

  assertEquals(response.status, 422);
  assertEquals(JSON.parse(body), { error: "media_transport_failed" });
  assertEquals(body.includes("coelo-media-prod"), false);
  assertEquals(body.includes("tenants/"), false);
  assertEquals(body.includes("r2_"), false);
});

Deno.test("refuses an unconfigured R2 without reaching the object", async () => {
  const probe: StorageProbe = { calls: [] };
  const dependencies = {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
      })[name],
    createClient: (r2Dependencies(r2Descriptor(), probe, []) as unknown as {
      createClient: unknown;
    }).createClient,
  } as unknown as CircularMediaDependencies;

  const response = await handleCircularMediaRequest(
    prepareRequest(),
    dependencies,
  );

  assertEquals(response.status, 422);
  assertEquals(await response.json(), { error: "media_transport_failed" });
  assertEquals(probe.calls, []);
});

Deno.test("rejects an unapproved type and an oversized attachment", async () => {
  const probe: StorageProbe = { calls: [] };
  const rpcNames: string[] = [];
  const typeResponse = await handleCircularMediaRequest(
    prepareRequest({ name: "asset.svg", mime_type: "image/svg+xml" }),
    r2Dependencies(r2Descriptor(), probe, rpcNames),
  );
  assertEquals(typeResponse.status, 422);
  assertEquals(await typeResponse.json(), { error: "invalid_request" });

  const sizeResponse = await handleCircularMediaRequest(
    prepareRequest({ size_bytes: 10 * 1024 * 1024 + 1 }),
    r2Dependencies(r2Descriptor(), probe, rpcNames),
  );
  assertEquals(sizeResponse.status, 422);
  assertEquals(await sizeResponse.json(), { error: "invalid_request" });

  const extensionResponse = await handleCircularMediaRequest(
    prepareRequest({ name: "asset.jpg" }),
    r2Dependencies(r2Descriptor(), probe, rpcNames),
  );
  assertEquals(extensionResponse.status, 422);
  assertEquals(await extensionResponse.json(), {
    error: "media_extension_mismatch",
  });

  // Nenhuma dessas recusas chegou a autorizar, assinar ou tocar armazenamento.
  assertEquals(rpcNames, []);
  assertEquals(probe.calls, []);
});

Deno.test("cleans stale R2 objects without touching legacy Storage", async () => {
  const deletedKeys: string[] = [];
  const storageBuckets: string[] = [];
  const rpcNames: string[] = [];
  const claimed = [
    {
      asset_id: "11111111-1111-4111-8111-111111111111",
      object_key: "tenants/a/circulars/circular/b/attachment/c/original/d.png",
      storage_provider: "r2",
      bucket_id: "coelo-media-prod",
    },
    {
      asset_id: "55555555-5555-4555-8555-555555555555",
      object_key: "institution/circulars/circular/legacy.pdf",
      storage_provider: "supabase",
      bucket_id: "coelo-circulars-private",
    },
  ];
  const dependencies = {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
        ...syntheticR2Environment,
      })[name],
    createClient: () => ({
      storage: {
        from: (bucket: string) => ({
          remove: () => {
            storageBuckets.push(bucket);
            return Promise.resolve({ data: null, error: null });
          },
        }),
      },
      rpc: (name: string) => {
        rpcNames.push(name);
        return Promise.resolve({
          data: name === "claim_stale_circular_media" ? claimed : null,
          error: null,
        });
      },
    }),
    createR2: (config: { bucket: string }) => ({
      presignGet: () => Promise.reject(new Error("unused")),
      presignPut: () => Promise.reject(new Error("unused")),
      get: () => Promise.reject(new Error("unused")),
      delete: (key: string) => {
        deletedKeys.push(`${config.bucket}:${key}`);
        return Promise.resolve();
      },
    }),
  } as unknown as CircularMediaDependencies;

  const response = await handleCircularMediaRequest(
    new Request("https://project.functions.supabase.co/circular-media", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-worker-secret": "worker-secret",
      },
      body: JSON.stringify({ action: "cleanup" }),
    }),
    dependencies,
  );

  assertEquals(response.status, 200);
  assertEquals(await response.json(), { deleted: 2 });
  assertEquals(deletedKeys, [
    "coelo-media-prod:tenants/a/circulars/circular/b/attachment/c/original/d.png",
  ]);
  assertEquals(storageBuckets, ["coelo-circulars-private"]);
  assertEquals(rpcNames, [
    "claim_stale_circular_media",
    "mark_circular_media_deleted",
    "mark_circular_media_deleted",
  ]);
});

Deno.test("routes the transport by provider and shares the R2 client", async () => {
  const source = await Deno.readTextFile(
    new URL("./index.ts", import.meta.url),
  );
  assertEquals(source.includes('from "../_shared/r2_s3.ts"'), true);
  assertEquals(source.includes("COELO_R2_SECRET_ACCESS_KEY"), true);
  assertEquals(source.includes('descriptor.storage_provider === "r2"'), true);
  assertEquals(source.includes("presignPut("), true);
  assertEquals(source.includes("coelo-circulars-private"), true);
  // Nenhum segredo literal e nenhuma copia local do cliente S3.
  assertEquals(source.includes("./r2_s3.ts"), false);
  assertEquals(source.includes("MOMENTS_R2_"), false);
});

function pngBytes(length: number) {
  const bytes = new Uint8Array(length);
  bytes.set([137, 80, 78, 71, 13, 10, 26, 10], 0);
  return bytes;
}

function finalizeRequest() {
  return new Request("https://project.functions.supabase.co/circular-media", {
    method: "POST",
    headers: {
      authorization: "Bearer user-jwt",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      action: "finalize",
      asset_id: "11111111-1111-4111-8111-111111111111",
      request_id: "11111111-1111-4111-8111-111111111111",
      institution_id: "22222222-2222-4222-8222-222222222222",
      circular_id: "33333333-3333-4333-8333-333333333333",
      name: "asset.png",
      mime_type: "image/png",
      size_bytes: 1024,
      display_order: 0,
    }),
  });
}

function finalizeDependencies(
  storedBytes: Uint8Array,
  captured: { adminRpc: Array<[string, Record<string, unknown>]> },
  deletedKeys: string[],
) {
  const descriptor = r2Descriptor();
  return {
    envGet: (name: string) =>
      ({
        CIRCULAR_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
        SUPABASE_URL: "https://project.supabase.co",
        SUPABASE_SERVICE_ROLE_KEY: "service-role",
        SUPABASE_ANON_KEY: "anon-key",
        CIRCULAR_MEDIA_WORKER_SECRET: "worker-secret",
        ...syntheticR2Environment,
      })[name],
    createClient: (_url: string, key: string) => {
      if (key === "service-role") {
        return {
          storage: {
            from: () => ({
              download: () => Promise.reject(new Error("legacy_not_expected")),
              remove: () => Promise.reject(new Error("legacy_not_expected")),
            }),
          },
          rpc: (name: string, args: Record<string, unknown>) => {
            captured.adminRpc.push([name, args]);
            return Promise.resolve({
              data: { asset_id: descriptor.asset_id, status: "ready" },
              error: null,
            });
          },
        };
      }
      return {
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "user-1" } }, error: null }),
        },
        rpc: (name: string) =>
          Promise.resolve({
            data: name === "authorize_circular_media_finalize"
              ? { finalize_ticket: "66666666-6666-4666-8666-666666666666" }
              : descriptor,
            error: null,
          }),
      };
    },
    createR2: (config: { bucket: string }) => ({
      presignGet: () => Promise.reject(new Error("unused")),
      presignPut: () => Promise.reject(new Error("unused")),
      get: (_key: string, maxBytes: number) => {
        if (storedBytes.byteLength > maxBytes) {
          return Promise.reject(new R2TransportError("size_limit"));
        }
        return Promise.resolve(storedBytes);
      },
      delete: (key: string) => {
        deletedKeys.push(`${config.bucket}:${key}`);
        return Promise.resolve();
      },
    }),
  } as unknown as CircularMediaDependencies;
}

Deno.test("finalizes an R2 asset on bytes read back from the bucket", async () => {
  const captured: { adminRpc: Array<[string, Record<string, unknown>]> } = {
    adminRpc: [],
  };
  const deletedKeys: string[] = [];
  const response = await handleCircularMediaRequest(
    finalizeRequest(),
    finalizeDependencies(pngBytes(1024), captured, deletedKeys),
  );

  assertEquals(response.status, 200);
  assertEquals(deletedKeys, []);
  assertEquals(captured.adminRpc.length, 1);
  const [name, args] = captured.adminRpc[0];
  assertEquals(name, "finalize_circular_media_upload");
  assertEquals(args.p_expected_byte_size, 1024);
  assertEquals(args.p_expected_mime_type, "image/png");
  // Checksum medido nos bytes, nunca declarado pelo cliente.
  assertEquals(/^[0-9a-f]{64}$/.test(String(args.p_checksum_sha256)), true);
});

Deno.test("discards an R2 object whose bytes fail the MIME signature", async () => {
  const captured: { adminRpc: Array<[string, Record<string, unknown>]> } = {
    adminRpc: [],
  };
  const deletedKeys: string[] = [];
  const forged = new Uint8Array(1024);
  forged.set([0x25, 0x50, 0x44, 0x46, 0x2d], 0);
  const response = await handleCircularMediaRequest(
    finalizeRequest(),
    finalizeDependencies(forged, captured, deletedKeys),
  );

  assertEquals(response.status, 422);
  assertEquals(await response.json(), { error: "invalid_media_signature" });
  assertEquals(captured.adminRpc, []);
  assertEquals(deletedKeys.length, 1);
  assertEquals(deletedKeys[0].startsWith("coelo-media-prod:tenants/"), true);
});

Deno.test("treats an unreadable R2 object as an incomplete upload", async () => {
  const captured: { adminRpc: Array<[string, Record<string, unknown>]> } = {
    adminRpc: [],
  };
  const deletedKeys: string[] = [];
  const response = await handleCircularMediaRequest(
    finalizeRequest(),
    finalizeDependencies(pngBytes(4096), captured, deletedKeys),
  );

  assertEquals(response.status, 422);
  assertEquals(await response.json(), { error: "media_upload_incomplete" });
  assertEquals(captured.adminRpc, []);
  assertEquals(deletedKeys, []);
});
