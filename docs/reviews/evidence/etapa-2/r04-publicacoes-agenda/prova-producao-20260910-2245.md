---
title: "Prova do contrato produtivo com a sessão qa-r03 — Avisos, Circulares e Agenda (leitura)"
source: "scratchpad/prova-producao.js (login por senha + RPCs via PostgREST contra o projeto coelo/evvbomzejfijozbtgvpt)"
status: "executado"
generated_at: "2026-09-11T01:43:01.736Z"
---

# Prova em produção — 2026-09-11T01:43:01.736Z

Sessão: qa-r03@coelo.me (AAL1, MFA fora do MVP). Dados sintéticos com prefixo [R04-QA]; avisos deixados como inactive (v2 não exclui). Nenhum token ou credencial foi gravado.

| action_id | prova | resultado | detalhe |
| --- | --- | --- | --- |
| notices.list | diretorio abre em producao | PASS | 0 itens |
| notices.create | rascunho persiste | PASS | id 30728c81-0fc5-4e4f-a405-912d5fa55dd0 |
| notices.create | replay idempotente | PASS |  |
| notices.edit | edicao persiste com versao otimista | PASS | v2 |
| notices.edit | reload (detail) mantem a edicao | PASS |  |
| notices.schedule | publicar com inicio futuro agenda | PASS | scheduled |
| notices.list | reload (diretorio) ve o agendado | PASS |  |
| notices.archive | inativar com motivo persiste | PASS | inactive |
| notices.archive | reload mantem inactive | PASS |  |
| notices.publish | publicar com inicio passado fica active | PASS | active |
| notices.archive | limpeza: aviso imediato inativado | PASS |  |
| notices.list | anon nao le (negativa) | PASS | status 401 |
| circulars.list | diretorio abre em producao | PASS | 0 itens |
| agenda.permissions | contexts lista instituicoes para o operador interno | FAIL | {"contexts":[],"capabilities":{"createAgendaItems":true,"editAllAgendaItems":true,"editOwnAgendaItems":true,"publishAgendaItems":true,"cance |
| circulars.list | anon nao le (negativa) | PASS | status 401 |
| agenda.view | lista abre em producao | PASS | 0 itens |
| agenda.view | anon nao executa (negativa) | PASS | status 401 |

Bloqueio: produção sem instituição ativa; Circulares (criar/agendar/publicar/encerrar/excluir) e Agenda (criar/editar/detalhe) aguardam uma instituição sintética (pedido ao coordenador).
