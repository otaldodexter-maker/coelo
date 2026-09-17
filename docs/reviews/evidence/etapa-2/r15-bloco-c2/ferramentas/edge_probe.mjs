// Prova de gateway de midia em producao com o usuario sintetico (mesmo padrao de
// r13-rpc-proof.mjs): login por senha, chama a Edge Function <fn> com o JWT,
// opcionalmente faz o PUT assinado com um arquivo local e o finalize.
// Uso: QA_ENV=<env> FN=child-safety-media STEPS='[{"action":"prepare",...}]' FILE=<png> node edge_probe.mjs
// Passos especiais: {"__put": true} usa upload_url/required_headers do passo anterior com FILE.
// Nunca imprime credenciais nem tokens; imprime status e corpo truncado.
import fs from 'node:fs';
import path from 'node:path';

const parseEnv = (file) =>
  Object.fromEntries(
    fs.readFileSync(file, 'utf8').split(/\r?\n/).filter((l) => l.includes('=') && !l.startsWith('#'))
      .map((l) => { const i = l.indexOf('='); return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^"|"$/g, '')]; }),
  );
const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1'));
const repoRoot = path.resolve(here, '..', '..', '..', '..', '..', '..');
const app = parseEnv(path.join(repoRoot, 'apps', 'superadmin', '.env.local'));
const qa = parseEnv(process.env.QA_ENV);
const baseUrl = app.COELO_SUPABASE_URL;
const anonKey = app.COELO_SUPABASE_PUBLISHABLE_KEY;
const fn = process.env.FN;
const cut = Number.parseInt(process.env.CUT ?? '900', 10);

const login = await fetch(`${baseUrl}/auth/v1/token?grant_type=password`, {
  method: 'POST',
  headers: { apikey: anonKey, 'content-type': 'application/json' },
  body: JSON.stringify({ email: qa.QA_EMAIL, password: qa.QA_PASSWORD }),
}).then((r) => r.json());
if (!login.access_token) { console.log('LOGIN FAIL', login.error_code ?? login.msg); process.exit(1); }
console.log('login ok as', qa.QA_EMAIL);

let previous = null;
for (const step of JSON.parse(process.env.STEPS ?? '[]')) {
  if (step.__preflight) {
    for (const origin of (process.env.ORIGINS ?? 'http://127.0.0.1:3017').split(',')) {
      const r = await fetch(previous.upload_url, { method: 'OPTIONS', headers: { origin, 'access-control-request-method': 'PUT', 'access-control-request-headers': 'content-type' } });
      console.log('## PREFLIGHT', origin, r.status, JSON.stringify(Object.fromEntries([...r.headers.entries()].filter(([k]) => k.startsWith('access-control')))));
    }
    continue;
  }
  if (step.__put) {
    const bytes = fs.readFileSync(process.env.FILE);
    const headers = Object.fromEntries(Object.entries(previous?.required_headers ?? {}));
    const r = await fetch(previous.upload_url, { method: 'PUT', headers, body: bytes });
    console.log('## PUT', r.status, (await r.text()).slice(0, 300));
    continue;
  }
  const r = await fetch(`${baseUrl}/functions/v1/${fn}`, {
    method: 'POST',
    headers: { apikey: anonKey, authorization: `Bearer ${login.access_token}`, 'content-type': 'application/json', origin: 'http://127.0.0.1:3017' },
    body: JSON.stringify(step),
  });
  const text = await r.text();
  let body; try { body = JSON.parse(text); } catch { body = text; }
  previous = typeof body === 'object' ? body : null;
  const shown = typeof body === 'object' && body ? { ...body, upload_url: body.upload_url ? '<signed>' : undefined, signed_url: body.signed_url ? '<signed>' : undefined } : body;
  console.log('##', step.action, r.status, JSON.stringify(shown).slice(0, cut));
}
