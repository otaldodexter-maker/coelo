// Prova em producao do chat interno v2 (candidatos realm-interno 240000..240400)
// com a sessao sintetica qa-r03@coelo.me. Le credenciais SOMENTE do ambiente do
// processo (QA_EMAIL, QA_PASSWORD, COELO_SUPABASE_URL, COELO_SUPABASE_ANON_KEY);
// nunca imprime valores de credencial ou token. Dados criados sao sinteticos e
// removidos ao fim (revogacao das mensagens; o grupo criado fica registrado no
// relatorio para o coordenador remover com o usuario de teste).
//
// Uso (PowerShell do Owner ou do agente, sem echo das variaveis):
//   deno run --allow-env --allow-net packages/coelo_database/scripts/chat-internal-production-proof.ts [--institution <uuid>] [--members <uuid,uuid>]
// Saida: linhas "PASS|FAIL|SKIP <caso> <detalhe sem segredo>" e resumo.

const required = (name: string): string => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`variavel ${name} ausente no ambiente`);
  return value;
};
const url = required("COELO_SUPABASE_URL").replace(/\/$/, "");
const anon = required("COELO_SUPABASE_ANON_KEY");
const email = required("QA_EMAIL");
const password = required("QA_PASSWORD");

const args = Deno.args;
const argValue = (flag: string): string | undefined => {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : undefined;
};
const institutionArg = argValue("--institution");
const membersArg = argValue("--members");
// --read-only: so leituras e a negativa de anon; nao escreve em conversa alguma
// (util para reconferir producao sem interferir na rota real de outra frente).
const readOnly = args.includes("--read-only");

const results: string[] = [];
let failures = 0;
const report = (status: "PASS" | "FAIL" | "SKIP", name: string, detail = "") => {
  if (status === "FAIL") failures++;
  results.push(`${status} ${name} ${detail}`.trim());
  console.log(`${status} ${name} ${detail}`.trim());
};

// 1. Sessao por senha (AAL1). O token vive so em memoria.
const signIn = await fetch(`${url}/auth/v1/token?grant_type=password`, {
  method: "POST",
  headers: { apikey: anon, "content-type": "application/json" },
  body: JSON.stringify({ email, password }),
});
if (!signIn.ok) {
  report("FAIL", "auth.sign_in", `status ${signIn.status}`);
  console.log(`resumo: ${failures} falha(s)`);
  Deno.exit(1);
}
const session = await signIn.json();
const accessToken: string = session.access_token;
report("PASS", "auth.sign_in", `aal ${session.user?.aal ?? "n/d"}`);

// Envelope spec-039 das RPCs; `code`/`message` cobrem o erro do PostgREST (ex.: PGRST202).
type Envelope = {
  ok?: boolean;
  data?: Record<string, unknown> | null;
  error?: { code?: string; http_status?: number } | null;
  code?: string;
  message?: string;
};
const rpc = async (name: string, params: Record<string, unknown> = {}): Promise<{ status: number; body: Envelope }> => {
  const response = await fetch(`${url}/rest/v1/rpc/${name}`, {
    method: "POST",
    headers: {
      apikey: anon,
      authorization: `Bearer ${accessToken}`,
      "content-type": "application/json",
      prefer: "params=single-object",
    },
    body: JSON.stringify(params),
  });
  let body: unknown = null;
  try { body = await response.json(); } catch { body = null; }
  return { status: response.status, body: (body ?? {}) as Envelope };
};
const okData = (r: { status: number; body: Envelope }): Record<string, unknown> | null =>
  r.status === 200 && r.body?.ok === true && r.body.data ? r.body.data : null;
const errCode = (r: { status: number; body: Envelope }): string =>
  r.body?.error?.code ?? r.body?.code ?? `http ${r.status}`;

// 2. Leitura: unread e inbox (chat.internal.read).
const unread = await rpc("superadmin_chat_unread_total_v2");
if (okData(unread)) report("PASS", "chat.list.unread_total", `total_unread=${okData(unread)!.total_unread}`);
else report("FAIL", "chat.list.unread_total", errCode(unread));

const inbox = await rpc("superadmin_chat_inbox_v2", { p_limit: 30, p_search: null, p_unread_only: false, p_cursor_activity_at: null, p_cursor_conversation_id: null });
const inboxData = okData(inbox);
if (inboxData) report("PASS", "chat.list.inbox", `total=${inboxData.total} items=${(inboxData.items as unknown[]).length}`);
else report("FAIL", "chat.list.inbox", errCode(inbox));

// 3. Criar grupo (P8) quando instituicao e membros forem informados.
let conversationId: string | null = null;
const requestId = crypto.randomUUID();
if (readOnly) {
  report("SKIP", "chat.create-group", "--read-only");
} else if (institutionArg && membersArg) {
  const create = await rpc("superadmin_chat_create_group_v2", {
    p_request_id: requestId, p_institution_id: institutionArg, p_title: `QA R04 ${new Date().toISOString().slice(0, 16)}`,
    p_person_ids: membersArg.split(","), p_unit_id: null, p_group_id: null, p_activity_id: null,
  });
  const created = okData(create);
  if (created) { conversationId = String(created.conversation_id); report("PASS", "chat.create-group", `conversation_id=${conversationId} member_count=${created.member_count}`); }
  else report("FAIL", "chat.create-group", errCode(create));
  const replay = await rpc("superadmin_chat_create_group_v2", {
    p_request_id: requestId, p_institution_id: institutionArg, p_title: `QA R04 ${new Date().toISOString().slice(0, 16)}`,
    p_person_ids: membersArg.split(","), p_unit_id: null, p_group_id: null, p_activity_id: null,
  });
  const replayed = okData(replay);
  if (replayed && replayed.replayed === true && replayed.conversation_id === conversationId) report("PASS", "chat.create-group.replay");
  else report("FAIL", "chat.create-group.replay", errCode(replay));
} else if (inboxData && (inboxData.items as Record<string, unknown>[]).length > 0) {
  conversationId = String((inboxData.items as Record<string, unknown>[])[0].conversation_id);
  report("SKIP", "chat.create-group", "sem --institution/--members; usando a primeira conversa da inbox");
} else {
  report("SKIP", "chat.create-group", "sem --institution/--members e inbox vazia");
}

// 4. Enviar, ler thread com recibo, editar, fixar/bandeira, marcar lida, revogar.
if (readOnly && inboxData && (inboxData.items as Record<string, unknown>[]).length > 0) {
  const firstId = String((inboxData.items as Record<string, unknown>[])[0].conversation_id);
  const thread = await rpc("superadmin_chat_thread_v2", { p_conversation_id: firstId, p_limit: 10, p_cursor_created_at: null, p_cursor_message_id: null });
  if (okData(thread)) report("PASS", "chat.open.read-only", `total=${okData(thread)!.total}`); else report("FAIL", "chat.open.read-only", errCode(thread));
} else if (conversationId) {
  const sendId = crypto.randomUUID();
  const send = await rpc("superadmin_chat_send_message_v2", { p_conversation_id: conversationId, p_body_text: "Mensagem sintetica QA R04", p_request_id: sendId });
  const sent = okData(send);
  if (sent) report("PASS", "chat.send", `message_id=${sent.message_id}`); else report("FAIL", "chat.send", errCode(send));
  const sendAgain = await rpc("superadmin_chat_send_message_v2", { p_conversation_id: conversationId, p_body_text: "Mensagem sintetica QA R04", p_request_id: sendId });
  if (okData(sendAgain)?.replayed === true) report("PASS", "chat.send.replay"); else report("FAIL", "chat.send.replay", errCode(sendAgain));

  const thread = await rpc("superadmin_chat_thread_v2", { p_conversation_id: conversationId, p_limit: 50, p_cursor_created_at: null, p_cursor_message_id: null });
  const threadData = okData(thread);
  const first = threadData ? (threadData.items as Record<string, unknown>[])[0] : undefined;
  if (first && "receipt" in first && "can_manage" in first) report("PASS", "chat.open+chat.receipts", `total=${threadData!.total} can_manage=${first.can_manage}`);
  else report("FAIL", "chat.open+chat.receipts", errCode(thread));

  if (sent) {
    const edit = await rpc("superadmin_chat_edit_message_v2", { p_conversation_id: conversationId, p_message_id: sent.message_id, p_body_text: "Mensagem sintetica QA R04 (editada)", p_request_id: crypto.randomUUID() });
    if (okData(edit)?.edited_at) report("PASS", "chat.edit"); else report("FAIL", "chat.edit", errCode(edit));
  }
  const pin = await rpc("superadmin_chat_set_pinned_v2", { p_conversation_id: conversationId, p_pinned: true });
  if (okData(pin)?.pinned_at) report("PASS", "chat.list.pin"); else report("FAIL", "chat.list.pin", errCode(pin));
  const flag = await rpc("superadmin_chat_set_flag_v2", { p_conversation_id: conversationId, p_flag: "blue" });
  if (okData(flag)?.flag === "blue") report("PASS", "chat.list.flag"); else report("FAIL", "chat.list.flag", errCode(flag));
  const reload = await rpc("superadmin_chat_inbox_v2", { p_limit: 30, p_search: null, p_unread_only: false, p_cursor_activity_at: null, p_cursor_conversation_id: null });
  const reloaded = okData(reload);
  const top = reloaded ? (reloaded.items as Record<string, unknown>[])[0] : undefined;
  if (top && top.conversation_id === conversationId && top.pinned_at && top.flag === "blue") report("PASS", "chat.list.reload", "fixada primeiro com bandeira azul");
  else report("FAIL", "chat.list.reload", errCode(reload));
  const unpin = await rpc("superadmin_chat_set_pinned_v2", { p_conversation_id: conversationId, p_pinned: false });
  const unflag = await rpc("superadmin_chat_set_flag_v2", { p_conversation_id: conversationId, p_flag: "none" });
  if (okData(unpin) && okData(unflag)) report("PASS", "chat.list.cleanup-preference"); else report("FAIL", "chat.list.cleanup-preference");

  if (first) {
    const read = await rpc("superadmin_chat_mark_read_v2", { p_conversation_id: conversationId, p_through_message_id: first.message_id });
    if (okData(read)) report("PASS", "chat.receipts.mark_read", `updated_count=${okData(read)!.updated_count}`); else report("FAIL", "chat.receipts.mark_read", errCode(read));
  }
  if (sent) {
    const revoke = await rpc("superadmin_chat_revoke_message_v2", { p_conversation_id: conversationId, p_message_id: sent.message_id, p_request_id: crypto.randomUUID() });
    if (okData(revoke)?.revoked_at) report("PASS", "chat.revoke", "mensagem sintetica revogada (cleanup)"); else report("FAIL", "chat.revoke", errCode(revoke));
  }
  const members = await rpc("superadmin_chat_group_members_v2", { p_conversation_id: conversationId });
  if (okData(members)) report("PASS", "chat.create-group.members", `total=${okData(members)!.total}`); else report("FAIL", "chat.create-group.members", errCode(members));

  // Negativa: id inexistente nao enumera.
  const missing = await rpc("superadmin_chat_thread_v2", { p_conversation_id: "00000000-0000-4000-8000-000000000000", p_limit: 10, p_cursor_created_at: null, p_cursor_message_id: null });
  if (errCode(missing) === "CHAT_NOT_FOUND") report("PASS", "chat.open.not_found"); else report("FAIL", "chat.open.not_found", errCode(missing));
}

// 5. anon nao executa as RPCs.
const anonCall = await fetch(`${url}/rest/v1/rpc/superadmin_chat_unread_total_v2`, {
  method: "POST", headers: { apikey: anon, "content-type": "application/json" }, body: "{}",
});
if (anonCall.status === 401 || anonCall.status === 403 || anonCall.status === 404) report("PASS", "rls.anon_denied", `http ${anonCall.status}`);
else report("FAIL", "rls.anon_denied", `http ${anonCall.status}`);

await fetch(`${url}/auth/v1/logout`, { method: "POST", headers: { apikey: anon, authorization: `Bearer ${accessToken}` } });
console.log(`resumo: ${results.filter((r) => r.startsWith("PASS")).length} PASS, ${failures} FAIL, ${results.filter((r) => r.startsWith("SKIP")).length} SKIP`);
if (conversationId && institutionArg) console.log(`cleanup pendente: conversa de grupo sintetica ${conversationId} (remover com o usuario de teste ao fim da rodada)`);
Deno.exit(failures > 0 ? 1 : 0);
