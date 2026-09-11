// Prova R05 do contrato produtivo com a sessao qa-r03 (Auth por senha, RPCs via PostgREST e
// Edge Function circular-media em R2). Nunca imprime credenciais, tokens ou e-mail.
// Dados sinteticos com prefixo [R05-QA] e limpeza no fim. Cobre: circulars.attach,
// circulars.respond, circulars.edit/schedule (reforco), agenda.request, agenda.location.
const fs = require('fs');
const crypto = require('crypto');
const env = (p) => Object.fromEntries(fs.readFileSync(p, 'utf8').split(/\r?\n/).filter((l) => l.includes('=') && !l.startsWith('#')).map((l) => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^"|"$/g, '')]; }));
const app = env('C:/Users/adrie/Documents/Coelo/apps/superadmin/.env.local');
const qa = env('C:/Users/adrie/Documents/Coelo-backups/qa-r03.env');
const URL_ = app.COELO_SUPABASE_URL, KEY = app.COELO_SUPABASE_PUBLISHABLE_KEY;
if (!URL_ || !KEY || !qa.QA_EMAIL || !qa.QA_PASSWORD) { console.error('env incompleto'); process.exit(1); }
const log = (...a) => console.log(...a);
const uuid = () => crypto.randomUUID();
let token = null;
async function login() {
  const r = await fetch(`${URL_}/auth/v1/token?grant_type=password`, { method: 'POST', headers: { apikey: KEY, 'Content-Type': 'application/json' }, body: JSON.stringify({ email: qa.QA_EMAIL, password: qa.QA_PASSWORD }) });
  const j = await r.json();
  if (!r.ok) { log('login FALHOU', r.status, j.error_code || j.msg || ''); process.exit(1); }
  token = j.access_token; log('login OK');
}
async function rpc(name, params, { anon = false } = {}) {
  const r = await fetch(`${URL_}/rest/v1/rpc/${name}`, { method: 'POST', headers: { apikey: KEY, Authorization: `Bearer ${anon ? KEY : token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(params) });
  const text = await r.text(); let j; try { j = JSON.parse(text); } catch { j = text; }
  return { status: r.status, body: j };
}
async function fn(name, body, { anon = false } = {}) {
  const r = await fetch(`${URL_}/functions/v1/${name}`, { method: 'POST', headers: { apikey: KEY, Authorization: `Bearer ${anon ? KEY : token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const text = await r.text(); let j; try { j = JSON.parse(text); } catch { j = text; }
  return { status: r.status, body: j };
}
const ok = (r) => r.status === 200 && r.body && r.body.ok === true;
const code = (r) => (r.body && r.body.error && (r.body.error.code || r.body.error)) || (r.body && r.body.code) || (r.body && r.body.message) || r.status;
const short = (r) => JSON.stringify(r.body).slice(0, 200);
const results = [];
const check = (id, label, pass, detail) => { results.push({ id, label, pass, detail }); log(`${pass ? 'PASS' : 'FAIL'} ${id} ${label}${detail ? ' — ' + detail : ''}`); };
// PNG 1x1 valido (assinatura real; a funcao valida bytes e MIME).
const PNG = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==', 'base64');
(async () => {
  await login();
  const tag = '[R05-QA ' + new Date().toISOString().slice(11, 19) + ']';
  const ctx = await rpc('superadmin_agenda_contexts', {});
  const contexts = (ctx.body && ctx.body.contexts) || [];
  const institutions = contexts.filter((c) => c.level === 'institution');
  const units = contexts.filter((c) => c.level === 'unit');
  // Preferir a instituicao sintetica qa-r04-escola quando existir.
  const inst = institutions.find((c) => /qa-r04-escola/i.test(c.name || '')) || institutions[0] || {};
  const institutionId = inst.institutionId || inst.institution_id || inst.id;
  check('agenda.permissions', 'contexts do operador interno listam instituicoes e unidades', !!institutionId, `${institutions.length} instituicoes, ${units.length} unidades; usando ${inst.name || institutionId}`);
  const unit = units.find((u) => (u.institutionId || u.institution_id) === institutionId);
  const unitId = unit && unit.id;

  // ---------- CIRCULARS: edit/schedule pela RPC + attach (R2) + respond ----------
  let circularId = null, cVer = 0, assetId = null;
  if (institutionId) {
    const qId = uuid(), optA = uuid(), optB = uuid();
    const question = { id: qId, kind: 'question', question: { id: qId, prompt: 'Vai participar?', kind: 'single_choice', required: true, options: [{ id: optA, label: 'Sim' }, { id: optB, label: 'Nao' }] } };
    const draft = { id: '', title: `${tag} Circular com anexo`, version: 0, status: 'draft', response_policy: 'per_person', audiences: ['families', 'school_staff'], blocks: [{ id: uuid(), kind: 'text', text: 'Bloco sintetico.' }, question] };
    let r = await rpc('superadmin_circular_save_draft_v2', { p_request_id: uuid(), p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_activity_id: null, p_payload: draft });
    check('circulars.create', 'rascunho com pergunta persiste', ok(r) && r.body.data.status === 'draft', ok(r) ? 'id ' + r.body.data.id : short(r));
    if (ok(r)) { circularId = r.body.data.id; cVer = r.body.data.version; }
  }
  if (circularId) {
    // attach: prepare -> PUT R2 -> finalize -> read -> bloco de midia salvo -> reload
    const reqId = uuid();
    let p = await fn('circular-media', { action: 'prepare', request_id: reqId, institution_id: institutionId, circular_id: circularId, name: 'pixel.png', mime_type: 'image/png', size_bytes: PNG.length, display_order: 0 });
    check('circulars.attach', 'prepare autoriza upload (R2 presign)', p.status === 200 && p.body.upload_url && p.body.asset_id, p.status === 200 ? `provider ${p.body.storage_provider || 'r2?'}; expira ${p.body.expires_at}` : short(p));
    if (p.status === 200 && p.body.upload_url) {
      assetId = p.body.asset_id;
      const host = new URL(p.body.upload_url).host;
      const put = await fetch(p.body.upload_url, { method: 'PUT', headers: { ...(p.body.required_headers || {}), 'content-type': 'image/png' }, body: PNG });
      check('circulars.attach', 'PUT do arquivo no R2 aceito', put.status >= 200 && put.status < 300, `status ${put.status} em ${host}`);
      const f = await fn('circular-media', { action: 'finalize', request_id: reqId, finalize_request_id: uuid(), institution_id: institutionId, circular_id: circularId, asset_id: assetId, name: 'pixel.png', mime_type: 'image/png', size_bytes: PNG.length, display_order: 0, checksum_sha256: null });
      check('circulars.attach', 'finalize valida bytes/assinatura e marca ready', f.status === 200 && (f.body.status === 'ready' || f.body.asset_id), short(f));
      const rd = await fn('circular-media', { action: 'read', asset_id: assetId });
      check('circulars.attach', 'read devolve ticket de leitura autorizado', rd.status === 200 && (rd.body.url || rd.body.signed_url || rd.body.read_url), rd.status === 200 ? Object.keys(rd.body).join(',') : short(rd));
      const readUrl = rd.body && (rd.body.url || rd.body.signed_url || rd.body.read_url);
      if (readUrl) {
        const got = await fetch(readUrl);
        const bytes = Buffer.from(await got.arrayBuffer());
        check('circulars.attach', 'bytes lidos do R2 conferem com o enviado', got.status === 200 && bytes.equals(PNG), `status ${got.status}, ${bytes.length} bytes`);
      }
      const anonRead = await fn('circular-media', { action: 'read', asset_id: assetId }, { anon: true });
      check('circulars.attach', 'anon nao le o anexo (negativa)', anonRead.status === 401 || anonRead.status === 403, 'status ' + anonRead.status);
      // salvar o bloco de midia no rascunho (o que o coordinator faz depois de finalize)
      const r = await rpc('superadmin_circular_save_draft_v2', { p_request_id: uuid(), p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_activity_id: null, p_payload: { id: circularId, title: `${tag} Circular com anexo`, version: cVer, status: 'draft', response_policy: 'per_person', audiences: ['families', 'school_staff'], blocks: [{ id: uuid(), kind: 'text', text: 'Bloco editado com anexo.' }, { id: uuid(), kind: 'media', asset_ids: [assetId] }] } });
      check('circulars.edit', 'edicao do rascunho com bloco de midia persiste', ok(r), ok(r) ? 'v' + r.body.data.version : short(r));
      if (ok(r)) cVer = r.body.data.version;
      const d = await rpc('superadmin_circular_detail_v2', { p_circular_id: circularId });
      const blocks = ok(d) ? JSON.stringify(d.body.data) : '';
      check('circulars.attach', 'reload (detail) mantem o asset no bloco de midia', ok(d) && blocks.includes(assetId), ok(d) ? 'asset presente' : short(d));
    }
    // schedule -> reload -> reagendar (edit) -> publish imediato para responder
    const when = new Date(Date.now() + 3600000).toISOString();
    let r = await rpc('superadmin_circular_publish_v2', { p_request_id: uuid(), p_circular_id: circularId, p_expected_version: cVer, p_publish_at: when });
    check('circulars.schedule', 'agendar (publish_at futuro) persiste', ok(r) && r.body.data.status === 'scheduled', ok(r) ? r.body.data.status : short(r));
    if (ok(r)) cVer = r.body.data.version;
    let d = await rpc('superadmin_circular_detail_v2', { p_circular_id: circularId });
    check('circulars.schedule', 'reload mantem scheduled com publish_at', ok(d) && JSON.stringify(d.body.data).includes('scheduled'), ok(d) ? 'ok' : short(d));
    // publicar imediato (republicar a agendada)
    r = await rpc('superadmin_circular_publish_v2', { p_request_id: uuid(), p_circular_id: circularId, p_expected_version: cVer, p_publish_at: null });
    check('circulars.publish', 'publicar imediato a agendada persiste', ok(r) && r.body.data.status === 'published', ok(r) ? r.body.data.status : short(r));
    if (ok(r)) cVer = r.body.data.version;
    d = await rpc('superadmin_circular_detail_v2', { p_circular_id: circularId });
    const detail = ok(d) ? d.body.data : {};
    const revisionId = detail.revision_id || (detail.circular && detail.circular.revision_id) || (detail.revision && detail.revision.id);
    const qs = JSON.stringify(detail);
    check('circulars.respond', 'detalhe publicado expoe revision_id', !!revisionId, revisionId ? 'rev ' + revisionId : Object.keys(detail).join(','));
    if (revisionId) {
      // ids da pergunta/opcao na revisao publicada (servidor pode regravar ids)
      let questionId = null, optionId = null;
      try { const m = qs.match(/"question_id":"([0-9a-f-]{36})"/) || qs.match(/"questions":\[\{"id":"([0-9a-f-]{36})"/); questionId = m && m[1]; const o = qs.match(/"options":\[\{"id":"([0-9a-f-]{36})"/); optionId = o && o[1]; } catch {}
      const sReq = uuid();
      let s = await rpc('save_circular_response_draft', { p_request_id: sReq, p_revision_id: revisionId, p_answers: { child_context_id: null, answers: questionId && optionId ? [{ question_id: questionId, option_ids: [optionId] }] : [] }, p_expected_version: 0 });
      check('circulars.respond', 'rascunho de resposta (save_circular_response_draft) pelo operador interno', s.status === 200 && s.body && s.body.session_id, s.status === 200 ? `session ${s.body.session_id} v${s.body.version}` : short(s));
      if (s.status === 200 && s.body && s.body.session_id) {
        const sub = await rpc('submit_circular_response', { p_request_id: uuid(), p_session_id: s.body.session_id, p_expected_version: s.body.version });
        check('circulars.respond', 'submit_circular_response persiste', sub.status === 200 && sub.body && (sub.body.status === 'submitted' || sub.body.status), sub.status === 200 ? 'status ' + sub.body.status : short(sub));
        const d2 = await rpc('superadmin_circular_detail_v2', { p_circular_id: circularId });
        check('circulars.respond', 'reload (detail) reflete resposta no resumo', ok(d2) && /"(responses|answered|submitted)[^"]*":\s*[1-9]/.test(JSON.stringify(d2.body.data)), ok(d2) ? (JSON.stringify(d2.body.data).match(/"(responses|answered|submitted|summary)[^}]{0,120}/) || ['sem resumo'])[0].slice(0, 120) : short(d2));
      }
    }
    // limpeza
    r = await rpc('superadmin_circular_close_v2', { p_request_id: uuid(), p_circular_id: circularId, p_expected_version: cVer });
    if (ok(r)) cVer = r.body.data.version;
    if (assetId) {
      const del = await fn('circular-media', { action: 'delete', asset_id: assetId });
      check('circulars.attach', 'delete do anexo (limpeza) aceito', del.status === 200, short(del));
    }
    r = await rpc('superadmin_circular_delete_v2', { p_request_id: uuid(), p_circular_id: circularId, p_expected_version: cVer });
    check('circulars.delete', 'limpeza da circular', ok(r) && r.body.data.deleted === true, ok(r) ? 'ok' : short(r));
  }
  const anonPrep = await fn('circular-media', { action: 'prepare', request_id: uuid(), institution_id: institutionId, circular_id: circularId || uuid(), name: 'x.png', mime_type: 'image/png', size_bytes: PNG.length, display_order: 0 }, { anon: true });
  check('circulars.attach', 'anon nao prepara upload (negativa)', anonPrep.status === 401 || anonPrep.status === 403, 'status ' + anonPrep.status);

  // ---------- AGENDA: request (pedido de publicacao) e location (contexto de unidade) ----------
  if (institutionId) {
    const payload = { institutionId, contextKind: 'institution', contextId: institutionId, title: `${tag} Evento para aprovacao`, type: 'event', startsAt: new Date(Date.now() + 2 * 86400000).toISOString(), endsAt: new Date(Date.now() + 2 * 86400000 + 3600000).toISOString(), status: 'draft' };
    let r = await rpc('superadmin_agenda_save', { p_request_id: uuid(), p_event_id: null, p_expected_revision: null, p_payload: payload, p_reason: null, p_override_reservation: false });
    check('agenda.request', 'rascunho para pedido persiste', r.status === 200 && r.body.id, r.status === 200 ? 'id ' + r.body.id : short(r));
    if (r.status === 200 && r.body.id) {
      const eventId = r.body.id; let rev = r.body.revision;
      const req = await rpc('superadmin_agenda_command', { p_request_id: uuid(), p_event_id: eventId, p_expected_revision: rev, p_action: 'request_publication', p_reason: null });
      check('agenda.request', 'request_publication cria pedido pendente', req.status === 200 && req.body.request_id, req.status === 200 ? 'request ' + req.body.request_id : short(req));
      const requestId = req.status === 200 ? req.body.request_id : null;
      const list = await rpc('superadmin_agenda_requests', { p_kind: 'publication', p_status: null, p_limit: 50, p_offset: 0 });
      const found = list.status === 200 && Array.isArray(list.body) && list.body.find((x) => x.id === requestId);
      check('agenda.request', 'superadmin_agenda_requests lista o pedido (reload)', !!found, found ? 'status ' + found.status : short(list));
      if (requestId) {
        const dec = await rpc('superadmin_agenda_decide_publication', { p_request_id: uuid(), p_publication_request_id: requestId, p_approve: true, p_reason: 'Aprovado no teste da Rodada 5' });
        check('agenda.request', 'decidir (aprovar) persiste', dec.status === 200 && dec.body.status === 'approved', dec.status === 200 ? 'status ' + dec.body.status : short(dec));
        const g = await rpc('superadmin_agenda_get', { p_event_id: eventId });
        check('agenda.request', 'reload do evento apos aprovacao', g.status === 200 && g.body.status !== 'draft', g.status === 200 ? 'status ' + g.body.status + ' rev ' + g.body.revision : short(g));
        if (g.status === 200) rev = g.body.revision;
        const guardian = await rpc('superadmin_agenda_requests', { p_kind: 'guardian', p_status: null, p_limit: 50, p_offset: 0 });
        check('agenda.request', 'pedidos de responsaveis (guardian) abrem', guardian.status === 200 && Array.isArray(guardian.body), guardian.status === 200 ? guardian.body.length + ' itens' : short(guardian));
        // limpeza: cancelar se publicado/agendado, senao excluir rascunho
        const c = await rpc('superadmin_agenda_command', { p_request_id: uuid(), p_event_id: eventId, p_expected_revision: rev, p_action: g.status === 200 && g.body.status === 'draft' ? 'delete_draft' : 'cancel', p_reason: 'Limpeza do teste da Rodada 5' });
        check('agenda.request', 'limpeza do evento', c.status === 200, short(c));
      }
    }
    // location: evento com contexto de unidade
    if (unitId) {
      const payloadU = { institutionId, contextKind: 'unit', contextId: unitId, title: `${tag} Evento da unidade`, type: 'event', startsAt: new Date(Date.now() + 3 * 86400000).toISOString(), endsAt: new Date(Date.now() + 3 * 86400000 + 3600000).toISOString(), status: 'draft', location: 'Quadra coberta' };
      const ru = await rpc('superadmin_agenda_save', { p_request_id: uuid(), p_event_id: null, p_expected_revision: null, p_payload: payloadU, p_reason: null, p_override_reservation: false });
      check('agenda.location', 'evento com contexto de unidade e local persiste', ru.status === 200 && ru.body.id, ru.status === 200 ? 'id ' + ru.body.id : short(ru));
      if (ru.status === 200 && ru.body.id) {
        const g = await rpc('superadmin_agenda_get', { p_event_id: ru.body.id });
        const js = JSON.stringify(g.body || {});
        check('agenda.location', 'reload mantem unidade e local', g.status === 200 && js.includes(unitId) && js.includes('Quadra coberta'), g.status === 200 ? 'contextKind ' + (g.body.contextKind || g.body.context_kind) : short(g));
        const c = await rpc('superadmin_agenda_command', { p_request_id: uuid(), p_event_id: ru.body.id, p_expected_revision: g.body.revision, p_action: 'delete_draft', p_reason: null });
        check('agenda.location', 'limpeza do rascunho da unidade', c.status === 200 && c.body.deleted === true, short(c));
      }
      // negativa: unidade de outra instituicao (unidade que nao pertence a institutionId)
      const foreign = units.find((u) => (u.institutionId || u.institution_id) !== institutionId);
      if (foreign) {
        const rf = await rpc('superadmin_agenda_save', { p_request_id: uuid(), p_event_id: null, p_expected_revision: null, p_payload: { ...payloadU, contextId: foreign.id, title: `${tag} cross` }, p_reason: null, p_override_reservation: false });
        check('agenda.location', 'unidade fora da instituicao e recusada (negativa)', rf.status !== 200, 'status ' + rf.status + ' ' + code(rf));
        if (rf.status === 200 && rf.body.id) await rpc('superadmin_agenda_command', { p_request_id: uuid(), p_event_id: rf.body.id, p_expected_revision: rf.body.revision, p_action: 'delete_draft', p_reason: null });
      }
    } else {
      check('agenda.location', 'existe unidade no contexto da instituicao sintetica', false, 'nenhuma unidade em ' + (inst.name || institutionId) + ': pacote de unidade sintetica necessario');
    }
  }
  const pass = results.filter((x) => x.pass).length;
  log(`\nRESUMO: ${pass}/${results.length} PASS`);
  fs.writeFileSync(process.argv[2] || 'prova-producao-r05-resultado.json', JSON.stringify({ at: new Date().toISOString(), results }, null, 2));
})().catch((e) => { log('ERRO', e.message); process.exit(1); });
