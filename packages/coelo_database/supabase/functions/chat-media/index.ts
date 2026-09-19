import { createClient } from "@supabase/supabase-js";

import { bytesResponse, decodeEnvelope, isBinaryUpload, readUploadBytes } from "../_shared/edge_bytes.ts";
import { ChatR2Client, chatR2Config } from "./r2_s3.ts";
import { matchesDeclaredType, readStoredBytes } from "./stored_bytes.ts";

// Gateway de anexos do chat interno (R05 realm-interno, 20260911210200).
// Contrato de tres tempos: prepare (RPC do usuario + PUT assinado), finalize
// (ticket do usuario + bytes relidos + RPC service_role) e read (RPC do usuario
// + GET assinado). expire e chamado por cron com segredo proprio. Sem Stream.
// R15 E3 (spec 058): prepare com `items[]` usa prepare_v2 (um lote = UMA
// mensagem, ate 10 itens; o 11o e CHAT_ATTACHMENT_LIMIT); finalize usa
// finalize_v2 (a mensagem so publica quando todos os irmaos terminam); discard
// remove um anexo de mensagem ainda em draft e apaga o objeto se ja estava ready.

type Json = Record<string, unknown>;
const allowedMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
  "video/mp4",
]);
const maximumBytes = 10 * 1024 * 1024;

function allowedOrigins() {
  return new Set(
    (Deno.env.get("CHAT_MEDIA_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

function corsHeaders(origin: string | null) {
  const headers: Record<string, string> = {
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info, x-worker-secret, x-coelo-media-envelope, x-coelo-surface",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

function reply(origin: string | null, status: number, body: Json) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(origin), "Content-Type": "application/json" },
  });
}

function environment() {
  return Object.fromEntries([
    "COELO_R2_ENDPOINT",
    "COELO_R2_REGION",
    "COELO_R2_ACCESS_KEY_ID",
    "COELO_R2_SECRET_ACCESS_KEY",
  ].map((name) => [name, Deno.env.get(name)]));
}

function requiredSecret(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function uuid(value: unknown) {
  if (typeof value !== "string" || !/^[0-9a-f-]{36}$/i.test(value)) {
    throw new Error("invalid_request");
  }
  return value;
}

/** Envelope da RPC interna: {ok, data, error{code,...}}. */
function unwrap(response: { data: unknown; error: unknown }): Json {
  if (response.error) throw new Error("rpc_transport_failure");
  const envelope = response.data as Json;
  if (envelope?.ok !== true) {
    const code = (envelope?.error as Json | undefined)?.code;
    throw new Error(typeof code === "string" ? code.toLowerCase() : "rpc_denied");
  }
  return envelope.data as Json;
}

const maximumBatchItems = 10;

/** Um item do lote: mesmas regras do envelope unitario. */
export function batchItemEnvelope(item: unknown) {
  if (typeof item !== "object" || item === null) throw new Error("invalid_request");
  const value = item as Json;
  if (
    typeof value.file_name !== "string" || value.file_name.length < 1 ||
    value.file_name.length > 255 ||
    typeof value.content_type !== "string" ||
    !allowedMimeTypes.has(value.content_type) ||
    typeof value.byte_size !== "number" ||
    !Number.isSafeInteger(value.byte_size) ||
    value.byte_size < 1 || value.byte_size > maximumBytes ||
    typeof value.sha256 !== "string" || !/^[0-9a-f]{64}$/.test(value.sha256)
  ) throw new Error("invalid_request");
  return {
    file_name: value.file_name,
    content_type: value.content_type,
    byte_size: value.byte_size,
    sha256: value.sha256,
  };
}

/** Lote: 1..10 itens; o 11o passa para o servidor responder CHAT_ATTACHMENT_LIMIT. */
export function batchEnvelope(body: Json) {
  if (
    typeof body.conversation_id !== "string" || !Array.isArray(body.items) ||
    body.items.length < 1 || body.items.length > maximumBatchItems + 1 ||
    (body.body_text !== undefined && body.body_text !== null &&
      (typeof body.body_text !== "string" || body.body_text.length > 4000))
  ) throw new Error("invalid_request");
  return {
    conversationId: body.conversation_id,
    bodyText: typeof body.body_text === "string" ? body.body_text : null,
    items: body.items.map(batchItemEnvelope),
  };
}

export function prepareEnvelope(body: Json) {
  if (
    typeof body.conversation_id !== "string" ||
    typeof body.file_name !== "string" || body.file_name.length < 1 ||
    body.file_name.length > 255 ||
    typeof body.content_type !== "string" ||
    !allowedMimeTypes.has(body.content_type) ||
    typeof body.byte_size !== "number" ||
    !Number.isSafeInteger(body.byte_size) ||
    body.byte_size < 1 || body.byte_size > maximumBytes ||
    typeof body.sha256 !== "string" || !/^[0-9a-f]{64}$/.test(body.sha256)
  ) throw new Error("invalid_request");
  return {
    conversationId: body.conversation_id,
    fileName: body.file_name,
    contentType: body.content_type,
    byteSize: body.byte_size,
    sha256: body.sha256,
  };
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (origin !== null && !allowedOrigins().has(origin)) {
    return reply(null, 403, { error: "origin_not_allowed" });
  }
  if (request.method === "OPTIONS") return reply(origin, 200, { ok: true });
  if (request.method !== "POST") {
    return reply(origin, 405, { error: "method_not_allowed" });
  }

  try {
    // Upload binário: envelope {attachment_id} no cabeçalho, bytes no corpo (_shared/edge_bytes.ts).
    const body = isBinaryUpload(request) ? decodeEnvelope(request) : await request.json() as Json;
    const url = requiredSecret("SUPABASE_URL");
    const admin = createClient(url, requiredSecret("SUPABASE_SERVICE_ROLE_KEY"), {
      auth: { persistSession: false },
    });
    const r2 = new ChatR2Client(chatR2Config(environment()));

    if (body.action === "expire") {
      if (
        request.headers.get("x-worker-secret") !==
          requiredSecret("CHAT_MEDIA_WORKER_SECRET")
      ) {
        return reply(origin, 401, { error: "authentication_required" });
      }
      const expired = unwrap(
        await admin.rpc("superadmin_chat_attachment_expire_v1", { p_limit: 100 }),
      );
      return reply(origin, 200, expired);
    }

    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) {
      return reply(origin, 401, { error: "authentication_required" });
    }
    const user = createClient(url, requiredSecret("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } },
      auth: { persistSession: false },
    });
    const identity = await user.auth.getUser();
    if (identity.error || !identity.data.user) {
      return reply(origin, 401, { error: "authentication_required" });
    }

    if (body.action === "read") {
      const descriptor = unwrap(
        await user.rpc("superadmin_chat_attachment_authorize_read_v1", {
          p_attachment_id: uuid(body.attachment_id),
        }),
      );
      const ttl = Number(descriptor.ttl_seconds ?? 300);
      if (body.inline === true) {
        // Bytes pela Edge: nenhuma URL assinada chega ao navegador.
        const bytes = await r2.get(String(descriptor.object_key), Number(descriptor.byte_size));
        return bytesResponse(corsHeaders(origin), bytes, String(descriptor.content_type));
      }
      const signed = await r2.presignGet(String(descriptor.object_key), ttl);
      return reply(origin, 200, {
        attachment_id: descriptor.attachment_id,
        asset_id: descriptor.attachment_id,
        signed_url: signed.url.toString(),
        file_name: descriptor.file_name,
        content_type: descriptor.content_type,
        byte_size: descriptor.byte_size,
        expires_in: ttl,
      });
    }

    if (body.action === "prepare" && Array.isArray(body.items)) {
      const input = batchEnvelope(body);
      const prepared = unwrap(
        await user.rpc("superadmin_chat_attachment_prepare_v2", {
          p_request_id: uuid(body.request_id),
          p_conversation_id: input.conversationId,
          p_items: input.items,
          p_body_text: input.bodyText,
        }),
      );
      const rawItems = Array.isArray(prepared.items) ? prepared.items as Json[] : [];
      const items = [];
      for (const item of rawItems) {
        const signed = await r2.presignPut(
          String(item.object_key),
          String(item.content_type),
          300,
        );
        items.push({
          index: item.index,
          attachment_id: item.attachment_id,
          asset_id: item.attachment_id,
          object_key: item.object_key,
          file_name: item.file_name,
          content_type: item.content_type,
          byte_size: item.byte_size,
          upload_url: signed.url.toString(),
          required_headers: signed.requiredHeaders,
          expires_at: new Date(Date.now() + 300_000).toISOString(),
          upload_status: item.upload_status,
          replayed: item.replayed === true,
        });
      }
      return reply(origin, 200, {
        message_id: prepared.message_id,
        message_status: prepared.message_status,
        body_text: prepared.body_text,
        replayed: prepared.replayed === true,
        items,
      });
    }

    if (body.action === "discard") {
      // Dono do ticket, mensagem ainda em draft: o banco decide se a mensagem
      // publica (irmaos prontos) ou arquiva (nenhum pronto); o objeto R2 de um
      // anexo que ja subiu e apagado aqui.
      const discarded = unwrap(
        await user.rpc("superadmin_chat_attachment_discard_v1", {
          p_attachment_id: uuid(body.attachment_id),
        }),
      );
      if (discarded.previous_status === "ready" || discarded.previous_status === "failed") {
        await r2.delete(String(discarded.object_key)).catch(() => {});
      }
      return reply(origin, 200, {
        attachment_id: discarded.attachment_id,
        asset_id: discarded.attachment_id,
        message_id: discarded.message_id,
        upload_status: discarded.upload_status,
        message_status: discarded.message_status,
        attachments: discarded.attachments,
      });
    }

    if (body.action === "prepare") {
      const input = prepareEnvelope(body);
      const prepared = unwrap(
        await user.rpc("superadmin_chat_attachment_prepare_v1", {
          p_request_id: uuid(body.request_id),
          p_conversation_id: input.conversationId,
          p_file_name: input.fileName,
          p_content_type: input.contentType,
          p_byte_size: input.byteSize,
          p_sha256: input.sha256,
        }),
      );
      const signed = await r2.presignPut(
        String(prepared.object_key),
        input.contentType,
        300,
      );
      return reply(origin, 200, {
        message_id: prepared.message_id,
        attachment_id: prepared.attachment_id,
        asset_id: prepared.attachment_id,
        object_key: prepared.object_key,
        upload_url: signed.url.toString(),
        required_headers: signed.requiredHeaders,
        expires_at: new Date(Date.now() + 300_000).toISOString(),
        upload_status: prepared.upload_status,
        replayed: prepared.replayed === true,
      });
    }

    if (body.action === "upload") {
      // O ticket do dono autoriza o upload; a Edge grava no R2 e segue para o
      // finalize normal (HEAD + releitura + sha256 medido).
      const ticket = unwrap(
        await user.rpc("superadmin_chat_attachment_authorize_finalize_v1", {
          p_attachment_id: uuid(body.attachment_id),
        }),
      );
      const bytes = await readUploadBytes(request, Number(ticket.byte_size));
      if (!matchesDeclaredType(bytes, String(ticket.content_type))) {
        throw new Error("uploaded_attachment_mismatch");
      }
      await r2.put(String(ticket.object_key), bytes, String(ticket.content_type));
      body.action = "finalize";
    }

    if (body.action === "finalize") {
      // O ticket so sai para o dono do anexo, no escopo da conversa.
      const ticket = unwrap(
        await user.rpc("superadmin_chat_attachment_authorize_finalize_v1", {
          p_attachment_id: uuid(body.attachment_id),
        }),
      );
      const stored = await r2.head(String(ticket.object_key));
      if (
        stored.byteSize !== Number(ticket.byte_size) ||
        stored.mimeType !== String(ticket.content_type)
      ) {
        await r2.delete(String(ticket.object_key)).catch(() => {});
        throw new Error("uploaded_attachment_mismatch");
      }
      // Bytes relidos: assinatura MIME real e sha256 medido aqui; a RPC
      // service_role compara com o anunciado no prepare e so entao a mensagem
      // aparece na thread.
      const measured = await readStoredBytes(
        r2,
        String(ticket.object_key),
        Number(ticket.byte_size),
        String(ticket.content_type),
      );
      const finalized = await admin.rpc("superadmin_chat_attachment_finalize_v2", {
        p_attachment_id: ticket.attachment_id,
        p_finalize_ticket: ticket.finalize_ticket,
        p_byte_size: measured.bytes.length,
        p_checksum_sha256: measured.sha256,
      });
      const data = (finalized.data as Json | null) ?? {};
      if (finalized.error || data.ok !== true) {
        // O banco ja marcou o anexo failed (a mensagem espera os irmaos); o objeto sai.
        await r2.delete(String(ticket.object_key)).catch(() => {});
        const code = (data.error as Json | undefined)?.code;
        throw new Error(typeof code === "string" ? code.toLowerCase() : "attachment_finalize_failed");
      }
      const result = data.data as Json;
      return reply(origin, 200, { ...result, asset_id: result.attachment_id });
    }
    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, {
      error: error instanceof Error ? error.message : "chat_media_gateway_failure",
    });
  }
});
