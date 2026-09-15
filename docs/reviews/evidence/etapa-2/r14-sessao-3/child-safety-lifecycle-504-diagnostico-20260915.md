---
status: blocked-mirror
lifecycle: current
round: R14
session: 3
owner_items:
  - owner.r12-13
  - owner.r12-15
  - owner.r12-16
action_ids:
  - child-safety.create
  - child-safety.edit
  - child-safety.suspend
environment: espelho-local
recorded_at: 2026-09-15T13:20:00-03:00
---

# Segurança infantil — diagnóstico do 504

## Achados

- `app_private.child_safety_change_lifecycle(uuid,uuid,bigint,text,text)` existe
  no espelho com `SECURITY DEFINER`, `search_path` vazio, guarda de AAL/ator,
  lock de idempotência por `request_id`, lock de linha, atualização versionada,
  auditoria e recibo.
- A chamada inválida, com ator inexistente e `statement_timeout='5s'`, retornou
  `child safety lifecycle unavailable` em aproximadamente 1 segundo. O guard
  inicial não reproduziu timeout.
- A suíte nominal `child_safety_platform_decision_v1_test.sql` parou antes da
  massa child safety: o trigger `app_private.coelo_profile_follow_trigger()`
  chamou `coelo_profile_follow_sync()` e tentou inserir em `follow_links` o
  follower `c0e10000-0000-4000-8000-000000000001`, inexistente em `people`.
- A suíte estrutural `child_safety_production_test.sql` também encontrou drift
  do espelho (capability `child_safety.export`, ACL de mutação/RPC e bucket) e
  terminou com consulta incompatível (`pg_policy.schemaname` inexistente).
- O espelho não contém massa válida de autorização (`authorized_person_authorizations`
  estava sem linhas), e não foi criado um fixture alternativo nem desabilitado
  trigger para “alcançar” a função. Nenhum SQL foi executado em produção.

## Conclusão operacional

O 504 ainda não tem causa raiz isolada: a base espelho não consegue atravessar o
fixture nominal e não oferece transação válida para medir o caminho de lifecycle.
Os pontos que exigem próxima investigação, sem inferência, são a massa/trigger
`coelo_profile_follow_sync`, a espera dos advisory locks (`request_id` e cadeia
de auditoria) e o contrato/ACL publicado no ambiente que respondeu 504. A fatia
`child-safety.create/edit/suspend` fica bloqueada até rebaseline do espelho ou
autorização nominal para um rito espelho corrigido.

