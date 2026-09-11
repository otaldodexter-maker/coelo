---
title: "Prova do contrato produtivo com a sessão qa-r03 — Avisos, Circulares e Agenda (CRUD)"
source: "prova-producao.js (login por senha + RPCs via PostgREST contra o projeto coelo/evvbomzejfijozbtgvpt), com a instituição sintética 9f040000-0000-4000-8000-000000000010"
status: "executado"
generated_at: "2026-09-11T02:00:58.842Z"
---

# Prova em produção — 2026-09-11T02:00:58.842Z

Sessão: qa-r03@coelo.me (AAL1). Dados sintéticos [R04-QA]: avisos deixados inactive; circulares excluídas (lógico); evento cancelado. Nenhum token ou credencial gravado.

| action_id | prova | resultado | detalhe |
| --- | --- | --- | --- |
| notices.list | diretorio abre em producao | PASS | 2 itens |
| notices.create | rascunho persiste | PASS | id 20e4bc8b-7f4a-4d96-a6f6-74cd37ce2c44 |
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
| circulars.create | rascunho persiste | PASS | id e74c1434-1db8-44a4-9b51-ff02c6e0508a |
| circulars.detail | detalhe abre (reload) | PASS | status undefined |
| circulars.edit | edicao persiste com versao otimista | FAIL | SAI_INTERNAL_ERROR |
| circulars.schedule | agendar (publish_at futuro) persiste | PASS | scheduled |
| circulars.filter | diretorio filtra por status e busca (reload) | PASS | 1 itens |
| circulars.close | encerrar respostas persiste | PASS | closed |
| circulars.delete | excluir circular encerrada (limpeza) | PASS | status archived |
| circulars.delete | excluir rascunho persiste (deleted=true) | PASS | status draft |
| circulars.delete | reload: rascunho excluido nao abre | PASS | CIRCULAR_NOT_FOUND |
| circulars.publish | publicar imediato persiste | PASS | published |
| circulars.delete | limpeza da publicada | PASS |  |
| circulars.list | anon nao le (negativa) | PASS | status 401 |
| agenda.view | lista abre em producao | PASS | 0 itens |
| agenda.create | evento persiste | PASS | id 77d0ee7a-88e8-4179-90cf-50449af39dfa |
| agenda.detail | detalhe abre (reload) | PASS | rev 1 |
| agenda.edit | edicao + publicacao persistem | PASS | rev 2 |
| agenda.edit | reload mantem titulo e status | PASS |  |
| agenda.edit | cancelar (limpeza) persiste | PASS | canceled |
| agenda.view | anon nao executa (negativa) | PASS | status 401 |

Única falha: circulars.edit (SAI_INTERNAL_ERROR) — causa 42702 (variável plpgsql circular_id ambígua) corrigida no candidato 20260910200400; repetir após o coordenador aplicar.
