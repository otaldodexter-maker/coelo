// Prova produtiva de agora.remove. Credenciais ficam fora do repositorio em
// Coelo-backups/qa-r03.env; a saida nunca inclui tokens, URLs ou PII.
const fs = require('node:fs');
const crypto = require('node:crypto');
const { spawnSync } = require('node:child_process');

const ref = 'evvbomzejfijozbtgvpt';
const base = `https://${ref}.supabase.co`;
const envPath = 'C:/Users/adrie/Documents/Coelo-backups/qa-r03.env';
const readEnv = (path) => Object.fromEntries(fs.readFileSync(path, 'utf8').split(/\r?\n/)
  .map((line) => line.match(/^\s*([A-Za-z0-9_]+)\s*=\s*(.*)\s*$/))
  .filter(Boolean).map((m) => [m[1], m[2].replace(/^['"]|['"]$/g, '')]));
const values = readEnv(envPath);
const keyResult = spawnSync('powershell.exe', ['-NoProfile', '-Command',
  `supabase projects api-keys --project-ref ${ref} --reveal --output json`], { encoding: 'utf8', windowsHide: true });
const keyPayload = JSON.parse(keyResult.stdout);
const keyRows = Array.isArray(keyPayload) ? keyPayload : (keyPayload.api_keys ?? keyPayload.keys ?? keyPayload);
const anon = (Array.isArray(keyRows) ? keyRows : Object.values(keyRows))
  .find((row) => row.type === 'publishable').api_key;
const json = async (url, options = {}) => {
  const response = await fetch(url, { ...options, signal: AbortSignal.timeout(20000) });
  let data = null; try { data = await response.json(); } catch (_) {}
  return { response, data };
};
const uuid = () => crypto.randomUUID();
const headers = (token) => ({ apikey: anon, authorization: `Bearer ${token}`, 'content-type': 'application/json' });
const rpc = (token, name, body) => json(`${base}/rest/v1/rpc/${name}`, { method: 'POST', headers: headers(token), body: JSON.stringify(body) });
const edge = (token, action, body) => json(`${base}/functions/v1/now-media`, { method: 'POST', headers: headers(token), body: JSON.stringify({ action, ...body }) });
const pass = (name, detail = '') => console.log(`PASS ${name}${detail ? ` ${detail}` : ''}`);
const fail = (name, detail = '') => { console.log(`FAIL ${name}${detail ? ` ${detail}` : ''}`); process.exitCode = 1; };
const idOf = (data) => data && typeof data.id === 'string' ? data.id : null;

async function main() {
  const login = await json(`${base}/auth/v1/token?grant_type=password`, {
    method: 'POST', headers: { apikey: anon, 'content-type': 'application/json' },
    body: JSON.stringify({ email: values.QA_EMAIL, password: values.QA_PASSWORD }),
  });
  if (!login.response.ok || !login.data?.access_token) return fail('auth.sign_in', `http ${login.response.status}`);
  const token = login.data.access_token; pass('auth.sign_in');
  const institutions = await json(`${base}/rest/v1/institutions?select=id&limit=100`, { headers: headers(token) });
  const institutionId = institutions.data?.[0]?.id;
  if (!institutionId) return fail('now.scope', 'no authorized synthetic institution');

  const draft = await rpc(token, 'save_now_draft', {
    p_request_id: uuid(), p_draft: { institution_id: institutionId, unit_id: null, group_id: null,
      caption: 'QA R14 E remove', overlay_text: '', crop_scale: 1, crop_x: 0, crop_y: 0,
      cover_position: 0, audiences: ['school_staff'], publish_at: null },
    p_publication_id: null, p_expected_version: 0,
  });
  const publicationId = idOf(draft.data);
  if (!publicationId) return fail('now.draft', `http ${draft.response.status}`);
  pass('now.draft');
  const bytes = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');
  const requestId = uuid();
  const prepared = await edge(token, 'prepare', { request_id: requestId, publication_id: publicationId,
    institution_id: institutionId, kind: 'media', name: 'qa-r14-remove.png', mime_type: 'image/png',
    size_bytes: bytes.length, rights_confirmed: false });
  if (!prepared.response.ok || prepared.data?.storage_provider !== 'r2') return fail('now.media.prepare', `http ${prepared.response.status}`);
  pass('now.media.prepare.r2');
  const uploaded = await fetch(prepared.data.upload_url, { method: 'PUT', headers: prepared.data.required_headers, body: bytes, signal: AbortSignal.timeout(20000) });
  if (!uploaded.ok) return fail('now.media.upload', `http ${uploaded.status}`);
  pass('now.media.upload');
  const finalized = await edge(token, 'finalize', { request_id: requestId, asset_id: prepared.data.asset_id,
    publication_id: publicationId, institution_id: institutionId, kind: 'media', name: 'qa-r14-remove.png',
    mime_type: 'image/png', size_bytes: bytes.length, rights_confirmed: false });
  if (!finalized.response.ok) return fail('now.media.finalize', `http ${finalized.response.status}`);
  pass('now.media.finalize');
  const published = await rpc(token, 'publish_now', { p_request_id: uuid(), p_publication_id: publicationId,
    p_expected_version: Number(draft.data.version), p_publish_at: null });
  if (!published.response.ok || published.data?.status !== 'published') return fail('now.publish', `http ${published.response.status}`);
  const publishedVersion = Number(published.data.management_version ?? Number(draft.data.version) + 1);
  pass('now.publish');
  const feed = await rpc(token, 'list_visible_now_publications', { p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_limit: 50 });
  const item = Array.isArray(feed.data) ? feed.data.find((row) => row.publication_id === publicationId) : null;
  const descriptor = item?.media?.find((row) => row.kind === 'media');
  if (!descriptor?.read_ticket) return fail('now.feed.before_remove', `http ${feed.response.status}`);
  const read = await edge(token, 'read', { read_ticket: descriptor.read_ticket });
  if (!read.response.ok || typeof read.data?.signed_url !== 'string') return fail('now.read.before_remove', `http ${read.response.status}`);
  pass('now.read.before_remove');
  const removeRequestId = uuid();
  const removed = await edge(token, 'remove', { request_id: removeRequestId, publication_id: publicationId,
    expected_version: publishedVersion, reason: 'QA R14 E immediate removal' });
  if (!removed.response.ok || removed.data?.status !== 'removed') return fail('agora.remove', `http ${removed.response.status}`);
  pass('agora.remove', `purge_status=${removed.data.purge_status}`);
  const replay = await edge(token, 'remove', { request_id: removeRequestId, publication_id: publicationId,
    expected_version: publishedVersion, reason: 'QA R14 E immediate removal' });
  if (!replay.response.ok || replay.data?.status !== 'removed') fail('agora.remove.idempotent', `http ${replay.response.status}`); else pass('agora.remove.idempotent');
  const oldTicket = await edge(token, 'read', { read_ticket: descriptor.read_ticket });
  if (oldTicket.response.status === 403 || oldTicket.response.status === 422) pass('agora.remove.old_ticket_denied', `http ${oldTicket.response.status}`); else fail('agora.remove.old_ticket_denied', `http ${oldTicket.response.status}`);
  const reload = await rpc(token, 'list_visible_now_publications', { p_institution_id: institutionId, p_unit_id: null, p_group_id: null, p_limit: 50 });
  const absent = !Array.isArray(reload.data) || !reload.data.some((row) => row.publication_id === publicationId);
  if (reload.response.ok && absent) pass('agora.remove.reload_absent'); else fail('agora.remove.reload_absent', `http ${reload.response.status}`);
  let conflict;
  try {
    conflict = await edge(token, 'remove', { request_id: uuid(), publication_id: publicationId,
      expected_version: publishedVersion, reason: 'QA conflict' });
    if (conflict.response.status === 422 || conflict.response.status === 409) pass('agora.remove.repeated_denied', `http ${conflict.response.status}`); else fail('agora.remove.repeated_denied', `http ${conflict.response.status}`);
  } catch (_) {
    fail('agora.remove.repeated_denied', 'request_timeout');
  }
  await fetch(`${base}/auth/v1/logout`, { method: 'POST', headers: { apikey: anon, authorization: `Bearer ${token}` } });
  console.log(`SUMMARY ${process.exitCode ? 'FAIL' : 'PASS'} publication_id_hash=${crypto.createHash('sha256').update(publicationId).digest('hex').slice(0, 12)}`);
}
main().catch((error) => { console.log(`FAIL unhandled ${error instanceof Error ? error.message : 'error'}`); process.exitCode = 1; });
