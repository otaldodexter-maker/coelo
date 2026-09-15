---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; R14-execucao-paralela.md"
status: evidence
generated_at: 2026-09-15
---

# Unidades › Erro (`units.error`) e Unidades › Acesso negado (`units.access-denied`) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `3f3579c54`, 127.0.0.1:3014,
CDP 9414, sessão `qa-r06-publicacoes`, Owner de plataforma). Os dois são estados de `/units/:unitId`
(`UnitDetailPage`), só alcançável por URL direta. Capturas em `capturas/units-*.png`.

| action_id | Rota normal | Backend em produção | Reload | Negativa |
|---|---|---|---|---|
| units.access-denied | `/units/00000000-0000-4000-8000-000000000000` (uuid inexistente) → painel "Acesso não autorizado · Você não tem permissão para consultar este registro." com Voltar/Recarregar e **nenhum dado** renderizado (01). | `superadmin_unit_detail_v2` devolve o envelope `{ok:false, error:{code: SAI_PERMISSION_DENIED, http_status 403}}` (mesma resposta por RPC com o sintético; negação auditada pela função) — inexistente e fora de escopo recebem a mesma negativa, sem enumeração. | Carga completa da mesma URL mantém "Acesso não autorizado" (02). | É a própria negativa real. Negativa por tenant com identidade de escopo `institution` só existe no pgTAP (`superadmin_internal_unit_detail_test` 31/31): todos os `qa-r06-*` têm escopo `platform`. |
| units.error | `/units/d0c40000…0002` carrega "Unidade QA R04" (00). Com a RPC `superadmin_unit_detail_v2` bloqueada por CDP (`Network.setBlockedURLs`, `ferramentas/cdp_block.dart`), "Recarregar" → painel "Não foi possível carregar os detalhes · Tente recarregar os dados." sem dado residual (01). | Falha de transporte (`ClientException`) → `unavailable` no controller; nenhum envelope malformado é tratado como autorizado (fail-closed provado por `supabase_unit_detail_repository_test`). | Após o desbloqueio, "Recarregar" (retry) recupera os dados reais da unidade (02). | A negação do servidor (403) continua sendo `denied`, não `error` — os dois estados não se confundem (01 de cada). |

Observações: nenhum defeito de código; nenhum teste alterado. Não há navegação interna para `/units/:id` no app
(o diretório leva a `/units/:id/edit`); o estado é alcançado por deep link — registrado, sem alteração por inferência.
