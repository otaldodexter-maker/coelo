---
name: coelo-ui
description: Use when creating, changing, or reviewing Coelo UI in Flutter or future Astro surfaces, including screens, widgets, components, tokens, themes, states, responsiveness, accessibility, catalog examples, and visual regressions.
metadata:
  source: "specs/013-ui-packages-componentization.md; docs/design/design-system.md; docs/superpowers/specs/2026-07-28-superadmin-error-pages-design.md; .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md; .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md; .agents/skills/coelo-ui/references/weekly-superadmin-ui-review.md"
  status: "active"
  generated_at: "2026-07-29"
---

# Coelo UI

Aplicar o Design System oficial sem transformar propostas em padrões
silenciosamente.

## Fluxo obrigatório

1. Identificar produto, tela e contexto. Quando a tarefa mencionar popup, modal,
   dialog, overlay, hover, foco, botão, button, chip, sugestão, enviar, send,
   menu, filtro, tabela, table, close, dismiss ou “X”, ler
   obrigatoriamente o [contrato de superfícies e interação](references/surface-interaction-contracts.md)
   antes de decidir ou implementar a composição visual.
   Quando mencionar Login, Home, Instituições, menu lateral, rail, Perfil,
   Configurações, popup de Bug, criar ou editar instituição, ler também as
   [baselines visuais aprovadas do Superadmin](references/approved-superadmin-visual-baselines.md)
   e consultar `pattern.approved-superadmin-surfaces`. O anexo temporário
   registra a aprovação; o golden e o teste indicados na matriz são a evidência
   persistente. Nunca usar `failures/` como referência.
   Quando mencionar listagem, diretório, cards/tabela, card hover, table hover,
   view toggle, arquivos, flyout, perfil, configurações, tour, sair, excluir ou
   deletar, ler também o
   [contrato de diretórios e flyouts](references/admin-directory-flyout-contracts.md)
   e consultar `pattern.admin-directory`, `pattern.flyout-actions` e
   `pattern.interaction-states`. Para `X`, sair, desligar, encerrar, fechar,
   remover, deletar ou excluir, consultar também `pattern.negative-actions`;
   toda ação negativa habilitada permanece na hierarquia
   `errorContainer`/`error`, independentemente do verbo escolhido.
   Quando popup ou dialog tiver uma, duas ou três ações, consultar
   `pattern.dialog-actions`: ações irmãs têm larguras iguais; uma ocupa 100%,
   duas dividem 50/50 e três dividem em terços, com gaps tokenizados. Empilhar
   todas em 100% somente quando constraints ou texto ampliado exigirem.
   Para hierarquia de botões, consultar `pattern.action-hierarchy`: laranja
   preenchido é a única ação principal; `OutlinedButton` em `surface` com
   contorno leve é secundário; `TextButton` em `surface` sem contorno é
   terciário. Em rodapé de tela ampla, terciária fica no extremo esquerdo e o
   grupo de continuidade no direito; não aplicar o 50/50 de dialogs à tela.
   Quando mencionar formulário, cadastro, edição, input, campo, select, upload,
   avatar, wizard, step form, rodapé ou color picker, ler obrigatoriamente o
   [contrato de formulários](references/form-layout-contracts.md), consultar
   `pattern.form-controls`, `pattern.selection-controls`, a seção “Formulários
   e entradas” do Design System e os exemplos do catálogo. Comparar com
   Instituições e autenticação.
   Quando mencionar página de erro, error page, fullscreen error, 403, 404,
   500, 503, rota não encontrada, acesso negado ou indisponibilidade, consultar
   `pattern.error-pages` e ler obrigatoriamente o
   [contrato de páginas de erro](references/error-page-contracts.md). Não
   substituir esse padrão por `CoeloStatePanel`: o painel é feedback dentro de
   uma superfície existente.
   Quando pedir revisão semanal, code review profundo, auditoria visual ou
   sincronização UI do Superadmin, ler obrigatoriamente o
   [runbook semanal](references/weekly-superadmin-ui-review.md).
2. Consultar primeiro o índice com
   `scripts/query-index.ps1 -Query "<termo>"`. Informar ao usuário:
   `Consultei o índice Coelo UI para <contexto>.`
3. Abrir somente arquivos e documentos apontados pelos resultados relevantes.
4. Reutilizar ou compor tokens, componentes e padrões antes de propor algo novo.
   Card administrativo clicável usa `CoeloAdminInteractiveCard`; flyout de
   ações usa `CoeloAdminFlyout` e marca itens terminais/destrutivos com
   `CoeloAdminFlyoutTone.negative`. Não recriar essas superfícies com `Card` +
   `InkWell`, `PopupMenuButton`, `MenuAnchor` ou `MenuItemButton` dentro de uma
   feature. Exceção legada exige entrada contada e justificada na allowlist;
   conveniência local não é justificativa.
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
   aplicar integralmente o contrato: superfície neutra, grid e gaps por tokens,
   campos compartilhados, conteúdo especializado, rodapé e matriz visual. Não
   usar `surfaceContainer` como faixa ou fundo decorativo sem função explícita.
   Ações primárias e tonais preservam a paleta laranja nos estados
   interativos, sem overlay cinza. Disabled tonal é exceção condicional para
   ação primária antecipada, nunca o padrão global. Botão de ícone assimétrico
   usa alvo e caixa centralizados pelos tokens `CoeloSize`.
   Antes de criar qualquer hover, classificar a superfície como ação primária,
   ação tonal, item discreto, linha contínua, card interativo, item destrutivo
   ou toggle segmentado. É proibido aplicar “hover padrão Material”, cinza/HEX
   local ou uma regra universal a famílias diferentes. Ação negativa habilitada
   nunca usa `primary`, grafite ou cinza: ícone, item e botão preservam o
   vermelho semântico também no repouso.
5. Respeitar [fronteiras de pacote](references/package-boundaries.md).
6. Se nada atender, seguir o
   [contrato de proposta](references/component-proposal.md) e aguardar aprovação.
7. Registrar o padrão aprovado antes do código.
8. Implementar; atualizar índice, catálogo, exemplos e testes.
9. Executar a [verificação proporcional](references/verification.md) e relatar
   pendências. Toda criação ou alteração de UI do Superadmin deve executar o
   validador bloqueante `apps/catalog/tool/validate_admin_visual_contracts.dart`.
   Ocorrência nova de widget bruto fora da allowlist bloqueia a entrega; não
   ampliar contagem ou allowlist para fazer o gate passar.

Consulta somente leitura não exige autorização. Componente, API pública,
variante, token semântico ou mudança de padrão exigem aprovação explícita.
Propostas criativas são livres; somente sua oficialização é bloqueada.

O Design System Coelo prevalece sobre recomendações genéricas.
