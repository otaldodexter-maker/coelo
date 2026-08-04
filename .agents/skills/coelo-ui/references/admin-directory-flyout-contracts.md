---
source: "docs/design/design-system.md; docs/superpowers/specs/2026-07-28-superadmin-institution-sticky-pagination-design.md; goldens aprovados de Instituições, Bug, Tour, Perfil, Configurações e formulário de Instituições"
status: "active"
generated_at: "2026-08-03"
---

# Diretórios administrativos, hover e flyouts

Consulta obrigatória para listagem, diretório, cards/tabela, view toggle,
arquivos, flyout, perfil, configurações, tour, sair, excluir ou deletar. A tela
de Instituições do Superadmin é a referência canônica de composição. A
implementação canônica é pública em `coelo_ui_admin`: usar
`CoeloAdminInteractiveCard` para cards clicáveis e `CoeloAdminFlyout` para
menus ancorados. Features não recriam essas superfícies com widgets Material
brutos.

Instituições não é apenas exemplo ilustrativo: é a baseline automática para
todo card do Coelo, inclusive fora de diretórios e em novas features. Somente
uma indicação explícita do usuário por outro padrão aprovado permite divergir.

## Anatomia do diretório

1. Toolbar com `CoeloAdminListingToolbar`: busca, filtros, toggle de visualização
   e `CoeloAdminFileActions`.
2. Conteúdo em cards ou tabela, nunca os dois simultaneamente.
3. Cards: `Wrap` com `CoeloSpacing.space6` nos dois eixos; largura calculada pela
   área disponível, mínimo de referência de 340 px por coluna; altura mínima de
   216 px; padding horizontal `space6` e vertical `space4`.
4. Tabela: `CoeloAdminCreateAction.banner`, `CoeloSpacing.space4` e
   `CoeloAdminResizableTable`, nessa ordem. Não colar a faixa de criação na
   tabela nem inventar outro gap. A superfície usa a largura natural das colunas
   até o limite disponível; somente expande ou rola horizontalmente quando o
   conteúdo realmente exigir.
5. Entre toolbar e conteúdo usar `CoeloSpacing.space4`.
6. A paginação usa `CoeloAdminPagination` em rodapé sticky privado, sem borda
   superior, com blur `CoeloSpacing.space3`, `surface` a 84% no tema claro e
   88% no escuro, e inset medido para não cobrir card, linha ou launcher. Cards
   oferecem `11, 20, 50, 100`; tabela oferece `8, 20, 50, 100`.

## Filtros, toggle e arquivos

- Busca e filtros têm alvo mínimo de 48 px, forma pill, superfície neutra e
  borda `outlineVariant`; aberto/focado usa borda `primary` de 2 px.
- Multi-select mantém rascunho até `Aplicar`; single-select aplica uma escolha e
  não usa checkbox. Reutilizar os componentes administrativos indexados.
- O toggle cards/tabela é um controle segmentado único: contêiner pill em
  `surface`, borda e divisória `outlineVariant`; selecionado, hover e foco usam
  a hierarquia `primaryContainer`/`primary`. Cada segmento mede 64 × 48 px e
  tem nome acessível. Não usar dois botões soltos nem cor cinza local.
- Clicar diretamente em Tabela ou ativá-la com Enter/Espaço seleciona
  `Agrupado`. Quando houver visões detalhadas, o flyout abre por hover no
  segmento inteiro, pressão longa em toda a área de 64 × 48 px ou `Alt+↓` com
  foco. Nunca limitar hover ou pressão longa ao ícone. `Esc` fecha e devolve o
  foco ao gatilho. O flyout usa `surface`, tint transparente, borda,
  `CoeloRadius.lg` e elevação semântica; a opção atual expõe semanticamente
  `selected: true`, sem depender somente da cor.
- O flyout de visões usa `CoeloAdminFlyout`; `MenuAnchor` local na feature não é
  uma variante permitida.
- A largura natural de `CoeloAdminResizableTable` nasce centralizada quando for
  menor que a viewport. Scrollbar e track horizontais são pintados acima da
  coluna fixa e permanecem visíveis desde a primeira coluna. A faixa de criação
  continua em largura total.
- Arquivos usa `CoeloAdminFileActions`. O flyout agrupa importação e exportações
  em `surface`, sem tint, e seus itens seguem o hover de item discreto.

## Matriz obrigatória de hover

Antes de estilizar hover, classificar a superfície. “Hover padrão Material”,
cinza local, HEX local ou uma regra única aplicada a tudo bloqueiam a entrega.

| Família | Hover/foco aprovado | Forma e espaçamento | Referência |
| --- | --- | --- | --- |
| Ação primária | permanece `primary`/`onPrimary`, sem overlay cinza | forma do botão | ações principais |
| Ação tonal | `primaryContainer`/`onPrimaryContainer`, sem overlay extra | forma do controle | sugestões e envio antecipado |
| Item discreto | fundo `primaryContainer`, conteúdo `primary` | `radius.md` e `spaceHalf` entre itens | menu lateral, Tour, Perfil e Arquivos |
| Linha contínua | fundo `primaryContainer` | sem raio e sem gap | opções de filtro e linhas de tabela |
| Card interativo | mantém `surface`; borda passa a `primary` translúcido e a sombra ganha ênfase primária sutil | preserva `radius.lg`; não preencher todo o card | qualquer card, por padrão |
| Ação negativa | fundo `errorContainer`, conteúdo `error` | varia por ícone, item ou botão; grupo de menu separado por divisor | X do Bug e `Sair` no Perfil |
| Toggle segmentado | segmento usa `primaryContainer`/`primary` | pill externa e divisória contínua | cards/tabela de Instituições |

Disabled não recebe hover. Foco visível deve ser equivalente, mas não pode
depender somente da cor. `surfaceTintColor` e overlays adicionais permanecem
transparentes.

## Card de Instituições e status progressivo

- O corpo do card permanece em `surface` no repouso, hover e foco. Não aplicar
  preenchimento cinza, `primaryContainer`, overlay Material ou hover retangular
  sobre a superfície inteira; overlay e splash adicionais são transparentes.
- Hover e foco preservam `radius.lg` e comunicam interatividade somente pela
  borda primária translúcida, sombra primária sutil e foco visível.
- Quando existe status semântico, seu indicador inicia como ponto circular de
  24 × 24, sem texto. Em Admin/Superadmin, implementar com
  `CoeloAdminExpandableStatusIndicator` e não recriar o estado localmente. No
  Principal, implementar o mesmo contrato no pacote próprio e nunca importar
  `coelo_ui_admin`. Em hover, foco por teclado ou ativação por toque no
  indicador, ele expande e revela o rótulo do status.
- O estado expandido preserva a cor semântica correspondente e inclui texto;
  nunca comunicar Ativa, Suspensa, Em implantação ou outro status apenas pela
  cor. O alvo interativo continua acessível mesmo com a forma visual compacta.
- A expansão usa duração e curva tokenizadas. Com reduced motion, a mudança de
  tamanho e rótulo ocorre sem animação não essencial.
- Um card sem status não inventa o indicador. Um card com status não troca este
  padrão por chip permanentemente aberto, salvo contrato de densidade diferente
  aprovado e indexado.

## Flyouts

- Usar `CoeloAdminFlyout`; cada opção é um `CoeloAdminFlyoutItem`. Ação
  terminal ou destrutiva define `startsGroup: true` e
  `tone: CoeloAdminFlyoutTone.negative`.
- Flyout usa `colorScheme.surface`, `surfaceTintColor: Colors.transparent`,
  `CoeloRadius.lg`, borda `outlineVariant`, elevação e padding `space2`.
- Tour da tela/menu/completo usa o flyout de Tour como referência.
- Perfil e Configurações formam o grupo padrão. `Sair`, revogar convite,
  acesso, vínculo ou autorização, excluir ou deletar
  pertencem a um grupo destrutivo inferior, separado por `Divider` e respiro
  `space1`.
- Itens padrão seguem item discreto. Itens destrutivos usam
  `errorContainer`/`error` no hover e foco. Nunca tornar o flyout inteiro
  vermelho e nunca misturar ação destrutiva no grupo padrão.
- Em ações de convite, `Reenviar convite` é item padrão. `Revogar convite` usa
  `startsGroup: true` e `tone: CoeloAdminFlyoutTone.negative`; o divisor e a
  hierarquia vermelha são obrigatórios mesmo quando a revogação for reversível.
- Ícone, texto, hover, foco e área clicável pertencem ao mesmo alvo mínimo de
  48 px. `Esc` fecha e devolve o foco ao gatilho.

## Ações negativas

`X`, sair, desligar, encerrar, fechar, remover, deletar e excluir devem ser
classificados semanticamente antes da escolha do widget. Enquanto habilitados,
todos permanecem na hierarquia vermelha do Design System:

- ícone de fechar/dispensar: `Icons.close_rounded`, ícone `error` já no repouso,
  fundo transparente e circular; hover/foco em `errorContainer`;
- item de menu terminal ou destrutivo: ícone e texto `error` no repouso,
  `errorContainer` no hover/foco, `radius.md` e divisor antes do grupo;
- botão textual/outlined negativo: conteúdo e borda, quando houver, em `error`;
  hover/foco em `errorContainer`;
- confirmação destrutiva principal pode usar fundo `error` e conteúdo
  contrastante do tema; cancelar permanece neutro.

Não usar `primary`, grafite ou cinza para ação negativa habilitada. Disabled não
simula perigo: usa o contrato disabled do componente, continua sem hover e deve
explicar indisponibilidade quando necessário. Fechar uma superfície e excluir
dados continuam operações diferentes; compartilhar a hierarquia vermelha não
compartilha regras de confirmação, autorização ou auditoria.

## Popup e formulários relacionados

- Popup modal segue `pattern.overlay-surfaces`; o diálogo de Bug é a referência
  visual. Não copiar seu conteúdo de domínio.
- Ações irmãs de popup têm largura igual; prioridade é comunicada pelo estilo,
  não por largura:
  - uma ação: 100% da largura útil;
  - duas ações: 50/50 com `CoeloSpacing.space3`;
  - três ações: três partes iguais com dois gaps `space3`;
  - quando a largura útil ou texto ampliado não comportar a linha, empilhar
    todas com 100% da largura e `space2` ou `space3` vertical.
- Em linha, ordenar neutra/cancelar, secundária e primária ou destrutiva. Em
  coluna, preservar uma ordem de leitura previsível e consistente na superfície;
  não alternar arbitrariamente entre dialogs.
- Não usar `Wrap` que produza uma linha com dois botões e outra com um, larguras
  intrínsecas diferentes ou botão principal artificialmente maior.
- Perfil, Configurações e Criar/Editar Instituições seguem
  `pattern.form-controls`, o contrato de formulários e suas matrizes
  responsivas.

## Verificação mínima

- Executar, a partir de `apps/catalog`,
  `rtk proxy C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe run tool/validate_admin_visual_contracts.dart ../.. assets/admin-visual-contract-allowlist.json`.
  O comando é bloqueante. Nova ocorrência de `Card` + `InkWell`,
  `PopupMenuButton`, `PopupMenuItem`, `MenuAnchor` ou `MenuItemButton` em feature
  não pode ser resolvida aumentando a allowlist; deve usar o componente
  canônico. A allowlist existe somente para legado contado e justificado.
- Validar 375, 768, 1024 e 1440 px quando a composição for alterada.
- Validar light/dark, texto a 200%, teclado, foco, semântica e reduced motion.
- Exercitar por teste cada família de hover usada na mudança.
- Comparar somente com goldens aprovados; `failures/` são artefatos transitórios.
