---
title: "R14 — handoff da Sessão 5 (Perfis de acesso, Instituições, Conta)"
source: "briefing comum da coordenadora (16/09); R14-pendencias.md; ADR 0041; inventario-etapa-2.json"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — handoff da Sessão 5

Sessão 5 (Opus 5), worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-acessos-instituicoes`,
branch `r14/acessos-instituicoes`, base `dev dbe518101`, servidor `127.0.0.1:3016`, Chrome CDP
`9416`, perfil `%TEMP%\coelo-r14-acessos-chrome`. Sem escrita SQL em produção (só PostgREST com a
identidade QA e escrita pela própria tela). Só a Sessão 5 escreve aqui; a coordenadora integra por
cherry-pick.

## Reivindicações

| Tela | action_ids | Owner items | Desde |
|---|---|---|---|
| Perfis de acesso (`/profiles`, `/profiles/new/platform`, `/profiles/platform/:id[/edit]`, `/internal-users/:id/edit`) | access-profiles.create, access-profiles.edit, access-profiles.assign | r12-20, 21, 22, 24, 25, 26, 27 | 16/09 11:40 BRT |
| Instituições › Erro / Acesso negado (`/institutions/:id/edit`) + flyout Arquivos | institutions.error, institutions.access-denied | — (ADR 0041 A4) | 16/09 |
| Conta (`/account`) | account.profile | r12-46 | 16/09 |

## Fatias entregues

| SHA | action_ids → estados | Owner items | Evidência |
|---|---|---|---|
| 89be705fa | (código) Perfis: matriz/revisão/detalhe traduzem módulo › tela › ação do catálogo real; telas com ações repetidas (Modelos de perfil × Admin/Superadmin/Principal) desdobradas por alvo — antes, 12 das 18 permissões de `access` ficavam invisíveis na matriz desktop; cabeçalho do módulo sem estouro em tela estreita; 6 testes de widget novos | — | apps/superadmin/test/features/access_profiles/presentation/access_profile_catalog_labels_test.dart |
| (este) | access-profiles.create FE verified, E2E verified-e2e (BE já done): criação pela rota real, code gerado, readback por PostgREST, reload de /profiles com 8 cards, negativas (P0002 sem mutação; 400 22023). `access-profiles.edit/assign` bloqueados por ambiente (ver Bloqueios). | r12-20, 21, 22, 24, 25, 26(sem mudança), 27 atualizados como partial com o que foi provado (r12-22: create fechado, falta edição) | r14-sessao-5/access-profiles-20260916.md; deltas-access-profiles-20260916.json |
| 63ec6e973 | (código) Perfis: tooltip de sensibilidade também por foco de teclado e para risco elevado; separador › (a seta → não existe na fonte do build web). Instituições: flyout Arquivos avisa "Arquivos em desenvolvimento" (ADR 0041 A4), teste atualizado | — | idem; apps/superadmin/test/features/institutions/presentation/widgets/institution_file_actions_test.dart |

## Avisos para as outras sessões

- 16/09 12:30–12:50 BRT: produção respondeu `504 PGRST003 Timed out acquiring connection from
  connection pool` em TODAS as RPCs (Perfis, Instituições), por mais de 20 minutos, logo após a
  abertura de `/profiles/platform/281699f2…` (detalhe do perfil). Não sei se a causa foi esse
  detalhe ou carga de outra sessão (o 504 de `child_safety_change_lifecycle` é conhecido). Se
  alguma sessão estiver repetindo a RPC de Segurança infantil, isso esgota o pool para todas.
- Massa criada em produção: perfil Superadmin `R14 S5 Perfil QA` (`281699f2-9399-40b4-a5c7-6d51f37a8a71`,
  code gerado `r14-s5-perfil-qa-46749519`, 1 capacidade `institution.role_models.read`).
- O catálogo real devolve `screen_label` em inglês para várias telas (`Directory`, `Management`,
  `Files`…) e `module_label` de `meal_plans` com codificação errada (`CardÃ¡pios`). O FE cobre com
  tradução local dos códigos; a correção do catálogo no BE é resíduo (não bloqueia).

## Sobra para a R15

- Se o pool não voltar nesta sessão: `access-profiles.edit/assign` (rota real de edição em
  `/profiles/platform/281699f2…/edit`, atribuição em `/internal-users/bf6008f0…/edit` com restauração do
  Owner), capturas de r12-24 (foco), r12-25 (~600 px), r12-26 (Continuar na edição), r12-27 (revisão com ›)
  e detalhe r12-21 — tudo no build `63ec6e973`, já pronto em `build/web`.
- BE (resíduos, sem bloqueio): `superadmin_access_profile_save`/`_detail` com id inexistente devolvem
  `500 P0002` (mapear para 404/422); `superadmin_access_profiles_list` devolve `{items,next_cursor}` enquanto
  o cliente lê `total/page`; catálogo com `screen_label` em inglês e `module_label` `CardÃ¡pios`;
  `linked_people_count` dos perfis Superadmin conta `platform_memberships` e mostra "Vínculos 0" para Owner.
- Instituições (`institutions.error/access-denied`), Conta (`account.profile`/r12-46) e `errors.409` não
  foram iniciados na rota real (bloqueio de ambiente). Preflight CORS da Edge `account-media`: origem
  `http://127.0.0.1:3016` → 403 `origin_not_allowed`; `3014` → 200. A prova de upload da Conta exige
  servir em 3014 ou incluir 3016 em `COELO_ALLOWED_ORIGINS` (decisão da coordenação).

## Bloqueios

- **ambiente** — pool de conexões de produção esgotado (PGRST003) a partir de 12:30 BRT; bloqueia
  reload do detalhe, edição, atribuição e as demais fatias até o pool voltar. Gate afetado: E2E de
  `access-profiles.*`, `institutions.*`, `account.profile`.

## Contadores

`validate-trackers.cjs` PASS: FE 187/232, BE 168/219, E2E 160/186 (access-profiles.create), Owner 21/53
(linhas r12-20/21/22/24/25/27 atualizadas como partial). `entrega-atual.json` e `R12-owner-items.json`
foram regravados pelo `sync-r12-owner-records.cjs` (projeção), não à mão.
