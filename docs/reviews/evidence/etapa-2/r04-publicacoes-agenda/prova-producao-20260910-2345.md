---
title: "Prova do contrato produtivo com a sessão qa-r03 — Avisos, Circulares e Agenda (CRUD) após 200400"
source: "prova-producao.js contra o projeto coelo/evvbomzejfijozbtgvpt, instituição sintética 9f040000-0000-4000-8000-000000000010"
status: "executado"
generated_at: "2026-09-11T03:15:22.258Z"
---

# Prova em produção — 2026-09-11T03:15:22.258Z — 33/33

Sessão qa-r03@coelo.me (AAL1). Dados sintéticos [R04-QA]; nenhum token gravado.

| action_id | prova | resultado | detalhe |
| --- | --- | --- | --- |
| notices.list | diretorio abre em producao | PASS | 4 itens |
| notices.create | rascunho persiste | PASS | id 105ac391-22f8-4592-84f3-af792e48ed11 |
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
| agenda.permissions | contexts lista instituicoes para o operador interno | PASS | inst 9f040000-0000-4000-8000-000000000010 |
| circulars.create | rascunho persiste | PASS | id 92626d6e-250e-461c-a69e-3d4ef639e4e8 |
| circulars.detail | detalhe abre (reload) | PASS | status undefined |
| circulars.edit | edicao persiste com versao otimista | PASS | v2 |
| circulars.schedule | agendar (publish_at futuro) persiste | PASS | scheduled |
| circulars.filter | diretorio filtra por status e busca (reload) | PASS | 1 itens |
| circulars.close | encerrar respostas persiste | PASS | closed |
| circulars.delete | excluir circular encerrada (limpeza) | PASS | status archived |
| circulars.delete | excluir rascunho persiste (deleted=true) | PASS | status draft |
| circulars.delete | reload: rascunho excluido nao abre | PASS | CIRCULAR_NOT_FOUND |
| circulars.publish | publicar imediato persiste | PASS | published |
| circulars.delete | limpeza da publicada | PASS |  |
| circulars.list | anon nao le (negativa) | PASS | status 401 |
| agenda.view | lista abre em producao | PASS | 1 itens |
| agenda.create | evento persiste | PASS | id 471aaa2f-5cf0-41be-a97e-9227efad9bc8 |
| agenda.detail | detalhe abre (reload) | PASS | rev 1 |
| agenda.edit | edicao + publicacao persistem | PASS | rev 2 |
| agenda.edit | reload mantem titulo e status | PASS |  |
| agenda.edit | cancelar (limpeza) persiste | PASS | canceled |
| agenda.view | anon nao executa (negativa) | PASS | status 401 |
