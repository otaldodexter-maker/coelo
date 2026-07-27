---
source: "user-approved visual references; docs/design/design-system.md; apps/superadmin/lib/app/shell/superadmin_bug_report_dialog.dart"
status: "approved"
generated_at: "2026-07-27"
---

# Padrão de superfície para popups e modais

## Objetivo

Eliminar a criação recorrente de popups com fundo laranja-claro e tornar o
diálogo de reporte de bug a referência visual canônica para overlays do Coelo.

## Contrato visual

- Todo popup, modal ou diálogo usa `colorScheme.surface` como superfície-base.
- No tema claro, a superfície-base é branca.
- No tema escuro, a superfície-base é a superfície neutra escura semântica.
- `primaryContainer`, laranja-claro e outras tonalidades de marca não podem ser
  usados como fundo-base do contêiner.
- O laranja permanece reservado a ações primárias, bordas ativas, seleção,
  hover, foco e destaques previstos pelo Design System.
- A barreira usa preto translúcido e preserva o contraste do conteúdo.
- O diálogo de reporte de bug do Superadmin é a referência visual canônica de
  composição, sem transformar seu conteúdo de domínio em componente genérico.

## Fontes a atualizar

1. `docs/design/design-system.md`, para oficializar a regra semântica.
2. `.agents/skills/coelo-ui`, para exigir a consulta e a aplicação do contrato.
3. O catálogo e seu índice, com exemplo recuperável por `popup`, `modal`,
   `dialog`, `overlay`, `surface`, `superfície`, `branco` e `laranja`.

## Catálogo

O catálogo deve demonstrar o mesmo popup em light e dark e registrar:

- superfície-base;
- barreira;
- cabeçalho e fechamento;
- ação primária;
- estado selecionado ou ativo sem contaminar a superfície-base.

O exemplo deve apontar para a regra oficial e para o proprietário atual. Esta
mudança não aprova automaticamente um novo componente público.

## Verificação

- Um cenário de baseline deve demonstrar que a orientação atual permite ou não
  impede com clareza o fundo laranja-claro.
- O mesmo cenário deve passar após a mudança no skill.
- A consulta do índice pelos termos de popup deve retornar o padrão.
- Validadores do índice e da sincronização do catálogo devem passar.
- Testes documentais ou de widget devem assegurar `colorScheme.surface` em
  light e dark e rejeitar `primaryContainer` como superfície-base.
- As mudanças preexistentes no repositório devem ser preservadas.

## Fora de escopo

- Redesenhar os popups existentes.
- Criar automaticamente um novo componente compartilhado.
- Alterar o conteúdo ou o fluxo funcional dos diálogos.
- Usar branco literal no tema escuro.
