---
title: "R14 — checkpoint de 16/09/2026 (segunda onda integrada)"
source: "R14-handoff-sessao-5.md; R14-handoff-sessao-6.md; R14-handoff-sessao-7.md; R14-handoff-sessao-8.md; decisions/0041-owner-decisions-r14-mesa-20260916.md; validate-trackers.cjs em 185a04628"
status: "active"
lifecycle: "current"
generated_at: "2026-09-16"
updated_at: "2026-09-16"
audience: "team"
---

# R14 — checkpoint de 16/09/2026

Corte integrado em `dev` pela coordenadora após a Mesa do Owner (ADR 0041) e a
segunda onda de execução (Sessões 5–8, worktrees `r14/*`). Este checkpoint é
o delta do corte; a fila continua sendo `R14-pendencias.md`.

## Contadores (validate-trackers, `185a04628`)

| Métrica | Antes (Mesa 16/09) | Depois |
|---|---|---|
| FE verificado | 186/232 | **189/232** |
| BE concluído | 168/219 | **171/219** |
| E2E verificado | 159/186 | **162/186** |
| Owner items done | 21/53 | 21/53 |

## action_ids certificados nesta onda (evidência em produção)

- `access-profiles.create` — FE verified, E2E verified-e2e
  (`r14-sessao-5/access-profiles-20260916.md`).
- `agora.create`, `agora.view` — FE verified, BE done, E2E verified-e2e;
  `agora.publish`, `agora.expire` — BE done, FE verified/pending
  (`r14-sessao-7/agora-20260916.md`).
- `agora.remove` — FE local-green (rota de remoção implementada; 67/67 testes);
  BE/E2E pendentes (`r14-sessao-7/agora-remove-20260916.md`).

## Produção

- Lote 72: OQ-046 (ledger reparado para `20260915120000` e
  `20260915130100`), coordenação.
- Lote 73: `20260915203000_forms_question_media_expire_audit_v1` aplicada
  pelo rito (Sessão 6).
- **Pendentes de aplicação** (versionadas, pgTAP verde no espelho, dump prévio
  fora do Git; `db query --linked` negado pelo executor):
  `20260916152000_child_safety_lifecycle_timeout_fix_v1` (D4) e
  `20260916154500_attendance_context_options_activity_scope_v1` (D3).
- **Incidente**: a partir de ~12:28 BRT o PostgREST de produção responde
  `504 PGRST003` (pool esgotado). Causa observada pela Sessão 8 (leitura D1):
  RPCs que sinalizam versão defasada com `raise serialization_failure`
  (SQLSTATE 40001) são reexecutadas sem limite pelo PostgREST 14.5; laços de
  `child_safety_change_lifecycle`, remoção/purge do Agora e Momentos ocupam
  as 10 conexões. Provas de rota real das Sessões 5/6/7 pararam por ambiente.
  Correção sistêmica em `docs/open-questions.md` OQ-047.

## Terceira onda (Sessões 9 e 10, trabalho local — integrada em `74040c470`)

- Sessão 9: cabeçalho global estabilizado via coelo-ui (causa observada:
  `headerProfile` da sessão sem host nos goldens desde `3945394f3`); 30
  referências de Segurança/Rotina/Perfis regravadas (C1); cards de Modelos de
  rotina com altura uniforme, "Efetivo: —" e Arquivar em todos (C3, r12-01);
  B1 Arquivar/Restaurar em Atividades e Rotina (spec 054, migration
  `20260916193000_archive_models_v1`, pgTAP 63/63 no espelho) — r12-01/02/10
  → partial/local-green.
- Sessão 10: B2 Histórico de Assiduidade (spec 052, `20260916180000`, pgTAP
  44/44), B3 snapshot híbrido de rotina (`20260916183000`, pgTAP 43/43), B8
  sino de Medicação (spec 053, `20260916190000`, pgTAP 29/29) — r12-04/06/33
  → partial/local-green.
- Integração: spec/carimbo da Sessão 9 renumerados (052 → 054;
  183000 → 193000) por colisão com a Sessão 10; os dois callbacks do diretório
  de Rotina mantidos; goldens de Rotina e do menu dev regravados pela remoção
  da aba Lançamentos/entrada Histórico (B2). Falhas pré-existentes não
  tocadas: `model_save_completion_routes_test` (3), `principal_real_route_test`
  (1), `principal_profile_for_you_production_routes_test` (1),
  `activity_routes_test` (1) e goldens de outras 30+ suítes (C1 nominal).
- Fila de aplicação em produção (pelo rito, nesta ordem, após D3/D4):
  `20260916180000`, `20260916183000`, `20260916190000`, `20260916193000`.

## Worktrees e branches da onda (disposição)

As seis worktrees `Coelo.worktrees\r14-<fatia>` e as branches
`r14/acessos-instituicoes`, `r14/formularios-chat`, `r14/agora-momentos`,
`r14/seguranca-assiduidade`, `r14/visual-arquivar` e `r14/assiduidade-historico`
(locais e `origin/`) foram integradas em `dev`
por cherry-pick (`809120367..6ddf6a72e` e `82a30f01c..74040c470`); os commits exclusivos são
equivalentes por patch aos integrados. Permanecem protegidas até o
fechamento da R14 para retomada das fatias bloqueadas pelo incidente.

## O que ficou (por causa)

- ambiente (incidente PostgREST): `access-profiles.edit/assign`,
  `institutions.error/access-denied`, `account.profile`/r12-46, `errors.409`,
  `forms.expire-file/delete-file`, `forms.create/edit` (r12-39/40),
  `forms.location-answer`, `chat.attach`/r12-52, `momentos.*`.
- permissão do executor (aplicação em produção): D3/D4 → `child-safety.edit/
  suspend`, r12-13/15/16, contexto Atividade/r12-05; projeção
  `management_version`/`can_remove` para `agora.remove` pela tela; fixture D5.
- massa/decisão: `agora.publish` E2E (nenhuma identidade QA é responsável na
  audiência Famílias; D6 veda massa); `agora.expire` E2E (24 h reais);
  r12-08 (D6).
- contrato (decisão do Owner): mosaico de várias mídias na mesma mensagem do
  Chat não é alcançável pela rota normal (`superadmin_chat_attachment_prepare_v1`
  cria uma mensagem por anexo) — r12-52.
