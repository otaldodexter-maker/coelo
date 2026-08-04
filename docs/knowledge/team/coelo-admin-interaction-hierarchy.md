---
title: Hierarquia de interação administrativa Coelo
knowledge_id: coelo-admin-interaction-hierarchy
source: docs/design/design-system.md
status: validated
generated_at: 2026-08-03
audience: team
surfaces: [admin, superadmin, catalog]
visibility: internal
review_owner: Coelo Product
---

# Hierarquia de interação administrativa Coelo

Hover não é uma regra visual única. Toda superfície deve ser classificada antes
da implementação: ação primária, tonal, item discreto, linha contínua, card
interativo, ação negativa, toggle segmentado ou tab linear de diretório. Cinza/HEX local e hover genérico
do Material não são padrões Coelo.

Ação primária usa botão laranja preenchido; `OutlinedButton` em `surface` com
contorno leve é secundário; `TextButton` em `surface` sem contorno é terciário.
Em rodapé de tela amplo, terciária/cancelar fica no extremo esquerdo e o grupo
de continuidade no direito. Em compacto, a primária ocupa a largura antes das
demais.

A composição completa aprovada é `Cancelar` terciário no extremo esquerdo e
`Anterior` + `Continuar` outlined seguidos de `Salvar alterações` filled no
extremo direito. Estados com menos ações preservam essa ordem. A regra 50/50,
terços ou quartos pertence a popup, não a rodapé de tela.

Em popup, largura não comunica prioridade: uma ação ocupa 100%; duas dividem
50/50; três dividem em terços, com gaps tokenizados. Quando constraints ou texto
ampliado não comportarem a linha, todas empilham em 100%; não existe quebra 2+1.

`X`, sair, desligar, encerrar, fechar, remover, deletar e excluir permanecem na
hierarquia `error`/`errorContainer` enquanto habilitados. Ícones, itens de menu
e botões negativos já são vermelhos em repouso e usam container vermelho no
hover/foco. Compartilhar a hierarquia visual não compartilha regras de
confirmação, autorização ou auditoria.

Flyouts usam `surface`, sem tint, borda, `radius.lg`, elevação e padding
tokenizado. Perfil e Configurações formam o grupo padrão; ações terminais ou
destrutivas ficam abaixo de divisor. O popup de Bug é a referência modal; Tour,
Perfil e Arquivos são referências de flyout.

Na implementação, cards administrativos clicáveis usam
`CoeloAdminInteractiveCard` e menus ancorados usam `CoeloAdminFlyout`. Itens
negativos definem `CoeloAdminFlyoutTone.negative`. Um validador bloqueante do
catálogo impede novas composições Material brutas; a allowlist é exclusiva do
legado contado e justificado e não deve crescer para acomodar tela nova.

Instituições é a baseline obrigatória para todo card de diretório
administrativo. O card usa `CoeloAdminInteractiveCard`, mantém `surface` e
`radius.lg`; hover/foco enfatizam
somente borda e sombra, nunca com overlay cinza ou retangular. Quando existe
status semântico, usar `CoeloAdminExpandableStatusIndicator`: ele começa como
ponto circular de 24 × 24 sem texto e expande
para revelar o rótulo em hover, foco ou toque no indicador. A apresentação usa
cores semânticas com texto e remove a animação não essencial em reduced motion.

Login, Instituições, Home, navegação, Conta, overlays e o wizard de
Criar/Editar instituição possuem uma matriz visual aprovada única. Para essas
famílias, consultar
`.agents/skills/coelo-ui/references/approved-superadmin-visual-baselines.md`,
o golden indicado e o padrão específico antes de alterar a composição. Pastas
`failures/` contêm somente diagnóstico de regressão e não são referência.

Categorias irmãs que filtram o mesmo diretório sem trocar de página usam a
baseline de `Acessos > Pessoas`: tabs lineares sobre `surface`, linha-base
`outlineVariant`, seleção por label e underline `primary`, e hover/foco tonal
primário sutil sem cinza. Há `space4` entre toolbar, tabs e conteúdo. Esse
padrão é diferente do toggle Cards/Tabela em cápsula, de filtros/chips e da
navegação entre rotas. No Superadmin, reutilizar `SuperadminUnderlineTabs`.

Ao criar, refazer, refatorar ou corrigir UI do Superadmin, a equipe declara uma
baseline principal entre Login, Instituições, Home, Menu/Flyouts,
Perfil/Configurações, Popup de Bug e Criar/Editar instituição. A comparação
abrange estado interativo, componente, seção e página inteira. Quando uma tela
é nomeada como referência, consultar código real, componentes compartilhados,
testes e golden; aproximação visual não é suficiente.

Qualquer tela que crie ou edite uma entidade escolhe automaticamente
Criar/Editar Instituição como baseline, mesmo que o pedido não a nomeie. Isso
inclui novos widgets, seções, correções e refatorações. Reutilizar
`SuperadminFormActionFooter`, `CoeloFormTextField` e
`CoeloAdminSingleSelectField`; a navegação e as seções específicas de
Instituições definem anatomia e responsividade. Uma necessidade real de
identidade diferente deve ser comparada e proposta ao Owner antes do código.
Sem aprovação explícita, prevalece a baseline aprovada e não se cria variante,
golden ou allowlist divergente.

Desde a confirmação do Owner em 2026-08-04, a baseline de Criar/Editar
Instituição corresponde ao render atual completo dos goldens: a tela, o
shell/menu como existem hoje e o chat fazem parte da mesma verdade visual. Não
substituir o menu atual por uma composição histórica ao aplicar essa referência.

Todo estado interativo solicitado deve ser rastreado, antes do código, até a
implementação real, componente ou contrato, teste comportamental e golden
específico na matriz `interactive-state-evidence-matrix.md`. Um golden geral da
página não substitui evidência de hover, foco, seleção, menu aberto, expansão ou
ação negativa. Estado sem evidência visual exige proposta, não improvisação.

Em mobile e tablet, Superadmin, Admin e Principal usam no tema claro uma base
`colorScheme.surface`, inspirada conceitualmente na limpeza estrutural de
Instagram e Airbnb. Cinza não é fundo-base padrão; `surfaceContainer*` serve a
regiões secundárias com função explícita. Dark theme usa seus papéis semânticos.

Os 14 padrões rejeitados bloqueiam faixas cinza genéricas em hover/seleção,
controles Material crus, date picker desproporcional, rodapé inventado e zero
gap entre cards/seções. Novos usos de `DropdownButton`,
`DropdownButtonFormField`, `RadioListTile`, `CheckboxListTile` e
`showDateRangePicker` dentro de features são barrados pelo gate visual; legado
permanece contado e não autoriza ampliar a allowlist. Sem componente adequado,
registrar proposta em vez de usar o default Material.
