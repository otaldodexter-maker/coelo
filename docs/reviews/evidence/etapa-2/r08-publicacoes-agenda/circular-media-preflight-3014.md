---
source: circular-media production OPTIONS with Origin http://127.0.0.1:3014
status: preflight-green-ui-pending
generated_at: 2026-09-12
---

# circular-media — preflight da origem 3014

Em 12/09/2026, 11:38 BRT, uma requisicao `OPTIONS` sem credenciais para a Edge
Function de producao retornou HTTP 200 e:

- `Access-Control-Allow-Origin: http://127.0.0.1:3014`;
- `Access-Control-Allow-Headers: authorization, apikey, content-type, x-client-info`;
- `Access-Control-Allow-Methods: POST, OPTIONS`.

Isso confirma que a origem autorizada e o cabecalho enviado por
`supabase_flutter` estao ativos. Nao confirma login, `prepare`, PUT privado,
`finalize`, salvamento do bloco ou reload; `circulars.attach` continua pendente
da prova pela interface no unico Chrome compartilhado.
