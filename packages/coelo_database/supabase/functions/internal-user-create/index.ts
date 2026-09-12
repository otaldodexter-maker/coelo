// internal-user-create (R06, dona: acessos-pessoas; deploy pelo coordenador).
//
// Cria um usuario interno do Superadmin em tres tempos (pacote 20260911170800):
//   1. com o token do operador: superadmin_internal_user_create_authorize_v1
//      (platform.member.update em escopo de plataforma; valida o rascunho);
//   2. com service_role: auth.admin.createUser e generateLink(recovery).
//      A senha aleatoria nunca sai do servidor; o link so volta na resposta
//      no-store ao operador autorizado para entrega por canal seguro (P51=B).
//   3. com service_role: superadmin_internal_user_create_for_worker_v1
//      (identidade + perfil + vinculo auth + membership); se falhar, o auth
//      user recem-criado e apagado.
// Nunca devolve senha, token ou dado sensivel alem da projecao do usuario.
import { createClient } from "@supabase/supabase-js";

type Json = Record<string, unknown>;

type Environment = Pick<typeof Deno.env, "get">;
type ClientFactory = typeof createClient;

function allowedOrigins(environment: Environment = Deno.env) {
  return new Set(
    (environment.get("COELO_ALLOWED_ORIGINS") ?? "")
      .split(",")
      .map((value) => value.trim())
      .filter(Boolean),
  );
}

function reply(origin: string | null, status: number, body: Json, environment: Environment = Deno.env) {
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    "Cache-Control": "no-store",
    "Vary": "Origin",
    "Access-Control-Allow-Headers":
      "authorization, apikey, content-type, x-client-info",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
  if (origin !== null && allowedOrigins(environment).has(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return new Response(status === 204 ? null : JSON.stringify(body), { status, headers });
}

function serviceKey(environment: Environment = Deno.env): string {
  const configured = environment.get("SUPABASE_SECRET_KEYS") ?? "";
  if (configured.startsWith("{")) {
    try {
      return (JSON.parse(configured) as Record<string, string>).default ?? "";
    } catch {
      return "";
    }
  }
  return configured.split(",").map((value) => value.trim()).find(Boolean) ??
    environment.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
}

function randomPassword(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return btoa(String.fromCharCode(...bytes)).replaceAll("=", "");
}

/// Link do Auth Admin pode apontar ao projeto Supabase, mas precisa ser HTTPS
/// e nao pode carregar credenciais no authority. Nunca registrar este valor.
export function securePasswordSetupLink(value: unknown, expectedOrigin: string): string | null {
  if (typeof value !== "string") return null;
  try {
    const url = new URL(value);
    const origin = new URL(expectedOrigin).origin;
    return url.protocol === "https:" && url.origin === origin && !url.username && !url.password &&
        url.pathname === "/auth/v1/verify"
      ? url.toString()
      : null;
  } catch {
    return null;
  }
}

/// Destino canônico previamente permitido no Auth. A origem CORS do operador
/// controla só a chamada à função; nunca passa a controlar onde um token de
/// recuperação vai parar.
export const passwordSetupRedirect = "https://superadmin.coelo.me/reset-password";

async function rollbackAuthUser(admin: any, authUserId: string): Promise<boolean> {
  try {
    const deleted = await admin.auth.admin.deleteUser(authUserId);
    return !deleted.error;
  } catch {
    return false;
  }
}

export function createInternalUserCreateHandler({
  environment = Deno.env,
  createSupabaseClient = createClient,
}: {
  environment?: Environment;
  createSupabaseClient?: ClientFactory;
} = {}) {
  return async function handleInternalUserCreate(request: Request): Promise<Response> {
  const origin = request.headers.get("origin");
  if (request.method === "OPTIONS") return reply(origin, 204, {}, environment);
  if (origin !== null && !allowedOrigins(environment).has(origin)) {
    return reply(origin, 403, { error: "request_denied" }, environment);
  }
  if (request.method !== "POST") return reply(origin, 405, { error: "method_not_allowed" }, environment);

  const authorization = request.headers.get("authorization") ?? "";
  const url = environment.get("SUPABASE_URL") ?? "";
  const anon = environment.get("SUPABASE_ANON_KEY") ?? "";
  const service = serviceKey(environment);
  if (!/^Bearer \S+$/.test(authorization) || !url || !anon || !service) {
    return reply(origin, 401, { error: "unauthorized" }, environment);
  }

  let body: { request_id?: unknown; draft?: unknown };
  try {
    body = await request.json();
  } catch {
    return reply(origin, 400, { error: "invalid_request" }, environment);
  }
  const requestId = typeof body.request_id === "string" ? body.request_id : "";
  const draft = body.draft && typeof body.draft === "object" ? body.draft as Json : null;
  if (!/^[0-9a-f-]{36}$/i.test(requestId) || !draft) {
    return reply(origin, 400, { error: "invalid_request" }, environment);
  }

  // 1. autorizacao com o token do operador (o servidor decide tudo).
  const user = createSupabaseClient(url, anon, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false },
  });
  const authorized = await user.rpc("superadmin_internal_user_create_authorize_v1", { p_draft: draft });
  const envelope = authorized.data as { ok?: unknown; data?: Json; error?: Json } | null;
  if (authorized.error || envelope?.ok !== true || !envelope.data) {
    return reply(origin, 403, { error: "not_authorized", detail: envelope?.error ?? null }, environment);
  }
  const actor = envelope.data.actor_internal_identity_id as string;
  const email = envelope.data.professional_email as string;

  // 2. auth user pelo Admin API (senha aleatoria, nunca devolvida).
  const admin = createSupabaseClient(url, service, { auth: { persistSession: false } });
  const created = await admin.auth.admin.createUser({
    email,
    password: randomPassword(),
    email_confirm: true,
    app_metadata: { coelo_realm: "superadmin_internal" },
  });
  if (created.error || !created.data.user) {
    return reply(origin, 409, { error: "auth_user_unavailable" }, environment);
  }
  const authUserId = created.data.user.id;

  let generated;
  try {
    generated = await admin.auth.admin.generateLink({
      type: "recovery",
      email,
      options: { redirectTo: passwordSetupRedirect },
    });
  } catch {
    await rollbackAuthUser(admin, authUserId);
    return reply(origin, 409, { error: "password_setup_link_unavailable" }, environment);
  }
  const passwordSetupLink = securePasswordSetupLink(generated.data?.properties?.action_link, url);
  if (generated.error || passwordSetupLink === null) {
    await rollbackAuthUser(admin, authUserId);
    return reply(origin, 409, { error: "password_setup_link_unavailable" }, environment);
  }

  // 3. identidade interna numa transacao; falha desfaz o auth user.
  const persisted = await admin.rpc("superadmin_internal_user_create_for_worker_v1", {
    p_request_id: requestId,
    p_actor_internal_identity_id: actor,
    p_auth_user_id: authUserId,
    p_draft: draft,
  });
  const result = persisted.data as { ok?: unknown; data?: Json } | null;
  if (persisted.error || result?.ok !== true || !result.data) {
    await rollbackAuthUser(admin, authUserId);
    return reply(origin, 409, { error: "internal_user_not_created" }, environment);
  }
  return reply(origin, 200, { ok: true, data: { ...result.data, password_setup_link: passwordSetupLink } }, environment);
  };
}

export const handleInternalUserCreate = createInternalUserCreateHandler();

if (import.meta.main) {
  Deno.serve((request) => handleInternalUserCreate(request));
}
