---
title: "Para você do Principal"
source: "referência visual aprovada pelo owner em 2026-08-20; docs/product/prd-app.md; docs/design/design-system.md; decisions/0012-contextual-experiences-and-conversation-history.md"
status: approved
generated_at: 2026-08-20
---

# Para você do Principal

## Objetivo

`Para você` é um hub editorial-contextual do responsável. A superfície começa
na visão global da pessoa e permite aprofundamento explícito por criança,
instituição, unidade e turma. Não é Aviso, popup, feed nem painel acadêmico de
um aluno ativo.

## Composição aprovada

- cabeçalho Coelo com saudação, visão atual e troca de contexto;
- card protagonista escolhido da ordem de prioridade e elegibilidade recebida;
- seis atalhos essenciais, cards editoriais e `Resumo do dia`;
- bloco explícito do contexto atual;
- navegação irmã para Acontece, Agora, Momentos, Agenda e Perfil.

A base clara usa `colorScheme.surface`, Nunito Sans, tokens oficiais e laranja
de marca. Assets editoriais já aprovados de Acontece e Perfil evitam criar uma
identidade paralela. Em 375 px a composição é vertical com navegação inferior e
cards editoriais horizontais. Em 768 px ganha respiro e distribuição em grade.
Em 1440 px usa rail, conteúdo central e resumo lateral sem virar dashboard.

## Dados e contexto

A apresentação recebe destaques já ordenados e renderiza o primeiro elegível.
Cada item informa tipo (`Destaque`, `Conteúdo` ou `Para você`), prioridade,
elegibilidade, conteúdo e CTA. Regras administrativas, persistência e backend
ficam fora deste preview.

O seletor local demonstra visão geral e aprofundamento por criança. Ele não
autoriza contexto, não invalida cache e não representa a futura implementação
produtiva da ADR 0012. Dados e vínculos demonstrativos não correspondem a
pessoas ou tenants reais.

## Evidência

O preview executável fica em `/dev/principal-for-you` no Superadmin e é
alcançável a partir de Acontece. Testes cobrem prioridade, estados vazios,
callbacks, seletor de contexto, limites 600/839/840/1024, texto a 200% e reduced
motion. Goldens preservam 375/768/1440 light, 1440 dark e seletor aberto.

## Fora de escopo

- bootstrap de `apps/principal` ou promoção para `coelo_ui_principal`;
- Supabase, schema, RLS, API de gestão ou persistência de contexto;
- refatoração das superfícies irmãs para um shell compartilhado;
- substituição do produto Aviso ou de sua experiência contextual em popup.
