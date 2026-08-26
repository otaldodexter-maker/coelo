---
source: packages/coelo_database/supabase/functions/unit-export
status: local-contract
generated_at: 2026-08-26
---

# Unit export worker

`unit-export` é um worker interno. Clientes Flutter e navegadores chamam apenas
`import-export-jobs`; acesso direto ao worker deve falhar antes de qualquer RPC.

## Delegação interna

`import-export-jobs` e `unit-export` precisam receber o mesmo segredo aleatório
de alta entropia em `COELO_UNIT_EXPORT_WORKER_SECRET`. O hub envia o valor apenas
no header `x-coelo-worker-secret`; o worker responde `403` quando o segredo está
ausente ou diverge.

O segredo não pode entrar em Git, bundle Flutter, URL, payload, log ou resposta.
Ele não substitui o JWT do ator: a sessão continua no header `Authorization` e
é revalidada pelas RPCs antes da materialização, conclusão e signed URL.

Implantar essa mudança exige configurar o segredo nas duas Edge Functions e
publicá-las de forma coordenada. Até essa configuração e os testes remotos, o
contrato permanece somente local-green e a composição Flutter continua
fail-closed.

## Verificação local

```powershell
deno test --config deno.json --allow-all units_export_hub_boundary_red_test.ts units_export_post_success_red_test.ts
```
