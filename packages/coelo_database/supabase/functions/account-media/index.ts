import { createClient } from "@supabase/supabase-js";

import { matchesDeclaredType, readStoredBytes, sha256Hex } from "../chat-media/stored_bytes.ts";
import { AccountR2Client, accountR2Config } from "./r2_s3.ts";

type Json = Record<string, unknown>;
const allowedMimeTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const maximumBytes = 2 * 1024 * 1024;

function allowedOrigins() {
  return new Set((Deno.env.get("ACCOUNT_MEDIA_ALLOWED_ORIGINS") ?? Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "")
    .split(",").map((value) => value.trim()).filter(Boolean));
}

function corsHeaders(origin: string | null) {
  const headers: Record<string, string> = {
    "Cache-Control": "no-store", Vary: "Origin",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-worker-secret, x-coelo-asset-id",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}

function reply(origin: string | null, status: number, body: Json) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } });
}

// Bytes da foto passam pela Edge (nunca do navegador direto ao R2): o CORS do
// bucket so lista alguns hosts e o app de desenvolvimento roda em qualquer porta.
function replyBytes(origin: string | null, bytes: Uint8Array, contentType: string) {
  return new Response(bytes.slice().buffer as ArrayBuffer, { status: 200, headers: { ...corsHeaders(origin),
    "Content-Type": "application/octet-stream", "X-Coelo-Content-Type": contentType } });
}

function environment() {
  return Object.fromEntries(["COELO_R2_ENDPOINT", "COELO_R2_REGION", "COELO_R2_ACCESS_KEY_ID",
    "COELO_R2_SECRET_ACCESS_KEY"].map((name) => [name, Deno.env.get(name)]));
}

function requiredSecret(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error("server_secret_unavailable");
  return value;
}

function uuid(value: unknown) {
  if (typeof value !== "string" || !/^[0-9a-f-]{36}$/i.test(value)) throw new Error("invalid_request");
  return value;
}

function input(body: Json) {
  if ((body.tenant_id != null && typeof body.tenant_id !== "string") || typeof body.file_name !== "string" ||
    body.file_name.length < 1 || body.file_name.length > 255 ||
    typeof body.content_type !== "string" || !allowedMimeTypes.has(body.content_type) ||
    typeof body.byte_size !== "number" || !Number.isSafeInteger(body.byte_size) ||
    body.byte_size < 1 || body.byte_size > maximumBytes || typeof body.sha256 !== "string" ||
    !/^[0-9a-f]{64}$/.test(body.sha256)) throw new Error("invalid_request");
  return body;
}

async function rpc(client: ReturnType<typeof createClient>, name: string, params: Json) {
  const response = await client.rpc(name, params);
  if (response.error || !response.data || typeof response.data !== "object") {
    throw new Error(response.error?.message ?? "rpc_denied");
  }
  return response.data as Json;
}

Deno.serve(async (request) => {
  const origin = request.headers.get("origin");
  if (origin !== null && !allowedOrigins().has(origin)) return reply(null, 403, { error: "origin_not_allowed" });
  if (request.method === "OPTIONS") return reply(origin, 200, { ok: true });
  if (request.method !== "POST") return reply(origin, 405, { error: "method_not_allowed" });
  try {
    const binary = (request.headers.get("content-type") ?? "").startsWith("application/octet-stream");
    const body = binary
      ? { action: "upload", asset_id: request.headers.get("x-coelo-asset-id") } as Json
      : await request.json() as Json;
    const url = requiredSecret("SUPABASE_URL");
    const admin = createClient(url, requiredSecret("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false } });
    const r2 = new AccountR2Client(accountR2Config(environment()));
    if (body.action === "expire") {
      if (request.headers.get("x-worker-secret") !== requiredSecret("ACCOUNT_MEDIA_WORKER_SECRET")) {
        return reply(origin, 401, { error: "authentication_required" });
      }
      const expired = await rpc(admin, "superadmin_account_avatar_expire_v1", { p_limit: 100 });
      for (const item of (expired.items as Json[] | undefined) ?? []) {
        await r2.delete(String(item.object_key)).catch(() => {});
      }
      return reply(origin, 200, { expired: expired.expired ?? 0 });
    }
    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) return reply(origin, 401, { error: "authentication_required" });
    const user = createClient(url, requiredSecret("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } }, auth: { persistSession: false },
    });
    const identity = await user.auth.getUser();
    if (identity.error || !identity.data.user) return reply(origin, 401, { error: "authentication_required" });

    if (body.action === "prepare") {
      const value = input(body);
      const prepared = await rpc(user, "superadmin_account_avatar_prepare_v1", {
        p_request_id: uuid(body.request_id), p_tenant_id: value.tenant_id == null ? null : uuid(value.tenant_id), p_file_name: value.file_name,
        p_content_type: value.content_type, p_byte_size: value.byte_size, p_sha256: value.sha256,
      });
      const signed = await r2.presignPut(String(prepared.object_key), String(value.content_type), 300);
      return reply(origin, 200, { ...prepared, upload_url: signed.url.toString(), required_headers: signed.requiredHeaders,
        expires_at: new Date(Date.now() + 300_000).toISOString() });
    }
    if (body.action === "upload") {
      const ticket = await rpc(user, "superadmin_account_avatar_authorize_finalize_v1", { p_asset_id: uuid(body.asset_id) });
      const bytes = new Uint8Array(await request.arrayBuffer());
      const contentType = String(ticket.content_type);
      if (bytes.byteLength !== Number(ticket.byte_size) || !matchesDeclaredType(bytes, contentType)) {
        throw new Error("account_avatar_mismatch");
      }
      await r2.put(String(ticket.object_key), bytes, contentType);
      const finalized = await rpc(admin, "superadmin_account_avatar_finalize_v1", {
        p_asset_id: ticket.asset_id, p_finalize_ticket: ticket.finalize_ticket,
        p_byte_size: bytes.byteLength, p_checksum_sha256: await sha256Hex(bytes),
      });
      return reply(origin, 200, finalized);
    }
    if (body.action === "finalize") {
      const ticket = await rpc(user, "superadmin_account_avatar_authorize_finalize_v1", { p_asset_id: uuid(body.asset_id) });
      const stored = await r2.head(String(ticket.object_key));
      if (stored.byteSize !== Number(ticket.byte_size) || stored.mimeType !== String(ticket.content_type)) {
        await r2.delete(String(ticket.object_key)).catch(() => {});
        throw new Error("account_avatar_mismatch");
      }
      const measured = await readStoredBytes(r2, String(ticket.object_key), Number(ticket.byte_size), String(ticket.content_type));
      const finalized = await rpc(admin, "superadmin_account_avatar_finalize_v1", {
        p_asset_id: ticket.asset_id, p_finalize_ticket: ticket.finalize_ticket,
        p_byte_size: measured.bytes.length, p_checksum_sha256: measured.sha256,
      });
      return reply(origin, 200, finalized);
    }
    if (body.action === "read") {
      const descriptor = await rpc(user, "superadmin_account_avatar_authorize_read_v1", { p_asset_id: uuid(body.asset_id) });
      if (body.inline === true) {
        const bytes = await r2.get(String(descriptor.object_key), Number(descriptor.byte_size));
        return replyBytes(origin, bytes, String(descriptor.content_type));
      }
      const ttl = Number(descriptor.ttl_seconds ?? 120);
      const signed = await r2.presignGet(String(descriptor.object_key), ttl);
      return reply(origin, 200, { asset_id: descriptor.asset_id, signed_url: signed.url.toString(),
        content_type: descriptor.content_type, expires_in: ttl });
    }
    if (body.action === "remove") {
      const descriptor = await rpc(user, "superadmin_account_avatar_remove_v1", { p_asset_id: uuid(body.asset_id) });
      await r2.delete(String(descriptor.object_key)).catch(() => {});
      return reply(origin, 200, descriptor);
    }
    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, { error: error instanceof Error ? error.message : "account_media_gateway_failure" });
  }
});
