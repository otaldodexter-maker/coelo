---
title: "Forms and Agenda Flutter UI completion plan"
source: "docs/superpowers/specs/2026-08-13-superadmin-forms-end-to-end-design.md; specs/006-comunicacao-agenda.md; decisions/0025-forms-private-storage-and-multipart-exports.md; decisions/0028-superadmin-agenda-product-surface.md"
status: local-green
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
  `4a9e851c`, `3d92f1d9`, `e697ac17`, `df2efdcd`, `118edba5`, `83a73890`,
  `449760d5`, `cf4e9481`, `2621fd7a`, `0e616523`, `a21b3992`, `de2fda82`,
  `a2f0f02b` e `ba7c8d3b`.
- O recorte está `local-green` visual/Flutter: wiring local, rotas isoladas,
  comportamento funcional, responsividade e goldens fecharam seus gates focados.
- `forms.monitor`, `forms.respond`, `forms.responses`, `forms.response-detail`,
  `forms.export`, `forms.upload`, `forms.resolve-file`, `forms.download`,
  `forms.expire-file` e `forms.delete-file` foram promovidos a `local-green`
  após os fixes funcionais locais e a repetição dos gates correspondentes.
- O total local sustentado no fechamento é 100/207 (48,31%); no recorte,
  22/22 action_ids estão `local-green` visual/Flutter.
- O handoff `c5de6b4b` continha mudanças em `SupabaseFormsApi` e no contrato de
  `packages/coelo_api`; `a21b3992` as reverteu/isolou, preservando o limite sem
  promover qualquer contrato backend novo.
- Estado máximo permanece `local-green` Flutter/visual. Supabase, backend,
  autorização real, remoto e E2E permanecem bloqueados/fora de escopo.
- Gate focado do recorte: 237/237 testes passaram; analyzer, contratos visuais,
  índice Coelo UI e conhecimento passaram. Existem 113 goldens únicos no recorte
  (42 Agenda + 71 Forms); 101 foram trabalhados após o handoff, sendo 84 novos e
  17 herdados atualizados, com inspeção visual representativa de cada superfície.
- A suíte Flutter global foi interrompida após 1.265 passes e 76 falhas somente
  em famílias fora do recorte/goldens de shell. Esses resíduos não foram
  corrigidos por ownership e não rebaixam o gate focado, mas impedem alegar
  repositório globalmente verde.

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
2. Concluído: arquivos de Forms, overlays e shell foram auditados; os testes
   focados foram repetidos no estado consolidado.
3. Concluído: `a21b3992` reverteu/isolou os hunks Supabase/API fora do recorte.
4. Concluído no recorte: 237/237, analyzer, goldens inspecionados e gates
   visual/index/knowledge verdes. A suíte global conserva 76 falhas externas ao
   ownership desta frente e não é declarada verde.

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
