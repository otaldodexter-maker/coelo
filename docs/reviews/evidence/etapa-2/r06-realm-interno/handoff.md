---
title: "Handoff — grupo realm-interno, Rodada 6 (E2-R06-20260911)"
grupo: "realm-interno"
branch: "work/etapa2-r06-realm-interno"
source: "comunicacao/realm-interno.json (revisoes 39-41); candidatos/realm-interno/20260912210000"
generated_at: "2026-09-11"
status: "entregue ao coordenador; aplicacao em producao pelo coordenador"
---

# Handoff — realm-interno (backend transversal da R06)

## Recorte

Etapa 2 → apps/superadmin → backend transversal de segurança: raiz da ponte de
ator (220400/130000), usuários sintéticos por grupo, 180060 e code review dos
pacotes 210500/211100. Só SQL + pgTAP; nenhum cliente, nenhuma Edge Function,
nenhum Cloudflare, sem MCP `dart`.

## Prova local

Projeto descartável `coelo_realm_r06` (portas 626xx, scratchpad): baseline +
`seed.sql` + as 141 migrations de `ordem-de-aplicacao-producao.txt` (lotes 1
a 48) por `psql` do container, depois o candidato. Regressão das 201 suítes:
**4753 ok / 231 not ok**; as 66 suítes com vermelho ou erro reexecutadas com
as duas funções revertidas ao corpo de 171000/130000 deram resultado idêntico
linha a linha (**0 regressões**; `regressao-pgtap-2026-09-11.md`).

## Entregue

| Ordem | Pacote | Assunto | pgTAP | Estado |
| --- | --- | --- | --- | --- |
| 1 | `candidatos/realm-interno/20260912210000_internal_actor_scope_root_v1.sql` | raiz da ponte de ator: R1 sync do 130000 respeita o escopo do espelho e desativa memberships fora dele; R2 `has_platform_permission(text,uuid)` não conta o espelho escopado de identidade interna sem `institution_id` (generaliza 211200 aos 12 helpers, 188 chamadores e 69 policies); helper `superadmin_internal_actor_scope_targets()` | `internal_actor_scope_root_v1_test.sql` 44/44 (16 vermelhos antes da correção) | pronto para o coordenador aplicar |

## O que a prova por família mostra (identidade owner escopada em A; B alheia)

| Família / helper | Antes | Depois |
| --- | --- | --- |
| `superadmin_internal_actor_institution_access_sync` (130000) | owner + institution_admin em A **e em B** | só em A; membership em B → `inactive` + `revoked_at` |
| `has_platform_permission('people.read')` (1 arg) | true | false (2 args com A: true; com B: false) |
| Pessoas, Segurança infantil, Formulários (`require_forms_actor`, `form_require_owner`), Suporte, Conta, Perfis (`access_profile_require_mutation`, `require_profile_authority`), Arquivos e Identidade da instituição | aceitavam (capacidade de plataforma) | 42501 (deny-by-default) |
| Rotina e Cuidado (`require_routine_actor`, `require_health_care_actor`) | aceitavam pela plataforma | aceitam **só** por `has_context_permission` na membership de A (B: false) |
| Agenda (211200) | negava | continua negando |
| Identidade interna de plataforma (controle) | passa nos 12 | passa nos 12 |
| Pessoa people-based com membership de instituição (P7) | conta sem instituição | inalterado |

Produção tem 0 identidades escopadas (medido 11/09 19:5x, somente leitura):
exposição latente fechada na raiz; o backfill do sync reconcilia 0 linhas.

## Item 2 — usuários sintéticos por grupo

O coordenador já criou os sete `qa-r06-*` e aplicou a própria semente
(`20260911230100`, ledger em produção, 7 vínculos e 7 perfis medidos). A
semente escrita por esta frente (`20260912230000`) foi removida da branch para
não colidir (mesmo nome de teste); nada a aplicar.

## Item 3 — 180060 (`has_activity_capability` exige `instructor`)

Não é mudança de comportamento na prática, e não precisa de decisão de produto:

- `activity_group_assignments` só recebe `assignment_role='instructor'` em
  qualquer caminho de escrita (baseline `assign_activity_professionals`, 180080,
  180110); `activity_admin` sempre vai para `activity_admin_assignments`
  (tabela própria com `CHECK (assignment_role = 'activity_admin')`). O
  `CHECK ... NOT VALID` que admite os dois valores na tabela de turma é
  resquício.
- Produção tem 0 linhas em `activity_group_assignments` (medido 11/09).
- A composição por `activity_v2_effective_permission` mantém a precedência da
  baseline (deny/prohibited → allow → required → setting → default → profile) e
  só insere a camada de ação explícita por atribuição, que é o modelo v2.
- Único chamador: `can_access_attendance_child` (Assiduidade, realm de pessoas).

Proposta: fechar a pendência 180060 como "confirmado, sem pacote"; opcional na
revisão profunda: validar o CHECK e reduzi-lo a `'instructor'`.

## Item 4 — code review (segunda leitura) de 210500 e 211100

`210500` (políticas de cuidado + sino):

- `unit_care_policies_platform_read` usa `has_platform_permission('platform.read')`
  de um argumento: pessoa people-based com membership de instituição (P7) lê as
  políticas de todas as unidades; identidade interna escopada passa a ser
  negada pelo 20260912210000. Baixa sensibilidade (configuração), registrar.
- `set_v1` restringe por `platform_role_code in ('owner','operations')` além da
  capacidade `units.update` (padrão já usado nas RPCs internas; P23 pede que
  perfis/permissões decidam — pendência de uniformização, não bloqueia).
- Destinatários excluem pessoas de serviço e o ator; `not_tracked` não
  notifica; `on conflict do nothing` nos recipients. Sem achado bloqueante.

`211100` (handles na criação):

- `structure_handle_in_use` é verificação antes do insert; a unicidade dentro
  de cada tabela é garantida por índice, mas a unicidade **entre** tabelas
  (unidade × turma × pessoa) não tem constraint: duas criações concorrentes de
  tipos diferentes com o mesmo @ podem passar. Risco baixo no MVP; revisão
  profunda: índice único global (tabela de handles) ou advisory lock por
  handle normalizado.
- Turma com `handle` vazio após normalização cai no padrão do gatilho; unidade
  usa o mesmo fallback do 211400. Sem achado bloqueante.

## Aberto e primeiro gate

| Item | Primeiro gate |
| --- | --- |
| aplicar 20260912210000 | coordenador (preflight no espelho na ordem real; sync reconcilia 0 linhas) |
| P48 (G4, item 6): owner → institution_admin, operations → leitura no sync | pacote da G4 nasce sobre o corpo do 20260912210000 e usa `superadmin_internal_actor_scope_targets()`; aplicar depois dele (avisado em `realm-interno.json`) |
| famílias que negam identidade escopada (Pessoas, Segurança infantil, Formulários, Suporte, Conta, Perfis, Arquivos, Identidade) | decisão de produto quando existir a primeira identidade escopada: aceitar por contexto (como Rotina/Cuidado) ou manter fail-closed |
| P7 para pessoas people-based (1 argumento conta membership de instituição) | revisão profunda: RPCs de plataforma passarem `institution_id` |

## Segredos criados

Nenhum nesta rodada.

## Adendo (20:20) — lote 50 e hotfix

O coordenador aplicou `20260912210000` em produção no lote 50 (20:12) na versão
da rev 40 (`fc8094553`), cuja reconciliação filtrava instituições ativas e
desativou 7 memberships de espelho de plataforma em `qa-r04-escola` (rascunho;
os `qa-r06-*` do lote 49). O hotfix
`candidatos/realm-interno/20260912210100_internal_actor_scope_root_v1_hotfix.sql`
instala a versão final (rev 42) e reativa essas memberships
(`superadmin_internal_actor_scope_reactivate_v1`, idempotente); pgTAP
`internal_actor_scope_root_v1_hotfix_test` 4/4, provado no descartável com a
versão do lote 50 instalada e o hotfix por cima. Lição registrada em
`skills-deltas-r06.md`.
