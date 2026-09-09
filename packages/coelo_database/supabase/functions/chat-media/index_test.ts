import { assertEquals, assertStringIncludes } from "jsr:@std/assert";

import {
  type ChatMediaDependencies,
  chatAttachmentObjectKey,
  handleChatMediaRequest,
} from "./index.ts";

const conversation = "11111111-1111-4111-8111-111111111111";
const request = "22222222-2222-4222-8222-222222222222";
const finalize = "33333333-3333-4333-8333-333333333333";
const asset = "44444444-4444-4444-8444-444444444444";

const dependencies: ChatMediaDependencies = {
  envGet: (name) =>
    name === "CHAT_MEDIA_ALLOWED_ORIGINS" ? "https://superadmin.coelo.me" : undefined,
  createClient: (() => {
    throw new Error("the gateway must not reach Supabase while unavailable");
  }) as unknown as ChatMediaDependencies["createClient"],
};

function post(body: unknown, headers: Record<string, string> = {}) {
  return new Request("https://functions.invalid/chat-media", {
    method: "POST",
    headers: { authorization: "Bearer token", "content-type": "application/json", ...headers },
    body: JSON.stringify(body),
  });
}

Deno.test("the request limit counts bytes, not UTF-16 code units", async () => {
  // 20000 accented characters: 20000 code units, under the 32768 limit, but
  // 40000 bytes in UTF-8, over it. A limit measured on the string waves this
  // through and the gateway buffers well past what it agreed to accept.
  // Portuguese payloads are the normal case here, not an exotic one.
  const accented = "á".repeat(20_000);
  const request = new Request("https://functions.invalid/chat-media", {
    method: "POST",
    headers: { authorization: "Bearer token", "content-type": "application/json" },
    body: JSON.stringify({ action: "read", read_ticket: accented }),
  });

  const response = await handleChatMediaRequest(request, dependencies);

  assertEquals(response.status, 413);
  assertEquals(await response.json(), { error: "request_too_large" });
});

Deno.test("a payload under the byte limit is still accepted", async () => {
  // The other side of the boundary: tightening the measure must not start
  // refusing bodies that were always legitimate.
  const response = await handleChatMediaRequest(
    post({ action: "read", read_ticket: "á".repeat(1_000) }),
    dependencies,
  );

  assertEquals(response.status, 503);
});

Deno.test("CORS reflects only a configured origin", async () => {
  const allowed = await handleChatMediaRequest(
    new Request("https://functions.invalid/chat-media", {
      method: "OPTIONS",
      headers: { origin: "https://superadmin.coelo.me" },
    }),
    dependencies,
  );
  assertEquals(allowed.status, 200);
  assertEquals(
    allowed.headers.get("access-control-allow-origin"),
    "https://superadmin.coelo.me",
  );

  const refused = await handleChatMediaRequest(
    new Request("https://functions.invalid/chat-media", {
      method: "OPTIONS",
      headers: { origin: "https://attacker.invalid" },
    }),
    dependencies,
  );
  assertEquals(refused.status, 403);
  assertEquals(refused.headers.get("access-control-allow-origin"), null);
});

Deno.test("only POST is accepted and only with a bearer token", async () => {
  const wrongMethod = await handleChatMediaRequest(
    new Request("https://functions.invalid/chat-media", { method: "GET" }),
    dependencies,
  );
  assertEquals(wrongMethod.status, 405);

  const noToken = await handleChatMediaRequest(
    new Request("https://functions.invalid/chat-media", {
      method: "POST",
      body: "{}",
    }),
    dependencies,
  );
  assertEquals(noToken.status, 401);

  const wrongScheme = await handleChatMediaRequest(
    new Request("https://functions.invalid/chat-media", {
      method: "POST",
      headers: { authorization: "Basic token" },
      body: "{}",
    }),
    dependencies,
  );
  assertEquals(wrongScheme.status, 401);
});

Deno.test("a body that is not a JSON object is refused", async () => {
  for (const raw of ["", "[]", "null", "\"text\"", "{"]) {
    const response = await handleChatMediaRequest(
      new Request("https://functions.invalid/chat-media", {
        method: "POST",
        headers: { authorization: "Bearer token" },
        body: raw,
      }),
      dependencies,
    );
    assertEquals(response.status, 400);
  }
});

Deno.test("an oversized body is refused before parsing", async () => {
  const response = await handleChatMediaRequest(
    new Request("https://functions.invalid/chat-media", {
      method: "POST",
      headers: { authorization: "Bearer token" },
      body: JSON.stringify({ action: "prepare", padding: "a".repeat(40_000) }),
    }),
    dependencies,
  );
  assertEquals(response.status, 413);
});

Deno.test("an unknown action is refused", async () => {
  const response = await handleChatMediaRequest(post({ action: "publish" }), dependencies);
  assertEquals(response.status, 400);
  assertEquals(await response.json(), { error: "invalid_request" });
});

Deno.test("a malformed attempt is refused before any unavailability answer", async () => {
  const response = await handleChatMediaRequest(
    post({
      action: "prepare",
      conversation_id: conversation,
      request_id: request,
      finalize_request_id: request,
      name: "registro.png",
      mime_type: "image/png",
      size_bytes: 1024,
    }),
    dependencies,
  );
  // Shape first: the caller learns the request was wrong, not that a branch is
  // missing, so a malformed call is never mistaken for a pending feature.
  assertEquals(response.status, 400);
  assertEquals(await response.json(), { error: "invalid_request" });
});

Deno.test("a video attachment is refused: Chat carries no Stream in the MVP", async () => {
  const response = await handleChatMediaRequest(
    post({
      action: "prepare",
      conversation_id: conversation,
      request_id: request,
      finalize_request_id: finalize,
      name: "registro.mp4",
      mime_type: "video/mp4",
      size_bytes: 1024,
    }),
    dependencies,
  );
  assertEquals(response.status, 400);
});

Deno.test("every operation whose contract is missing says so with a named reason", async () => {
  const cases: Array<[unknown, string, string]> = [
    [
      {
        action: "prepare",
        conversation_id: conversation,
        request_id: request,
        finalize_request_id: finalize,
        name: "registro.png",
        mime_type: "image/png",
        size_bytes: 1024,
      },
      "chat_media_prepare_unavailable",
      "catalog_branch_missing",
    ],
    [
      { action: "finalize", conversation_id: conversation, asset_id: asset, request_id: finalize },
      "chat_media_finalize_unavailable",
      "catalog_branch_missing",
    ],
    [
      {
        action: "bind",
        conversation_id: conversation,
        asset_id: asset,
        message_request_id: request,
      },
      "chat_media_bind_unavailable",
      "send_contract_missing",
    ],
    [
      { action: "discard", conversation_id: conversation, asset_id: asset, request_id: request },
      "chat_media_discard_unavailable",
      "catalog_branch_missing",
    ],
    [
      { action: "read", read_ticket: asset },
      "chat_media_read_unavailable",
      "read_ticket_missing",
    ],
  ];
  for (const [body, error, reason] of cases) {
    const response = await handleChatMediaRequest(post(body), dependencies);
    assertEquals(response.status, 503, `${error} must not answer 2xx`);
    assertEquals(await response.json(), { error, reason });
  }
});

Deno.test("a malformed read ticket is a bad request, not a missing service", async () => {
  // 503 says the service is not there yet; 400 says the caller sent nonsense.
  // Collapsing the two would hide a client bug behind a server pendency for as
  // long as the branch stays unimplemented.
  for (const ticket of ["", " ", null, 42, undefined]) {
    const response = await handleChatMediaRequest(
      post({ action: "read", read_ticket: ticket }),
      dependencies,
    );
    assertEquals(
      response.status,
      400,
      `read_ticket ${JSON.stringify(ticket)} must be refused as invalid_request`,
    );
    assertEquals(await response.json(), { error: "invalid_request" });
  }
});

Deno.test("the object key carries no file name and no person", () => {
  const key = chatAttachmentObjectKey(conversation, asset);
  assertStringIncludes(key, conversation);
  assertStringIncludes(key, asset);
  assertEquals(key.includes("registro"), false);
  assertEquals(key.startsWith("chat/"), true);
  assertEquals(key.endsWith("/original"), true);
});
