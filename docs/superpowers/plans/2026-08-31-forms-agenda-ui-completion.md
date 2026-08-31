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

1. Receber base, hashes e lista de arquivos de V4.19/V4.20.
2. Auditar `git show --name-status`, incorporar os commits na worktree e repetir
   testes de Forms, overlays e shell.
3. Resolver apenas conflitos desta frente; não copiar hunks do checkout principal.
4. Atualizar o plano com os caminhos efetivamente herdados.

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
