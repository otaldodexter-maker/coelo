---
title: "Design System Base"
status: "draft"
generated_at: "2026-06-22"
---

# Design System Base

## Objetivo

Definir tokens, assets, UI core e criterios de acessibilidade para Flutter e Astro.

## Status

Draft de fundacao. Nao autoriza implementacao ate aprovacao explicita.

## Superficies E Pacotes

- `packages/coelo_tokens`
- `packages/coelo_ui_core`
- `apps/site`

## Fontes

- `design-system`
- `brand-history`

## Escopo Inicial

- Definir problema e resultado esperado.
- Mapear entidades e dados afetados.
- Mapear papeis, permissoes, tenant e auditoria.
- Definir estados de UX quando houver interface.
- Definir eventos, logs e notificacoes quando aplicavel.
- Definir criterios de aceite e testes.

## Fora De Escopo

- Codigo de produto.
- Instalacao de dependencias.
- Migrations reais sem spec tecnica aprovada.
- Deploy ou infraestrutura ativa.

## Dados E Permissoes

Toda spec que tocar dados privados deve declarar `tenant_id`/`institution_id`, membership, papel contextual, ownership, visibilidade, RLS/policies e tentativas de acesso cruzado que precisam falhar.

## UX States

Quando houver UI, declarar estados de carregamento, vazio, erro, sem permissao, sucesso, mobile e acessibilidade.

## Criterios De Aceite

- Escopo pequeno e testavel.
- Fontes oficiais citadas.
- Conflitos registrados em `docs/open-questions.md`.
- Nenhum segredo ou `service_role` no cliente.
- Testes definidos antes da implementacao.

## Testes Requeridos

- Unitarios para regras de dominio quando aplicavel.
- Testes de permissao/RLS quando tocar banco.
- Testes de import boundaries quando tocar pacotes.
- Testes de acessibilidade/golden quando tocar UI.

## Perguntas Abertas

Registrar qualquer lacuna em `docs/open-questions.md` antes de implementar.
