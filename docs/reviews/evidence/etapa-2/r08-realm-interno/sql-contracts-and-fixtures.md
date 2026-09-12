---
title: "R08 G5 — contratos SQL, fixture expirada e candidato H09"
source: "R08-plano.md G5; migrations dos lotes 49–55; suites pgTAP"
status: "ACL aprovada no espelho por G0; candidato H09 não aplicado"
generated_at: "2026-09-12T11:06:41-03:00"
---

# Contratos SQL e fixtures

## ACL/RLS e função compartilhada

Ambiente observado: `origin/dev`/worktree após lote 55, somente arquivos. Não
houve Docker, conexão ao espelho ou consulta de produção. Portanto os números
abaixo são planos de teste, não resultados atuais:

| Ordem | Suíte | Plano | Cobertura relevante |
| --- | --- | ---: | --- |
| 1 | `principal_internal_actor_bridge_v1_test.sql` | 22 | ponte base, grants e idempotência |
| 2 | `internal_actor_scope_root_v1_test.sql` | 46 | raiz platform/institution, isolamento, revogação e ACL |
| 3 | `internal_actor_scope_root_v1_hotfix_test.sql` | 4 | reativação do espelho sem reativar escopo alheio |
| 4 | `internal_actor_institution_access_by_role_v1_test.sql` | 16 | consumidor compartilhado do lote 55 e troca/revogação por papel |

A revisão confirma a composição forward-only: `210000` fecha a raiz do
escopo; `210100` remove o filtro de status somente na seleção do alvo e
preserva as condições de escopo; `130400` substitui o sincronizador para
mapear Owner/Operations a papéis institucionais e continua reutilizando o alvo
da raiz. `anon` e `authenticated` não recebem execução direta do sincronizador.

Ordem exigida no espelho: baseline e fila real até lote 49; lotes 50–55 na
ordem do ledger; então as quatro suítes acima. Uma falha em qualquer suíte
impede usar este documento como aceite. O papel relacionado ao caso 180060
não foi reaberto.

Recibo G0 `b1ec76b120d62557e457749adc100940c0c039c1`: no baseline local
`supabase_db_coelo_baseline`, materializado até o lote 55, as quatro suítes
passaram na ordem acima em **22/22 + 46/46 + 4/4 + 16/16**, todas com exit
nativo 0, wrapper 0 e rollback. O preflight de definições finais passou 20/20.
Os logs integrais pertencem a
`docs/reviews/evidence/etapa-2/r08-ambiente-runtime/` naquele commit. Esta
frente não reexecutou nem soma o resultado como execução própria.

## Consulta de diagnóstico H09

O repositório contém `app_private.sweep_expired_now_publications(uuid,integer)`
e o acionamento manual com escopo, mas nenhum job versionado. Antes de aplicar
o candidato, C0 deve registrar o resultado sanitizado no espelho e em produção:

```sql
select jobid, jobname, schedule, command, active
from cron.job
where jobname = 'coelo-now-publications-expire'
   or command like '%sweep_expired_now_publications%';
```

O candidato `20260912140545_now_publication_expiry_dispatch_v1.sql` deve ser o
primeiro item deste grupo no lote 56. Ele falha com `55000` sem `pg_cron` ou
sem o sweep, substitui somente o job nominal e agenda chamada limitada a 500
itens a cada cinco minutos. Leituras continuam fail-closed no intervalo; o
sweep materializa estado e auditoria e não apaga publicação ou mídia R2.

O mesmo preflight G0 confirmou `pg_cron`, `cron.job` e o sweep no espelho e
retornou zero job por nome/comando. Isso fecha a reprodução local do H09; a
consulta de produção, backup, aplicação e ledger continuam exclusivos de C0.

O teste `now_publication_expiry_dispatch_v1_test.sql` tem seis casos
declarativos. Ele foi preparado, mas não executado por ausência do espelho
liberado; não há alegação de pgTAP verde.

## Fixture segura de convite expirado para G2

`superadmin_internal_invites_v2_test.sql` já cria identidade interna Owner,
sessão AAL2, instituição, perfil e convite sintéticos dentro de `begin` /
`rollback`. A fixture força `expires_at = now() - interval '1 minute'`, chama
`superadmin_invite_resend_v2` com request id
`9d100000-0000-4000-8000-000000000603` e versão esperada 1.

Foram acrescentados casos para exigir:

- primeiro retorno não-replay com link efêmero, novo estado `pending` e
  validade futura;
- recibo idempotente com `result_json.link = null`, sem persistir o token em
  claro.

O token não é impresso pela suíte e todo o arranjo é revertido. O plano passou
de 33 para 35. G2 pode usar os IDs acima apenas no espelho transacional, nunca
como dado permanente ou credencial.

Primeiro replay G0: 34/35, native 0, wrapper 1 e rollback. Os três casos novos
do convite expirado passaram; a única falha era a asserção histórica de
`platform.invites.manage.requires_mfa = true`, incompatível com a migration
vigente que adiou MFA no MVP e com o caso AAL1 já presente na própria suíte.
A expectativa foi corrigida para `false`. No recibo G0
`0a9811a86e94cdca4cc425c85bc1d73042f8dd41`, o rerun focal passou em
**35/35**, native 0, wrapper 0 e rollback. A falha intermediária permanece
registrada, sem ser somada ao resultado final.
