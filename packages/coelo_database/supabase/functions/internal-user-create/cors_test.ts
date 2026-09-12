import { assertEquals, assertStringIncludes } from "@std/assert";
import { handleInternalUserCreate, securePasswordSetupLink } from "./index.ts";

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
