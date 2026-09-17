---
title: "R15 — Fechamento (17/09/2026)"
source: "decisions/0043-r15-closure-r16-opening-20260917.md; R15-checkpoint-20260917.md; R15-pendencias.md (congelado); R15-handoff-bloco-a|b|c1|c2.md; R15-apoio-bloco-b.md; validate-trackers.cjs em 37d762976"
status: "historical"
lifecycle: "historical"
generated_at: "2026-09-17"
updated_at: "2026-09-17"
execution_status: "PASS DOCUMENTED_PARTIAL em 2026-09-17; 22 aceites E2E novos no dia; fila transferida integralmente para a R16"
audience: "team"
---

> Documento histórico. R15 foi encerrada em 17/09/2026 por decisão do Owner
> (ADR 0043) e sua fila foi consolidada na R16. A fonte atual é
> `R16-pendencias.md` e `docs/agent/current-state.md`.

# R15 — Fechamento

R15 abriu em 16/09/2026 (fila única de R01–R14) e fechou em 17/09/2026 em
`dev`/`origin/dev` `37d762976`, sem abrir Etapa 3 e sem deploy público. Rodou num único
dia com cinco sessões paralelas (A, B, B′ apoio, C1, C2) em worktrees próprias,
integração por cherry-pick pela coordenadora e o Owner presente para as decisões
E10–E14.

## Resultado por contador (abertura → fechamento)

| Métrica | 16/09 (abertura) | 17/09 (fechamento) |
|---|---|---|
| FE verificado | 189/232 | **207/232 (89,2%)** |
| BE concluído | 172/219 | **185/219 (84,5%)** |
| E2E verificado | 162/186 | **184/186 (98,9%)** |
| Owner items done | 21/53 | **39/53 (73,6%)** |

## O que fechou na R15

- **Produção (lotes 75–80)**: OQ-047 sistêmica (175 `40001` → `PT409` em 126 RPCs),
  Chat com vários anexos por mensagem (E3, spec 058), leitor "Para você" (B9, spec 059),
  B5 busca de pessoa + B6 pessoa sem conta + imagens de Cardápios em R2 (specs 061–063),
  projeção `can_remove` do Agora, fixture da massa QA R15; Edges `chat-media`,
  `child-safety-media` (v2), `meal-plan-media`, `meal-plan-image-cleanup`, `now-media`,
  `form-media` v23 (`verify_jwt=false`, E14).
- **E2E certificados na rota real**: `chat.attach`, `access-profiles.edit`, `access-profiles.assign`, `institutions.error`, `institutions.access-denied`, `account.profile`, `principal.for-you`, `principal.profile-edit`, `forms.create`, `forms.edit`, `forms.delete-file`, `momentos.create`, `momentos.publish`, `momentos.view`, `momentos.remove`, `child-safety.edit`, `child-safety.suspend`, `agora.expire`, `agora.remove`, `auth.recover`, `auth.reset`, `forms.expire-file`.
- **Owner items → done**: r12-01, 02, 13, 15, 16, 20, 21, 22, 24, 25, 26, 27, 39, 40,
  47, 52 (e os que as sessões fecharam até 16:20; ver checkpoint).
- **Specs** 058, 059, 061–069 escritas (064 e 068 draft-for-review); goldens E4 do
  Principal regravados (25); regra durável PT409 projetada em skills e `docs/knowledge`.

## O que não fechou e por quê

- **Massa/contrato**: `forms.location-answer`, `agora.publish` — ver `R15-checkpoint-20260917.md` (causas por item).
- **Contrato**: conta só de responsável não abre tela nenhuma (shell exige identidade
  interna; Principal sem `institution_memberships`) — OQ-048, spec 064/Etapa 3.
- **Ambiente**: CORS dos buckets R2 restrito (E13, Etapa 3); `superadmin.coelo.me` não existe.
- **Decisão**: prova detalhada do reset de senha (E10) e SMTP próprio → Etapa 3; MFA → pós-MVP.
- **Owner items abertos** (14): Assiduidade (r12-04/05/06/08), Medicação r12-33,
  Conta r12-46, B5/B6/Cardápios r12-17/18/38 (backend em produção; E2E completo pendente),
  Perfis r12-20 (rolagem), Perfis de cuidado r12-29/30, perfil transversal r12-19/23,
  r12-10, r12-49, r12-53.

## Transferência para a R16

Tudo o que está aberto/parcial em `R15-pendencias.md` (Owner items, 19 H, 2 itens da
ADR 0038, 2 ação(ões) não terminal(is)) e os resíduos operacionais atualizados
foram levados para `R16-pendencias.md` com os mesmos IDs. Itens `done` não retornam.

## Git e artefatos

- `dev` = `origin/dev` = `37d762976`; stash vazio; gate PASS DOCUMENTED_PARTIAL.
- Branches e tags remotas apagadas (manifesto `docs/agent/branch-cleanup-manifest-20260917.md`;
  bundle `Coelo-backups/r15-fechamento/coelo-all-refs-20260917-pre-limpeza.bundle`);
  worktrees `r14-*`/`r15-*` removidas.
- Dumps de produção fora do Git em `Coelo-backups/schema-producao-20260917-*.sql`.
