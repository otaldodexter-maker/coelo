---
name: coelo-ui
description: Use when creating, changing, or reviewing Coelo UI in Flutter or future Astro surfaces, including screens, widgets, components, tokens, themes, states, responsiveness, accessibility, catalog examples, and visual regressions.
metadata:
  source: "specs/013-ui-packages-componentization.md; docs/design/design-system.md"
  status: "active"
  generated_at: "2026-07-27"
---

# Coelo UI

Aplicar o Design System oficial sem transformar propostas em padrões
silenciosamente.

## Fluxo obrigatório

1. Identificar produto, tela e contexto. Quando a tarefa mencionar popup, modal,
   dialog, overlay, hover, menu, filtro, tabela, table, close, dismiss ou “X”, ler
   obrigatoriamente o [contrato de superfícies e interação](references/surface-interaction-contracts.md)
   antes de decidir ou implementar a composição visual.
   Quando mencionar formulário, cadastro, edição, input, campo, select, upload
   ou color picker, consultar obrigatoriamente `pattern.form-controls`,
   `pattern.selection-controls`, a seção “Formulários e entradas” do Design
   System e os exemplos do catálogo. Comparar também pelo menos um consumidor
   já aprovado, como autenticação ou outra tela administrativa.
2. Consultar primeiro o índice com
   `scripts/query-index.ps1 -Query "<termo>"`. Informar ao usuário:
   `Consultei o índice Coelo UI para <contexto>.`
3. Abrir somente arquivos e documentos apontados pelos resultados relevantes.
4. Reutilizar ou compor tokens, componentes e padrões antes de propor algo novo.
   Não criar campo textual ou single-select local quando
   `CoeloFormTextField` ou `CoeloAdminSingleSelectField` atenderem. Medidas de
   grid, gaps, padding e rodapé devem citar tokens existentes ou uma referência
   visual aprovada; números locais sem justificativa bloqueiam a implementação.
   Popup, dialog, menu e overlay usam `colorScheme.surface` com
   `surfaceTintColor: Colors.transparent`; `primaryContainer`, laranja-claro e
   cinza são proibidos como fundo-base. Antes de concluir, comparar visualmente
   com o popup de bug, submenu do sino ou importação de arquivo.
   Todo menu de single-select acompanha exatamente a largura do gatilho e não
   exibe check; seleção é comunicada por cor semântica e texto. Em formulários,
   não usar `surfaceContainer` como faixa ou fundo decorativo sem função
   explícita.
5. Respeitar [fronteiras de pacote](references/package-boundaries.md).
6. Se nada atender, seguir o
   [contrato de proposta](references/component-proposal.md) e aguardar aprovação.
7. Registrar o padrão aprovado antes do código.
8. Implementar; atualizar índice, catálogo, exemplos e testes.
9. Executar a [verificação proporcional](references/verification.md) e relatar
   pendências.

Consulta somente leitura não exige autorização. Componente, API pública,
variante, token semântico ou mudança de padrão exigem aprovação explícita.
Propostas criativas são livres; somente sua oficialização é bloqueada.

O Design System Coelo prevalece sobre recomendações genéricas.
