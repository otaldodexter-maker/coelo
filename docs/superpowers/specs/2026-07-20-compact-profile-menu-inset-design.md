---
title: "Compact Profile Menu Safe Inset"
source: "User-approved tablet and mobile profile menu spacing adjustment"
status: "approved"
generated_at: "2026-07-20"
---

# Respiro do menu de perfil compacto

## Objetivo

Impedir que o menu de perfil aberto no mobile e tablet encoste visualmente na borda direita da viewport.

## Design aprovado

- Aplicar margem visual direita mínima de `CoeloSpacing.space4` ao painel do perfil quando `_ProfileSummary.compact` for verdadeiro.
- Preservar alinhamento vertical abaixo do avatar, largura, conteúdo, cantos, sombra, cores e hovers atuais.
- Preservar integralmente o posicionamento desktop não compacto.
- Usar apenas tokens Coelo; nenhum valor hexadecimal ou novo componente.

## Critérios de aceite

- Em 375 px e 768 px, o painel aberto mantém pelo menos `CoeloSpacing.space4` até a borda direita.
- O painel continua abaixo do acionador e totalmente dentro da viewport.
- O menu desktop permanece com a geometria atual.
- Testes existentes e build web continuam aprovados.
