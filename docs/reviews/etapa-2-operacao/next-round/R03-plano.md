---
title: "Rodada 3 — plano acordado com o Owner"
source: "Decisões do Owner em 10/09/2026 (tarde); ADR 0034; docs/reviews/evidence/etapa-2/goldens-claro-decisoes-2026-09-10.md; TRABALHO-ATUAL.md (grupos da rodada noturna)"
status: "approved-plan; prompts-not-written-yet"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Rodada 3 — plano

Este documento fixa **o que** a Rodada 3 faz e **quem** faz. Os prompts das
conversas novas serão escritos depois, quando o Owner mandar; nada aqui inicia
execução. Base: `dev` após `ec36bdfb0`.

## Princípios acordados

1. **Composto primeiro, telas depois.** Nenhuma frente abre tela antes de o
   composto de diretório administrativo existir e os 13 diretórios estarem
   migrados para ele. É isso que elimina o retrabalho apontado pelo Owner.
2. **Por grupos, ponta a ponta.** Cada frente cuida das telas e subtelas do seu
   grupo em Front-end, Back-end e E2E. Não há divisão "Codex faz UI, Claude faz
   backend": a divisão por camada cria fila de espera entre ferramentas e
   perde contexto da tela.
3. **Régua do MVP (ADR 0034).** Rota normal abre, CRUD persiste no Supabase
   real, RLS nega outro tenant, reload mantém estado. Pacote SQL verde vai
   para produção no mesmo turno pelo integrador. Provas exaustivas ficam para a
   revisão profunda.
4. **Pendências e avanços gravados no mesmo turno** nos três rastreadores e,
   quando mudarem regra, nas skills `coelo-frontend`, `coelo-backend`,
   `coelo-frontend-backend` e `coelo-ui`. Handoff de meia página por frente.
5. **Dúvida vai para o Owner** em lote, com referência visual quando for UI/UX.
   Ele decide mais rápido do que o agente.

## Fase 0 — composto (Claude, escritor único, antes das frentes)

| Entrega | Conteúdo | Prova |
| --- | --- | --- |
| Composto de diretório administrativo em `coelo_ui_admin` | Cabeçalho com Pesquisar e Bug; toolbar de filtros; abas Todos/Ativos/Rascunhos/Inativos; toggle card/tabela; grid com card Criar primeiro (inclusive vazio e falha); tabela no padrão; paginação; chat; 375/768/1024/1440 | Goldens do composto por largura no pacote; Instituições e Atividades passam a ser instâncias dele |
| Migração dos 13 diretórios | institutions, units, groups, activities, forms, support, agenda, meal_plans, plans, audit, health_care, chat, circulars (+ people, invites, access_profiles, notices onde houver diretório) | Cada golden da lista de decisões resolvido: R volta à referência, A regravado após a observação |
| Teste de arquitetura | Falha quando uma feature declara Table, Toolbar, Pagination, Header ou Directory próprios | `flutter test` em `apps/superadmin/test/architecture` |
| Regressões apontadas | Chat: Criar grupo, Fixar conversas, bandeiras; confirmação de saída em Instituições; chip Destaque | Testes de widget por item |

Estimativa após inspeção: composto e migração de Estrutura em um dia de
frente; demais diretórios em mais um. Calibrar pela execução.

## Fase 1 — grupos ponta a ponta (em paralelo, depois da Fase 0)

A cota do Codex é limitada (só a reserva Luna), então o Codex recebe **duas**
worktrees com os grupos mais mecânicos e bem especificados, sem plataforma de
mídia nem SQL de estrutura. O restante roda no Claude com Opus.

| Grupo | Ferramenta | Famílias | IDs (inventário) | Observação |
| --- | --- | --- | --- | --- |
| formularios-cuidado | Codex | forms_authoring, forms_responses, forms_files, health_care, medication | 27 | Lista de goldens já decidida; XLSX de respostas no R2 depende da Fase Cloudflare |
| operacoes-sistema | Codex | agenda, support, account, meal_plans, plans, audit, catalog, error_pages | 61 | Suporte e Conta constroem camada Supabase agora (Decisão 4 da ADR 0034); Cardápios envia `p_expected_revision` |
| estrutura | Claude Opus | institutions, units, groups, activities, assessments, locations | 49 | Primeiro grupo a fechar E2E; leitura de `pg_proc` autorizada para as RPCs de Unidades |
| acessos-pessoas | Claude Opus | people, access_profiles, access_models, invites, internal_users, child_safety, profile_files | 38 | Preserva duplicação e confinamento de Convites já integrados |
| alunos-rotina | Claude Opus | students, attendance, daily_routine | 16 | Objetos `app_private` sem migration entram na fila SQL |
| coelo-principal-comunicacao | Claude Opus | acontece, agora, momentos, circulars, chat, notices, principal_profile | 39 | Regras SHELL/MAIS/IMG/FOTO da lista de goldens; Avisos com `pg_cron` e worker |
| coordenacao-integracao | Claude (este) | integra `dev`, aplica SQL em produção na ordem da fila, rastreadores, Cloudflare/mídia | — | Lê `comunicacao/*.json` do Codex e do Claude; único escritor dos rastreadores |

Ordem de fechamento E2E: Estrutura → Suporte e Conta → Formulários e Cuidado →
Acessos e Pessoas → Alunos e Rotina → Principal e Comunicação.

## Fase Cloudflare (coordenação, aguarda autorização nominal do Owner)

Estado real em 10/09: três buckets privados existem (ENAM, sem CORS, sem
lifecycle além do padrão de multipart, sem domínio). `circular-media`,
`form-media`, `form-operations` e `form-export-download` já falam com R2 pela
API S3; `happens-media`, `now-media` e `moments-media` ainda usam Supabase
Storage (ADR 0030, superada). O spike R2 de 06/2026 nunca foi concluído ao
vivo (EV-001 a EV-005 bloqueados por falta de credencial).

Pacote a autorizar: CORS restrito nos três buckets; expiração no
`coelo-transient-prod`; token R2 de escopo mínimo (objeto: leitura/escrita nos
três buckets, nada de DNS, billing ou Workers) guardado nos secrets das Edge
Functions; migrar as três funções restantes para R2; concluir as provas do
spike (upload autorizado, GET autorizado, cross-tenant negado, URL expirada,
órfão, CORS, MIME/tamanho, secret scan) com dados sintéticos.

## Decisões ainda abertas para o Owner

1. Autorização nominal do pacote Cloudflare acima.
2. Botão Arquivos no chat mobile: opção A (manter e rotular, recomendada), B
   (esconder no Chat) ou C (só em 1024+).
3. Confirmação dos grupos do Codex (formulários-cuidado e operacoes-sistema)
   ou troca por outros dois.
