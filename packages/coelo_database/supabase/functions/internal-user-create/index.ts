// internal-user-create (R06, dona: acessos-pessoas; deploy pelo coordenador).
//
// Cria um usuario interno do Superadmin em tres tempos (pacote 20260911170800):
//   1. com o token do operador: superadmin_internal_user_create_authorize_v1
//      (platform.member.update em escopo de plataforma; valida o rascunho);
//   2. com service_role: auth.admin.createUser (e-mail confirmado, senha
//      aleatoria nunca devolvida; o usuario define a senha por
//      "Esqueci minha senha" - depende do SMTP do projeto, P51);
//   3. com service_role: superadmin_internal_user_create_for_worker_v1
//      (identidade + perfil + vinculo auth + membership); se falhar, o auth
//      user recem-criado e apagado.
// Nunca devolve senha, token ou dado sensivel alem da projecao do usuario.
import { createClient } from "@supabase/supabase-js";

type Json = Record<string, unknown>;

function allowedOrigins() {
  return new Set(
    (Deno.env.get("COELO_ALLOWED_ORIGINS") ?? "")
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
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins().has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(JSON.stringify(body), { status, headers });
}

function serviceKey(): string {
  const configured = Deno.env.get("SUPABASE_SECRET_KEYS") ?? "";
  if (configured.startsWith("{")) {
    try {
      return (JSON.parse(configured) as Record<string, string>).default ?? "";
    } catch {
      return "";
    }
  }
  return configured.split(",").map((value) => value.trim()).find(Boolean) ??
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

function randomPassword(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replaceAll("=", "");
}

export async function handleInternalUserCreate(request: Request): Promise<Response> {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return reply(origin, 204, {});
  if (origin !== null && !allowedOrigins().has(origin)) {
    return reply(origin, 403, { error: "request_denied" });
  }
  if (request.method !== "POST") return reply(origin, 405, { error: "method_not_allowed" });

  const authorization = request.headers.get("authorization") ?? "";
  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  const service = serviceKey();
  if (!/^Bearer \S+$/.test(authorization) || !url || !anon || !service) {
    return reply(origin, 401, { error: "unauthorized" });
  }

  let body: { request_id?: unknown; draft?: unknown };
  try {
    body = await request.json();
  } catch {
    return reply(origin, 400, { error: "invalid_request" });
  }
  const requestId = typeof body.request_id === "string" ? body.request_id : "";
  const draft = body.draft && typeof body.draft === "object" ? body.draft as Json : null;
  if (!/^[0-9a-f-]{36}$/i.test(requestId) || !draft) {
    return reply(origin, 400, { error: "invalid_request" });
  }

  // 1. autorizacao com o token do operador (o servidor decide tudo).
  const user = createClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const authorized = await user.rpc("superadmin_internal_user_create_authorize_v1", { p_draft: draft });
  const envelope = authorized.data as { ok?: unknown; data?: Json; error?: Json } | null;
  if (authorized.error || envelope?.ok !== true || !envelope.data) {
    return reply(origin, 403, { error: "not_authorized", detail: envelope?.error ?? null });
  }
  const actor = envelope.data.actor_internal_identity_id as string;
  const email = envelope.data.professional_email as string;

  // 2. auth user pelo Admin API (senha aleatoria, nunca devolvida).
  const admin = createClient(url, service, { auth: { persistSession: false } });
  const created = await admin.auth.admin.createUser({
    email,
    password: randomPassword(),
    email_confirm: true,
    app_metadata: { coelo_realm: "superadmin_internal" },
  });
  if (created.error || !created.data.user) {
    return reply(origin, 409, { error: "auth_user_unavailable" });
  }
  const authUserId = created.data.user.id;

  // 3. identidade interna numa transacao; falha desfaz o auth user.
  const persisted = await admin.rpc("superadmin_internal_user_create_for_worker_v1", {
    p_request_id: requestId,
    p_actor_internal_identity_id: actor,
    p_auth_user_id: authUserId,
    p_draft: draft,
  });
  const result = persisted.data as { ok?: unknown; data?: Json } | null;
  if (persisted.error || result?.ok !== true || !result.data) {
    await admin.auth.admin.deleteUser(authUserId);
    return reply(origin, 409, { error: "internal_user_not_created" });
  }
  return reply(origin, 200, { ok: true, data: result.data });
}

if (import.meta.main) {
  Deno.serve((request) => handleInternalUserCreate(request));
}
