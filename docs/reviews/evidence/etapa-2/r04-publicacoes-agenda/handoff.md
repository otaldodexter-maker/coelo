---
title: "Handoff R04 — publicacoes-agenda (Avisos, Circulares, Agenda)"
source: "comunicacao/publicacoes-agenda.json rev 19; commits da branch work/etapa2-r04-publicacoes-agenda; provas em producao (prova-producao-*.md) e capturas ui/"
status: "mini-revisao de 10 minutos (03:25-03:50 de 11/09/2026)"
generated_at: "2026-09-11"
---

# Handoff R04 — publicacoes-agenda

Recorte: `apps/superadmin` → famílias agenda (7), notices (6), circulars (11) = 24 ações.
Sessão de teste: `qa-r03@coelo.me` (AAL1). Credencial só no ambiente do processo; nenhum token
gravado. Dados sintéticos `[R04-QA]`/`[R04-QA UI]` em produção: avisos deixados `inactive`
(o v2 não exclui), circulares excluídas (lógico) ou encerradas, evento cancelado.

## Backend: pacotes entregues (todos sobre a baseline, pgTAP no descartável `coelo_baseline_pa`)

| Ordem | Pacote | Ações | pgTAP | Estado |
| --- | --- | --- | --- | --- |
| 1 | `20260910200000_superadmin_internal_notices_v2_baseline` | notices.* | 38/38 | produção 22:29 (lote 9) |
| 2 | `20260910200100_superadmin_internal_circulars_v2_baseline` | circulars.* | 34/34 | produção 22:29 |
| 3 | `20260910200200_superadmin_internal_circular_delete_v2` | circulars.delete | 10/10 + 15/15 | produção 22:29 |
| 4 | `20260910200300_agenda_internal_realm_compat_v1` | agenda.* | 22/22 | produção 22:29 |
| 5 | `20260910200400_superadmin_circular_save_draft_v2_fix` | circulars.edit | (34/34 acima) | produção 23:23 (lote 10) |
| 6 | `20260910200500_notice_publication_worker_v2` | notices.publish/schedule | 52/52 | produção 02:09 (lote 15); disparo (secret+cron) = P30 do Owner |

Prova limpa do zero (db reset + seed + migrations/ + candidatos + pgTAP): 117/117 às 22:23 (antes do 200400/200500).

## Produção por RPC com a sessão (mesmas assinaturas dos repositórios)

`prova-producao-20260910-2345.md`: **33/33** — Avisos (criar, replay, editar, agendar, publicar, inativar, reload,
anon 401), Circulares (criar, editar, agendar, filtrar, publicar, encerrar, excluir rascunho, reload, anon 401),
Agenda (contexts, criar, detalhe, editar+publicar, reload, cancelar, anon 401).

## Rota normal pela UI (build web de `test_driver/qa_main.dart`, Chrome via CDP)

Capturas em `ui/`:

| Captura | O que prova |
| --- | --- |
| ui-01-login, ui-02-home | login real do qa-r03 e Home com a sessão |
| ui-03-notices | `/notices` abre o diretório de Avisos no composto com dados de produção |
| ui-04, ui-05 | `/notices/new` abre o formulário real; validação honesta da mensagem |
| ui-06-notice-saved | rascunho criado pela tela persistiu (listado) |
| ui-07-notices-reload | app recarregado por completo, sessão mantida, aviso presente |
| ui-08-circulars | `/circulars` vazio com busca, filtro, toggle, Arquivos, abas e Criar |
| ui-09..ui-11 | compositor: instituição, título, texto, "Rascunho salvo" |
| ui-12, ui-12b | **achado**: a 1440 o balão de chat cobre o botão Publicar (centro 1330×856); a 1024 o rodapé empilha |
| ui-14..ui-17 | público obrigatório, campo de agendamento inline, publicação → diretório |
| ui-18..ui-20 | detalhe (Publicada, resumo de respostas) → Encerrar respostas com confirmação → Encerrada |
| ui-21..ui-23 | rascunho novo → detalhe → Excluir com confirmação |
| ui-24-circulars-reload | após recarregar: rascunho excluído sumiu, encerrada persiste |
| ui-25-agenda | `/agenda` abre o calendário com os eventos [R04-QA] de produção |
| ui-26-agenda-new | `/agenda/events/new` abre o formulário real (Criar evento) |

Não feito pela UI (ficou por tempo/memória): editar aviso pela tela, publicar/inativar aviso pela tela,
escolher data no seletor de agendamento (o campo abre mas o picker não foi acionado pelo CDP),
criar/editar evento pela tela, Agenda de eventos (lista) em produção, `circulars.respond`/`attach`.

## Front-end

- Agenda de eventos migrada ao composto `CoeloAdminDirectory` (`_EventTable` e enum local fora da allowlist).
- Estado vazio/sem resultados dos três diretórios provado (13 testes) pela regra do Owner de 10/09.
- Calendário a 375: células compactas (decisão A "retângulos amassados"), goldens 375 regravados,
  overflow no shell a 375 fechado (teste deixa de ser skip). Goldens do recorte 48/48; regressão 36/36.
- Bateria agenda+notices+circulars+architecture após a migração do composto: 477 PASS, 2 SKIP.

## Achados abertos (registrados no JSON)

1. **Balão de chat "Mensagens" em criar/editar/publicar** (Decisão 7) — em `/circulars/new` a 1440 cobre o
   botão Publicar e impede publicar pela tela; em `/notices/new` cobre parte do Continuar. Dono: shell
   (principal-chat-sistema/coordenador). Bloqueia `circulars.publish` verified na largura padrão.
2. Diretório de Circulares não recarrega após excluir (mostra o rascunho até recarregar). FE, `circulars.delete`.
3. "Editar circular" continua oferecido em circular Encerrada (o servidor recusa). FE, `circulars.edit`.
4. Membership interno com escopo de instituição não vê Agenda (deny-by-default mantido; decisão registrada).
5. Testes históricos `superadmin_agenda_production_test` (row_security_active) e `superadmin_agenda_contexts_test`
   (institution_type_id/proconfig) falham pela forma de produção; reescrever.
6. Métricas por geração (20260909191100) e cadeia legada people-based de Avisos ficam fora até haver worker rodando.

## Dúvidas ao Owner

- `agenda_calendar_light_375`: leitura da observação "retângulos muito amassados" = célula quase quadrada com marcas
  coloridas e +N (render atual) em vez de rótulos truncados. Confirmar.
- `agenda_detail_light_375/768/1440` (R): manter o indicador de status com alvo de 48 px (render atual, vem do
  composto) ou voltar ao círculo de 24 px da referência?
- FUNDO em `agenda_create_light_375`, `agenda_detail_*`, `notice_form_initial_mobile_light_375`: origem no
  `SuperadminFormFrame` compartilhado; regravar só após a correção do frame.

## Complemento 02:30–03:05 (segundo Chrome, viewport 1024)

| Captura | O que prova |
| --- | --- |
| ui-27-notice-open | `/notices/:id/edit` abre o aviso criado pela tela com os dados reais |
| ui-28-notice-edited, ui-30 | título editado e salvo; diretório mostra "[R04-QA UI] Aviso editado pela tela" |
| ui-31, ui-32, ui-33 | grade de cards; menu de ações (Pré-visualizar, Editar, Publicar, Inativar); Publicar → indicador passa a ativo |
| ui-34, ui-35, ui-36 | Inativar com motivo obrigatório → indicador vermelho (inativo) |
| ui-37, ui-38, ui-39, ui-40 | Criar evento pela tela: passos, revisão, Publicar → detalhe publicado na instituição sintética |
| ui-41-agenda-detail-reload | após recarregar o app o evento persiste (via calendário) |

Achados adicionais: (a) deep link direto para `/agenda/events/:id` após carga fria fica no spinner até passar pelo
calendário; (b) no detalhe após reload, contexto e audiência mostram o UUID da instituição em vez do nome
(contexts ainda não carregados). Ambos FE, `agenda.detail`.
