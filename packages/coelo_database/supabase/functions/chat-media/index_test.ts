import { assertEquals } from "jsr:@std/assert@1.0.14";

Deno.test("chat gateway autentica o usuario, nunca usa Supabase Storage nem Stream", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("user.auth.getUser()"), true);
  assertEquals(source.includes("superadmin_chat_attachment_prepare_v1"), true);
  assertEquals(source.includes("superadmin_chat_attachment_authorize_finalize_v1"), true);
  assertEquals(source.includes("superadmin_chat_attachment_finalize_v2"), true);
  assertEquals(source.includes("superadmin_chat_attachment_finalize_v1"), false);
  assertEquals(source.includes("superadmin_chat_attachment_authorize_read_v1"), true);
  assertEquals(source.includes(".storage.from("), false);
  assertEquals(source.includes("COELO_STREAM_API_TOKEN"), false);
  assertEquals(source.includes("video/mp4"), true);
  assertEquals(source.includes("presignPut"), true);
  assertEquals(source.includes("r2.head("), true);
  assertEquals(source.includes("asset_id: prepared.attachment_id"), true);
  assertEquals(source.includes("asset_id: descriptor.attachment_id"), true);
});

Deno.test("CORS por allowlist e expire so com segredo do worker", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("CHAT_MEDIA_ALLOWED_ORIGINS"), true);
  assertEquals(source.includes('"Access-Control-Allow-Origin": "*"'), false);
  assertEquals(source.includes("CHAT_MEDIA_WORKER_SECRET"), true);
  assertEquals(source.includes("superadmin_chat_attachment_expire_v1"), true);
  assertEquals(source.includes('body.action === "expire"'), true);
});

Deno.test("finalize mede os bytes e usa ticket do usuario com RPC service_role", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("readStoredBytes"), true);
  assertEquals(source.includes("p_finalize_ticket"), true);
  assertEquals(source.includes("p_checksum_sha256: measured.sha256"), true);
  assertEquals(source.includes('.schema("app_private")'), false);
});

Deno.test("prepare preserva o status autoritativo do anexo", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes("upload_status: prepared.upload_status"), true);
  assertEquals(source.includes("asset_id: result.attachment_id"), true);
});

Deno.test("lote (E3): prepare com items usa prepare_v2, assina um PUT por item e discard apaga o objeto", async () => {
  const source = await Deno.readTextFile(new URL("./index.ts", import.meta.url));
  assertEquals(source.includes('body.action === "prepare" && Array.isArray(body.items)'), true);
  assertEquals(source.includes("superadmin_chat_attachment_prepare_v2"), true);
  assertEquals(source.includes("p_items: input.items"), true);
  assertEquals(source.includes("asset_id: item.attachment_id"), true);
  assertEquals(source.includes("upload_status: item.upload_status"), true);
  assertEquals(source.includes("message_status: prepared.message_status"), true);
  assertEquals(source.includes('body.action === "discard"'), true);
  assertEquals(source.includes("superadmin_chat_attachment_discard_v1"), true);
  assertEquals(source.includes("r2.delete(String(discarded.object_key))"), true);
});

Deno.test("lote (E3): envelope do lote valida itens com as regras do unitario", async () => {
  const serve = Deno.serve;
  Deno.serve = (() => ({})) as unknown as typeof Deno.serve;
  let batchEnvelope: (body: Record<string, unknown>) => { items: unknown[]; bodyText: string | null };
  try {
    ({ batchEnvelope } = await import("./index.ts"));
  } finally {
    Deno.serve = serve;
  }
  const item = { file_name: "a.jpg", content_type: "image/jpeg", byte_size: 10, sha256: "a".repeat(64) };
  const ok = batchEnvelope({ conversation_id: "c", items: [item, { ...item, file_name: "b.png", content_type: "image/png" }], body_text: "x" });
  assertEquals(ok.items.length, 2);
  assertEquals(ok.bodyText, "x");
  const refused = (body: Record<string, unknown>) => {
    try { batchEnvelope(body); } catch { return true; }
    return false;
  };
  assertEquals(refused({ conversation_id: "c", items: [] }), true);
  assertEquals(refused({ conversation_id: "c", items: [{ ...item, sha256: "zz" }] }), true);
  assertEquals(refused({ conversation_id: "c", items: [{ ...item, content_type: "text/plain" }] }), true);
  assertEquals(refused({ conversation_id: "c", items: Array.from({ length: 12 }, () => item) }), true);
  // 11 itens passam no gateway para que o servidor responda CHAT_ATTACHMENT_LIMIT (422)
  assertEquals(batchEnvelope({ conversation_id: "c", items: Array.from({ length: 11 }, () => item) }).items.length, 11);
});
