import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1.0.14";

import {
  type NowMediaDependencies,
  handleNowMediaRequest,
} from "./index.ts";
import { R2TransportError } from "../_shared/r2_s3.ts";

// Ramo R2 do gateway de midia do Agora.
//
// A ADR 0032 faz do R2 privado o master da midia nova do MVP, mas esta funcao
// criava TODO objeto novo no Supabase Storage. O ramo abaixo espelha o que o
// circular-media ja faz: decide pelo `storage_provider` que o servidor devolve
// no descritor, reusa o cliente compartilhado de `_shared/r2_s3.ts` e nunca
// deixa bucket, chave, provedor ou credencial atravessarem a fronteira.
//
// RETIDO DE PROPOSITO: `prepare_now_asset_upload` ainda NAO devolve
// `storage_provider`, entao em producao o descritor cai sempre no ramo legado.
// Estes testes injetam o descritor dos dois jeitos para que o ramo novo seja
// exercitado de verdade em vez de ficar dormindo sem prova.

const environment: Record<string, string> = {
  NOW_MEDIA_ALLOWED_ORIGINS: "https://admin.coelo.test",
  SUPABASE_URL: "https://project.supabase.co",
  SUPABASE_SERVICE_ROLE_KEY: "service-role",
  SUPABASE_ANON_KEY: "anon-key",
  COELO_R2_ENDPOINT: "https://account.r2.cloudflarestorage.com",
  COELO_R2_REGION: "auto",
  COELO_R2_ACCESS_KEY_ID: "r2-access-key",
  COELO_R2_SECRET_ACCESS_KEY: "r2-secret-key",
};

type Probe = {
  storageCalls: string[];
  r2Calls: string[];
  buckets: string[];
};

function dependenciesFor(
  descriptor: Record<string, unknown>,
  probe: Probe,
  options: { r2Fails?: boolean; unconfigured?: boolean; bytes?: Uint8Array } = {},
): NowMediaDependencies {
  const bytes = options.bytes ??
    new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3, 4]);
  return {
    envGet: (name: string) =>
      options.unconfigured && name.startsWith("COELO_R2_")
        ? undefined
        : environment[name],
    createClient: ((_url: string, key: string) => {
      if (key === "service-role") {
        return {
          storage: {
            from: (bucket: string) => ({
              createSignedUploadUrl: () => {
                probe.storageCalls.push(`upload:${bucket}`);
                return Promise.resolve({
                  data: { signedUrl: "https://storage.test/u", token: "tok" },
                  error: null,
                });
              },
              createSignedUrl: () => {
                probe.storageCalls.push(`read:${bucket}`);
                return Promise.resolve({
                  data: { signedUrl: "https://storage.test/r" },
                  error: null,
                });
              },
              download: () => {
                probe.storageCalls.push(`download:${bucket}`);
                return Promise.resolve({
                  data: new Blob([bytes.slice()]),
                  error: null,
                });
              },
              remove: () => {
                probe.storageCalls.push(`remove:${bucket}`);
                return Promise.resolve({ data: null, error: null });
              },
            }),
          },
          rpc: () => Promise.resolve({ data: descriptor, error: null }),
        };
      }
      return {
        auth: {
          getUser: () =>
            Promise.resolve({ data: { user: { id: "viewer" } }, error: null }),
        },
        rpc: (name: string) => {
          if (name === "finalize_now_asset_upload") {
            return Promise.resolve({ data: { ok: true }, error: null });
          }
          return Promise.resolve({ data: descriptor, error: null });
        },
      };
    }) as unknown as NowMediaDependencies["createClient"],
    createR2: (config: { bucket: string }) => {
      probe.buckets.push(config.bucket);
      const fail = () =>
        Promise.reject(new R2TransportError("transport_failed"));
      return {
        presignPut: (key: string) => {
          probe.r2Calls.push(`put:${key}`);
          if (options.r2Fails) return fail();
          return Promise.resolve({
            url: new URL("https://r2.test/put?sig=1"),
            requiredHeaders: { "content-type": "image/png" },
          });
        },
        presignGet: (key: string) => {
          probe.r2Calls.push(`get:${key}`);
          if (options.r2Fails) return fail();
          return Promise.resolve({ url: new URL("https://r2.test/get?sig=1") });
        },
        get: (key: string) => {
          probe.r2Calls.push(`read:${key}`);
          if (options.r2Fails) return fail();
          return Promise.resolve(bytes);
        },
        delete: (key: string) => {
          probe.r2Calls.push(`delete:${key}`);
          if (options.r2Fails) return fail();
          return Promise.resolve();
        },
      } as never;
    },
  } as unknown as NowMediaDependencies;
}

function probe(): Probe {
  return { storageCalls: [], r2Calls: [], buckets: [] };
}

function post(body: Record<string, unknown>) {
  return new Request("https://project.functions.supabase.co/now-media", {
    method: "POST",
    headers: {
      authorization: "Bearer user-jwt",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

const uploadBody = {
  action: "prepare",
  request_id: "request-1",
  institution_id: "institution-1",
  publication_id: "publication-1",
  kind: "media",
  name: "foto.png",
  mime_type: "image/png",
  size_bytes: 12,
};

const r2Descriptor = {
  asset_id: "asset-1",
  storage_provider: "r2",
  bucket_id: "coelo-media-prod",
  object_key: "now/institution-1/publication-1/asset-1.png",
  mime_type: "image/png",
};

const legacyDescriptor = {
  asset_id: "asset-1",
  bucket_id: "coelo-now-mvp",
  object_key: "institution-1/publication-1/asset-1.png",
  mime_type: "image/png",
};

Deno.test("prepares an R2 upload with a short lived signed PUT", async () => {
  const tracked = probe();
  const response = await handleNowMediaRequest(
    post(uploadBody),
    dependenciesFor(r2Descriptor, tracked),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.storage_provider, "r2");
  assertStringIncludes(body.upload_url, "https://r2.test/put");
  assertEquals(body.required_headers["content-type"], "image/png");
  assertEquals(tracked.buckets, ["coelo-media-prod"]);
  assertEquals(tracked.storageCalls, []);
});

Deno.test("never returns bucket, key or credential on the R2 branch", async () => {
  const tracked = probe();
  const response = await handleNowMediaRequest(
    post(uploadBody),
    dependenciesFor(r2Descriptor, tracked),
  );
  const raw = await response.text();

  assertEquals(raw.includes("coelo-media-prod"), false);
  assertEquals(raw.includes(r2Descriptor.object_key), false);
  assertEquals(raw.includes("r2-secret-key"), false);
  assertEquals(raw.includes("r2-access-key"), false);
  assertEquals(raw.includes("service-role"), false);
});

Deno.test("keeps the legacy Supabase branch untouched", async () => {
  const tracked = probe();
  const response = await handleNowMediaRequest(
    post(uploadBody),
    dependenciesFor(legacyDescriptor, tracked),
  );
  const body = await response.json();

  assertEquals(response.status, 200);
  assertEquals(body.storage_provider, "supabase_mvp");
  assertEquals(body.upload_token, "tok");
  assertEquals(tracked.storageCalls, ["upload:coelo-now-mvp"]);
  assertEquals(tracked.r2Calls, []);
});

Deno.test("signs an R2 read and leaves the legacy read alone", async () => {
  const onR2 = probe();
  const r2Response = await handleNowMediaRequest(
    post({ action: "read", read_ticket: "ticket-1" }),
    dependenciesFor(r2Descriptor, onR2),
  );
  const r2Body = await r2Response.json();
  assertEquals(r2Response.status, 200);
  assertStringIncludes(r2Body.signed_url, "https://r2.test/get");
  assertEquals(onR2.storageCalls, []);

  const legacy = probe();
  const legacyResponse = await handleNowMediaRequest(
    post({ action: "read", read_ticket: "ticket-1" }),
    dependenciesFor(legacyDescriptor, legacy),
  );
  assertEquals(legacyResponse.status, 200);
  assertEquals(legacy.storageCalls, ["read:coelo-now-mvp"]);
  assertEquals(legacy.r2Calls, []);
});

Deno.test("a private read expires in sixty seconds on both providers", async () => {
  for (const descriptor of [r2Descriptor, legacyDescriptor]) {
    const response = await handleNowMediaRequest(
      post({ action: "read", read_ticket: "ticket-1" }),
      dependenciesFor(descriptor, probe()),
    );
    const body = await response.json();
    assertEquals(response.status, 200);
    assertEquals(body.expires_in, 60);
  }
});

Deno.test("reports an opaque failure when the R2 transport fails", async () => {
  const tracked = probe();
  const response = await handleNowMediaRequest(
    post(uploadBody),
    dependenciesFor(r2Descriptor, tracked, { r2Fails: true }),
  );
  const body = await response.json();

  assertEquals(response.status, 422);
  assertEquals(body.error, "media_transport_failed");
  assertEquals(JSON.stringify(body).includes("coelo-media-prod"), false);
});

Deno.test("refuses an unconfigured R2 without reaching the object", async () => {
  const tracked = probe();
  const response = await handleNowMediaRequest(
    post(uploadBody),
    dependenciesFor(r2Descriptor, tracked, { unconfigured: true }),
  );

  assertEquals(response.status, 422);
  assertEquals(tracked.r2Calls, []);
  assertEquals(tracked.storageCalls, []);
});

Deno.test("finalizes an R2 asset on bytes read back from the bucket", async () => {
  const tracked = probe();
  const response = await handleNowMediaRequest(
    post({
      ...uploadBody,
      action: "finalize",
      asset_id: "asset-1",
    }),
    dependenciesFor(r2Descriptor, tracked),
  );

  assertEquals(response.status, 200);
  assertEquals(tracked.r2Calls, [`read:${r2Descriptor.object_key}`]);
  assertEquals(tracked.storageCalls, []);
});

Deno.test("discards an R2 object whose bytes fail the MIME signature", async () => {
  const tracked = probe();
  const response = await handleNowMediaRequest(
    post({
      ...uploadBody,
      action: "finalize",
      asset_id: "asset-1",
    }),
    dependenciesFor(r2Descriptor, tracked, {
      bytes: new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]),
    }),
  );
  const body = await response.json();

  assertEquals(response.status, 422);
  assertEquals(body.error, "invalid_asset_signature");
  assertEquals(tracked.r2Calls.includes(`delete:${r2Descriptor.object_key}`), true);
});

Deno.test("still rejects an unauthenticated POST before touching anything", async () => {
  const tracked = probe();
  const request = new Request(
    "https://project.functions.supabase.co/now-media",
    {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(uploadBody),
    },
  );

  const response = await handleNowMediaRequest(
    request,
    dependenciesFor(r2Descriptor, tracked),
  );

  assertEquals(response.status, 401);
  assertEquals(request.bodyUsed, false);
  assertEquals(tracked.r2Calls, []);
  assertEquals(tracked.storageCalls, []);
});
