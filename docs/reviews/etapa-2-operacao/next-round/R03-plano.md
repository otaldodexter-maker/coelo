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
execução. A conversa que escreveu este plano **não executa CRUD nem coordena**:
o coordenador da rodada é uma conversa nova com prompt próprio (decisão do
Owner em 10/09). Base: `dev` após `da7ee9db8`.

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

## Fase 0 — composto (conversa Claude dedicada, escritor único, antes das frentes)

| Entrega | Conteúdo | Prova |
| --- | --- | --- |
| Composto de diretório administrativo em `coelo_ui_admin` | Cabeçalho com Pesquisar e Bug; toolbar de filtros; abas Todos/Ativos/Rascunhos/Inativos; toggle card/tabela; grid com card Criar primeiro (inclusive vazio e falha); tabela no padrão; paginação; chat; 375/768/1024/1440 | Goldens do composto por largura no pacote; Instituições e Atividades passam a ser instâncias dele |
| Migração dos 13 diretórios | institutions, units, groups, activities, forms, support, agenda, meal_plans, plans, audit, health_care, chat, circulars (+ people, invites, access_profiles, notices onde houver diretório) | Cada golden da lista de decisões resolvido: R volta à referência, A regravado após a observação |
| Teste de arquitetura | Falha quando uma feature declara Table, Toolbar, Pagination, Header ou Directory próprios | `flutter test` em `apps/superadmin/test/architecture` |
| Regressões apontadas | Chat: Criar grupo, Fixar conversas, bandeiras; confirmação de saída em Instituições; chip Destaque | Testes de widget por item |
| Cabeçalho mobile e Arquivos no Chat | Cabeçalho 375/768 no padrão do anexo do Owner com botão de Bug (MENU-M); botão Arquivos escondido em Conversas por configuração do composto (ARQUIVOS-CHAT) | Goldens do composto em 375/768; teste do chat sem Arquivos |

Estimativa após inspeção: composto e migração de Estrutura em um dia de
frente; demais diretórios em mais um. Calibrar pela execução.

## Fase 1 — grupos ponta a ponta (em paralelo, depois da Fase 0)

A cota do Codex é limitada (só a reserva Luna), então o Codex recebe **duas**
worktrees com os grupos mais simples e parecidos entre si (o Owner apontou a
semelhança entre formulários, eventos e circulares), sem SQL de estrutura nem
plataforma de mídia nova. O restante roda no Claude com Opus. Proposta a
confirmar pelo Owner:

| Grupo | Ferramenta | Famílias | IDs (inventário) | Observação |
| --- | --- | --- | --- | --- |
| publicacoes-agenda | Codex | agenda, notices, circulars | 24 | Três cadastros com público, agendamento e publicação; mesma anatomia de formulário. Circulares já usa R2 pela função existente. Avisos: `pg_cron` e worker vêm da fila SQL do coordenador |
| operacoes | Codex | support, account, plans, audit | 21 | Suporte e Conta constroem camada Supabase agora (Decisão 4 da ADR 0034); sem mídia |
| estrutura | Claude Opus | institutions, units, groups, activities, assessments, locations | 49 | Primeiro grupo a fechar E2E; leitura de `pg_proc` autorizada para as RPCs de Unidades |
| acessos-pessoas | Claude Opus | people, access_profiles, access_models, invites, internal_users, child_safety, profile_files | 38 | Preserva duplicação e confinamento de Convites já integrados |
| formularios-cuidado-rotina | Claude Opus | forms_authoring, forms_responses, forms_files, health_care, medication, students, attendance, daily_routine | 43 | XLSX de respostas no R2; objetos `app_private` sem migration entram na fila SQL |
| principal-chat-sistema | Claude Opus | acontece, agora, momentos, principal_profile, chat, meal_plans, imports, catalog, error_pages, auth, shell | 55 | Regras SHELL/MAIS/IMG/FOTO; regressão do chat; Cardápios envia `p_expected_revision` |
| coordenacao-integracao | Claude, conversa nova | integra `dev`, aplica SQL em produção na ordem da fila, rastreadores, executa o pacote Cloudflare autorizado | — | Lê `comunicacao/*.json` do Codex e do Claude; único escritor dos rastreadores |

Ordem de fechamento E2E: Estrutura → Suporte e Conta → Formulários e Cuidado →
Acessos e Pessoas → Alunos e Rotina → Principal e Comunicação.

Custo: o MVP começa sem custo. O piloto cabe no nível gratuito do R2 (10 GB-mês,
1 M Class A, 10 M Class B, egress grátis). Stream é pré-pago (US$ 5 por 1.000
minutos armazenados, US$ 1 por 1.000 minutos entregues, sem nível gratuito),
por isso só o Agora usa cópia Stream por até 24 h e só quando a publicação
exigir; nada mais promove vídeo ao Stream antes de métricas.

## Fase Cloudflare (coordenação; pacote autorizado pelo Owner em 10/09, ADR 0034 Decisão 5)

Estado real em 10/09: três buckets privados existem (ENAM, sem CORS, sem
lifecycle além do padrão de multipart, sem domínio). `circular-media`,
`form-media`, `form-operations` e `form-export-download` já falam com R2 pela
API S3; `happens-media`, `now-media` e `moments-media` ainda usam Supabase
Storage (ADR 0030, superada). O spike R2 de 06/2026 nunca foi concluído ao
vivo (EV-001 a EV-005 bloqueados por falta de credencial).

Pacote autorizado, a executar pela conversa coordenadora da rodada: CORS restrito nos três buckets; expiração no
`coelo-transient-prod`; token R2 de escopo mínimo (objeto: leitura/escrita nos
três buckets, nada de DNS, billing ou Workers) guardado nos secrets das Edge
Functions; migrar as três funções restantes para R2; concluir as provas do
spike (upload autorizado, GET autorizado, cross-tenant negado, URL expirada,
órfão, CORS, MIME/tamanho, secret scan) com dados sintéticos.

## Decisões já tomadas e ainda abertas

Tomadas em 10/09: pacote Cloudflare autorizado (execução nos prompts); botão
Arquivos escondido em Conversas (opção B); cabeçalho mobile com Bug; custo zero;
coordenador em conversa nova; Codex com os grupos mais simples.

Aberta: confirmação dos dois grupos do Codex propostos acima
(publicacoes-agenda e operacoes) ou troca por outros dois.
