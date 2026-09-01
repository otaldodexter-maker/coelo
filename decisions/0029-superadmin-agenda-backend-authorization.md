---
title: "Autorização do backend produtivo da Agenda no Superadmin"
source: "ordens explícitas do Owner Coelo na conversa Finalização de Telas Operações em 2026-09-01; decisions/0028-superadmin-agenda-product-surface.md; specs/006-comunicacao-agenda.md"
status: approved
generated_at: "2026-09-01"
---

# ADR 0029 - Autorização do backend produtivo da Agenda no Superadmin

## Contexto

A ADR 0028 autorizou a superfície produtiva da Agenda exclusivamente no
Superadmin, mas limitou a entrega anterior a Flutter, UI e fixtures de `/dev`.
Em 2026-09-01 o Owner determinou explicitamente a conclusão ponta a ponta das
telas de Operações, incluindo Supabase, CRUD e RLS.

## Decisão

Fica autorizada a implementação do backend produtivo da Agenda em
`packages/coelo_database` e sua integração em `apps/superadmin`, mantendo
`apps/admin` e `apps/principal` fora deste recorte.

O backend deve:

- usar tabelas expostas com RLS deny-by-default e acesso do cliente somente por
  RPCs públicas mínimas;
- revalidar Auth, ator interno, capability, contexto e tenant em toda leitura e
  escrita;
- preservar lifecycle, recorrência, audiência, respostas, solicitações de
  publicação, histórico e idempotência definidos na spec funcional;
- impedir exclusão de eventos publicados, conflito de reserva não autorizado,
  IDOR e acesso cross-tenant;
- registrar recibos imutáveis para mutações e decisões sensíveis;
- não persistir perguntas que solicitem dados sensíveis e limitar o catálogo a
  resposta curta e Sim/Não;
- manter aniversários derivados, minimizados e sem ano de nascimento.

## Consequências

- `specs/050-superadmin-agenda-backend.md` passa a ser o contrato técnico do
  backend.
- A limitação de backend da ADR 0028 permanece como registro histórico, mas é
  superada por esta decisão para a Agenda no Superadmin.
- Rotas produtivas só deixam de ser fail-closed quando a evidência remota de
  autorização, isolamento e persistência estiver concluída.
