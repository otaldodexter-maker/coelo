// Smoke produtivo R08 do contrato de Circulares. Nao imprime credenciais,
// tokens, links assinados ou e-mail. Sem --execute faz apenas leitura da
// hierarquia; a mutacao exige os tres IDs conferidos no passo de inspecao.
const fs = require('fs');
const crypto = require('crypto');

const readEnv = (path) => Object.fromEntries(
  fs.readFileSync(path, 'utf8').split(/\r?\n/)
    .filter((line) => line.includes('=') && !line.startsWith('#'))
    .map((line) => {
      const index = line.indexOf('=');
      return [line.slice(0, index).trim(), line.slice(index + 1).trim().replace(/^"|"$/g, '')];
    }),
);
const app = readEnv('C:/Users/adrie/Documents/Coelo/apps/superadmin/.env.local');
const qa = readEnv('C:/Users/adrie/Documents/Coelo-backups/qa-r06-publicacoes.env');
const baseUrl = app.COELO_SUPABASE_URL;
const apiKey = app.COELO_SUPABASE_PUBLISHABLE_KEY;
if (!baseUrl || !apiKey || !qa.QA_EMAIL || !qa.QA_PASSWORD) {
  console.error('env incompleto');
  process.exit(1);
}

const arg = (name) => process.argv.find((value) => value.startsWith(`--${name}=`))?.slice(name.length + 3);
const execute = process.argv.includes('--execute');
const audit = process.argv.includes('--audit');
const institutionId = arg('institution');
const unitId = arg('unit');
const groupId = arg('group');
const auditCircularId = arg('circular');
const auditAssetId = arg('asset');
const outputPath = arg('output') || 'smoke-circular-media-r08-result.json';
const uuid = () => crypto.randomUUID();
const png = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  'base64',
);
let token;
const results = [];
const check = (step, pass, detail) => {
  const passed = Boolean(pass);
  results.push({ step, pass: passed, detail });
  console.log(`${passed ? 'PASS' : 'FAIL'} ${step}${detail ? ` - ${detail}` : ''}`);
};
const ok = (response) => response.status === 200 && response.body?.ok === true;
const compact = (response) => {
  const code = response.body?.error?.code || response.body?.code || response.body?.message;
  return `status ${response.status}${code ? `, code ${code}` : ''}`;
};

async function login() {
  const response = await fetch(`${baseUrl}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: apiKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: qa.QA_EMAIL, password: qa.QA_PASSWORD }),
  });
  const body = await response.json();
  if (!response.ok || !body.access_token) throw new Error(`login falhou: ${response.status}`);
  token = body.access_token;
  console.log('PASS login normal');
}

async function rpc(name, params, { anonymous = false } = {}) {
  const response = await fetch(`${baseUrl}/rest/v1/rpc/${name}`, {
    method: 'POST',
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${anonymous ? apiKey : token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(params),
  });
  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = text; }
  return { status: response.status, body };
}

async function edge(body, { anonymous = false } = {}) {
  const response = await fetch(`${baseUrl}/functions/v1/circular-media`, {
    method: 'POST',
    headers: {
      apikey: apiKey,
      Authorization: `Bearer ${anonymous ? apiKey : token}`,
      'Content-Type': 'application/json',
      'X-Client-Info': 'coelo-r08-smoke/1',
    },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let responseBody;
  try { responseBody = JSON.parse(text); } catch { responseBody = text; }
  return { status: response.status, body: responseBody };
}

async function table(path) {
  const response = await fetch(`${baseUrl}/rest/v1/${path}`, {
    headers: { apikey: apiKey, Authorization: `Bearer ${token}` },
  });
  const text = await response.text();
  let body;
  try { body = JSON.parse(text); } catch { body = text; }
  return { status: response.status, body };
}

async function inspectHierarchy() {
  const response = await rpc('superadmin_agenda_contexts', {});
  if (response.status !== 200) throw new Error(`hierarquia indisponivel: ${compact(response)}`);
  const contexts = response.body?.contexts || response.body || [];
  const safe = contexts.map((context) => ({
    level: context.level,
    id: context.id,
    name: context.name,
    institutionId: context.institutionId || context.institution_id || null,
    unitId: context.unitId || context.unit_id || null,
  }));
  console.log(JSON.stringify({ hierarchy: safe }, null, 2));
  return safe;
}

async function run() {
  await login();
  const hierarchy = await inspectHierarchy();
  if (audit) {
    if (!auditCircularId || !auditAssetId) throw new Error('audit exige circular e asset');
    const detail = await rpc('superadmin_circular_detail_v2', { p_circular_id: auditCircularId });
    const mediaRead = await edge({ action: 'read', asset_id: auditAssetId });
    const circularRows = await table(
      `circulars?id=eq.${encodeURIComponent(auditCircularId)}&select=id,status,deleted_at,management_version`,
    );
    const assetRows = await table(
      `circular_media_assets?id=eq.${encodeURIComponent(auditAssetId)}&select=id,circular_id,status,storage_provider,cleanup_attempted_at`,
    );
    const auditResult = {
      at: new Date().toISOString(),
      ids: { circularId: auditCircularId, assetId: auditAssetId },
      detail: { status: detail.status, code: detail.body?.error?.code || detail.body?.code || null },
      mediaRead: {
        status: mediaRead.status,
        code: mediaRead.body?.error?.code || mediaRead.body?.code || null,
        ticketReturned: Boolean(mediaRead.body?.url || mediaRead.body?.signed_url || mediaRead.body?.read_url),
      },
      circularCatalog: {
        status: circularRows.status,
        rowCount: Array.isArray(circularRows.body) ? circularRows.body.length : null,
        rows: Array.isArray(circularRows.body) ? circularRows.body : [],
      },
      assetCatalog: {
        status: assetRows.status,
        rowCount: Array.isArray(assetRows.body) ? assetRows.body.length : null,
        rows: Array.isArray(assetRows.body) ? assetRows.body : [],
      },
      note: 'read-only post-incident audit; no signed URL or credential recorded',
    };
    fs.writeFileSync(outputPath, JSON.stringify(auditResult, null, 2));
    console.log(JSON.stringify(auditResult, null, 2));
    return;
  }
  if (!execute) return;
  if (!institutionId || !unitId || !groupId) throw new Error('execute exige institution, unit e group');
  const institution = hierarchy.find((item) => item.level === 'institution' && item.id === institutionId);
  const unit = hierarchy.find((item) => item.level === 'unit' && item.id === unitId);
  const group = hierarchy.find((item) => item.level === 'group' && item.id === groupId);
  if (!institution || !unit || !group) throw new Error('IDs nao pertencem a hierarquia lida');
  if (unit.institutionId !== institutionId || group.institutionId !== institutionId) {
    throw new Error('unidade/grupo fora da instituicao selecionada');
  }

  const tag = `[R08-QA ${new Date().toISOString().slice(11, 19)}]`;
  const textBeforeId = uuid();
  const textAfterId = uuid();
  const questionId = uuid();
  const yesId = uuid();
  const noId = uuid();
  const mediaBlockId = uuid();
  let circularId;
  let version = 0;
  let assetId;

  const initialBlocks = [
    { id: textBeforeId, kind: 'text', text: 'Texto antes da midia.' },
    {
      id: questionId,
      kind: 'question',
      question: {
        id: questionId,
        prompt: 'Confirma ciencia?',
        kind: 'single_choice',
        required: true,
        options: [{ id: yesId, label: 'Sim' }, { id: noId, label: 'Nao' }],
      },
    },
    { id: textAfterId, kind: 'text', text: 'Texto depois da pergunta.' },
  ];
  let response = await rpc('superadmin_circular_save_draft_v2', {
    p_request_id: uuid(), p_institution_id: institutionId, p_unit_id: unitId,
    p_group_id: groupId, p_activity_id: null,
    p_payload: {
      id: '', title: `${tag} Circular midia intercalada`, version: 0, status: 'draft',
      response_policy: 'per_person', audiences: ['families'], blocks: initialBlocks,
    },
  });
  check('create draft', ok(response), compact(response));
  if (!ok(response)) throw new Error('rascunho nao criado');
  circularId = response.body.data.id;
  version = response.body.data.version;

  const requestId = uuid();
  response = await edge({
    action: 'prepare', request_id: requestId, institution_id: institutionId,
    circular_id: circularId, name: 'r08-pixel.png', mime_type: 'image/png',
    size_bytes: png.length, display_order: 1,
  });
  check('media prepare v13', response.status === 200 && response.body?.upload_url && response.body?.asset_id, compact(response));
  if (response.status !== 200 || !response.body?.upload_url) throw new Error('prepare falhou');
  assetId = response.body.asset_id;
  const uploadHost = new URL(response.body.upload_url).host;
  const put = await fetch(response.body.upload_url, {
    method: 'PUT', headers: { ...(response.body.required_headers || {}), 'content-type': 'image/png' }, body: png,
  });
  check('R2 PUT', put.ok, `status ${put.status}, host ${uploadHost}`);
  if (!put.ok) throw new Error('PUT falhou');
  response = await edge({
    action: 'finalize', request_id: requestId, finalize_request_id: uuid(),
    institution_id: institutionId, circular_id: circularId, asset_id: assetId,
    name: 'r08-pixel.png', mime_type: 'image/png', size_bytes: png.length,
    display_order: 1,
    checksum_sha256: crypto.createHash('sha256').update(png).digest('hex'),
  });
  check('media finalize ready', response.status === 200 && response.body?.status === 'ready', compact(response));
  if (response.status !== 200) throw new Error('finalize falhou');

  const orderedBlocks = [
    initialBlocks[0],
    { id: mediaBlockId, kind: 'media', asset_ids: [assetId] },
    initialBlocks[1],
    initialBlocks[2],
  ];
  response = await rpc('superadmin_circular_save_draft_v2', {
    p_request_id: uuid(), p_institution_id: institutionId, p_unit_id: unitId,
    p_group_id: groupId, p_activity_id: null,
    p_payload: {
      id: circularId, title: `${tag} Circular midia intercalada`, version,
      status: 'draft', response_policy: 'per_person', audiences: ['families'], blocks: orderedBlocks,
    },
  });
  check('save ordered blocks', ok(response), compact(response));
  if (!ok(response)) throw new Error('ordem nao salva');
  version = response.body.data.version;
  response = await rpc('superadmin_circular_detail_v2', { p_circular_id: circularId });
  const draftBlocks = response.body?.data?.draft?.blocks || [];
  const kinds = draftBlocks.map((block) => block.kind);
  check('detail feeds preview/reader in order', ok(response) && JSON.stringify(kinds) === JSON.stringify(['text', 'media', 'question', 'text']), kinds.join('>'));

  response = await rpc('superadmin_circular_publish_v2', {
    p_request_id: uuid(), p_circular_id: circularId, p_expected_version: version, p_publish_at: null,
  });
  check('publish', ok(response) && response.body.data.status === 'published', compact(response));
  if (!ok(response)) throw new Error('publicacao falhou');
  version = response.body.data.version;

  response = await edge({ action: 'read', asset_id: assetId });
  const readUrl = response.body?.url || response.body?.signed_url || response.body?.read_url;
  check('authorized media read ticket', response.status === 200 && Boolean(readUrl), compact(response));
  if (readUrl) {
    const get = await fetch(readUrl);
    const bytes = Buffer.from(await get.arrayBuffer());
    check('read bytes equal PNG', get.ok && bytes.equals(png), `status ${get.status}, ${bytes.length} bytes`);
  }
  const anonymousRead = await edge({ action: 'read', asset_id: assetId }, { anonymous: true });
  check('anonymous read denied', anonymousRead.status === 401 || anonymousRead.status === 403, `status ${anonymousRead.status}`);

  response = await rpc('superadmin_circular_detail_v2', { p_circular_id: circularId });
  const detail = response.body?.data || {};
  const revisionId = detail.revision_id || detail.revision?.id || detail.circular?.revision_id;
  check('published revision available', ok(response) && Boolean(revisionId), Boolean(revisionId) ? 'yes' : compact(response));
  if (revisionId) {
    let saved = await rpc('save_circular_response_draft', {
      p_request_id: uuid(), p_revision_id: revisionId,
      p_answers: { child_context_id: null, answers: [{ question_id: questionId, option_ids: [yesId] }] },
      p_expected_version: 0,
    });
    check('P50 save response as Superadmin owner', saved.status === 200 && Boolean(saved.body?.session_id), compact(saved));
    if (saved.status === 200 && saved.body?.session_id) {
      const submitted = await rpc('submit_circular_response', {
        p_request_id: uuid(), p_session_id: saved.body.session_id, p_expected_version: saved.body.version,
      });
      check('P50 submit response', submitted.status === 200 && submitted.body?.status === 'submitted', compact(submitted));
      const summary = await rpc('superadmin_circular_response_summary_v2', { p_circular_id: circularId });
      const counts = summary.body?.data || {};
      check('P50 summary reload', ok(summary) && Number(counts.submitted_count || 0) >= 1, `submitted ${counts.submitted_count || 0}`);
    }
  }

  response = await rpc('superadmin_circular_close_v2', {
    p_request_id: uuid(), p_circular_id: circularId, p_expected_version: version,
  });
  check('cleanup close', ok(response), compact(response));

  const passed = results.filter((result) => result.pass).length;
  fs.writeFileSync(outputPath, JSON.stringify({
    at: new Date().toISOString(),
    fixture: { tag, institutionId, unitId, groupId, circularId, assetId },
    tests: { passed, failed: results.length - passed, total: results.length },
    results,
    notes: [
      'API smoke only; not UI/E2E',
      'anonymous negative only; no cross-tenant claim for global owner',
      'synthetic circular and asset are retained after close until the formal end of Stage 2',
    ],
  }, null, 2));
  console.log(`RESUMO ${passed}/${results.length} PASS`);
  if (passed !== results.length) process.exitCode = 1;
}

run().catch((error) => {
  console.error(`ERRO ${error.message}`);
  process.exit(1);
});
