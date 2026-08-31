---
title: "Agenda institucional produtiva no Superadmin"
source: "decisão explícita do Owner em 2026-08-31; docs/product/prd-master.md; docs/product/prd-superadmin.md; docs/product/prd-admin.md; docs/product/prd-app.md; docs/architecture/domain-map.md; specs/006-comunicacao-agenda.md"
status: approved
generated_at: "2026-08-31"
---

# ADR 0028 - Agenda institucional produtiva no Superadmin

## Contexto

Os PRDs originais posicionavam a Agenda na experiência cotidiana do Admin e do
Principal e excluíam sua operação institucional rotineira do Superadmin. O
repositório, porém, possui o protótipo Flutter de Agenda em `apps/superadmin`, e
o Owner aprovou em 2026-08-31 a mudança explícita de superfície para o recorte
atual do produto.

A divergência altera o escopo produtivo de três aplicações e, portanto, não
pode ser resolvida silenciosamente.

## Decisão

A Agenda institucional produtiva do recorte atual existe exclusivamente em
`apps/superadmin`. Referências anteriores à Agenda produtiva em `apps/admin` e
`apps/principal` ficam preservadas como histórico e possibilidade futura, mas
não autorizam implementação nessas aplicações.

O contrato funcional e de UI está em `specs/006-comunicacao-agenda.md`. A
Agenda continua sendo o domínio D13 e não absorve a fonte de verdade de
Autorizações formais do domínio D14. Ela pode compor RSVP, ciência e autorização
simples vinculados ao evento, preservando ownership, evidência, revogação e
auditoria formais no domínio responsável.

Esta decisão autoriza Flutter/Dart, UI/UX e fixtures determinísticas de `/dev`.
Não aprova banco, Supabase, Auth, RLS, RPC, migration, Edge Function, Storage,
deploy nem contrato backend novo. Enquanto a integração não existir, as rotas
produtivas exibem a mesma composição visual e permanecem fail-closed nas ações
que dependem de persistência ou autorização remota.

## Referência visual vinculante

A anatomia visual aprovada corresponde a
`docs/design/references/superadmin-agenda-approved-2026-08-31.png`, 1536 × 1024,
SHA-256 `8ce5ef455644280326851add9c97d2add83065f7ebdab80fc22b448ef266227f`.

A implementação usa shell, containers, tokens e componentes canônicos Coelo; a
imagem não autoriza aproximações Material genéricas.

## Consequências

- `apps/superadmin` é a única superfície produtiva autorizada nesta versão.
- `apps/admin` e `apps/principal` não recebem rotas ou telas produtivas de Agenda.
- `/dev` e produção compartilham composição; somente `/dev` usa fixtures locais.
- A Agenda não incorpora agendamentos de Formulários.
- Os PRDs recebem aditivos explícitos que prevalecem sobre suas seções antigas
  de Agenda no recorte atual.
- Uma expansão futura para Admin ou Principal exige nova decisão aprovada.

