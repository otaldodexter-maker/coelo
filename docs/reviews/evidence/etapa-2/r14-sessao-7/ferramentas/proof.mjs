// Prova por PostgREST/Edge com identidade QA (sem chave de servico; nada sensivel impresso).
// QA_ENV=<env> STEPS='[["rpc","fn",{...}],["edge","fn",{...}]]' node proof.mjs
import fs from 'node:fs';
const parseEnv=(f)=>Object.fromEntries(fs.readFileSync(f,'utf8').split(/\r?\n/).filter(l=>l.includes('=')&&!l.startsWith('#')).map(l=>{const i=l.indexOf('=');return [l.slice(0,i).trim(),l.slice(i+1).trim().replace(/^"|"$/g,'')];}));
const app=parseEnv('C:/Users/adrie/Documents/Coelo.worktrees/r14-agora-momentos/apps/superadmin/.env.local');
const qa=parseEnv(process.env.QA_ENV); const base=app.COELO_SUPABASE_URL; const anon=app.COELO_SUPABASE_PUBLISHABLE_KEY;
const login=await fetch(`${base}/auth/v1/token?grant_type=password`,{method:'POST',headers:{apikey:anon,'content-type':'application/json'},body:JSON.stringify({email:qa.QA_EMAIL,password:qa.QA_PASSWORD})}).then(r=>r.json());
if(!login.access_token){console.log('LOGIN FAIL',login.error_code??login.msg);process.exit(1);} console.log('login ok as',qa.QA_EMAIL);
const H={apikey:anon,authorization:`Bearer ${login.access_token}`,'content-type':'application/json'};
const call=async(kind,fn,body)=>{const url=kind==='rpc'?`${base}/rest/v1/rpc/${fn}`:`${base}/functions/v1/${fn}`;const r=await fetch(url,{method:'POST',headers:H,body:JSON.stringify(body)});const t=await r.text();let b;try{b=JSON.parse(t)}catch{b=t}return {status:r.status,body:b};};
const red=(o)=>JSON.stringify(o).replace(/"(signed_url|upload_url|read_ticket)"\s*:\s*"[^"]*"/g,'"$1":"<redigido>"');
const cut=Number(process.env.CUT||900);
for(const [kind,fn,body] of JSON.parse(process.env.STEPS||'[]')){const r=await call(kind,fn,body);console.log('##',kind,fn,r.status);console.log(red(r.body).slice(0,cut));}
