---
source: R08 C0 integrado e Supabase remoto
status: deploy verificado, fluxo UI pendente
generated_at: 2026-09-12T11:37:58.357155-03:00
---

# Internal user create P51

Pacote autor bd3f4f7cd, integrado por merge. Deno8PASS/0FAIL exit0, 14ms. Primeira invocacao na raiz falhou por imports sem deno.json; corrigido cwd da funcao, sem alterar dependencias.

Deploy CLI --use-api exit0; list_edge_functions confirma version4 ACTIVE, updated_at1789223839436, verify_jwtfalse preservado. SHA remoto b641ec8b3e3053273996cd142a5013f21364dddc1b5b684645168e42f24b9e2a.

Preflight OPTIONS:

[
  {
    "origin": "http://127.0.0.1:3014",
    "status": 204,
    "acao": "http://127.0.0.1:3014",
    "headers": "authorization, apikey, content-type, x-client-info"
  },
  {
    "origin": "https://superadmin.coelo.me",
    "status": 204,
    "acao": "https://superadmin.coelo.me",
    "headers": "authorization, apikey, content-type, x-client-info"
  },
  {
    "origin": "https://outside.invalid",
    "status": 204,
    "acao": null,
    "headers": "authorization, apikey, content-type, x-client-info"
  }
]

Nenhum usuario/link/token criado nesta verificacao. UI de entrega e allowlistAuth de redirect ainda pendentes; sem SMTP declarado, sem promocaoE2E.
