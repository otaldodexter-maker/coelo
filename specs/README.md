# Catálogo de specs

As specs descrevem escopo e contratos; status de spec **não** prova implementação
FE/BE/RLS/E2E. Para o trabalho corrente, comece por `docs/agent/current-state.md`;
para regras que mudaram depois da spec, `docs/agent/source-of-truth.md` e as ADRs
vigentes (`decisions/README.md`) mandam. `status` é a qualidade editorial;
`lifecycle` diz se a spec orienta trabalho hoje (`current`), é preparação
(`future`) ou proveniência (`historical`/`superseded`).

Índice gerado em 17/09/2026 a partir do frontmatter (após o fechamento FE/BE/E2E
da Etapa 2). Specs `current` com status `draft-for-review` aguardam decisão do
Owner; as specs 064–069 estão destinadas à Etapa 3 (ADR 0044) e a 070 foi
implementada na R16 (lote 81).

## Vigentes (`current`) — 49

| Arquivo | Título | status | lifecycle |
|---|---|---|---|
| `001-site-publico-astro.md` | Site Publico Astro | draft | **current** |
| `002-auth-multitenant.md` | Auth Multi-tenant | draft | **current** |
| `003-superadmin-core.md` | Superadmin Core | approved-for-technical-spec | **current** |
| `004-admin-instituicao.md` | Admin Instituicao | draft | **current** |
| `005-principal-app.md` | Principal App | draft | **current** |
| `006-comunicacao-agenda.md` | Agenda institucional do Superadmin | approved | **current** |
| `007-design-system-base.md` | Design System Base | draft | **current** |
| `008-lgpd-seguranca-midia.md` | LGPD Seguranca E Midia | draft | **current** |
| `011-superadmin-database-rls.md` | Superadmin MVP Database e RLS | implemented-foundation-with-contextual-domains | **current** |
| `012-superadmin-mvp.md` | Superadmin MVP | approved-for-planning | **current** |
| `013-ui-packages-componentization.md` | Pacotes UI, Catalogo e Governanca de Componentes | implemented-foundation-with-operational-gates | **current** |
| `014-atividade-contextual.md` | Atividade Contextual | implemented-database-foundation | **current** |
| `015-contextual-people-access-attendance.md` | Pessoas, Acessos Contextuais E Assiduidade | implemented-database-foundation | **current** |
| `017-superadmin-unit-schema-foundation.md` | Fundação de tipo e herança de plano por unidade | implemented-database-foundation | **current** |
| `018-profiles-permissions-superadmin.md` | Perfis e Permissões no Superadmin | approved-for-implementation | **current** |
| `019-superadmin-people-directory.md` | Diretório de Pessoas do Superadmin | implemented-and-validated | **current** |
| `027-superadmin-audit-production.md` |  | approved | **current** |
| `028-superadmin-conversations-production.md` | Conversas produtivas do Superadmin | approved | **current** |
| `030-superadmin-child-safety-production.md` | Segurança da criança produtiva | approved-for-implementation | **current** |
| `036-principal-now-publication-mvp.md` |  | approved | **current** |
| `037-principal-circulars.md` | Circulares privadas e versionadas no Principal | approved | **current** |
| `038-attendance-responsive-dashboard.md` | Dashboard responsivo de Assiduidade | approved | **current** |
| `039-superadmin-internal-auth-session-context.md` | Auth, sessão e contexto interno do Superadmin | approved-for-implementation | **current** |
| `040-superadmin-internal-institution-read-v2.md` | Leitura v2 de Instituições para o Superadmin interno | approved-for-implementation | **current** |
| `041-superadmin-internal-institution-list-filter-v2.md` | Listagem e filtros v2 de Instituições para o Superadmin interno | approved-for-implementation | **current** |
| `042-superadmin-internal-institution-edit-core-v2.md` | Edição cadastral core v2 de Instituições pelo Superadmin interno | approved-for-implementation | **current** |
| `043-superadmin-internal-unit-detail-v2.md` | Detalhe e reload v2 de Unidade para o Superadmin interno | approved-for-implementation | **current** |
| `045-superadmin-internal-group-detail-v2.md` | Detalhe e reload v2 de Turma para o Superadmin interno | approved-for-implementation | **current** |
| `046-superadmin-internal-person-detail-v2.md` | Detalhe e reload v2 de Pessoas para o Superadmin interno | approved-for-implementation | **current** |
| `047-superadmin-internal-invite-detail-v2-draft.md` | Rascunho técnico — Convites DETAIL/RELOAD CORE v2 e ponte de schema | draft-for-review | **current** |
| `048-superadmin-internal-attendance-call-detail-v2-draft.md` | Rascunho técnico — Assiduidade Call DETAIL/RELOAD CORE v2 | draft-for-review | **current** |
| `049-superadmin-internal-care-profile-crud-v2.md` | CRUD v2 de Perfis de cuidado para o Superadmin interno | draft-for-review | **current** |
| `050-principal-ui-ux-closure.md` |  | approved | **current** |
| `050-superadmin-agenda-backend.md` | Backend produtivo da Agenda institucional do Superadmin | approved | **current** |
| `052-superadmin-attendance-history-and-routine-snapshot.md` | Assiduidade › Histórico de chamadas e snapshot da rotina na chamada | approved-contract; implementação local R14 Sessão 10 | **current** |
| `053-superadmin-medication-in-app-notifications.md` | Medicação › sino in-app para a equipe da unidade e educadores da turma | approved-contract; implementação local R14 Sessão 10 | **current** |
| `054-archive-activity-routine-models.md` | Arquivar e restaurar modelos de Atividade e de Rotina (inativação reversível) | draft-for-review | **current** |
| `058-superadmin-chat-multi-attachment-message.md` | 058 — Chat interno: vários anexos por mensagem (E3) | approved | **current** |
| `059-principal-view-as-for-you-profile-edit.md` | 059 — Principal hospedado: \"ver como\" no cabeçalho, leitor Para você e Editar perfil (B9) | approved | **current** |
| `061-superadmin-child-safety-person-search.md` | Busca de pessoa autorizada no wizard de Segurança da criança (B5) | approved-for-implementation | **current** |
| `062-superadmin-child-safety-person-without-account.md` | Pessoa autorizada sem conta no wizard de Segurança da criança (B6) | approved-for-implementation | **current** |
| `063-superadmin-meal-plan-images-r2.md` | Imagens de Cardápios em R2 privado pelo Media Gateway (r12-38) | approved-for-implementation | **current** |
| `064-access-profiles-transversal-employee-principal.md` | Perfil transversal e perfil de funcionário no Principal (OQ-044, owner.r12-19/23) | draft-for-review | **current** |
| `065-superadmin-care-profile-collections-redesign.md` | Perfis de cuidado — coleções redesenhadas (ADR 0041 §5, owner.r12-29/30) | approved-for-implementation | **current** |
| `066-entity-lifecycle-activate-inactivate-delete.md` | Ciclo de vida ativar / inativar / excluir (OQ-033 opção B) e institutions.status | approved-for-implementation | **current** |
| `067-superadmin-locations-map-image.md` | Operação › Locais — mapa por imagem, mídia com visibilidade e hierarquia (OQ-034) | approved-for-implementation | **current** |
| `068-principal-official-profiles-auto-follow.md` | Perfis oficiais do Coelo seguidos automaticamente no Principal (OQ-032) | draft-for-review | **current** |
| `069-superadmin-notices-duplicate-cta-refresh.md` | Avisos — duplicar (H08), destino do CTA de Comunicação (H13) e atualização sem sumir a lista (H23) | approved-for-implementation | **current** |
| `070-now-guardian-reader.md` | Leitor do Agora para Famílias reconhece o responsável por vínculo (OQ-048) | approved-for-implementation | **current** |

## Preparação (`future`) — 2

| Arquivo | Título | status | lifecycle |
|---|---|---|---|
| `022-superadmin-plans-ui.md` |  | approved | **future** |
| `051-superadmin-plans-production.md` | Gestão produtiva de Planos no Superadmin | future-reference | **future** |

## Proveniência (`historical`/`superseded`) — 9

Protótipos, spikes e specs substituídas pela implementação de produção. Não
orientam trabalho novo; a superfície atual segue as specs vigentes e a ADR do tema.

| Arquivo | Título | status | lifecycle |
|---|---|---|---|
| `009-media-r2-spike-checklist.md` | Checklist Da Spec 009 - Midia R2 | complete | **historical** |
| `009-media-r2-spike.md` | Spike Tecnico De Midia R2 | approved-for-spike | **historical** |
| `010-superadmin-completo-v1-technical-spec.md` | Superadmin MVP Technical Spec e SDD | draft-for-review | **historical** |
| `016-superadmin-support-prototype.md` |  | approved-design | **historical** |
| `020-superadmin-attendance-prototype.md` | Protótipo local de Assiduidade e Chamada | implemented-local-prototype | **historical** |
| `020-superadmin-health-care.md` | Saúde e Cuidado no Superadmin | approved-for-demonstrative-ui | **historical** |
| `021-superadmin-daily-routine-prototype.md` | Protótipo local de Rotina diária | implemented-local-prototype | **historical** |
| `023-superadmin-internal-users-local-preview.md` |  | approved-for-local-preview | **historical** |
| `044-unit-child-table-direct-access-closure.md` | Acesso direto às tabelas filhas de Unidade — bloqueio de proveniência | blocked-provenance | **historical** |
