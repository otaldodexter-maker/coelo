---
title: "R14 — handoff da Sessão 3 (Bloco C)"
source: "R14-execucao-paralela.md; R14-pendencias.md; inventario-etapa-2.json"
status: "blocked-with-local-progress"
lifecycle: "current"
generated_at: "2026-09-15"
updated_at: "2026-09-15"
audience: "team"
---

# R14 — handoff da Sessão 3

Sessão 3, worktree `C:\Users\adrie\Documents\Coelo.worktrees\r14-c`, branch
`r14/bloco-c`, servidor `127.0.0.1:3016`, Chrome CDP solicitado `9416`.
Antes da retomada, a pasta principal foi atualizada com
`git pull --ff-only origin dev`; `origin/dev` confirmado em `5839a0ef2`, que
também era o HEAD limpo da worktree. Esta sessão não edita os handoffs das
Sessões 1 e 2.

Após a retomada, a worktree foi sincronizada com avanço fast-forward publicado
pelas demais sessões; `origin/dev` atual é `e592063d6`.

## Reivindicações e liberações

| Tela | action_ids | Owner items | Estado ao liberar |
|---|---|---|---|
| Avaliações › Fechar/Reabrir | `assessments.close`, `assessments.reopen` | `owner.r12-49` | liberada; sem promoção E2E |
| Segurança infantil | `child-safety.create`, `child-safety.edit`, `child-safety.suspend` | `owner.r12-13`, `owner.r12-15`, `owner.r12-16` | liberada; diagnóstico/prova local concluídos, rota pendente |
| Perfis de acesso | `access-profiles.create`, `access-profiles.edit`, `access-profiles.assign` | `owner.r12-19` a `owner.r12-27` | liberada explicitamente; nenhuma mutação real confirmada |
| Arquivos de Formulários | `forms.expire-file`, `forms.delete-file` | fila R14 | liberada; prova local, sem promoção de rota/worker |

## Apoio de acesso QA remoto

O fluxo oficial `internal-user-create` foi executado na rota real autenticada
para destravar a validação do Bloco C. O usuário sintético
`qa-r14-c-owner-20260915@coelo.me` foi criado no Auth remoto do projeto
`evvbomzejfijozbtgvpt`, UID `edb2c331-8b64-4779-a084-d32646eb415d`, às
2026-09-15 16:23:20 (horário exibido pelo dashboard). A tela de detalhe
confirmou `QA R14BlocoC`, cargo `QA-Owner-R14-C`, perfil `Owner`, alcance
`Global à plataforma`, convite pendente e credencial `Sem acesso`.

Action ID contratual: `superadmin.internal-users.create` (a UI não expôs o
correlation/action UUID individual; nenhum identificador foi inventado). A
senha não foi definida e o link seguro de definição não foi copiado nem
registrado. Esta criação é massa de apoio e não certifica, por si só,
`access-profiles.create/edit/assign` nem os Owner items do Bloco C.

## Commits e provas

| SHA | Conteúdo | Evidência |
|---|---|---|
| `0cbcf19f8`, `abdc2fbee`, `6d9210d19` | assessments close/reopen e bloqueio por alvo CDP divergente | `r14-sessao-3/assessments-close-reopen/assessments-close-reopen-20260915.md` e `deltas-revert-unverified-target-20260915.json` |
| `544a2b899` | fixtures nominais para o follower global exigido pelo espelho em child-safety e Forms; compatibilidade PG17 nos testes de policy; expectativa obsoleta do consumidor de modelos removida | `docs/reviews/evidence/etapa-2/r14-sessao-3/bloco-c-local-20260915.md` |

### Child safety

O 504 de `child_safety_change_lifecycle` foi diagnosticado primeiro no
espelho. A causa alcançada foi drift de massa/estrutura: o trigger de
`follow_links` exigia a pessoa global
`c0e10000-0000-4000-8000-000000000001`. O fixture foi adicionado somente aos
testes. No espelho foram rebaselineadas as migrations publicadas
`20260910170500`, `20260910170600`, `20260910170700`, `20260910171800`,
`20260910171900` e `20260910172100`. A `20260910172000` não foi forçada porque
o guard Owner acusou capacidades não relacionadas ausentes.

Resultados no espelho: `child_safety_platform_decision_v1_test.sql` 25/25 e
`child_safety_production_test.sql` 63/63. Não houve SQL em produção, mudança de
ledger ou fixture para mascarar timeout. O 504 não se reproduziu após o
rebaseline, mas isso não é prova E2E.

### Forms

Sem repetir `forms.upload`/`forms.resolve-file`, que já estão certificados na
prova publicada da Sessão 1, foram executados no espelho:

- `forms_question_media_terminal_unbind_v1_test.sql`: 7/7;
- `forms_question_media_retry_delete_v1_test.sql`: 9/9.

Esses testes cobrem expiração, delete, mismatch, unbind, retry idempotente e
negativa cross-tenant; não certificam worker físico nem rota autenticada.

### Access profiles

`model_command_consumer_test.dart` passou 9/9. O ajuste remove a expectativa
de preencher “Código”, pois o contrato atual gera o identificador técnico no
backend e não expõe esse campo no formulário. Não houve create/edit/assign real
confirmado; não foi iniciada atribuição em `/internal-users/:id/edit`.

O usuário QA Owner remoto acima ficou disponível para uma retomada autenticada;
o cadastro usado para destravar o acesso não foi contado como prova dos três
action_ids de perfis.

## Bloqueios e sobra para R15

- A prova remota de criação de usuário foi concluída, mas o servidor prescrito
  `127.0.0.1:3016` não está na allowlist CORS do Edge Function remoto: o
  preflight retornou 204 sem `Access-Control-Allow-Origin`. Para não alterar
  produção por inferência, a mesma rota foi exercitada em `127.0.0.1:3014`,
  origem já allowlisted. O ajuste governado da origem 3016 e a repetição das
  provas autenticadas continuam para R15; o CDP efetivamente disponível foi
  9415, não 9416.
- O usuário QA Owner está com convite pendente e sem credencial ativa. Ainda
  não houve handoff de senha ao usuário nem mudança de senha por automação.
- Repetir `assessments.close/reopen` no alvo autenticado estável usando o mesmo
  diário `d2c945d8`, sem duplicar participante, vínculo, configuração ou diário.
- Executar `access-profiles.create/edit/assign` após confirmar ausência de
  reivindicação ativa conflitante e registrar o `action_id` real.
- Executar `child-safety.create/edit/suspend` na rota normal após massa/contrato
  QA autorizados, incluindo escopo e reload.
- Promover `forms.expire-file/delete-file` somente com prova de comando
  autoritativo, auditoria e worker/rota conforme a fila; não repetir
  upload/resolve sem nova falha.

As telas não concluídas ficam explicitamente liberadas para a próxima sessão:
`assessments.close/reopen`, `access-profiles.create/edit/assign`,
`child-safety.create/edit/suspend` e `forms.expire-file/delete-file`. A criação
da massa QA acima está concluída, mas não promove nenhuma dessas telas nem
altera os contadores centrais.

## Contadores e arquivos não alterados

Contadores locais: FE 184/231, BE 166/224, E2E 157/192 e Owner 15/53.
`node docs/reviews/validate-trackers.cjs` foi mantido como gate anterior e os
arquivos de coordenação não foram alterados. Não foram alterados cabeçalho ou
contadores da R14, `current-state.md`, checkpoint ou `entrega-atual.json`.
