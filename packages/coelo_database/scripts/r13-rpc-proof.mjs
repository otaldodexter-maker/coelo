// R13: prova de RPC em producao com o usuario sintetico da frente (ADR 0034 D19).
// Uso: QA_ENV=<caminho do qa-r06-<grupo>.env> STEPS='[["rpc",{...}],...]' node scripts/r13-rpc-proof.mjs
// Le COELO_SUPABASE_URL e COELO_SUPABASE_PUBLISHABLE_KEY de apps/superadmin/.env.local.
// Nunca imprime credenciais nem tokens; imprime status HTTP e corpo truncado.
import fs from 'node:fs';
import path from 'node:path';

const parseEnv = (file) =>
  Object.fromEntries(
    fs
      .readFileSync(file, 'utf8')
      .split(/\r?\n/)
      .filter((line) => line.includes('=') && !line.startsWith('#'))
      .map((line) => {
        const idx = line.indexOf('=');
        return [line.slice(0, idx).trim(), line.slice(idx + 1).trim().replace(/^"|"$/g, '')];
      }),
  );

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, '$1')), '..', '..', '..');
const app = parseEnv(path.join(repoRoot, 'apps', 'superadmin', '.env.local'));
const qa = parseEnv(process.env.QA_ENV);
const baseUrl = app.COELO_SUPABASE_URL;
const anonKey = app.COELO_SUPABASE_PUBLISHABLE_KEY;

const login = await fetch(`${baseUrl}/auth/v1/token?grant_type=password`, {
  method: 'POST',
  headers: { apikey: anonKey, 'content-type': 'application/json' },
  body: JSON.stringify({ email: qa.QA_EMAIL, password: qa.QA_PASSWORD }),
}).then((r) => r.json());
if (!login.access_token) {
  console.log('LOGIN FAIL', login.error_code ?? login.msg ?? login.error);
  process.exit(1);
}
console.log('login ok as', qa.QA_EMAIL);

const rpc = async (fn, args = {}) => {
  const r = await fetch(`${baseUrl}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      apikey: anonKey,
      authorization: `Bearer ${login.access_token}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify(args),
  });
  const text = await r.text();
  let body;
  try {
    body = JSON.parse(text);
  } catch {
    body = text;
  }
  return { status: r.status, body };
};

const cut = Number.parseInt(process.env.CUT ?? '1500', 10);
const steps = JSON.parse(process.env.STEPS ?? '[]');
for (const [fn, args] of steps) {
  const res = await rpc(fn, args);
  console.log('##', fn, res.status);
  console.log(JSON.stringify(res.body).slice(0, cut));
}
