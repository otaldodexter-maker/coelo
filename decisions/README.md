# Catálogo de decisões (ADRs)

As ADRs registram decisões persistentes do Owner. Este README é um roteador; não
substitui o texto da ADR. `accepted`/`approved` descreve a decisão editorial, não
prova implementação. Para o trabalho atual, comece por `docs/agent/current-state.md`.
Ordem de precedência: `docs/agent/source-of-truth.md`.

## Ler primeiro (overlays vigentes por tema)

| Tema | ADR | Regra de leitura |
| --- | --- | --- |
| Definição do MVP e corte Etapa 3 × Etapa 4 | `0045-mvp-definition-etapa3-etapa4-20260918.md` | Etapa 2 fechada; Etapa 3 = correções, tour, acesso contextual, specs 065–069; Etapa 4 = publicação, apps próprios, push preparado, IA; importação/MFA/lojas na V1. |
| Estado da Etapa 2 e critério de medição | `0044-owner-decisions-mesa-r16-20260917.md` | Etapa 2 medida pelo E2E do MVP; 33 ações em `v1`; destinos R16 / Etapa 3 / V1 dos 91 itens. |
| Rodadas (R15 → R16) e repositório só com `dev` | `0043-r15-closure-r16-opening-20260917.md` | R16 vigente; R17 exige decisão do Owner. |
| Contratos e aceites da Mesa R14/R15 | `0041-owner-decisions-r14-mesa-20260916.md`, `0042-r14-closure-r15-opening-20260916.md` | B1–B10, D1–D8, E1–E14 (PT409, massa QA R15, reset por decisão). |
| Backlog de produto decidido na R13 | `0038-owner-decisions-etapa2-backlog-20260914.md` | Não reabrir o que o Owner decidiu. |
| Planos comerciais e Auth | `0039-owner-scope-commercial-plans-auth-stage3-20260915.md` | Planos fora do MVP; recuperação/reset na Etapa 3 (E10: aceito por decisão). |
| Remoção do Agora | `0040-agora-immediate-removal.md` | Revogação imediata + purge R2. |
| Aplicação remota e régua de aceite | `0034-mvp-remote-application-and-acceptance-bar.md` | Produção é o único remoto; rito por lote. |
| Mídia privada | `0032-mvp-private-media-r2.md` | R2 privado master; catálogo/permissões no Postgres. |
| Importação/exportação | `0031-mvp-import-export-buttons-only.md` | Só Formulários exporta no MVP. |
| Principal: host e mídia | `0037-principal-host-context-and-media-controls.md` | Com a ADR 0032 e a spec da superfície. |
| **Etapa 3** (reservada) | `0035-etapa3-mvp-contextual-access-and-app-delivery.md` | Planejamento aprovado; abre só por decisão explícita do Owner, com proposta consolidada. |

## Índice completo (gerado em 17/09/2026 a partir do frontmatter)

| Arquivo | Título | status | lifecycle |
|---|---|---|---|
| `0001-monorepo.md` | Monorepo | Accepted for planning | **current** |
| `0002-product-surfaces-and-subdomains.md` | Product Surfaces And Subdomains | Accepted for planning | **current** |
| `0003-multitenancy.md` | Multitenancy | Accepted for planning | **current** |
| `0004-auth-permissions.md` | Auth Permissions | Accepted for planning | **current** |
| `0005-data-model.md` | Data Model | Accepted for planning | **current** |
| `0006-frontend-architecture.md` | Frontend Architecture | Accepted for planning | **current** |
| `0007-flutter-app-structure.md` | Flutter App Structure | Accepted for planning | **current** |
| `0008-astro-site.md` | Astro Site | Accepted for planning | **current** |
| `0009-design-system-and-tokens.md` | Design System And Tokens | Accepted for planning | **current** |
| `0010-private-media-r2.md` | Private Media R2 | superseded-for-mvp | **superseded** |
| `0011-flutter-routing-performance.md` | Flutter Routing and Performance Foundation | Accepted for implementation | **current** |
| `0012-contextual-experiences-and-conversation-history.md` | Experiencias Contextuais E Continuidade De Conversas | Accepted for planning | **current** |
| `0013-dark-primary-pressed-token.md` | Dark Primary Pressed Token | Accepted for implementation | **current** |
| `0014-contextual-activities-and-delegated-unit-creation.md` | Atividades Contextuais E Criacao Delegada Pela Unidade | Accepted and implemented | **current** |
| `0015-contextual-people-authorizations-attendance.md` | Pessoas Contextuais, Autorizacoes Operacionais E Assiduidade | Accepted | **current** |
| `0016-unit-type-and-plan-inheritance.md` | Tipo Próprio E Herança De Plano Por Unidade | Accepted | **current** |
| `0017-access-profile-governance.md` | Governança de perfis de acesso | accepted | **current** |
| `0018-happens-product-name.md` | Acontece como nome oficial do feed privado | Accepted for planning | **current** |
| `0019-superadmin-internal-identity.md` | Identidade interna exclusiva do Superadmin | accepted | **current** |
| `0022-superadmin-activities-and-identity-storage.md` | Atividades privilegiadas no Superadmin e storage de identidade | approved | **current** |
| `0024-child-safety-private-evidence-storage.md` | Storage privado para evidências de segurança da criança | approved | **current** |
| `0025-forms-private-storage-and-multipart-exports.md` | Storage privado, anonimato e exportações multipart de Formulários | approved | **current** |
| `0026-happens-mvp-private-supabase-storage.md` |  | superseded-by-adr-0032 | **historical** |
| `0027-circulars-private-supabase-storage-and-versioned-feed.md` | Circulares versionadas e mídia privada no Supabase Storage | approved-exception | **historical** |
| `0028-superadmin-agenda-product-surface.md` | Agenda institucional produtiva no Superadmin | approved | **current** |
| `0029-superadmin-agenda-backend-authorization.md` | Autorização do backend produtivo da Agenda no Superadmin | approved | **current** |
| `0030-mvp-private-media-supabase-storage.md` | Mídia privada do MVP no Supabase Storage | superseded | **superseded** |
| `0031-mvp-import-export-buttons-only.md` | Importação e exportação como controles visuais no MVP | approved | **current** |
| `0032-mvp-private-media-r2.md` | Mídia privada de produção no Cloudflare R2 e Stream | approved | **current** |
| `0033-contextual-people-roles-and-family-contexts.md` | Pessoas, papéis contextuais e contextos familiares | approved-for-spec | **current** |
| `0034-mvp-remote-application-and-acceptance-bar.md` | Aplicação remota autorizada e régua de aceite do MVP | approved | **current** |
| `0035-etapa3-mvp-contextual-access-and-app-delivery.md` | Etapa 3 do MVP: acesso contextual de funcionários e entrega dos apps | approved-for-planning-not-implementation | **current** |
| `0036-delivery-reconciliation-and-owner-commitments.md` |  | Accepted | **current** |
| `0037-principal-host-context-and-media-controls.md` |  | accepted | **current** |
| `0038-owner-decisions-etapa2-backlog-20260914.md` |  | accepted | **current** |
| `0039-owner-scope-commercial-plans-auth-stage3-20260915.md` | Decisão do Owner: Planos comerciais fora do MVP e Auth na Etapa 3 | accepted | **current** |
| `0040-agora-immediate-removal.md` | Remoção imediata de publicações do Agora | accepted | **current** |
| `0041-owner-decisions-r14-mesa-20260916.md` | Decisões do Owner na Mesa R14 de 16/09/2026 | accepted | **current** |
| `0042-r14-closure-r15-opening-20260916.md` | Fechamento da R14 e abertura da R15 como fila única (16/09/2026) | accepted | **current** |
| `0043-r15-closure-r16-opening-20260917.md` | Fechamento da R15 e abertura da R16 como fila única (17/09/2026) | accepted | **current** |
| `0044-owner-decisions-mesa-r16-20260917.md` | Decisões do Owner na Mesa R16 (17/09/2026) | accepted | **current** |
| `0045-mvp-definition-etapa3-etapa4-20260918.md` | Definição do MVP e corte entre Etapa 3 e Etapa 4 (18/09/2026) | accepted | **current** |

`0001`–`0009` são a base arquitetural (monorepo, superfícies, tenancy, permissões,
dados, Flutter/Astro, design). ADRs `superseded` permanecem como proveniência.
