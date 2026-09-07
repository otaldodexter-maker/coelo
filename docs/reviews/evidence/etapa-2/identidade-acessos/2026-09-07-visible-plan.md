---
title: "E2E 1 — passos por tela e camada"
source: "recorte do Coordenador E2E; trabalho local da branch codex/e2e-identidade-acessos"
status: "in-progress"
generated_at: "2026-09-07"
---

# Plano visível

Somente Superadmin. Remoto é produção e permanece read-only sem lease.
Um único writer: agente principal. Subagentes fazem inspeção e review sem
alterações: account_review (sessão), realm_audit (Usuários internos/contrato
RPC), rls_negative_review (P0 RLS; depois Conta). Não houve execução de BD,
Docker ou deploy por esta frente nesta retomada.

## Usuários internos — internal-users.list

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | read/update/suspend internos | Recorte local listado; criação/convite não habilitados |
| 2/6 Backend/negativas | RPCs superadmin_internal_user_profiles e superadmin_internal_users_list | Adapter testado via HTTP simulado; falta prova SQL/runtime autorizado |
| 3/6 Cliente/estados | scope/main/app/router/diretório | Composição readonly, negativa e limpeza de tela implementadas |
| 4/6 Integração/reload | Sessão → RPC → UI | Aberto: ausência de prova com backend real; cache/revogação em andamento |
| 5/6 Regressão/visual | testes Flutter | Diretório 13/13; composição inicial combinada 32/32; visual real ainda aberto |
| 6/6 Review/evidências/commit | commits locais | 151d9ddf, 022e1568, bbafe63e; reviews locais aprovados, sem promover E2E |

## Sessão — troca de contexto e revogação

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | SuperadminSession; reserva R03 | Preservar autorização/MFA, alterar notificação e descarte de resultados antigos |
| 2/6 Backend/negativas | Nenhum BD nesta fatia | Servidor continua reautorizando; não há mudança de claims/capabilities |
| 3/6 Cliente/estados | authorize/_setSessionState | Alteração semântica notifica; reautorização equivalente permanece estável |
| 4/6 Integração/reload | Lista normal escuta sessão | ListenableBuilder + chave de revisão; teste prova nova carga e perda de permissão sem RPC |
| 5/6 Regressão/visual | sessão/scope/router/login | 55/55 locais verdes; MediaSession/cache privados ainda abertos |
| 6/6 Review/evidências/commit | account_review | Bootstrap concorrente inicial corrigido após RED; revisão final aprovada |

## Usuários internos — detalhe/edição

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | detail/update/change_status | Subagente identificou preview residual; reserva de rota solicitada |
| 2/6 Backend/negativas | RPCs superadmin_internal_user_detail/update/change_status | SQL lido, não executado; divergência de versões sob revisão |
| 3/6 Cliente/estados | detail/form | Aberto: fallback cache em erro, instituições fake, avatar não persistido, e-mail imutável no SQL |
| 4/6 Integração/reload | Nenhum fluxo novo habilitado | Aberto; separar read/update/suspend antes de habilitar |
| 5/6 Regressão/visual | matriz proposta pelo subagente | REDs ainda a implementar |
| 6/6 Review/evidências/commit | Sem commit desta fatia | Não declarar detalhe/edição prontos |

## Perfis e Modelos — P0 RLS

| Passo | Camada / objeto | Estado e próximo gate |
|---|---|---|
| 1/6 Contrato/inventário | 3 tabelas app_private | catalog_versions, command_receipts e command_receipts_v2 nominais identificadas |
| 2/6 Backend/negativas | app_private.access_profile_* | Proposta estática de RLS/ACL; Eng1 deve provar owners/bypass/trigger/replay local |
| 3/6 Cliente/estados | Não incluído no pacote RLS | Não converter receipts people-based para UUID interno |
| 4/6 Integração/reload | Nenhum BD executado | Aguarda replay/preflight; remoto exige lease |
| 5/6 Regressão/visual | pgTAP proposto | ACL real + RLS independente + trigger/receipts positivos e rollback |
| 6/6 Review/evidências/commit | Inspeção read-only | Não há migration aplicada nem estado local-green |

Os rastreadores oficiais permanecem sob autoria exclusiva do Coordenador.
Este plano registra andamento, não amplia o recorte nem substitui evidência.
