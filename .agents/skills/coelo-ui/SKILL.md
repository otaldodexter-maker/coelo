---
name: coelo-ui
description: Use when creating, changing, or reviewing Coelo UI in Flutter or future Astro surfaces, including screens, widgets, components, tokens, themes, states, responsiveness, accessibility, catalog examples, and visual regressions.
metadata:
  source: "specs/013-ui-packages-componentization.md; docs/design/design-system.md; docs/superpowers/specs/2026-07-28-superadmin-error-pages-design.md; .agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md; .agents/skills/coelo-ui/references/interactive-state-evidence-matrix.md; .agents/skills/coelo-ui/references/rejected-visual-patterns-inbox.md; .agents/skills/coelo-ui/references/admin-directory-flyout-contracts.md; .agents/skills/coelo-ui/references/weekly-superadmin-ui-review.md"
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
   Para **qualquer** criação ou alteração visual no Superadmin — inclusive novo
   widget, protótipo ou superfície não citada acima — ler também os
   [padrões visuais rejeitados](references/rejected-visual-patterns-inbox.md) e
   consultar `pattern.rejected-visual-patterns`. Antes de implementar, declarar
   qual família de `pattern.approved-superadmin-surfaces` é a baseline principal:
   Login; Instituições; Home; Menu/Flyouts; Perfil/Configurações; Popup de Bug;
   ou Criar/Editar instituição. Se nenhuma família atender, seguir proposta e
   aguardar aprovação; default Material nunca preenche essa lacuna.
   Quando mencionar listagem, diretório, cards/tabela, card hover, table hover,
   view toggle, arquivos, flyout, perfil, configurações, tour, sair, excluir ou
   deletar, ler também o
   [contrato de diretórios e flyouts](references/admin-directory-flyout-contracts.md)
   e consultar `pattern.admin-directory`, `pattern.flyout-actions` e
   `pattern.interaction-states`. Para qualquer card de diretório administrativo,
   Instituições é baseline obrigatória e deve ser consultado também
   `pattern.institution-card-status`. Para `X`, sair, desligar, encerrar, fechar,
   remover, deletar ou excluir, consultar também `pattern.negative-actions`;
   toda ação negativa habilitada permanece na hierarquia
   `errorContainer`/`error`, independentemente do verbo escolhido.
   Quando mencionar tabs, abas, categorias irmãs, segmentos de diretório ou
   `Acessos > Pessoas`, ler também o
   [contrato de tabs lineares de diretório](references/directory-linear-tabs-contract.md)
   e consultar `pattern.directory-linear-tabs`. Esse padrão é condicional:
   filtra o mesmo diretório sem trocar a toolbar ou a página; não substitui o
   toggle em cápsula de Cards/Tabela, filtros, chips ou navegação entre rotas.
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
   e entradas” do Design System e os exemplos do catálogo. Toda tela que crie
   ou edite qualquer entidade do Superadmin adota automaticamente Criar/Editar
   instituição como baseline principal, mesmo quando o pedido não citar essa
   referência. Abrir `institution_form_page.dart`, sua navegação, seções,
   `SuperadminFormActionFooter`, testes funcionais e goldens mobile light e
   desktop dark; autenticação continua sendo a referência do campo-base.
   Se uma regra real do produto exigir identidade ou composição diferente,
   parar antes do código, apresentar a comparação e a proposta visual ao
   usuário e aguardar aprovação explícita. Não implementar a divergência como
   experimento, protótipo ou solução temporária.
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
   Quando o usuário disser “baseie-se”, “use como referência” ou nomear uma
   tela aprovada, a consulta é literal: abrir o código real da tela, componentes
   compartilhados usados, testes funcionais e golden aplicável antes de editar.
   Reutilizar esses componentes quando atenderem; se uma peça nova for
   necessária, preservar anatomia, tokens, estados, espaçamento e hierarquia da
   referência. Uma aproximação visual ou widget Material “parecido” não atende.
   Antes de qualquer código visual, ler também a
   [matriz de evidência dos estados interativos](references/interactive-state-evidence-matrix.md)
   e preencher mentalmente, para cada estado pedido ou alcançável no controle:
   implementação real,
   componente/contrato, teste comportamental e golden exato. Os quatro campos
   são bloqueantes. Não limitar o inventário ao verbo do pedido: introduzir um
   filtro, flyout, card ou botão inclui todos os estados que o usuário consegue
   alcançar. Golden geral da página não substitui evidência de hover,
   foco, seleção, menu aberto, expansão ou ação negativa. Se o golden específico
   não existir, parar e propor a referência; não programar primeiro para depois
   decidir qual imagem deveria ser verdadeira.
4. Reutilizar ou compor tokens, componentes e padrões antes de propor algo novo.
   O checklist de entrada é bloqueante: (a) baseline aprovada escolhida;
   (b) anti-padrões rejeitados comparados; (c) componente canônico localizado;
   (d) gaps, padding, estados e ações mapeados a tokens. Omitir qualquer item
   bloqueia código. “É só protótipo”, “depois ajustamos” e “o default funciona”
   não são exceções.
   Card administrativo clicável usa `CoeloAdminInteractiveCard`; flyout de
   ações usa `CoeloAdminFlyout` e marca itens terminais/destrutivos com
   `CoeloAdminFlyoutTone.negative`. Não recriar essas superfícies com `Card` +
   `InkWell`, `PopupMenuButton`, `MenuAnchor` ou `MenuItemButton` dentro de uma
   feature. Exceção legada exige entrada contada e justificada na allowlist;
   conveniência local não é justificativa.
   Quando Instituições for a referência, verificar explicitamente
   `CoeloAdminListingToolbar`, busca, filtros, toggle Cards/Tabela,
   `CoeloAdminFileActions`, `CoeloAdminFlyout`, `CoeloAdminInteractiveCard`,
   `CoeloAdminExpandableStatusIndicator`, tabela e paginação antes de criar
   qualquer substituto local.
   O card de Instituições define o contrato visual de todo card de diretório e
   deve ser implementado com `CoeloAdminInteractiveCard`:
   a superfície continua `surface`, o raio é preservado e hover/foco alteram
   somente borda e sombra; overlay/splash permanece transparente, sem cinza. Quando o card
   possui status semântico, usar `CoeloAdminExpandableStatusIndicator`; o
   indicador começa compacto em 24 × 24 sem texto e
   expande para revelar o rótulo em hover, foco ou toque; usa cores semânticas,
   não depende apenas da cor e elimina a animação não essencial com reduced
   motion. Não substituir esse comportamento por chip sempre aberto.
   Categorias irmãs de um mesmo diretório no Superadmin reutilizam
   `SuperadminUnderlineTabs`: superfície transparente, linha-base neutra,
   seleção laranja por label + underline e hover/foco tonal primário sutil, sem
   cápsula e sem cinza. Preservar `space4` entre toolbar, tabs e conteúdo. Não
   recriar `TabBar` ou `InkWell` local enquanto o compartilhado atender.
   Não criar campo textual ou single-select local quando
   `CoeloFormTextField` ou `CoeloAdminSingleSelectField` atenderem. Medidas de
   grid, gaps, padding e rodapé devem citar tokens existentes ou uma referência
   visual aprovada; números locais sem justificativa bloqueiam a implementação.
   Em tela de criar/editar do Superadmin, reutilizar
   `SuperadminFormActionFooter`: `TextButton` terciário no extremo esquerdo e
   `OutlinedButton`/uma única ação `FilledButton` no grupo direito; no compacto,
   ações em largura total com a primária primeiro. A navegação de etapas de
   Instituições é referência de anatomia e responsividade, não um convite para
   importar widgets específicos de domínio; se for necessário generalizá-la,
   seguir o contrato de proposta e pedir aprovação antes de criar a API.
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
   Em `apps/superadmin/lib/features`, não introduzir `DropdownButton`,
   `DropdownButtonFormField`, `RadioListTile`, `CheckboxListTile` ou
   `showDateRangePicker` diretamente. Reutilizar o componente Coelo indexado;
   quando não existir seletor especializado aprovado, registrar proposta em vez
   de aceitar o default Material. Não ampliar allowlist para fazer o gate passar.
   Em mobile e tablet no tema claro de Superadmin, Admin ou Principal, a base da
   página usa `colorScheme.surface`. Instagram e Airbnb são referências
   conceituais de limpeza e hierarquia por conteúdo/espaço, não de identidade:
   cinza não é fundo-base padrão. Reservar `surfaceContainer*` para superfícies
   secundárias com função explícita, campos, estados, skeletons ou separação
   local. No dark theme, usar papéis semânticos escuros; nunca branco literal.
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
