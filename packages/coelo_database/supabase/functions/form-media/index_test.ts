import { assertEquals } from "@std/assert";
import { type FormMediaDependencies, handleFormMediaRequest } from "./index.ts";

const environment: Record<string, string> = {
  COELO_ALLOWED_ORIGINS: "https://superadmin.example.test",
  SUPABASE_URL: "https://database.example.test",
  SUPABASE_ANON_KEY: "synthetic-public-key",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-server-key",
};
const id = "11111111-1111-4111-8111-111111111111";
const mediaId = "22222222-2222-4222-8222-222222222222";
const readToken = "33333333-3333-4333-8333-333333333333";
const readNow = Date.parse("2026-09-08T16:00:00Z");
const readCommand = {
  action: "read",
  payload: { asset_id: id, rendition: "preview" },
};
const readGrant = {
  asset_id: id,
  rendition: "preview",
  read_token: readToken,
  expires_at: "2026-09-08T16:01:00Z",
};
const readDescriptor = {
  asset_id: id,
  rendition: "preview",
  media_asset_id: mediaId,
  institution_id: id,
  form_id: id,
  bucket: "coelo-media-prod",
  object_key:
    `tenants/${id}/forms/form/${id}/answer-image/${mediaId}/preview/${readToken}.webp`,
  mime_type: "image/webp",
  expires_at: "2026-09-08T16:02:00Z",
};

function readHarness(options: {
  rendition?: "preview" | "original";
  grant?: unknown;
  descriptor?: unknown;
  grantError?: boolean;
  redeemError?: boolean;
  failAt?: "authorize" | "redeem" | "sign";
  advanceOnRedeem?: number;
  advanceOnSign?: number;
} = {}) {
  const calls: string[] = [];
  const signed: { key: string; ttl: number }[] = [];
  let current = readNow;
  const client = {
    auth: { getUser: () => Promise.resolve({ data: { user: { id } } }) },
    from: () => {
      throw new Error("read must not query People");
    },
    storage: {
      from: () => {
        throw new Error("read must not use Storage");
      },
    },
    rpc: (name: string, parameters: unknown) => {
      calls.push(name);
      if (name === "superadmin_form_authorize_media_read_v2") {
        assertEquals(parameters, {
          p_query: {
            ...readCommand.payload,
            rendition: options.rendition ?? "preview",
          },
        });
        if (options.failAt === "authorize") {
          throw new Error("private token and URL");
        }
        return Promise.resolve({
          data: "grant" in options
            ? options.grant
            : { ok: true, data: readGrant },
          error: options.grantError,
        });
      }
      assertEquals(name, "form_redeem_media_read_r2_v1");
      assertEquals(parameters, { p_read_token: readToken });
      if (options.failAt === "redeem") throw new Error("private token and URL");
      current += options.advanceOnRedeem ?? 0;
      return Promise.resolve({
        data: "descriptor" in options ? options.descriptor : readDescriptor,
        error: options.redeemError,
      });
    },
  };
  const dependencies: FormMediaDependencies = {
    envGet: (key) =>
      ({
        ...environment,
        COELO_R2_ENDPOINT: "https://r2.example.test",
        COELO_R2_REGION: "auto",
        COELO_R2_ACCESS_KEY_ID: "synthetic-access",
        COELO_R2_SECRET_ACCESS_KEY: "synthetic-secret",
      })[key],
    createClient: ((_url: string, key: string) => ({
      ...client,
      rpc: (name: string, parameters: unknown) => {
        assertEquals(
          key,
          name === "superadmin_form_authorize_media_read_v2"
            ? environment.SUPABASE_ANON_KEY
            : environment.SUPABASE_SERVICE_ROLE_KEY,
        );
        return client.rpc(name, parameters);
      },
    })) as unknown as FormMediaDependencies["createClient"],
    now: () => new Date(current),
    createR2: (config) => {
      calls.push("r2");
      assertEquals(config.bucket, "coelo-media-prod");
      return {
        presignGet: (key, ttl) => {
          signed.push({ key, ttl: ttl! });
          current += options.advanceOnSign ?? 0;
          if (options.failAt === "sign") {
            throw new Error("private token and URL");
          }
          return Promise.resolve({
            url: new URL("https://r2.example.test/temporary"),
            requiredHeaders: {},
          });
        },
      };
    },
  };
  return { dependencies, calls, signed };
}

Deno.test("internal read bypasses People and Storage and preserves Forms ID", async () => {
  const harness = readHarness();
  const result = await handleFormMediaRequest(
    request(readCommand),
    harness.dependencies,
  );
  assertEquals(result.status, 200);
  assertEquals(await result.json(), {
    asset_id: id,
    state: "available",
    ticket: {
      url: "https://r2.example.test/temporary",
      expires_at: "2026-09-08T16:01:00.000Z",
      headers: {},
    },
  });
  assertEquals(harness.calls, [
    "superadmin_form_authorize_media_read_v2",
    "form_redeem_media_read_r2_v1",
    "r2",
  ]);
  assertEquals(harness.signed, [{ key: readDescriptor.object_key, ttl: 60 }]);
  assertEquals(result.headers.get("cache-control"), "no-store");
});

Deno.test("internal read denies malformed or mismatched grants before redeem or R2", async () => {
  for (
    const grant of [
      null,
      {},
      { ok: false, error: { secret: "private" } },
      {
        ok: true,
        data: readGrant,
        error: { code: "SAI_PERMISSION_DENIED", secret: "private" },
      },
      { ok: true, data: { ...readGrant, asset_id: mediaId } },
      { ok: true, data: { ...readGrant, rendition: "original" } },
      { ok: true, data: { ...readGrant, read_token: "private-token" } },
      { ok: true, data: { ...readGrant, expires_at: "2026-09-08T15:59:59Z" } },
      { ok: true, data: { ...readGrant, expires_at: 123 } },
    ]
  ) {
    const harness = readHarness({ grant });
    const result = await handleFormMediaRequest(
      request(readCommand),
      harness.dependencies,
    );
    assertEquals(result.status, 404);
    assertEquals(await result.json(), { error: "media_unavailable" });
    assertEquals(harness.calls, ["superadmin_form_authorize_media_read_v2"]);
  }
});

Deno.test("internal read denies mismatched catalog descriptors before R2", async () => {
  for (
    const descriptor of [
      null,
      {},
      { ...readDescriptor, asset_id: mediaId },
      { ...readDescriptor, rendition: "original" },
      { ...readDescriptor, media_asset_id: id },
      { ...readDescriptor, bucket: "coelo-transient-prod" },
      { ...readDescriptor, institution_id: mediaId },
      { ...readDescriptor, form_id: mediaId },
      { ...readDescriptor, institution_id: null },
      { ...readDescriptor, form_id: null },
      { ...readDescriptor, object_key: "https://private.example.test/secret" },
      {
        ...readDescriptor,
        object_key: readDescriptor.object_key.replace(
          "/preview/",
          "/original/",
        ),
      },
      {
        ...readDescriptor,
        object_key: readDescriptor.object_key.replace(
          "answer-image",
          "question-image",
        ),
      },
      {
        ...readDescriptor,
        object_key: readDescriptor.object_key + "?secret=private",
      },
      { ...readDescriptor, object_key: readDescriptor.object_key + "\n" },
      {
        ...readDescriptor,
        object_key: readDescriptor.object_key.replace(".webp", ".png"),
      },
      { ...readDescriptor, mime_type: "image/svg+xml" },
      { ...readDescriptor, expires_at: "invalid" },
      { ...readDescriptor, expires_at: "2026-09-08T15:59:59Z" },
    ]
  ) {
    const harness = readHarness({ descriptor });
    const result = await handleFormMediaRequest(
      request(readCommand),
      harness.dependencies,
    );
    assertEquals(result.status, 404);
    assertEquals(await result.json(), { error: "media_unavailable" });
    assertEquals(harness.calls, [
      "superadmin_form_authorize_media_read_v2",
      "form_redeem_media_read_r2_v1",
    ]);
  }
});

Deno.test("internal read bounds ticket TTL by both receipts and 120 seconds", async () => {
  for (
    const [grantSeconds, artifactSeconds, expected] of [[60, 30, 30], [
      500,
      400,
      120,
    ], [60.9, 120, 60]]
  ) {
    const harness = readHarness({
      grant: {
        ok: true,
        data: {
          ...readGrant,
          expires_at: new Date(readNow + grantSeconds * 1000).toISOString(),
        },
      },
      descriptor: {
        ...readDescriptor,
        expires_at: new Date(readNow + artifactSeconds * 1000).toISOString(),
      },
    });
    const result = await handleFormMediaRequest(
      request(readCommand),
      harness.dependencies,
    );
    assertEquals(result.status, 200);
    assertEquals(harness.signed[0].ttl, expected);
    assertEquals(
      (await result.json()).ticket.expires_at,
      new Date(readNow + expected * 1000).toISOString(),
    );
  }
});

Deno.test("internal read rechecks expiry after redeem and asynchronous signing", async () => {
  for (
    const options of [{ advanceOnRedeem: 60_000 }, { advanceOnSign: 60_000 }]
  ) {
    const harness = readHarness(options);
    const result = await handleFormMediaRequest(
      request(readCommand),
      harness.dependencies,
    );
    assertEquals(result.status, 404);
    assertEquals(await result.json(), { error: "media_unavailable" });
  }
});

Deno.test("internal read sanitizes denial, RPC errors and secret-bearing exceptions", async () => {
  for (
    const options of [
      { grantError: true },
      { redeemError: true },
      { failAt: "authorize" as const },
      { failAt: "redeem" as const },
      { failAt: "sign" as const },
    ]
  ) {
    const harness = readHarness(options);
    const result = await handleFormMediaRequest(
      request(readCommand),
      harness.dependencies,
    );
    assertEquals(result.status, 404);
    assertEquals(await result.json(), { error: "media_unavailable" });
    if (options.failAt !== "sign") assertEquals(harness.signed.length, 0);
  }
});

Deno.test("internal read uses the shared signer with a frozen clock and no network", async () => {
  const harness = readHarness();
  const result = await handleFormMediaRequest(request(readCommand), {
    ...harness.dependencies,
    createR2: undefined,
  });
  assertEquals(result.status, 200);
  const data = await result.json();
  const url = new URL(data.ticket.url);
  assertEquals(url.origin, "https://r2.example.test");
  assertEquals(url.pathname, `/coelo-media-prod/${readDescriptor.object_key}`);
  assertEquals(url.searchParams.get("X-Amz-Expires"), "60");
  assertEquals(url.searchParams.get("X-Amz-Date"), "20260908T160000Z");
  assertEquals(data.ticket.expires_at, "2026-09-08T16:01:00.000Z");
  assertEquals(JSON.stringify(data).includes("synthetic-secret"), false);
});

Deno.test("internal read signs original only when both receipts authorize original", async () => {
  const original = {
    ...readCommand,
    payload: { ...readCommand.payload, rendition: "original" },
  };
  const objectKey = readDescriptor.object_key.replace(
    "/preview/",
    "/original/",
  );
  const harness = readHarness({
    rendition: "original",
    grant: { ok: true, data: { ...readGrant, rendition: "original" } },
    descriptor: {
      ...readDescriptor,
      rendition: "original",
      object_key: objectKey,
    },
  });
  const result = await handleFormMediaRequest(
    request(original),
    harness.dependencies,
  );
  assertEquals(result.status, 200);
  assertEquals(harness.signed, [{ key: objectKey, ttl: 60 }]);
});

Deno.test("internal read rejects invalid provider configuration before constructing R2", async () => {
  for (
    const [key, value] of [["COELO_R2_ENDPOINT", "http://unsafe.test"], [
      "COELO_R2_SECRET_ACCESS_KEY",
      "",
    ]]
  ) {
    const harness = readHarness();
    const result = await handleFormMediaRequest(request(readCommand), {
      ...harness.dependencies,
      envGet: (name) =>
        name === key ? value : harness.dependencies.envGet(name),
    });
    assertEquals(result.status, 404);
    assertEquals(await result.json(), { error: "media_unavailable" });
    assertEquals(harness.calls.includes("r2"), false);
  }
});
const command = {
  action: "prepare",
  request_id: id,
  expected_version: 0,
  payload: {
    occurrence_id: id,
    item_id: id,
    mime_type: "image/webp",
    byte_length: 128,
    checksum: "a".repeat(64),
  },
};
function request(body: unknown, origin = environment.COELO_ALLOWED_ORIGINS) {
  return new Request("https://gateway.example.test", {
    method: "POST",
    headers: { origin, authorization: "Bearer synthetic-session" },
    body: JSON.stringify(body),
  });
}

Deno.test("HTTP rejects invalid commands before creating backend clients", async () => {
  let calls = 0;
  const dependencies: FormMediaDependencies = {
    envGet: (key) => environment[key],
    createClient: (() => {
      calls++;
      throw new Error("must not run");
    }) as FormMediaDependencies["createClient"],
  };
  for (
    const body of [
      null,
      [],
      true,
      { ...command, request_id: "bad" },
      { ...command, expected_version: -1 },
      { ...command, tenant_id: id },
      { ...command, payload: { ...command.payload, edit_secret: null } },
      { ...command, payload: "x".repeat(32_769) },
    ]
  ) {
    const response = await handleFormMediaRequest(request(body), dependencies);
    assertEquals(response.status, 400);
    assertEquals(await response.json(), { error: "invalid_request" });
    assertEquals(response.headers.get("cache-control"), "no-store");
  }
  assertEquals(calls, 0);
});

Deno.test("HTTP keeps preflight and unauthorized origins away from backend", async () => {
  const dependencies: FormMediaDependencies = {
    envGet: (key) => environment[key],
    createClient: (() => {
      throw new Error("must not run");
    }) as FormMediaDependencies["createClient"],
  };
  const denied = await handleFormMediaRequest(
    request(command, "https://other.example.test"),
    dependencies,
  );
  assertEquals(denied.status, 403);
  const preflight = await handleFormMediaRequest(
    new Request("https://gateway.example.test", {
      method: "OPTIONS",
      headers: { origin: environment.COELO_ALLOWED_ORIGINS },
    }),
    dependencies,
  );
  assertEquals(preflight.status, 204);
  const missing = await handleFormMediaRequest(
    new Request("https://gateway.example.test", {
      method: "POST",
      body: JSON.stringify(command),
    }),
    dependencies,
  );
  assertEquals(missing.status, 401);
});

Deno.test("HTTP sanitizes unexpected backend failures", async () => {
  const response = await handleFormMediaRequest(request(command), {
    envGet: (key) => environment[key],
    createClient: (() => {
      throw new Error("private upstream URL and token");
    }) as FormMediaDependencies["createClient"],
  });
  assertEquals(response.status, 503);
  assertEquals(await response.json(), { error: "media_unavailable" });
});

Deno.test("HTTP prepare preserves the authorized command and safe upload ticket", async () => {
  let received: unknown;
  const query = {
    select: () => query,
    eq: () => query,
    maybeSingle: () => Promise.resolve({ data: { person_id: id } }),
  };
  const client = {
    auth: { getUser: () => Promise.resolve({ data: { user: { id } } }) },
    from: () => query,
    rpc: (_name: string, parameters: unknown) => {
      received = parameters;
      return Promise.resolve({
        data: {
          asset_id: id,
          storage_path: `ab/${id}`,
          expires_at: "2026-09-08T16:00:00Z",
        },
      });
    },
    storage: {
      from: () => ({
        createSignedUploadUrl: () =>
          Promise.resolve({
            data: {
              signedUrl: "https://upload.example.test/temporary",
              token: "synthetic-upload-ticket",
            },
          }),
      }),
    },
  };
  const response = await handleFormMediaRequest(request(command), {
    envGet: (key) => environment[key],
    createClient: (() =>
      client) as unknown as FormMediaDependencies["createClient"],
  });
  assertEquals(response.status, 200);
  assertEquals(received, {
    p_request_id: id,
    p_expected_version: 0,
    p_payload: command.payload,
  });
  assertEquals(await response.json(), {
    asset_id: id,
    signed_upload_url: "https://upload.example.test/temporary",
    upload_token: "synthetic-upload-ticket",
    expires_at: "2026-09-08T16:00:00Z",
  });
});

Deno.test("HTTP preserves legacy finalize, download and discard for People actors", async () => {
  for (const action of ["finalize", "download", "discard"]) {
    const calls: string[] = [];
    const query = {
      select: () => query,
      eq: () => query,
      maybeSingle: () => Promise.resolve({ data: { person_id: id } }),
    };
    const client = {
      auth: { getUser: () => Promise.resolve({ data: { user: { id } } }) },
      from: (table: string) => {
        assertEquals(table, "person_auth_links");
        return query;
      },
      rpc: (name: string, parameters: unknown) => {
        calls.push(name);
        if (name === "form_media_authorize_for_worker") {
          assertEquals(parameters, {
            p_asset_id: id,
            p_actor_person_id: id,
            p_edit_secret: undefined,
          });
          return Promise.resolve({
            data: { state: "finalized", storage_path: `ab/${id}` },
          });
        }
        assertEquals(parameters, {
          p_request_id: id,
          p_expected_version: 0,
          p_payload: { asset_id: id },
        });
        return Promise.resolve({ data: { state: "discarded" } });
      },
      storage: {
        from: (bucket: string) => {
          assertEquals(bucket, "coelo-forms-private");
          return {
            createSignedUrl: (path: string, ttl: number) => {
              assertEquals(path, `ab/${id}`);
              assertEquals(ttl, 60);
              return Promise.resolve({
                data: { signedUrl: "https://legacy.example.test/temporary" },
              });
            },
          };
        },
      },
    };
    const result = await handleFormMediaRequest(
      request({ ...command, action, payload: { asset_id: id } }),
      {
        envGet: (key) => environment[key],
        createClient: (() =>
          client) as unknown as FormMediaDependencies["createClient"],
        createR2: () => {
          throw new Error("legacy must not use R2");
        },
      },
    );
    assertEquals(result.status, 200);
    assertEquals(
      calls,
      action === "finalize"
        ? ["form_finalize_asset_upload", "form_media_authorize_for_worker"]
        : action === "download"
        ? ["form_media_authorize_for_worker"]
        : ["form_discard_asset"],
    );
    assertEquals(
      await result.json(),
      action === "finalize"
        ? { asset_id: id, state: "finalized" }
        : action === "download"
        ? {
          signed_url: "https://legacy.example.test/temporary",
          expires_in: 60,
        }
        : { state: "discarded" },
    );
  }
});
