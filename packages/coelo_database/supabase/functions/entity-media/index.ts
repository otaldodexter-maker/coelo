// Fotos de perfil, capa e ícone de instituição, unidade, turma, atividade e pessoa em R2 privado.
// Os bytes sempre passam por aqui (upload e leitura): o navegador nunca fala com o R2, então o
// CORS do bucket não entra na conta. Autorização, tenant e ticket ficam no Postgres.
import { createClient } from "@supabase/supabase-js";

import { matchesDeclaredType, sha256Hex } from "../chat-media/stored_bytes.ts";
import { EntityR2Client, entityR2Config } from "./r2_s3.ts";
import { isAcceptableSvg, maximumSvgBytes } from "./svg_contract.ts";

type Json = Record<string, unknown>;
const allowedMimeTypes = new Set(["image/jpeg", "image/png", "image/webp", "image/svg+xml"]);
const maximumBytes = 5 * 1024 * 1024;
const entityKinds = new Set(["institution", "unit", "group", "activity", "person"]);
const imageKinds = new Set(["profile", "cover", "icon", "icon_vector"]);

// Assinatura real dos bytes: raster pelo cabeçalho; SVG pelo contrato estreito (sem script/href/externo).
function bytesMatchDeclaredType(bytes: Uint8Array, contentType: string) {
  if (contentType === "image/svg+xml") return isAcceptableSvg(bytes);
  return matchesDeclaredType(bytes, contentType);
}

function allowedOrigins() {
  return new Set((Deno.env.get("ENTITY_MEDIA_ALLOWED_ORIGINS") ?? Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "")
    .split(",").map((value) => value.trim()).filter(Boolean));
}

function corsHeaders(origin: string | null) {
  const headers: Record<string, string> = {
    "Cache-Control": "no-store", Vary: "Origin",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info, x-coelo-asset-id, x-coelo-surface",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) headers["Access-Control-Allow-Origin"] = origin;
  return headers;
}

function reply(origin: string | null, status: number, body: Json) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders(origin), "Content-Type": "application/json" } });
}

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
  if (typeof body.entity_kind !== "string" || !entityKinds.has(body.entity_kind) ||
    typeof body.image_kind !== "string" || !imageKinds.has(body.image_kind) ||
    typeof body.file_name !== "string" || body.file_name.length < 1 || body.file_name.length > 255 ||
    typeof body.content_type !== "string" || !allowedMimeTypes.has(body.content_type) ||
    typeof body.byte_size !== "number" || !Number.isSafeInteger(body.byte_size) ||
    body.byte_size < 1 || body.byte_size > maximumBytes || typeof body.sha256 !== "string" ||
    ((body.image_kind === "icon_vector") !== (body.content_type === "image/svg+xml")) ||
    (body.content_type === "image/svg+xml" && body.byte_size > maximumSvgBytes) ||
    !/^[0-9a-f]{64}$/.test(body.sha256) ||
    (body.icon_spec != null && (typeof body.icon_spec !== "object" || Array.isArray(body.icon_spec)))) {
    throw new Error("invalid_request");
  }
  return body;
}

// deno-lint-ignore no-explicit-any
async function rpc(client: any, name: string, params: Json) {
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
    const r2 = new EntityR2Client(entityR2Config(environment()));

    const authorization = request.headers.get("authorization");
    if (!authorization?.startsWith("Bearer ")) return reply(origin, 401, { error: "authentication_required" });
    const user = createClient(url, requiredSecret("SUPABASE_ANON_KEY"), {
      global: { headers: { Authorization: authorization } }, auth: { persistSession: false },
    });
    const identity = await user.auth.getUser();
    if (identity.error || !identity.data.user) return reply(origin, 401, { error: "authentication_required" });

    if (body.action === "prepare") {
      const value = input(body);
      const prepared = await rpc(user, "superadmin_entity_image_prepare_v1", {
        p_request_id: uuid(body.request_id), p_entity_kind: value.entity_kind, p_entity_id: uuid(value.entity_id),
        p_image_kind: value.image_kind, p_file_name: value.file_name, p_content_type: value.content_type,
        p_byte_size: value.byte_size, p_sha256: value.sha256, p_icon_spec: value.icon_spec ?? null,
      });
      return reply(origin, 200, prepared);
    }
    if (body.action === "upload") {
      const ticket = await rpc(user, "superadmin_entity_image_authorize_upload_v1", { p_asset_id: uuid(body.asset_id) });
      const bytes = new Uint8Array(await request.arrayBuffer());
      const contentType = String(ticket.content_type);
      const sha256 = await sha256Hex(bytes);
      if (bytes.byteLength !== Number(ticket.byte_size) || sha256 !== String(ticket.sha256) ||
        !bytesMatchDeclaredType(bytes, contentType)) {
        throw new Error("entity_image_mismatch");
      }
      await r2.put(String(ticket.object_key), bytes, contentType);
      const admin = createClient(url, requiredSecret("SUPABASE_SERVICE_ROLE_KEY"), { auth: { persistSession: false } });
      const finalized = await rpc(admin, "superadmin_entity_image_finalize_v1", {
        p_asset_id: ticket.asset_id, p_finalize_ticket: ticket.finalize_ticket,
        p_byte_size: bytes.byteLength, p_checksum_sha256: sha256,
      }).catch(async (error) => {
        await r2.delete(String(ticket.object_key)).catch(() => {});
        throw error;
      });
      return reply(origin, 200, finalized);
    }
    if (body.action === "read") {
      // reader "principal": equipe do tenant ou responsável por guardian_links + can_view (regra no Postgres).
      const readRpc = body.reader === "principal"
        ? "principal_entity_image_authorize_read_v1"
        : "superadmin_entity_image_authorize_read_v1";
      const descriptor = await rpc(user, readRpc, { p_asset_id: uuid(body.asset_id) });
      const bytes = await r2.get(String(descriptor.object_key), Number(descriptor.byte_size));
      return replyBytes(origin, bytes, String(descriptor.content_type));
    }
    if (body.action === "remove") {
      const descriptor = await rpc(user, "superadmin_entity_image_remove_v1", { p_asset_id: uuid(body.asset_id) });
      await r2.delete(String(descriptor.object_key)).catch(() => {});
      return reply(origin, 200, descriptor);
    }
    return reply(origin, 400, { error: "invalid_request" });
  } catch (error) {
    return reply(origin, 422, { error: error instanceof Error ? error.message : "entity_media_gateway_failure" });
  }
});
