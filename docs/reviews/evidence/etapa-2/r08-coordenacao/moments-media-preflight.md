---
title: "R08 — integração e deploy do preflight de Momentos"
source: "G4 1d09cb3c8; suíte Deno na base integrada; Supabase CLI e OPTIONS remoto"
status: "deploy verificado; fluxo de mídia pela UI pendente"
generated_at: "2026-09-12"
---

# Resultado medido

Etapa 2 → apps/superadmin → Coelo (Principal) → Momentos → mídia →
`momentos.create`, `momentos.publish`, `momentos.view`.

G4 acrescentou `x-client-info` à lista existente de cabeçalhos CORS.
C0 integrou por merge de conteúdo e executou a suíte completa da função:
`rtk proxy deno test --allow-env --allow-read`, no diretório
`packages/coelo_database/supabase/functions/moments-media`.
Resultado na base integrada: **27 PASS, 0 FAIL**, exit 0, 515 ms no resumo
do Deno. O aviso de depreciação de `punycode` foi preservado.

Deploy realizado pelo C0 via `supabase functions deploy moments-media
--project-ref evvbomzejfijozbtgvpt --workdir packages/coelo_database --use-api`.
Listagem posterior confirmou **moments-media v10 ACTIVE**, atualizado em
2026-09-12T13:59:38.900Z. Configuração `verify_jwt=false` já existente;
autorização do handler preservada, sem mudança de segredo ou SQL.

OPTIONS medido em **2026-09-12T11:00:04-03:00**, solicitando POST e
`authorization,apikey,content-type,x-client-info`:

| Origem | HTTP | Allow-Origin | x-client-info permitido |
| --- | --- | --- | --- |
| http://127.0.0.1:3014 | 200 | origem exata | sim |
| https://superadmin.coelo.me | 200 | origem exata | sim |
| https://untrusted.example | 403 | ausente | origem negada |

Nenhum objeto, usuário, chave ou dado sintético foi criado nesta prova.
Sem promoção FE/BE/E2E: prepare/PUT/finalize/publicação/reload continuam
dependendo da prova pela rota normal com arquivo privado.

Contrato técnico conferido na [documentação oficial de CORS](https://supabase.com/docs/guides/functions/cors).
O índice de changelog foi consultado; as mudanças encontradas não alteram
este ajuste da lista de cabeçalhos da função existente.
