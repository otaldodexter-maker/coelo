---
title: "Superadmin Core"
status: "approved-for-technical-spec"
generated_at: "2026-06-23"
---

# Superadmin Core

## Objetivo

Definir o Superadmin MVP como primeira fatia operacional do Coelo, com banco primeiro e Flutter por ultimo, usando componentização e tecnicas corretas para construção de app web e mobile responsivo em FLutter/Dart.

O nucleo inclui instituicoes, planos/status, usuarios internos, avisos/popups, suporte auditado, logs e base de dados preparada para dashboards futuros.

## Status

Escopo aprovado para Technical Spec/SDD. A foundation inicial de banco/RLS foi detalhada em `specs/011-superadmin-database-rls.md` e gerou a migration `packages/coelo_database/migrations/20260623191021_superadmin_foundation_v1.sql`.

Este documento ainda nao autoriza codigo de produto Flutter, deploy ou novas migrations fora da foundation ja registrada sem spec tecnica revisada.

## Superficies E Pacotes

- `apps/superadmin`
- `packages/coelo_auth`
- `packages/coelo_database`
- `packages/coelo_ui_admin`

## Fontes

- `prd-superadmin`
- `auth-multitenant-permissions`
- `lgpd-security-media`
- `data-model`
- Decisoes de produto registradas em 2026-06-23 na conversa de planejamento do Superadmin Completo v1

## Escopo Inicial

- Ativacao de instituicao como primeiro fluxo implementavel: criar instituicao, definir status/plano, vincular owner da instituicao, emitir convite e registrar auditoria.
- Modelo de dados preparado para crescimento: campos ampliados de instituicao, planos, limites, contrato, branding leve, configuracoes e metadados.
- Avisos/popups com segmentacao avancada por regras, incluindo instituicao, unidade, grupo/turma, papel, contexto e filtros futuros.
- Governanca interna com 5 papeis: Owner, Operations, Support, Content e Auditor.
- Owner Coelo inicial unico, com poder total, MFA obrigatoria e delegacao de novos Owners por convite + MFA.
- Eventos, contadores e snapshots suficientes para dashboard futuro, sem construir a tela de dashboard agora.
- Wireframes em Figma apenas em baixa fidelidade, cobrindo desktop, tablet e mobile.

## Fora De Escopo

- Codigo de produto.
- Instalacao de dependencias.
- Novas migrations reais sem spec tecnica aprovada.
- Deploy ou infraestrutura ativa.
- Dashboard visual completo.
- Prototipo visual final no Figma.
- Cobranca automatica, assinatura e bloqueios financeiros automaticos.
- Impersonation invisivel ou uso de credenciais de usuario final.

## Dados E Permissoes

Toda spec que tocar dados privados deve declarar `tenant_id`/`institution_id`, membership, papel contextual, ownership, visibilidade, RLS/policies e tentativas de acesso cruzado que precisam falhar.

O Owner Coelo e uma excecao explicita ao principio de menor privilegio: pode liberar permissoes e executar acoes globais, mas deve exigir MFA, trilha de auditoria completa, justificativa para acoes sensiveis e revisao antes de producao.

## UX States

Quando houver UI, declarar estados de carregamento, vazio, erro, sem permissao, sucesso, desktop, tablet, mobile e acessibilidade.

O primeiro wireframe deve cobrir o fluxo de ativacao de instituicao. Avisos/popups, usuarios internos, suporte e auditoria seguem como fluxos posteriores dentro do mesmo Superadmin v1.

## Criterios De Aceite

- Escopo pequeno e testavel.
- Fontes oficiais citadas.
- Conflitos registrados em `docs/open-questions.md`.
- Nenhum segredo ou `service_role` no cliente.
- Testes definidos antes da implementacao.
- Banco desenhado antes das telas e sem depender do wireframe para regras de autorizacao.
- Ativacao de instituicao gera tenant, plano/status, owner institucional, convite e audit log.
- Segmentacao avancada de avisos/popups esta prevista em schema, mesmo que a UI completa venha depois.
- Eventos, contadores e snapshots futuros estao especificados sem obrigar dashboard visual no MVP.

## Testes Requeridos

- Unitarios para regras de dominio quando aplicavel.
- Testes de permissao/RLS quando tocar banco.
- Testes de import boundaries quando tocar pacotes.
- Testes de acessibilidade/golden quando tocar UI.
- Testes de Owner com MFA obrigatoria e delegacao por convite + MFA (Apenas na V1, não no MVP).
- Testes cross-tenant para instituicoes, avisos/popups, suporte, auditoria, eventos e contadores.
- Testes responsivos dos wireframes/telas para desktop, tablet e mobile.

## Perguntas Abertas

Registrar qualquer lacuna em `docs/open-questions.md` antes de implementar, especialmente limites juridicos e tecnicos do poder total do Owner Coelo.
