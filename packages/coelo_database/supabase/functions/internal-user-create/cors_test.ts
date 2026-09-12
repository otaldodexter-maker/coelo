import { assertEquals, assertStringIncludes } from "@std/assert";
import {
  createInternalUserCreateHandler,
  handleInternalUserCreate,
  passwordSetupRedirect,
  securePasswordSetupLink,
} from "./index.ts";

Deno.test("aceita somente link HTTPS de definicao de senha sem credenciais", () => {
  assertEquals(
    securePasswordSetupLink(
      "https://project.supabase.co/auth/v1/verify?token_hash=opaque&type=recovery",
      "https://project.supabase.co",
    ),
    "https://project.supabase.co/auth/v1/verify?token_hash=opaque&type=recovery",
  );
  assertEquals(securePasswordSetupLink("http://project.supabase.co/recovery", "https://project.supabase.co"), null);
  assertEquals(securePasswordSetupLink("https://operator:secret@project.supabase.co/recovery", "https://project.supabase.co"), null);
  assertEquals(securePasswordSetupLink("https://evil.example/auth/v1/verify", "https://project.supabase.co"), null);
});

Deno.test("o redirect da definicao de senha e o destino HTTPS canônico", () => {
  assertEquals(passwordSetupRedirect, "https://superadmin.coelo.me/reset-password");
});

Deno.test("OPTIONS permitido responde 204 vazio e aceita x-client-info", async () => {
  Deno.env.set("COELO_ALLOWED_ORIGINS", "https://superadmin.coelo.me");

  const response = await handleInternalUserCreate(
    new Request("https://functions.example/internal-user-create", {
      method: "OPTIONS",
      headers: {
        Origin: "https://superadmin.coelo.me",
        "Access-Control-Request-Headers":
          "authorization, apikey, content-type, x-client-info",
      },
    }),
  );

  assertEquals(response.status, 204);
  assertEquals(await response.text(), "");
  assertEquals(
    response.headers.get("Access-Control-Allow-Origin"),
    "https://superadmin.coelo.me",
  );
  assertStringIncludes(
    response.headers.get("Access-Control-Allow-Headers") ?? "",
    "x-client-info",
  );
});

Deno.test("OPTIONS não autorizado não concede allow-origin", async () => {
  Deno.env.set("COELO_ALLOWED_ORIGINS", "https://superadmin.coelo.me");

  const response = await handleInternalUserCreate(
    new Request("https://functions.example/internal-user-create", {
      method: "OPTIONS",
      headers: { Origin: "https://evil.example" },
    }),
  );

  assertEquals(response.status, 204);
  assertEquals(await response.text(), "");
  assertEquals(response.headers.has("Access-Control-Allow-Origin"), false);
});

Deno.test("POST anônimo permanece negado", async () => {
  Deno.env.set("COELO_ALLOWED_ORIGINS", "https://superadmin.coelo.me");

  const response = await handleInternalUserCreate(
    new Request("https://functions.example/internal-user-create", {
      method: "POST",
      headers: { Origin: "https://superadmin.coelo.me" },
      body: "{}",
    }),
  );

  assertEquals(response.status, 401);
  assertEquals(
    response.headers.get("Access-Control-Allow-Origin"),
    "https://superadmin.coelo.me",
  );
});

function testEnvironment(values: Record<string, string>) {
  return { get: (name: string) => values[name] };
}

function authorizedRequest() {
  return new Request("https://functions.example/internal-user-create", {
    method: "POST",
    headers: {
      Origin: "https://superadmin.coelo.me",
      Authorization: "Bearer operator-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      request_id: "123e4567-e89b-12d3-a456-426614174000",
      draft: { display_name: "Operador de teste" },
    }),
  });
}

function authorizedRuntimeRequest() {
  return new Request("https://functions.example/internal-user-create", {
    method: "POST",
    headers: {
      Origin: "http://127.0.0.1:3014",
      Authorization: "Bearer operator-token",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      request_id: "123e4567-e89b-12d3-a456-426614174000",
      draft: { display_name: "Operador de teste" },
    }),
  });
}

Deno.test("cria o usuario somente apos gerar link de recovery para a rota normal", async () => {
  const generatedCalls: unknown[] = [];
  const clientFactory = ((_: string, key: string) => {
    if (key === "anon-key") {
      return {
        rpc: async () => ({
          data: { ok: true, data: { actor_internal_identity_id: "actor-1", professional_email: "operator@example.test" } },
          error: null,
        }),
      };
    }
    return {
      auth: {
        admin: {
          createUser: async () => ({ data: { user: { id: "auth-1" } }, error: null }),
          generateLink: async (input: unknown) => {
            generatedCalls.push(input);
            return {
              data: { properties: { action_link: "https://project.supabase.co/auth/v1/verify?token_hash=opaque&type=recovery" } },
              error: null,
            };
          },
          deleteUser: async () => ({ error: null }),
        },
      },
      rpc: async () => ({ data: { ok: true, data: { id: "internal-1" } }, error: null }),
    };
  }) as never;
  const handle = createInternalUserCreateHandler({
    environment: testEnvironment({
      COELO_ALLOWED_ORIGINS: "https://superadmin.coelo.me,http://127.0.0.1:3014",
      SUPABASE_URL: "https://project.supabase.co",
      SUPABASE_ANON_KEY: "anon-key",
      SUPABASE_SERVICE_ROLE_KEY: "service-key",
    }),
    createSupabaseClient: clientFactory,
  });

  const response = await handle(authorizedRuntimeRequest());

  assertEquals(response.status, 200);
  assertEquals(generatedCalls, [{
    type: "recovery",
    email: "operator@example.test",
    options: { redirectTo: "https://superadmin.coelo.me/reset-password" },
  }]);
  assertEquals((await response.json()).ok, true);
});

Deno.test("falha ao gerar link devolve erro e tenta compensar o auth user", async () => {
  let deletedUserId: string | null = null;
  const clientFactory = ((_: string, key: string) => {
    if (key === "anon-key") {
      return {
        rpc: async () => ({
          data: { ok: true, data: { actor_internal_identity_id: "actor-1", professional_email: "operator@example.test" } },
          error: null,
        }),
      };
    }
    return {
      auth: {
        admin: {
          createUser: async () => ({ data: { user: { id: "auth-1" } }, error: null }),
          generateLink: async () => ({ data: null, error: { message: "unavailable" } }),
          deleteUser: async (id: string) => {
            deletedUserId = id;
            return { error: { message: "cleanup unavailable" } };
          },
        },
      },
      rpc: async () => ({ data: null, error: null }),
    };
  }) as never;
  const handle = createInternalUserCreateHandler({
    environment: testEnvironment({
      COELO_ALLOWED_ORIGINS: "https://superadmin.coelo.me",
      SUPABASE_URL: "https://project.supabase.co",
      SUPABASE_ANON_KEY: "anon-key",
      SUPABASE_SERVICE_ROLE_KEY: "service-key",
    }),
    createSupabaseClient: clientFactory,
  });

  const response = await handle(authorizedRequest());

  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "password_setup_link_unavailable" });
  assertEquals(deletedUserId, "auth-1");
});

Deno.test("excecao ao gerar link devolve erro e tenta compensar o auth user", async () => {
  let deletedUserId: string | null = null;
  const clientFactory = ((_: string, key: string) => {
    if (key === "anon-key") {
      return {
        rpc: async () => ({
          data: { ok: true, data: { actor_internal_identity_id: "actor-1", professional_email: "operator@example.test" } },
          error: null,
        }),
      };
    }
    return {
      auth: {
        admin: {
          createUser: async () => ({ data: { user: { id: "auth-1" } }, error: null }),
          generateLink: async () => { throw new Error("network unavailable"); },
          deleteUser: async (id: string) => {
            deletedUserId = id;
            return { error: null };
          },
        },
      },
      rpc: async () => ({ data: null, error: null }),
    };
  }) as never;
  const handle = createInternalUserCreateHandler({
    environment: testEnvironment({
      COELO_ALLOWED_ORIGINS: "https://superadmin.coelo.me",
      SUPABASE_URL: "https://project.supabase.co",
      SUPABASE_ANON_KEY: "anon-key",
      SUPABASE_SERVICE_ROLE_KEY: "service-key",
    }),
    createSupabaseClient: clientFactory,
  });

  const response = await handle(authorizedRequest());

  assertEquals(response.status, 409);
  assertEquals(await response.json(), { error: "password_setup_link_unavailable" });
  assertEquals(deletedUserId, "auth-1");
});
