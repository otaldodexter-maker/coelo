---
title: "R05 · Operações — handoff ao coordenador"
source: "comunicacao/operacoes.json rev 21–25; commits de work/etapa2-r05-operacoes; rota real com qa-r03 sobre o build web release (qa_main) em 127.0.0.1:3008; pgTAP no projeto descartável coelo_ops_r05"
status: "handoff; o coordenador aplica deltas, pacote e edita skills/rastreadores"
generated_at: "2026-09-11"
group: "operacoes"
---

# 1. O que fechou (por action_id, com prova)

| Ação | FE | BE | E2E | Prova |
| --- | --- | --- | --- | --- |
| audit.list / audit.filter / audit.detail | verified (proposto) | done (proposto) | verified-e2e (proposto) | `/audit` com qa-r03: `audit_list_events_for_superadmin` 200 (59 páginas), filtro Resultados (Falha = 0, Negado = 3 páginas), busca "invite" (4 páginas), Próxima por cursor, detalhe via `audit_get_event_for_superadmin` 200, reload mantém; pgTAP 210100 37/37 em produção (lote 10). Capturas `rota-real/30-37`. Deltas: `deltas-r05-ops-audit.json` (9). |
| plans.list / plans.create / plans.edit | verified (proposto) | local-green | N | `/plans` 200; criar (`superadmin_plan_save` 200, plano `5b0fc76b-…`), editar (`plan_get` 200, `plan_save` 200, revisão 2), reload mantém "editado". Gate do cliente ligado em `fab9b9fd0`. pgTAP `superadmin_plans_behavior_v1_test` 40/40 exige o candidato `20260911200000_superadmin_plans_platform_scope_v1` (não aplicado). Capturas `rota-real/40-47`. Deltas: `deltas-r05-ops-plans.json` (6). |
| support.table / kanban / detail (G-SUP, A+) | verified (mantido) | done | verified-e2e | Composto `CoeloAdminResizableTable` centraliza toda célula (0e4b2f27c); Suporte com detalhe sob a toolbar em 1024 (decisão R) e altura do corpo corrigida (3b6ef24d3); 32 goldens regravados; página R/A para o Owner: https://claude.ai/code/artifact/7737ccf7-1489-4d67-ba5f-858c051150d2 (cópia em `g-sup/pagina-lado-a-lado-suporte.html`). Aprovação visual pendente do Owner. |
| profile-files.import / export | verified (mantido) | deferred | deferred | Pessoas → Arquivos → Importar / Exportar XLSX respondem "Indisponível nesta etapa" sem picker nem RPC (contagem de RPCs inalterada). Capturas `rota-real/60-63`. |
| imports.list | verified (mantido) | deferred | deferred | `/imports` ganhou o cabeçalho da tela (regra MENU); Nova importação "Disponível depois do MVP", sem picker/parser/job. Capturas `50` (antes) e `51` (depois). |

# 2. Pacotes SQL prontos (o coordenador aplica)

- `packages/coelo_database/candidatos/operacoes/20260911200000_superadmin_plans_platform_scope_v1.sql` — pgTAP `superadmin_plans_behavior_v1_test` 40/40 e `superadmin_plans_production_test` 13/13 no descartável `coelo_ops_r05` (baseline + 107 migrations na ordem de produção). **Achado de segurança:** após o P7 (`20260910171000`), `has_platform_permission(text)` conta membership de instituição e `assert_plan_permission` usava essa forma: perfil de instituição com `plan.change` criava/editava plano da plataforma. O pacote exige `has_scoped_platform_permission(p, null)`, corrige o status padrão no `superadmin_plan_save` (23502) e revoga grants diretos herdados. Sem chave de composição (gate do cliente já segue `planCatalogRepository`). Depois de aplicar: plans.list/create/edit BE `done` e E2E `verified-e2e` (FE já provado).

# 3. O que ficou aberto (primeiro gate)

1. **account.logout / account.sessions** — regra do coordenador (13:00): Sair global e revogação derrubam as sessões das outras frentes; prova só depois de 15:30 com aviso 5 min antes. `account.sessions` não tem tela nem API de cliente (listar/revogar sessões do próprio usuário exige Edge Function sobre o Admin API do GoTrue): **pergunta ao Owner** se entra no MVP ou fica pós-MVP (recomendação: pós-MVP; `blocked-decision`).
2. **catalog.validate / sync / publish** — gate real medido em 14:00: `validate_catalog_index` OK; `validate_package_boundaries` 5 diagnósticos (componentes do composto Fase 0 sem entrada no índice: `CoeloAdminDirectory`, `CoeloAdminDirectoryStatusTabs`, `CoeloAdminDirectoryViewToggle`, `CoeloAdminPaginationFooter`, `CoeloAdminUnderlineTabs`); `validate_catalog_sync` 21 diagnósticos (5 acima + 7 `source-example-fingerprint-mismatch`: `admin.flyout`, `admin.resizable-table`, `admin.work-item-card`, `superadmin.form-action-footer`, `core.date-range-picker`, `core.date-range-field`, `core.date-time-field`, e o relatório versionado desatualizado). Defeito da ferramenta: `validate_catalog_sync` regrava `assets/catalog-sync-report.json` com caminhos absolutos da máquina (revertido). `catalog.publish` = deploy do app do Catálogo (Cloudflare Pages, decisão nominal do Owner). Backend Supabase não se aplica a esta família (proposta antiga de N/A continua sem aprovação).
3. **plans.activate / plans.assign** — semântica (arquivar/restaurar da spec 051; atribuição não é comando aprovado): decisão do Owner, sem mudança.
4. **G-SUP aprovação visual** — 16 goldens claros de Suporte + 4 de Planos na página R/A; o Owner responde por arquivo.
5. **audit.export / account.mfa / account.theme** — adiados por decisão (ADR 0034; Decisão 12); `account.theme` FE `pending-verification` (persistência local provada na R04 com `account.settings`).

# 4. Pendências novas registradas (nada se perde)

- `support.table`: shell chamava `superadmin_support_list` e `superadmin_account_profile_get` antes da sessão (401 no `/login`) — **corrigido em 13be50ae8** (carga condicionada a `session.isAuthenticated`).
- `audit.filter`: filtro Período tem aparência distinta (rótulo flutuante + ícone) dos demais filtros do composto; conferir com `coelo-ui`.
- `plans.create`: campo Motivo de auditoria (último da Revisão) fica sob o rodapé ancorado até rolar (P15 não aplicado em `PlanFormPage`).
- `plans.list`: parser do cliente exige as 13 chaves de entitlements e `DateTime.parse(starts_at)` com `starts_at` nulável — plano criado fora do cliente ou assinatura sem data quebra a tela.
- `imports.list`: `ImportDirectoryPage` declara toolbar/tabela/paginação próprias (fora do `CoeloAdminDirectory`); sem toggle/abas no vazio; botão Arquivos só ícone. Família adiada; migrar ao composto na revisão profunda.
- `shell.navigate`: `prototype_navigation_routes_test` ("Bad state: No element") falha também em `origin/dev` limpo; pré-existente.
- Composto (0e4b2f27c): goldens de tabelas de outras famílias regravados a pedido do coordenador em 4371853e1 (perfis de acesso 8, formulários 11, rotina 1, importações 9); G2 regravou os mesmos 8 de perfis em c227e531f (mesmo SDK).
- Resíduos sintéticos em produção (limpeza no fim da Etapa 2, P42): plano `5b0fc76b-51cd-4361-8d4f-e7033853eba6` (`r05-qa-plano-teste`, 2 recibos em `plan_change_receipts`); eventos de auditoria gerados pela prova (append-only).

# 5. Regras para as skills (o coordenador edita)

- **coelo-ui / coelo-frontend:** a feature não envolve célula de tabela com `Align`; o composto `CoeloAdminResizableTable` alinha à esquerda e centraliza na linha. Detalhe lateral em corpo estreito no desktop (janela ≥ 840 e corpo < 840) entra como `bodyOverride` do composto para manter a toolbar visível (decisão R do Owner em `support_detail_light_1024`); em 768/375 o detalhe toma o corpo (A). Altura do corpo com `bodyOverride` considera as linhas da toolbar por largura (1 / 3 / 5).
- **coelo-frontend:** rota de mutação de família cujo SQL está na baseline segue o repositório composto em `hasAuthoritativeMutationCapability` (Planos como Pessoas/Cuidado); carga de dados operacionais no router só com sessão.
- **coelo-backend:** `has_platform_permission(text)` depois do P7 conta membership de instituição; catálogo de plataforma (Planos) e qualquer RPC sem instituição devem usar `has_scoped_platform_permission(p, null)`. pgTAP estrutural com `row_security_active` não existe: usar `pg_class.relrowsecurity and relforcerowsecurity`. Ferramenta do Catálogo regrava o relatório com caminhos absolutos: rodar só para diagnosticar e reverter.
- **coelo-frontend-backend:** RPCs conferidas por `performance.getEntriesByType('resource')` com `responseStatus` no build release (sem aba Network do DevTools); texto em campo de formulário no release entra por `enter_text` do driver após clique por CDP (`Input.insertText` não chega ao campo).
