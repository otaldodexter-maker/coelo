// Spike R2 com dados sinteticos (docs/spikes/media-r2/test-matrix.md).
// Executa contra coelo-transient-prod usando o mesmo cliente das Edge Functions.
// Nao grava segredo em lugar nenhum: le COELO_R2_* do ambiente do processo.
//
//   deno run --allow-env --allow-net packages/coelo_database/scripts/r2-spike-synthetic.ts
//
// Cobre R2-T001 (PUT autorizado), T002 (MIME divergente), T003 (HEAD confirma),
// T004 (GET autorizado), T007 (URL expirada) e limpeza do objeto. T005/T006
// (negativas por tenant/membership) e T008 (orfao) pertencem ao gateway
// (Edge Functions + catalogo) e sao provados nos pgTAP/HTTP das funcoes.
import { R2Client } from "../supabase/functions/_shared/r2_s3.ts";

const env = (name: string) => {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} ausente no ambiente`);
  return value;
};

const client = new R2Client({
  endpoint: env("COELO_R2_ENDPOINT"),
  region: Deno.env.get("COELO_R2_REGION") ?? "auto",
  accessKeyId: env("COELO_R2_ACCESS_KEY_ID"),
  secretAccessKey: env("COELO_R2_SECRET_ACCESS_KEY"),
  bucket: Deno.env.get("COELO_R2_SPIKE_BUCKET") ?? "coelo-transient-prod",
});

const key = `spike/synthetic/${crypto.randomUUID()}/evidence.txt`;
const bytes = new TextEncoder().encode(`coelo spike ${new Date().toISOString()}\n`);
const results: Array<[string, string, string]> = [];
const record = (id: string, ok: boolean, detail: string) =>
  results.push([id, ok ? "PASS" : "FAIL", detail]);

// R2-T001 upload autorizado por URL assinada (PUT), sem expor a chave.
const put = await client.presignPut(key, "text/plain", 60);
const putResponse = await fetch(put.url, { method: "PUT", headers: put.requiredHeaders, body: bytes });
record("R2-T001", putResponse.status === 200, `PUT assinado -> HTTP ${putResponse.status}`);

// R2-T002 MIME divergente do assinado e recusado.
const mismatch = await fetch(put.url, {
  method: "PUT",
  headers: { ...put.requiredHeaders, "content-type": "image/png" },
  body: bytes,
});
record("R2-T002", mismatch.status === 403, `PUT com content-type divergente -> HTTP ${mismatch.status}`);

// R2-T003 metadados do objeto conferem com o enviado.
const head = await client.head(key);
record("R2-T003", head.byteSize === bytes.byteLength && head.mimeType === "text/plain", `HEAD bytes=${head.byteSize} mime=${head.mimeType}`);

// R2-T004 leitura autorizada com expiracao curta.
const get = await client.presignGet(key, 30);
const getResponse = await fetch(get.url);
const body = new Uint8Array(await getResponse.arrayBuffer());
record("R2-T004", getResponse.status === 200 && body.byteLength === bytes.byteLength, `GET assinado -> HTTP ${getResponse.status}, ${body.byteLength} bytes`);

// R2-T007 URL expirada deixa de funcionar.
const shortGet = await client.presignGet(key, 1);
await new Promise((resolve) => setTimeout(resolve, 2500));
const expired = await fetch(shortGet.url);
record("R2-T007", expired.status === 403, `GET apos expirar -> HTTP ${expired.status}`);

// Limpeza: o objeto sintetico nao fica no bucket.
await client.delete(key);
let gone = false;
try {
  await client.head(key);
} catch {
  gone = true;
}
record("cleanup", gone, "objeto sintetico removido");

console.log(`bucket=${client.config.bucket} chave=${key}`);
for (const [id, status, detail] of results) console.log(`${id}\t${status}\t${detail}`);
if (results.some(([, status]) => status === "FAIL")) Deno.exit(1);
