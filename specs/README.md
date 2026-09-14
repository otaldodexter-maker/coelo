# Catálogo de specs

As specs descrevem escopo e contratos; status de spec não prova implementação
FE/BE/RLS/E2E. Para a fila corrente, comece por
`docs/agent/current-state.md`. Para regras que mudaram depois da spec, consulte
`docs/agent/source-of-truth.md` e as ADRs atuais antes de implementar.

## Fundação e contratos já registrados

`001-site-publico-astro.md`, `002-auth-multitenant.md`,
`003-superadmin-core.md`, `004-admin-instituicao.md`, `005-principal-app.md`,
`006-comunicacao-agenda.md`, `007-design-system-base.md`,
`008-lgpd-seguranca-midia.md`, `009-media-r2-spike.md`,
`011-superadmin-database-rls.md`, `013-ui-packages-componentization.md`,
`014-atividade-contextual.md`, `015-contextual-people-access-attendance.md`,
`017-superadmin-unit-schema-foundation.md`, `019-superadmin-people-directory.md`,
`020-superadmin-attendance-prototype.md`, `020-superadmin-health-care.md`,
`021-superadmin-daily-routine-prototype.md` e
`023-superadmin-internal-users-local-preview.md`.

Esses arquivos misturam fundação, protótipo e contrato. Leia o frontmatter e a
evidência indicada; “implemented”, “validated” ou “approved” não significa
aceite ponta a ponta.

## MVP/Etapa 2 e contratos aprovados

`012-superadmin-mvp.md`, `018-profiles-permissions-superadmin.md`,
`022-superadmin-plans-ui.md`, `027-superadmin-audit-production.md`,
`028-superadmin-conversations-production.md`,
`030-superadmin-child-safety-production.md`,
`036-principal-now-publication-mvp.md`, `037-principal-circulars.md`,
`038-attendance-responsive-dashboard.md`,
`039-superadmin-internal-auth-session-context.md`,
`040-superadmin-internal-institution-read-v2.md`,
`041-superadmin-internal-institution-list-filter-v2.md`,
`042-superadmin-internal-institution-edit-core-v2.md`,
`043-superadmin-internal-unit-detail-v2.md`,
`045-superadmin-internal-group-detail-v2.md`,
`046-superadmin-internal-person-detail-v2.md`,
`050-superadmin-agenda-backend.md`, `050-principal-ui-ux-closure.md` e
`051-superadmin-plans-production.md`.

As ADRs posteriores podem restringir esses contratos: em particular, ADR 0031
adia importações/exportações gerais, ADR 0032 substitui o desenho de mídia por
R2 privado, ADR 0034 separa estado documental de aceite real e ADR 0038 altera
regras da fila R13. `plans.assign` fica fora do MVP até nova decisão.

## Planejamento, futuro ou bloqueio

- `010-superadmin-completo-v1-technical-spec.md`: desenho amplo histórico; não
  é a fila atual.
- `016-superadmin-support-prototype.md`: design/protótipo.
- `044-unit-child-table-direct-access-closure.md`: bloqueada por proveniência.
- `047-superadmin-internal-invite-detail-v2-draft.md`,
  `048-superadmin-internal-attendance-call-detail-v2-draft.md` e
  `049-superadmin-internal-care-profile-crud-v2.md`: rascunhos para revisão.
- `009-media-r2-spike-checklist.md`: checklist de spike já concluído; não é
  contrato de implementação.

## Regras do catálogo

Os prefixos numéricos `020` e `050` aparecem em dois arquivos diferentes. O
nome completo do arquivo é o identificador, não o número isolado. Lacunas de
numeração não autorizam criar specs novas nem reutilizar referências quebradas.
Referências a specs ausentes devem ir para `docs/open-questions.md` ou ser
corrigidas para o caminho canônico, mantendo proveniência histórica quando
necessário.
