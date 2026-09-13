import { createClient } from "@supabase/supabase-js";

import { ChatR2Client, chatR2Config } from "./r2_s3.ts";
import { readStoredBytes } from "./stored_bytes.ts";

// Gateway de anexos do chat interno (R05 realm-interno, 20260911210200).
// Contrato de tres tempos: prepare (RPC do usuario + PUT assinado), finalize
// (ticket do usuario + bytes relidos + RPC service_role) e read (RPC do usuario
// + GET assinado). expire e chamado por cron com segredo proprio. Sem Stream.

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

function reply(origin: string | null, status: number, body: Json) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info, x-worker-secret",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), { status, headers });
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
    const body = await request.json() as Json;
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
      const signed = await r2.presignGet(String(descriptor.object_key), ttl);
      return reply(origin, 200, {
        attachment_id: descriptor.attachment_id,
        signed_url: signed.url.toString(),
        file_name: descriptor.file_name,
        content_type: descriptor.content_type,
        byte_size: descriptor.byte_size,
        expires_in: ttl,
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
        object_key: prepared.object_key,
        upload_url: signed.url.toString(),
        required_headers: signed.requiredHeaders,
        expires_at: new Date(Date.now() + 300_000).toISOString(),
        upload_status: prepared.upload_status,
        replayed: prepared.replayed === true,
      });
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
      const finalized = await admin.rpc("superadmin_chat_attachment_finalize_v1", {
        p_attachment_id: ticket.attachment_id,
        p_finalize_ticket: ticket.finalize_ticket,
        p_byte_size: measured.bytes.length,
        p_checksum_sha256: measured.sha256,
      });
      const data = (finalized.data as Json | null) ?? {};
      if (finalized.error || data.ok !== true) {
        // O banco ja marcou failed/archived em caso de mismatch; o objeto sai.
        await r2.delete(String(ticket.object_key)).catch(() => {});
        const code = (data.error as Json | undefined)?.code;
        throw new Error(typeof code === "string" ? code.toLowerCase() : "attachment_finalize_failed");
      }
      return reply(origin, 200, data.data as Json);
    }
    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, {
      error: error instanceof Error ? error.message : "chat_media_gateway_failure",
    });
  }
});
