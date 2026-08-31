---
title: "Forms and Agenda Flutter UI completion plan"
source: "docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md; specs/006-comunicacao-agenda.md; decisions/0025-forms-private-storage-and-multipart-exports.md; decisions/0028-superadmin-agenda-product-surface.md"
status: in-progress
generated_at: "2026-08-31"
---

# Forms and Agenda Flutter UI completion plan

## Guardrails

- Worktree: `C:\Users\adrie\Documents\Coelo-worktrees\forms-agenda-ui-completion`.
- Branch: `codex/forms-agenda-ui-completion`.
- Base inicial: `f1aeacf67c218e7e889005ab98391f3d63096f11`.
- Estado máximo: `local-green` Flutter/visual.
- Sem Supabase, Postgres, Auth, RLS, RPC, migrations, Edge Functions, Storage,
  deploy, projeto remoto, `packages/coelo_database` ou contrato backend novo.
- Produção e `/dev` compartilham composição; somente `/dev` recebe fixtures e
  mutações locais. Produção permanece fail-closed.
- V4.19/V4.20, router, navegação, shell compartilhado, overlays e tracker ficam
  congelados até o handoff focado da frente concorrente.

## Estado de handoff e consolidação — 2026-08-31

- Base registrada: `f1aeacf67c218e7e889005ab98391f3d63096f11`.
- Branch/worktree: `codex/forms-agenda-ui-completion` em
  `C:\Users\adrie\Documents\Coelo-worktrees\forms-agenda-ui-completion`.
- O handoff visual de V4.19/V4.20 foi incorporado no commit `c5de6b4b`; ele
  trouxe diretório/editor de Forms, testes/goldens e ajustes compartilhados.
- Commits desta frente, em ordem, até o último checkpoint de código:
  `9020be56`, `ff75b1c2`, `c5de6b4b`, `cda7cd0f`, `7f04a8af`, `1ce0a23d`,
  `02619c70`, `56dedf84`, `dac6405b`, `2f616367`, `81264bbb`, `48de2f18`,
  `e0529081`, `6a06619e`, `54f311cb`, `9d4ab0d6`, `877d9cb5`, `2f98e6c8`,
  `4a9e851c`, `3d92f1d9`, `e697ac17`, `df2efdcd`, `118edba5` e `83a73890`.
- O estado continua `in-progress`: wiring de mídia, correção do contrato visual,
  testes de rota e goldens ainda possuem resíduos não commitados na worktree.
- `forms.monitor`, `forms.respond`, `forms.responses`, `forms.response-detail`,
  `forms.export`, `forms.upload`, `forms.resolve-file`, `forms.download`,
  `forms.expire-file` e `forms.delete-file` ficam `in-progress` enquanto os
  fixes funcionais locais e seus gates ainda estão em andamento.
- O total local sustentado neste checkpoint é 90/207 (43,48%). O valor
  100/207 (48,31%) somente será válido depois que essas dez ações passarem
  pelos testes funcionais e gates correspondentes.
- O handoff `c5de6b4b` também contém mudanças em `SupabaseFormsApi` e no contrato
  de `packages/coelo_api`; elas não estão autorizadas por este recorte e devem
  ser extraídas ou receber aprovação explícita antes da integração final.
- Estado máximo permanece `local-green` Flutter/visual. Supabase, backend,
  autorização real, remoto e E2E permanecem bloqueados/fora de escopo.

## Fase 1 — Agenda independente

1. Escrever REDs do contrato visual atual: Calendário/Lista, ausência de hero e
   Semana, timeline, detalhe diário responsivo e estados fail-closed.
2. Refatorar modelos e store de demonstração para lifecycle, recorrência,
   ocorrência, timezone, respostas, reminders, capabilities e histórico.
3. Implementar calendário mensal e detalhe diário: fullscreen a 375; painel
   expansível a 768/1024/1440; retorno de foco e URL representável.
4. Implementar Lista timeline conforme a referência aprovada, com busca,
   contexto, estados, hover/foco e menu.
5. Completar criar/editar/detalhe usando frame, campos, calendários, dialogs e
   containers canônicos.
6. Separar Solicitações, Aprovações e visualização de Permissões.
7. Cobrir aniversários minimizados, CTA para Forms sem acoplamento e intenções
   locais de notificações.
8. Gerar goldens reais e inspecionar cada imagem antes de aceitar a baseline.

## Fase 2 — Incorporar handoff Forms

1. Concluído: base e handoff V4.19/V4.20 identificados; o commit incorporado é
   `c5de6b4b`.
2. Concluído parcialmente: arquivos de Forms, overlays e shell foram auditados;
   os testes focados foram repetidos ao longo dos commits da frente.
3. Pendente para o consolidador: separar os hunks de Supabase/API fora do recorte
   e reconciliar apenas os resíduos explicitamente listados no checkpoint final.
4. Pendente: repetir a suíte combinada, analyzer, goldens inspecionados e gates
   globais no estado já limpo/commitado.

## Fase 3 — Formulários

1. Paridade e reachability de list/create/overview/edit/publish/test.
2. Motor compartilhado de resposta para test/respond, retomada, revisão,
   identificado/anônimo, segredo perdido e falha preservando dados.
3. Monitor, respostas e detalhe com cursor, drill-down, elegibilidade e
   anonimização.
4. Upload/arquivos com progresso, cancelamento, retry, indisponibilidade,
   expiração, exclusão e mídia protegida sem path/URL permanente.
5. Export jobs CSV/XLSX/ZIP nos estados waiting/processing/completed/split/
   expired/failed.
6. Publicação, working version, autosave initial/dirty/saving/saved/conflict/
   failure, duplicar/copiar/mover/arquivar/excluir.
7. Audiências hierárquicas, schedules once/daily/weekly/monthly, ocorrências,
   timezone e reminders.

## Ciclo obrigatório por unidade

1. Confirmar ownership e consultar o índice Coelo UI.
2. Escrever teste RED comportamental proporcional e executar a falha esperada.
3. Implementar a menor correção que resolve a causa.
4. Executar testes focados e estados responsivos/acessíveis.
5. Gerar golden Flutter, abrir e comparar com a baseline aprovada.
6. Atualizar tracker e conhecimento quando houver mudança durável.
7. Criar commit pequeno e focado.

## Gates finais

- Formatter e testes focados.
- Suítes Flutter dos pacotes afetados, rotas e navegação.
- `flutter analyze` e `git diff --check`.
- `apps/catalog/tool/validate_admin_visual_contracts.dart`.
- Validações do índice Coelo UI e gates de conhecimento.
- Matriz 375/768/1024/1440, light/dark, texto 100/150/200%, reduced motion,
  teclado/mouse/toque, foco/hover/menu/retorno de foco e ausência de overflow.
- Revisão independente; corrigir todo P0/P1 e repetir gates afetados.
