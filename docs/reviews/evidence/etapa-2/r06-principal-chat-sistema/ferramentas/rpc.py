# Prova de RPC em producao com a sessao qa-r06-principal. Credenciais so em memoria; nunca imprime.
import json, os, sys, urllib.request
def env(path):
    d={}
    for l in open(path,encoding='utf-8'):
        l=l.strip()
        if l and not l.startswith('#') and '=' in l:
            k,v=l.split('=',1); d[k.strip()]=v.strip().strip('"').strip("'")
    return d
e=env('C:/Users/adrie/Documents/Coelo.worktrees/e2-r06-principal-chat-sistema/apps/superadmin/.env.local')
q=env('C:/Users/adrie/Documents/Coelo-backups/qa-r06-principal.env')
URL=e['COELO_SUPABASE_URL']; KEY=e['COELO_SUPABASE_PUBLISHABLE_KEY']
def call(path, body=None, token=None, method='POST', extra=None):
    h={'apikey':KEY,'Content-Type':'application/json'}
    if token: h['Authorization']='Bearer '+token
    if extra: h.update(extra)
    req=urllib.request.Request(URL+path, data=json.dumps(body).encode() if body is not None else None, headers=h, method=method)
    try:
        with urllib.request.urlopen(req) as r: return r.status, json.loads(r.read() or b'null')
    except urllib.error.HTTPError as err:
        return err.code, json.loads(err.read() or b'null')
st,tok=call('/auth/v1/token?grant_type=password',{'email':q.get('QA_EMAIL'),'password':q.get('QA_PASSWORD')})
if st!=200: print('login',st,tok.get('error_description') or tok.get('msg')); sys.exit(1)
T=tok['access_token']; print('login 200')
for arg in sys.argv[1:]:
    name,_,body=arg.partition('=')
    st,res=call('/rest/v1/rpc/'+name, json.loads(body) if body else {}, T, extra={'Prefer':'params=single-object'} if body else None)
    print('##',name,st); print(json.dumps(res,ensure_ascii=False)[:2500])
