---
source: "Sessão 1 da R14 (Opus 5), 15/09/2026; folga do Bloco C; owner.r12-12/14/15"
status: evidence
generated_at: 2026-09-15
---

# Segurança infantil › Criança (`child-safety.child`; owner.r12-12, r12-14, r12-15) — rota real, 15/09/2026

Mesmo ambiente de `circulars-attach-20260915.md` (produção, build QA de `r14/bloco-ab` em `3d1da743e`, 127.0.0.1:3014,
CDP 9414, sessão `qa-r06-publicacoes`, Owner). Criança sintética "Crianca QA R04" (`d0c40000…0003`), duas
autorizações reais de "QA R04 Responsavel" (Mãe/Pai), ambas `approved` + `suspended` desde a R05.
Capturas em `capturas/child-safety-child-*.png`.

| action_id | Rota normal | Leitura em produção | Reload | Negativa |
|---|---|---|---|---|
| child-safety.child | `/safety` (cards, abas com contagens) › card da criança → `/safety/children/d0c40000…0003`: tabela Nome / Relação / Validade / Status / Ações com "Mãe"/"Pai" (r12-14, códigos localizados), "Desde 11/09/2026 · até revogação" e "Aprovado · Suspensa" (r12-12: decisão e ciclo de vida separados) (01). "Gerenciar" abre o diálogo com criança, contexto, relação, capacidades ("Retirada"), motivo, decisão, "Situação: Suspensa", validade e só "Concluir" (r12-15, estado suspenso) (02). | `superadmin_child_safety_get(p_child_id)` (projeção `decision_status`/`lifecycle_status`/`relationship_code`/`version`). | Carga completa relê a tabela com os mesmos dados (03). | `superadmin_child_safety_get` de id inexistente → `P0002 child safety record unavailable` (não enumerável); RLS/pgTAP `child_safety_production_test` já certificados no BE. |

## Bloqueio encontrado (SQL — Sessão 2)

`child_safety_change_lifecycle(p_request_id novo, p_authorization_id 34d29829…, p_expected_version 99,
p_lifecycle_status 'suspended', p_reason …)` não responde: PostgREST devolve **504** após o timeout do gateway
(duas tentativas, sessão `qa-r06-publicacoes`). Com versão errada o esperado era `40001`/conflito imediato. Como
a UI de "Suspender autorização" usa a mesma RPC, `child-safety.suspend` e a reprova de `child-safety.edit`
(que exige autorização pendente + `child_safety_edit_pending_authorization`) ficam bloqueadas até o diagnóstico
no espelho (possível espera de lock/advisory ou `has_mfa_aal2()` em laço). Não foi tentada a versão correta
para não mutar massa com a função travada.

Observações: após carga completa de `/safety/children/:id` (deep link), o banner "Criar autorização" não aparece
— `can_create` vem só do diretório; lacuna de composição, sem alteração por inferência. Estados "pendente" e
"aprovado ativo" do diálogo (r12-15) não exercitados nesta fatia (não há autorização nesses estados e a criação
depende do wizard + decisão, que passa pela RPC travada).
