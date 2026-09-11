// Prova do contrato produtivo com a sessao qa-r03 (Auth por senha + RPCs via PostgREST).
// Nunca imprime credenciais, tokens ou e-mail. Dados sinteticos com prefixo [R04-QA] e limpeza no fim.
const fs = require('fs');
const env = (p) => Object.fromEntries(fs.readFileSync(p, 'utf8').split(/\r?\n/).filter((l) => l.includes('=') && !l.startsWith('#')).map((l) => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^"|"$/g, '')]; }));
const app = env('C:/Users/adrie/Documents/Coelo/apps/superadmin/.env.local');
const qa = env('C:/Users/adrie/Documents/Coelo-backups/qa-r03.env');
const URL_ = app.COELO_SUPABASE_URL, KEY = app.COELO_SUPABASE_PUBLISHABLE_KEY;
if (!URL_ || !KEY || !qa.QA_EMAIL || !qa.QA_PASSWORD) { console.error('env incompleto'); process.exit(1); }
const log = (...a) => console.log(...a);
const uuid = () => require('crypto').randomUUID();
let token = null;
async function login() {
  const r = await fetch(`${URL_}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: qa.QA_EMAIL, password: qa.QA_PASSWORD }) });
  const j = await r.json();
  if (!r.ok) { log('login FALHOU', r.status, j.error_code || j.msg || ''); process.exit(1); }
  token = j.access_token; log('login OK (aal=' + (JSON.parse(Buffer.from(token.split('.')[1], 'base64').toString()).aal) + ')');
}
async function rpc(name, params, { anon = false } = {}) {
  const r = await fetch(`${URL_}/rest/v1/rpc/${name}`, { method: 'POST', headers: { apikey: KEY, Authorization: `Bearer ${anon ? KEY : token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(params) });
  const text = await r.text(); let j; try { j = JSON.parse(text); } catch { j = text; }
  return { status: r.status, body: j };
}
const ok = (r) => r.status === 200 && r.body && r.body.ok === true;
const code = (r) => (r.body && r.body.error && r.body.error.code) || (r.body && r.body.code) || (r.body && r.body.message) || r.status;
const results = [];
const check = (id, label, pass, detail) => { results.push({ id, label, pass, detail }); log(`${pass ? 'PASS' : 'FAIL'} ${id} ${label}${detail ? ' — ' + detail : ''}`); };
(async () => {
  await login();
  const tag = '[R04-QA ' + new Date().toISOString().slice(11, 19) + ']';
  // ---------- AVISOS ----------
  let r = await rpc('superadmin_notice_directory_v2', { p_types: null, p_search: null, p_statuses: null, p_priorities: null, p_cursor_occurred_at: null, p_cursor_id: null, p_limit: 24 });
  check('notices.list', 'diretorio abre em producao', ok(r), ok(r) ? `${r.body.data.items.length} itens` : code(r));
  const noticePayload = { type: 'popup', title: `${tag} Aviso de teste`, body: 'Aviso sintetico da Rodada 4.', priority: 'routine', audience: { rules: [{ dimension: 'platform', select_all: true, target_ids: [] }] }, audience_label: 'Toda a plataforma', behavior: 'dismissible', target_device: 'all', content_format: 'text_background', popup_size: 'standard', has_outer_inset: true, button_label: 'Entendi', recurrence: 'one_time', weekly_days: [], image_orientation: 'vertical', starts_at: new Date(Date.now() + 86400000).toISOString(), ends_at: new Date(Date.now() + 2 * 86400000).toISOString() };
  const nReq = uuid();
  r = await rpc('superadmin_notice_save_draft_v2', { p_request_id: nReq, p_notice_id: null, p_expected_version: null, p_payload: noticePayload });
  check('notices.create', 'rascunho persiste', ok(r) && r.body.data.status === 'draft', ok(r) ? 'id ' + r.body.data.id : JSON.stringify(r.body).slice(0, 200));
  const noticeId = ok(r) ? r.body.data.id : null;
  let ver = ok(r) ? r.body.data.management_version : null;
  if (noticeId) {
    const r2 = await rpc('superadmin_notice_save_draft_v2', { p_request_id: nReq, p_notice_id: null, p_expected_version: null, p_payload: noticePayload });
    check('notices.create', 'replay idempotente', ok(r2) && r2.body.data.id === noticeId);
    r = await rpc('superadmin_notice_save_draft_v2', { p_request_id: uuid(), p_notice_id: noticeId, p_expected_version: ver, p_payload: { ...noticePayload, title: `${tag} Aviso editado` } });
    check('notices.edit', 'edicao persiste com versao otimista', ok(r) && r.body.data.title.endsWith('editado'), ok(r) ? 'v' + r.body.data.management_version : code(r));
    ver = ok(r) ? r.body.data.management_version : ver;
    r = await rpc('superadmin_notice_detail_v2', { p_notice_id: noticeId });
    check('notices.edit', 'reload (detail) mantem a edicao', ok(r) && r.body.data.title.endsWith('editado'));
    r = await rpc('superadmin_notice_publish_v2', { p_request_id: uuid(), p_notice_id: noticeId, p_expected_version: ver });
    check('notices.schedule', 'publicar com inicio futuro agenda', ok(r) && r.body.data.status === 'scheduled', ok(r) ? r.body.data.status : code(r));
    ver = ok(r) ? r.body.data.management_version : ver;
    r = await rpc('superadmin_notice_directory_v2', { p_types: null, p_search: tag, p_statuses: ['scheduled'], p_priorities: null, p_cursor_occurred_at: null, p_cursor_id: null, p_limit: 24 });
    check('notices.list', 'reload (diretorio) ve o agendado', ok(r) && r.body.data.items.some((i) => i.id === noticeId));
    r = await rpc('superadmin_notice_change_status_v2', { p_request_id: uuid(), p_notice_id: noticeId, p_expected_version: ver, p_status: 'inactive', p_reason: 'Teste da Rodada 4 encerrado' });
    check('notices.archive', 'inativar com motivo persiste', ok(r) && r.body.data.status === 'inactive', ok(r) ? r.body.data.status : code(r));
    r = await rpc('superadmin_notice_detail_v2', { p_notice_id: noticeId });
    check('notices.archive', 'reload mantem inactive', ok(r) && r.body.data.status === 'inactive');
    // publish imediato: segundo aviso com inicio passado
    const r3 = await rpc('superadmin_notice_save_draft_v2', { p_request_id: uuid(), p_notice_id: null, p_expected_version: null, p_payload: { ...noticePayload, title: `${tag} Aviso imediato`, starts_at: new Date(Date.now() - 60000).toISOString() } });
    if (ok(r3)) {
      const r4 = await rpc('superadmin_notice_publish_v2', { p_request_id: uuid(), p_notice_id: r3.body.data.id, p_expected_version: r3.body.data.management_version });
      check('notices.publish', 'publicar com inicio passado fica active', ok(r4) && r4.body.data.status === 'active', ok(r4) ? r4.body.data.status : code(r4));
      const r5 = await rpc('superadmin_notice_change_status_v2', { p_request_id: uuid(), p_notice_id: r3.body.data.id, p_expected_version: ok(r4) ? r4.body.data.management_version : r3.body.data.management_version, p_status: 'inactive', p_reason: 'Limpeza do teste' });
      check('notices.archive', 'limpeza: aviso imediato inativado', ok(r5));
    }
  }
  r = await rpc('superadmin_notice_directory_v2', { p_types: null, p_search: null, p_statuses: null, p_priorities: null, p_cursor_occurred_at: null, p_cursor_id: null, p_limit: 24 }, { anon: true });
  check('notices.list', 'anon nao le (negativa)', r.status !== 200 || (r.body && r.body.ok === false), 'status ' + r.status);
  // ---------- CIRCULARES ----------
  r = await rpc('superadmin_circular_directory_v2', { p_institution_id: null, p_search: null, p_statuses: null, p_cursor_updated_at: null, p_cursor_id: null, p_limit: 25 });
  check('circulars.list', 'diretorio abre em producao', ok(r), ok(r) ? `${r.body.data.items.length} itens` : code(r));
  // instituicao para a circular: primeira das contexts de agenda ou institution list
  const ctx = await rpc('superadmin_agenda_contexts', {});
  const inst = ctx.body && ctx.body.contexts ? (ctx.body.contexts.find((c) => c.level === 'institution') || {}) : {};
  const institutionId = inst.institutionId || inst.institution_id || inst.id;
  check('agenda.permissions', 'contexts lista instituicoes para o operador interno', !!institutionId, institutionId ? 'inst ' + institutionId : JSON.stringify(ctx.body).slice(0, 160));
  let circularId = null, cVer = 0;
  if (institutionId) {
    const cReq = uuid();
    const draft = { id: '', title: `${tag} Circular de teste`, version: 0, status: 'draft', response_policy: 'per_person', audiences: ['guardians_only'], blocks: [{ id: uuid(), kind: 'text', text: 'Bloco sintetico.' }] };
    r = await rpc('superadmin_circular_save_draft_v2', { p_request_id: cReq, p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_activity_id: null, p_payload: draft });
    check('circulars.create', 'rascunho persiste', ok(r) && r.body.data.status === 'draft', ok(r) ? 'id ' + r.body.data.id : JSON.stringify(r.body).slice(0, 200));
    if (ok(r)) { circularId = r.body.data.id; cVer = r.body.data.version; }
  }
  if (circularId) {
    r = await rpc('superadmin_circular_detail_v2', { p_circular_id: circularId });
    check('circulars.detail', 'detalhe abre (reload)', ok(r), ok(r) ? 'status ' + (r.body.data.status || r.body.data.circular?.status) : code(r));
    r = await rpc('superadmin_circular_save_draft_v2', { p_request_id: uuid(), p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_activity_id: null, p_payload: { id: circularId, title: `${tag} Circular editada`, version: cVer, status: 'draft', response_policy: 'per_person', audiences: ['guardians_only'], blocks: [{ id: uuid(), kind: 'text', text: 'Bloco editado.' }] } });
    check('circulars.edit', 'edicao persiste com versao otimista', ok(r), ok(r) ? 'v' + r.body.data.version : code(r));
    if (ok(r)) cVer = r.body.data.version;
    const when = new Date(Date.now() + 3600000).toISOString();
    r = await rpc('superadmin_circular_publish_v2', { p_request_id: uuid(), p_circular_id: circularId, p_expected_version: cVer, p_publish_at: when });
    check('circulars.schedule', 'agendar (publish_at futuro) persiste', ok(r) && r.body.data.status === 'scheduled', ok(r) ? r.body.data.status : JSON.stringify(r.body).slice(0, 160));
    if (ok(r)) cVer = r.body.data.version;
    r = await rpc('superadmin_circular_directory_v2', { p_institution_id: institutionId, p_search: tag, p_statuses: ['scheduled'], p_cursor_updated_at: null, p_cursor_id: null, p_limit: 25 });
    check('circulars.filter', 'diretorio filtra por status e busca (reload)', ok(r) && r.body.data.items.some((i) => i.id === circularId), ok(r) ? r.body.data.items.length + ' itens' : code(r));
    r = await rpc('superadmin_circular_close_v2', { p_request_id: uuid(), p_circular_id: circularId, p_expected_version: cVer });
    check('circulars.close', 'encerrar respostas persiste', ok(r) && r.body.data.status === 'closed', ok(r) ? r.body.data.status : JSON.stringify(r.body).slice(0, 160));
    if (ok(r)) cVer = r.body.data.version;
    r = await rpc('superadmin_circular_delete_v2', { p_request_id: uuid(), p_circular_id: circularId, p_expected_version: cVer });
    check('circulars.delete', 'excluir circular encerrada (limpeza)', ok(r) && r.body.data.deleted === true, ok(r) ? 'status ' + r.body.data.status : JSON.stringify(r.body).slice(0, 160));
    // segundo rascunho: excluir em rascunho + publicar imediato
    const r6 = await rpc('superadmin_circular_save_draft_v2', { p_request_id: uuid(), p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_activity_id: null, p_payload: { id: '', title: `${tag} Rascunho a excluir`, version: 0, status: 'draft', response_policy: 'per_person', audiences: ['guardians_only'], blocks: [{ id: uuid(), kind: 'text', text: 'x' }] } });
    if (ok(r6)) {
      const r7 = await rpc('superadmin_circular_delete_v2', { p_request_id: uuid(), p_circular_id: r6.body.data.id, p_expected_version: r6.body.data.version });
      check('circulars.delete', 'excluir rascunho persiste (deleted=true)', ok(r7) && r7.body.data.deleted === true, ok(r7) ? 'status ' + r7.body.data.status : JSON.stringify(r7.body).slice(0, 160));
      const r8 = await rpc('superadmin_circular_detail_v2', { p_circular_id: r6.body.data.id });
      check('circulars.delete', 'reload: rascunho excluido nao abre', !ok(r8), code(r8));
    }
    const r9 = await rpc('superadmin_circular_save_draft_v2', { p_request_id: uuid(), p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_activity_id: null, p_payload: { id: '', title: `${tag} Publicada imediata`, version: 0, status: 'draft', response_policy: 'per_person', audiences: ['guardians_only'], blocks: [{ id: uuid(), kind: 'text', text: 'x' }] } });
    if (ok(r9)) {
      const r10 = await rpc('superadmin_circular_publish_v2', { p_request_id: uuid(), p_circular_id: r9.body.data.id, p_expected_version: r9.body.data.version, p_publish_at: null });
      check('circulars.publish', 'publicar imediato persiste', ok(r10) && r10.body.data.status === 'published', ok(r10) ? r10.body.data.status : JSON.stringify(r10.body).slice(0, 160));
      let v = ok(r10) ? r10.body.data.version : r9.body.data.version;
      const r11 = await rpc('superadmin_circular_close_v2', { p_request_id: uuid(), p_circular_id: r9.body.data.id, p_expected_version: v });
      v = ok(r11) ? r11.body.data.version : v;
      const r12 = await rpc('superadmin_circular_delete_v2', { p_request_id: uuid(), p_circular_id: r9.body.data.id, p_expected_version: v });
      check('circulars.delete', 'limpeza da publicada', ok(r12));
    }
  }
  r = await rpc('superadmin_circular_directory_v2', { p_institution_id: null, p_search: null, p_statuses: null, p_cursor_updated_at: null, p_cursor_id: null, p_limit: 25 }, { anon: true });
  check('circulars.list', 'anon nao le (negativa)', r.status !== 200 || (r.body && r.body.ok === false), 'status ' + r.status);
  // ---------- AGENDA ----------
  r = await rpc('superadmin_agenda_list', { p_from: new Date(Date.now() - 30 * 86400000).toISOString(), p_to: new Date(Date.now() + 370 * 86400000).toISOString(), p_institution_id: null, p_search: '', p_limit: 100, p_offset: 0 });
  check('agenda.view', 'lista abre em producao', r.status === 200 && r.body && Array.isArray(r.body.items), r.status === 200 ? `${r.body.items.length} itens` : JSON.stringify(r.body).slice(0, 160));
  let eventId = null, rev = null;
  if (institutionId) {
    const aReq = uuid();
    const payload = { institutionId, contextKind: 'institution', contextId: institutionId, title: `${tag} Reuniao de teste`, type: 'event', startsAt: new Date(Date.now() + 86400000).toISOString(), endsAt: new Date(Date.now() + 86400000 + 7200000).toISOString(), status: 'draft' };
    r = await rpc('superadmin_agenda_save', { p_request_id: aReq, p_event_id: null, p_expected_revision: null, p_payload: payload, p_reason: null, p_override_reservation: false });
    check('agenda.create', 'evento persiste', r.status === 200 && r.body && r.body.id, r.status === 200 ? 'id ' + r.body.id : JSON.stringify(r.body).slice(0, 200));
    if (r.status === 200 && r.body && r.body.id) { eventId = r.body.id; rev = r.body.revision; }
  }
  if (eventId) {
    r = await rpc('superadmin_agenda_get', { p_event_id: eventId });
    check('agenda.detail', 'detalhe abre (reload)', r.status === 200 && r.body.id === eventId, r.status === 200 ? 'rev ' + r.body.revision : code(r));
    r = await rpc('superadmin_agenda_save', { p_request_id: uuid(), p_event_id: eventId, p_expected_revision: rev, p_payload: { institutionId, contextKind: 'institution', contextId: institutionId, title: `${tag} Reuniao editada`, type: 'event', startsAt: new Date(Date.now() + 86400000).toISOString(), endsAt: new Date(Date.now() + 86400000 + 7200000).toISOString(), status: 'published' }, p_reason: null, p_override_reservation: false });
    check('agenda.edit', 'edicao + publicacao persistem', r.status === 200 && r.body.status === 'published', r.status === 200 ? 'rev ' + r.body.revision : JSON.stringify(r.body).slice(0, 200));
    if (r.status === 200) rev = r.body.revision;
    r = await rpc('superadmin_agenda_get', { p_event_id: eventId });
    check('agenda.edit', 'reload mantem titulo e status', r.status === 200 && r.body.title.endsWith('editada') && r.body.status === 'published');
    r = await rpc('superadmin_agenda_command', { p_request_id: uuid(), p_event_id: eventId, p_expected_revision: rev, p_action: 'cancel', p_reason: 'Limpeza do teste da Rodada 4' });
    check('agenda.edit', 'cancelar (limpeza) persiste', r.status === 200 && r.body.status === 'canceled', r.status === 200 ? r.body.status : JSON.stringify(r.body).slice(0, 200));
  }
  r = await rpc('superadmin_agenda_list', { p_from: new Date().toISOString(), p_to: new Date(Date.now() + 86400000).toISOString(), p_institution_id: null, p_search: '', p_limit: 10, p_offset: 0 }, { anon: true });
  check('agenda.view', 'anon nao executa (negativa)', r.status !== 200, 'status ' + r.status);
  const pass = results.filter((x) => x.pass).length;
  log(`\nRESUMO: ${pass}/${results.length} PASS`);
  fs.writeFileSync(process.argv[2] || 'prova-producao-resultado.json', JSON.stringify({ at: new Date().toISOString(), results }, null, 2));
})().catch((e) => { log('ERRO', e.message); process.exit(1); });
