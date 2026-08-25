import { assertEquals } from "jsr:@std/assert";

import {
  type CircularMediaDependencies,
  handleCircularMediaRequest,
} from "./index.ts";

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
  assertEquals(
    source.includes("createSignedUrl(String(descriptor.object_key), 120)"),
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
