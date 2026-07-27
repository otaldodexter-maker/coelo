---
name: coelo-knowledge
description: Use when a Coelo task changes or explains product behavior, UX, domain rules, permissions, documentation, or other observable system knowledge that may be reusable by the team, administrators, or end users.
---

# Memória de conhecimento Coelo

## Overview

Tratar `docs/knowledge` como projeção pesquisável, nunca como fonte canônica ou depósito de conversas.

## Gate de memória

Buscar primeiro com `scripts/Search-CoeloKnowledge.ps1`, ler as fontes e respeitar
`AGENTS.md`. Atualizar fonte canônica antes da projeção. Criar projeção somente
para conhecimento aprovado, durável e reutilizável; usar `no-op` quando nada
durável mudou. Separar `team`, `admin` e `users` em arquivos relacionados pelo
mesmo `knowledge_id`. Conflitos vão para `docs/open-questions.md`.

Recusar PII, CPF, dados de crianças, tenants reconhecíveis, mensagens, mídias,
logs integrais, segredos, tokens e conversas brutas. A base nunca concede
autorização por tenant, papel, vínculo ou contexto.

Validar com `scripts/Test-CoeloKnowledge.ps1` e
`tests/Test-CoeloKnowledge.ps1`, e relatar a captura ou o `no-op`.

