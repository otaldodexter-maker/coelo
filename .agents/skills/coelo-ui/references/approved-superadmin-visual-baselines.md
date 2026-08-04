---
source: "Aprovação visual do Owner Coelo em 2026-07-29 e confirmação em 2026-08-04; docs/design/design-system.md; goldens e testes do Superadmin"
status: "active"
generated_at: "2026-08-04"
---

# Baselines visuais aprovadas do Superadmin

Esta matriz transforma os 32 anexos aprovados pelo Owner Coelo em referência
persistente. Os anexos temporários serviram para a aprovação; depois dela, os
goldens, testes e regras abaixo são a evidência canônica. Não usar imagens em
`failures/` como referência.

Esta matriz é obrigatória para criar, refazer, refatorar ou corrigir qualquer
UI do Superadmin, do estado interativo à página inteira. Quando o usuário
nomear uma tela como referência, abrir sua implementação, componentes
compartilhados, testes e golden; não basta imitar a aparência. Toda proposta
também deve ser comparada com os
[padrões rejeitados](rejected-visual-patterns-inbox.md).
Para estados interativos, usar obrigatoriamente também a
[matriz de evidência](interactive-state-evidence-matrix.md), que liga cada
estado ao código real, componente, teste e golden exato.

## Matriz de aprovação

| Anexos | Superfície e estados aprovados | Evidência persistente |
| --- | --- | --- |
| 1–7 | Login: campo em repouso e foco, senha, checkbox, botão padrão/hover, link e aviso de acesso restrito | `apps/superadmin/test/features/auth/presentation/screens/goldens/superadmin_login_light.png`; `superadmin_login_golden_test.dart`; `superadmin_login_screen_test.dart` |
| 8–18 | Instituições: paginação, criar card, card/hover, grid, arquivos, filtros, busca/foco, toggle, tabela e seus espaçamentos | `apps/superadmin/test/features/institutions/presentation/screens/goldens/`; `institution_directory_page_golden_test.dart`; `institution_directory_page_test.dart` |
| 19 | Home/Central de ajuda: conversas à esquerda, ajuda central, sugestões e compositor inferior | `apps/superadmin/test/features/help_center/presentation/screens/goldens/help_center_empty_light_1440.png`; `help_center_page_golden_test.dart` |
| 20–24 | Menu expandido e rail compacto; níveis, seleção, hover e flyouts de Tour/Acessos | `apps/superadmin/test/app/shell/superadmin_shell_test.dart`; `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_directory_collapsed_flyout_hover_light_1024.png` |
| 25–26 | Flyout da conta: Perfil, Configurações, divisor e Sair negativo, incluindo hover | `apps/superadmin/test/app/shell/superadmin_shell_test.dart`; contrato `pattern.flyout-actions` |
| 27 | Perfil: cards em duas colunas, formulário, acesso/segurança e rodapé com extremos | `apps/superadmin/test/features/account/presentation/screens/goldens/profile_1440_dark.png`; `account_pages_golden_test.dart`; `profile_page_test.dart` |
| 28 | Ajustar foto: cabeçalho, X vermelho, crop, reset, slider e ações 50/50 | `apps/superadmin/test/features/account/presentation/screens/profile_page_test.dart`; contratos `pattern.overlay-surfaces` e `pattern.dialog-actions` |
| 29 | Configurações: largura central, cards, tema segmentado e reduzir animações | `apps/superadmin/test/features/account/presentation/screens/goldens/settings_1440_dark.png`; `account_pages_golden_test.dart`; `settings_page_test.dart` |
| 30 | Bug: popup neutro, X vermelho, selects, texto, anexo, ajuda e Enviar disabled | goldens `*_bug_open_light_1440.png`; `CoeloAdminDialogShell`; `pattern.overlay-surfaces` |
| 31–32 | Criar/Editar instituição: baseline obrigatória de qualquer tela que crie ou edite uma entidade; estado atual completo, incluindo shell/menu atual, chat, stepper lateral, conteúdo, uploads, campos e rodapé de tela | `apps/superadmin/test/features/institutions/presentation/screens/goldens/institution_form_create_light_375.png`; `institution_form_edit_dark_1440.png`; `institution_form_page_golden_test.dart` |
| Aprovação 2026-08-03 | Acessos > Pessoas: toolbar em faixa própria e tabs lineares sutis para categorias irmãs | `apps/superadmin/lib/shared/presentation/widgets/superadmin_underline_tabs.dart`; `person_directory_page_test.dart`; contrato `pattern.directory-linear-tabs` |
| Aprovação 2026-08-04 | Rodapé de fluxo: `Cancelar` no extremo esquerdo; `Anterior` + `Continuar` outlined e `Salvar alterações` filled no extremo direito; estados menores preservam a ordem | `SuperadminFormActionFooter`; `pattern.form-controls`; testes do componente e do catálogo |
| Aprovação 2026-08-04 | Mídia e marca: ajuste circular de foto, ajuste retangular de capa e seletor avançado de cores | `AvatarCropDialog`; `CoverCropDialog`; `showSuperadminAdvancedColorPicker`; `pattern.media-adjustment`; `pattern.advanced-color-picker` |
| Aprovação 2026-08-04 | Navegação paginada de qualquer fluxo sequencial: concluída, atual tonal e pendente; paginação de registros permanece um contrato distinto | `SuperadminFormStepNavigation`; `pattern.form-step-navigation`; `pattern.directory-pagination` |

## Regras que os anexos tornam explícitas

### Login

- Campo usa superfície neutra, label persistente, ícone e borda
  `outlineVariant`; foco usa borda `primary` de 2 px sem preenchimento laranja.
- Checkbox selecionado e ação principal usam `primary`. O botão principal
  permanece laranja no hover, com o estado pressionado/forte do tema, sem
  overlay cinza.
- Link de recuperação usa a cor de ação aprovada e sublinhado. O aviso de
  acesso restrito é uma superfície tonal informativa, não um alerta de erro.

### Instituições

- Toolbar, conteúdo e paginação formam uma composição única. Não alterar
  medidas de card, tabela, gaps ou paginação isoladamente.
- Card comum preserva `surface` no hover; somente borda e sombra ganham ênfase
  primária sutil. O card de criar usa borda tracejada; no hover, borda e círculo
  do ícone assumem a hierarquia primária.
- Instituições é a baseline obrigatória para todo card de diretório
  administrativo, não apenas para esta feature. O card nunca recebe hover cinza
  ou retangular: preserva `surface`, `radius.lg` e overlay transparente.
- O status do card começa como indicador circular de 24 × 24 sem texto e
  expande para revelar o rótulo em hover, foco ou toque no indicador. As cores
  são semânticas, o texto impede dependência exclusiva de cor e reduced motion
  remove a animação não essencial.
- Filtro aberto usa linhas contínuas. Opção hovered não recebe raio; seleção
  usa checkbox laranja. O rodapé do multi-select divide `Limpar` tonal e
  `Aplicar` preenchido em 50/50.
- A tabela preserva cabeçalho tonal neutro, divisores, linhas contínuas e
  distância `space4` da faixa de criação. Linha hovered não vira card.

### Navegação, flyouts e ações negativas

- Menu expandido e rail compacto compartilham a mesma semântica: top-level
  selecionado usa fundo primário; filho hovered usa `primaryContainer`; filho
  selecionado usa primário. Pai de seção ativa ganha ênfase sem competir com o
  item filho.
- Flyouts de Tour, Acessos, Arquivos e Conta usam `surface`, borda, elevação e
  item discreto arredondado. Não usar fundo tonal no flyout inteiro.
- `X`, Sair, Desligar, Encerrar, Fechar, Remover, Deletar e Excluir usam
  `error` em repouso e `errorContainer` no hover/foco. Ações terminais ficam em
  grupo inferior separado por divisor.
- Em `Acessos > Pessoas`, categorias irmãs usam tabs lineares sem cápsula:
  linha-base neutra, label e underline laranja somente na seleção, hover/foco
  tonal primário sutil e `space4` separando toolbar, tabs e conteúdo. Esse
  padrão não substitui o toggle Cards/Tabela nem filtros/chips.

### Perfil, Configurações, Home e formulários

- Perfil usa conteúdo principal mais largo e coluna auxiliar; o rodapé de tela
  posiciona Redefinir/Cancelar à esquerda e Salvar à direita.
- Configurações usa conteúdo central com largura máxima, cards neutros, três
  segmentos de tema iguais e switch de reduzir animações.
- Home preserva painel de conversas, área central de orientação e compositor
  inferior; sugestões são ações tonais e o envio mantém a hierarquia laranja.
- Criar/Editar instituição é a verdade visual padrão de toda criação/edição no
  Superadmin, seja formulário simples ou wizard de página. O domínio altera
  conteúdo e regras, não autoriza uma identidade paralela. Em desktop, Cancelar
  fica no extremo esquerdo e o grupo Anterior/Continuar/Salvar no direito.
  `OutlinedButton` é secundário, `TextButton` é terciário e somente uma ação
  preenchida é primária.
- Por confirmação do Owner em 2026-08-04, os goldens de Criar/Editar registram
  a tela como existe hoje por inteiro. O shell, o menu atual e o chat exibidos
  nesses goldens também pertencem à referência; não devem ser removidos,
  substituídos ou aproximados por uma versão antiga ao reutilizar a baseline.
- Qualquer divergência de composição ou identidade deve ser proposta ao Owner
  antes do código, com comparação, componentes, estados, tokens,
  responsividade e testes. Sem aprovação explícita, preservar esta baseline.
- Em dialogs: uma ação ocupa 100%, duas dividem 50/50 e três dividem em terços.
  Em tela ampla: usar extremos; não aplicar a regra 50/50 do dialog ao rodapé.

## Gate visual

Antes de concluir mudança nessas superfícies:

1. consultar `pattern.approved-superadmin-surfaces` e o padrão específico;
2. identificar o golden aprovado equivalente;
3. validar 375, 768, 1024 e 1440 quando a composição responder por breakpoint;
4. validar light/dark, hover, foco, teclado, texto a 200% e reduced motion;
5. executar teste funcional antes do golden e nunca atualizar golden para
   esconder regressão.
6. não aceitar golden geral da página como prova de hover, foco, seleção, menu
   aberto, expansão ou ação negativa; usar o arquivo exato da matriz.
