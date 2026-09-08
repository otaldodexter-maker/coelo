import { assertEquals } from "@std/assert";
import { type FormMediaDependencies, handleFormMediaRequest } from "./index.ts";

const environment: Record<string, string> = {
  COELO_ALLOWED_ORIGINS: "https://superadmin.example.test",
  SUPABASE_URL: "https://database.example.test",
  SUPABASE_ANON_KEY: "synthetic-public-key",
  SUPABASE_SERVICE_ROLE_KEY: "synthetic-server-key",
};
const id = "11111111-1111-4111-8111-111111111111";
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
