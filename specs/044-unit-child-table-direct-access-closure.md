---
title: "Acesso direto às tabelas filhas de Unidade — bloqueio de proveniência"
source: "AGENTS.md; decisions/0016-unit-type-and-plan-inheritance.md; decisions/0019-superadmin-internal-identity.md; specs/017-superadmin-unit-schema-foundation.md; specs/039-superadmin-internal-auth-session-context.md; specs/043-superadmin-internal-unit-detail-v2.md; ledger e catálogo remotos Coelo consultados somente por SELECT em 2026-08-28; reviews Eng Sup de 2026-08-28"
status: "blocked-provenance"
generated_at: "2026-08-28"
---

# Acesso direto às tabelas filhas de Unidade — bloqueio de proveniência

## Objetivo

Registrar por que o Design A de fechamento direto de
`public.unit_addresses` e `public.unit_contacts` não pode ser implementado,
testado como GREEN ou promovido a deploy a partir do baseline canônico atual.

Este documento substitui o draft inicialmente marcado como
`approved-for-implementation`. A decisão superveniente de 2026-08-28 congelou
o Design A em `blocked-provenance`. Nenhuma migration, policy, grant, função ou
aplicação Flutter é autorizada por esta spec.

## Baseline remoto comprovado

A consulta read-only ao projeto remoto Coelo comprovou:

- `units.read` existe, está ativa, não exige MFA pelo catálogo e possui grants
  `allow` ativos e não revogados para Owner e Operations;
- `public.unit_addresses` e `public.unit_contacts` estão com RLS habilitada e
  forçada, possuem `SELECT` para `authenticated` e policies
  `unit_addresses_authorized_read` e `unit_contacts_authorized_read`;
- ambas as policies resolvem a instituição da Unidade e chamam
  `app_private.has_scoped_platform_permission('units.read', institution_id)`;
- o helper pertence ao realm legado: deriva `current_person_id()`, consulta
  `platform_memberships`, papel, grant/override, escopo institucional e MFA da
  membership; ele não valida o principal interno nem `auth.sessions` conforme
  a spec 039;
- existe alcance SQL para um ator legado válido que satisfaça capability,
  membership, escopo e MFA aplicável. Não há prova comportamental de exploração
  HTTP nem de acesso cross-tenant fora desse escopo;
- `service_role` mantém ACL direta ampla nas duas tabelas.

Portanto, a premissa anterior de policy global por `platform.read`, RLS não
forçada ou capability `units.read` ausente estava incorreta para o remoto. O
estado é um gap de cutover entre o realm legado e o contrato interno, não um
incidente cross-tenant remoto demonstrado.

## Proveniência individual de Units

| Versão | Estado comprovado | Fonte recuperável | Classificação |
| --- | --- | --- | --- |
| `20260811214000` | 140 statements remotos | blob original `c8f1f45edfd99591f1dd85586ca52644bd0e4b35`, commit/tree `aeb72024305578017006e344f091c79b205c7156` | deployed-equivalent 140/140; não equivale ao hardening `a6a2bec5...` |
| `20260811214500` | 50 statements remotos | blob `15a10f55fb1ed096de49c2d19c98cca3b992e79e` | deployed-equivalent 50/50 |
| `20260811214600` | 4 statements remotos | blob `dca067c922ccbccd6175c24161ef284878fe713f` | deployed-equivalent 4/4 |
| `20260811215451` | 115 statements remotos | nenhuma variante inspecionada é equivalente | `text-conflict`; não restaurar por nome |

A versão `20260811214000` também materializou `units.read/create/update`,
RPCs legadas, `public.unit_types`/subtypes e renomeou
`units.institution_type_id` para `units.unit_type_id`. O remoto atual mantém
`unit_type_id NOT NULL` com FK para `unit_types(id)`.

Esse modelo conflita com ADR 0016, spec 017, spec 043 e a migration local de
DETAIL v2, que usam `institution_type_id` e `institution_types`. A migration
`20260828002000_superadmin_internal_unit_detail.sql` continua `local-green`
contra o canônico local, mas sua precondição física falha no remoto. Ela está
`blocked-schema/provenance`, não `remote-green`, não deployable e não regredida.

## Dependência Profile/About

O único writer versionado encontrado para `unit_contacts` é
`public.save_profile_about(...)`. Sua proveniência remota foi fechada
individualmente:

- `20260821192000` corresponde 35/35 ao blob hardened
  `4e3a89b3876bc4edf0901e8b1a596159d3d5944a`, commit
  `3a19cf7b46fed55774193fd98f3d8b68e25f43d3`; o blob original
  `e8c2086e...` tem 33 statements e não foi o implantado;
- `20260821200000` corresponde 5/5 ao blob
  `17096406520b2d009892ab93625a79b732860352`, commit
  `de0fb2da79b4755c37675bef69e7686ee1904227`;
- `20260825193131`, blob `a53cdc0f...`, commit `08ef9dc4...`, é local-only
  e regride o contrato implantado de draft, publicação separada, AAL2 e erro
  seguro. Não pode ser usado no replay nem restaurado como hardening.

O writer implantado é `SECURITY DEFINER`, owner `postgres`, `search_path=''` e
executável por `authenticated`, mas continua derivando autoridade de
`current_person_id()` e do realm `people`. Receipt, revisions e autoria também
usam `actor_person_id`. Ele não é uma ponte autorizada para o principal interno
da spec 039 e seu upsert de contato não participa do protocolo
`units.management_version`.

## Classificação de risco

- **P0 de release/cutover:** o draft anterior não reconhecia policies, grants,
  capability e schema físicos remotos; qualquer SQL baseado nele poderia
  falhar ou alterar autorização incorretamente.
- **P0 de precondição:** DETAIL v2 local referencia colunas e catálogo ausentes
  no remoto atual.
- **P0 de autoridade:** RPCs Units e Profile/About implantadas pertencem ao
  realm pessoa e não podem autorizar o principal interno.
- **P1 de acesso direto:** o Data API continua disponível para atores legados
  válidos com `units.read`; isso contorna o gateway auditado interno, mas não há
  prova de BOLA/cross-tenant fora do escopo do helper.
- **P1 de concorrência:** `save_profile_about` escreve contato fora do
  versionamento de Units.

## Impacto nas telas

- **Unidades — detalhe/reload:** permanece local-green no backend local, porém
  bloqueado para aplicação remota pelo drift de schema e autoridade.
- **Unidades — listar/criar/editar/status:** permanecem fail-closed no Flutter
  produtivo e sem contrato interno aprovado; `units.read/create/update` remotas
  não autorizam reutilização das RPCs legadas.
- **Perfil/Sobre — contato da Unidade:** o writer remoto existe para o realm
  legado, mas não pode ser tratado como writer do Superadmin interno.

## Ações proibidas enquanto bloqueado

- não revogar, substituir ou criar policies/grants das tabelas filhas;
- não alterar `has_scoped_platform_permission` nem criar OR entre realms;
- não restaurar migrations por nome ou promover recoveries em lote;
- não criar migration de rename/compatibilidade entre os dois catálogos;
- não alterar a spec 043 nem declarar DETAIL remoto/deployable;
- não usar `20260825193131` no staging;
- não executar migration, deploy ou mutação remota.

## Gates para retomar o Design A

1. decisão documental entre `unit_types/unit_type_id` e
   `institution_types/institution_type_id`, incluindo dados, FKs e índices;
2. reconciliação forward-only das migrations implantadas ausentes do HEAD, uma
   versão por vez e sem reescrever ledger;
3. contrato explícito de coexistência/cutover dos realms legado e interno;
4. writer de contato com autoridade, idempotência, versão e auditoria tipadas;
5. inventário de consumidores externos e gateways nominais;
6. novo RED, replay real, negativos cross-app/cross-tenant, regressões e review
   P0/P1 antes de qualquer promoção.

## Estado e evidência

- ambiente remoto consultado: projeto Coelo, somente catálogo e ledger;
- zero retorno de payload de negocio, PII ou dado infantil;
- zero escrita, migration, deploy, Docker ou alteração Flutter;
- Design A: `blocked-provenance/drift`;
- DETAIL v2: `local-green + blocked-schema/provenance`;
- progresso integrado/E2E: inalterado.

Gate de conhecimento: `no-op`. Esta spec e OQ-032 são as fontes canônicas da
divergência; nenhum comportamento implantado novo foi projetado em
`docs/knowledge`.

## Evidência executável de proveniência — 2026-08-31

O inventário remoto SELECT-only confirmou o contrato físico divergente sem
consultar linhas de negócio: `public.units.unit_type_id uuid not null` referencia
`public.unit_types(id)` e possui `units_unit_type_id_idx`; não existe
`units.institution_type_id` nesse ambiente. O perfil local aprovado continua com
`units.institution_type_id uuid not null`, FK para `institution_types(id)` e
`units_institution_type_id_idx`.

A migration forward-only local
`20260831164937_assert_unit_hierarchy_contract.sql` adiciona somente o guard
privado `app_private.assert_unit_hierarchy_contract()`. Ele é `SECURITY INVOKER`,
usa `search_path=''`, não pode ser executado por `anon`, `authenticated` ou
`service_role` e falha com SQLSTATE `55000` quando os contratos forem misturados.
O guard não renomeia colunas, não migra dados, não cria compatibilidade, não
altera policy/grant de tabelas e não resolve OQ-032 silenciosamente.

O RED comprovou a ausência do guard no replay anterior. O GREEN aplicou 52
migrations canônicas e dois preflights até `20260831164937`; a regressão passou
11 arquivos pgTAP/284 asserts. O remoto permaneceu sem mutação e continua
`blocked-environment`; esta prova reduz o risco de aplicação acidental, mas não
remove nenhum dos seis gates para retomar o Design A.
