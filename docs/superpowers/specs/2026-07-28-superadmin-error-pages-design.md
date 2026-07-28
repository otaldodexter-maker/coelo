---
title: "Páginas de erro do Superadmin"
source: "User-approved plan on 2026-07-28; docs/design/design-system.md; decisions/0011-flutter-routing-performance.md"
status: "implemented"
generated_at: "2026-07-28"
---

# Páginas de erro do Superadmin

## Objetivo

Oferecer respostas claras e acessíveis para erros 403, 404, 500 e 503 no
Superadmin, preservando a linguagem visual leve da referência aprovada sem
duplicar implementações.

## Escopo

- Uma única tela local e parametrizada para os quatro códigos.
- Tela fullscreen, sem shell, menu ou cabeçalho.
- Fundo semântico laranja-claro, conteúdo centralizado e ação contextual.
- `404` conectado ao `errorBuilder` do `go_router`.
- Rota dinâmica `/dev/errors/:code` para QA das quatro variantes.

Não fazem parte desta entrega mudanças de backend, RLS, autorização, outros
apps Flutter ou uma promoção para os pacotes compartilhados.

## Anatomia e conteúdo

| Código | Mensagem | Ação |
| --- | --- | --- |
| 403 | Você não tem permissão para acessar esta área. | Voltar ao início |
| 404 | Não encontramos a página que você procura. | Voltar ao início |
| 500 | Não foi possível concluir esta ação. | Tentar novamente |
| 503 | O Coelo está temporariamente indisponível. | Tentar novamente |

Código, divisor e mensagem formam um único grupo semântico. Em largura ampla,
ficam em linha; em largura compacta ou com texto ampliado, passam para coluna.
A ação fica abaixo do grupo e recebe foco visível pelo tema Coelo.

## Tokens, acessibilidade e responsividade

- Usar somente `ColorScheme`, `TextTheme`, `CoeloSpacing`,
  `CoeloBreakpoints` e dimensões já aprovadas.
- Light e dark usam `primaryContainer` e `onPrimaryContainer`.
- O conteúdo possui largura máxima e padding adaptativo.
- O código e a mensagem são anunciados como uma única informação de erro.
- A ação mantém alvo mínimo, teclado, foco e semântica nativos de botão.
- Validar 375, 768, 1024 e 1440 px, além de texto a 200%.

## Aceite e testes

- As quatro variantes exibem código, texto e ação corretos.
- A ação delega navegação ou nova tentativa ao callback recebido.
- URL desconhecida autenticada preserva a URL e renderiza 404.
- A rota de QA aceita somente 403, 404, 500 e 503; outros valores mostram 404.
- Não há overflow nos viewports definidos nem com texto ampliado.
- Existem goldens light e dark para as quatro variantes.
- `dart analyze` e testes afetados passam sem diagnósticos.

## Implementação

Implementado em 2026-07-28 no Superadmin com tela local parametrizada, rota
dinâmica de QA, fallback 404 do roteador e cobertura de widget, roteamento,
responsividade, semântica e regressão visual.
