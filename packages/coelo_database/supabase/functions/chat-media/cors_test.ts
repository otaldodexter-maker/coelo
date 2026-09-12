import { assertEquals } from "@std/assert";

type Handler = (request: Request) => Promise<Response>;
let handleRequest: Handler;
const serve = Deno.serve;
try {
  Deno.serve = ((handler: Handler) => {
    handleRequest = handler;
  }) as unknown as typeof Deno.serve;
  await import("./index.ts");
} finally {
  Deno.serve = serve;
}

Deno.test("preflight permite cabecalhos do cliente Supabase apenas na origem autorizada", async () => {
  const key = "CHAT_MEDIA_ALLOWED_ORIGINS";
  const previous = Deno.env.get(key);
  const origin = "http://127.0.0.1:3014";
  Deno.env.set(key, origin);
  try {
    const requestedHeaders = [
      "authorization",
      "apikey",
      "content-type",
      "x-client-info",
    ];
    const response = await handleRequest(
      new Request("https://gateway.test", {
        method: "OPTIONS",
        headers: {
          origin,
          "access-control-request-method": "POST",
          "access-control-request-headers": requestedHeaders.join(", "),
        },
      }),
    );
    assertEquals(response.status, 200);
    assertEquals(response.headers.get("access-control-allow-origin"), origin);
    const allowedHeaders = response.headers.get("access-control-allow-headers")!
      .split(",").map((header) => header.trim().toLowerCase());
    for (const header of requestedHeaders) {
      assertEquals(allowedHeaders.includes(header), true, header);
    }

    const denied = await handleRequest(
      new Request("https://gateway.test", {
        method: "OPTIONS",
        headers: { origin: "https://untrusted.example" },
      }),
    );
    assertEquals(denied.status, 403);
    assertEquals(denied.headers.has("access-control-allow-origin"), false);
  } finally {
    if (previous === undefined) Deno.env.delete(key);
    else Deno.env.set(key, previous);
  }
});
