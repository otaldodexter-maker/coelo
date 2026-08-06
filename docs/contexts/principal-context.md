---
title: "Principal Context"
source: "docs/product/prd-app.md; docs/product/prd-master.md; docs/security/auth-multitenant-permissions.md; decisions/0012-contextual-experiences-and-conversation-history.md"
status: "planning-context"
generated_at: "2026-07-22"
---

# Principal Context

## Superficie

`apps/principal`, Flutter privado em `app.coelo.me` e futuro mobile.

## Objetivo

Aplicacao diaria da pessoa global em seus diferentes papeis contextuais:
responsavel, professora, coordenadora, equipe, aluno e outros vinculos
autorizados. Inclui Happens, Now, Moments, rotina, chat, agenda, notificacoes,
perfis e experiencias sociais privadas.

## Fontes

- `docs/product/prd-app.md`
- `docs/product/prd-master.md`
- `docs/security/auth-multitenant-permissions.md`
- `docs/security/lgpd-security-media.md`
- `docs/design/design-system.md`
- `decisions/0012-contextual-experiences-and-conversation-history.md`

## Regras

- Usar sempre o nome `principal`; nao usar `family` em nomes novos.
- Mobile-first, privacidade por padrao e melhor interesse da crianca.
- UI especifica do app fica em `coelo_ui_principal`.
- Uma credencial representa a pessoa global; papel, instituicao, unidade, grupo
  e crianca representada pertencem ao contexto ativo.
- Trocar de experiencia e explicito e recompoe navegacao, dados e permissoes.
- A pessoa pode favoritar contextos autorizados e acessar uma experiencia
  separada de "Ver como responsavel".
- Uma pessoa e uma crianca podem acumular varios vinculos e escopos; a UI nao
  deve codificar combinacoes fechadas.
- Acoes em nome de crianca registram o adulto como ator e a crianca/contexto
  como sujeito representado.
- Conversas entre contextos distintos da mesma pessoa sao permitidas com aviso,
  autoria contextual e historico preservado.
- Revogar um vinculo remove imediatamente o acesso daquele escopo sem afetar os
  demais vinculos validos da pessoa.
