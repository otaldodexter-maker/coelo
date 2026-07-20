---
source: solicitação aprovada do usuário
status: approved-design
generated_at: 2026-07-20
---

# Refinamento de cards, tabela e tema do diretório de instituições

## Objetivo

Fazer o último refinamento visual do diretório de instituições, mantendo a arquitetura existente, os dados fictícios da prévia e os tokens semânticos do design system Coelo.

## Cards

- O status recolhido terá 24 px de diâmetro e conservará a cor semântica já usada para cada estado.
- Hover e foco expandirão o círculo para o rótulo completo; toque continuará disponível para dispositivos sem hover.
- O card terá menor altura e menor padding vertical, preservando respiro lateral e legibilidade.
- Ícone, rótulo e valor de Tipo, Plano, Unidades e Grupos (Turmas) permanecerão alinhados, mas terão maior distância entre rótulo e valor.
- Nome, localização e detalhes continuarão truncando de forma segura quando não houver espaço.

## Tabela e banner

- O banner “Criar instituição” ocupará somente a largura útil da página e ficará fora da rolagem horizontal.
- A tabela terá um viewport com largura máxima igual à área de conteúdo; apenas seu conteúdo interno será mais largo.
- A barra horizontal ficará visível dentro do contêiner da tabela e aceitará mouse, trackpad e toque.
- As colunas poderão ser redimensionadas arrastando seus divisores no cabeçalho, respeitando largura mínima por coluna.
- O redimensionamento será local à sessão e não será persistido.
- A ordem será: Instituição, Tipo, Unidades, Grupos, Plano, Status, E-mail, Telefone, Celular, Domínio, Logradouro, Número, Complemento, Bairro, Município e UF.
- A repetição de Número e Complemento na solicitação foi interpretada como duplicação textual; haverá somente um par correspondente ao endereço legal.
- E-mail, Telefone, Celular e Domínio manterão ações de copiar.
- A implementação usará widgets Flutter existentes e um cabeçalho leve próprio, sem adicionar pacote de tabela.

## Dados

- O modelo do diretório passará a mapear `street`, `number` e `complement`, campos que já existem em `institution_addresses` e na view `institution_directory`.
- Nenhuma migration nova será necessária.
- Endereço exibido será o endereço legal da instituição, não o endereço de uma unidade.

## Cabeçalho

- Bug e notificações continuarão como botões circulares.
- Em hover, foco e pressão, fundo e ícone usarão o mesmo estado semântico de ação do toggle cards/tabela, incluindo `CoeloActionColors.primaryHover`.
- Nenhuma cor hexadecimal será adicionada localmente.

## Toggle claro e escuro

- O menu não exibirá mais “Seguir o sistema”.
- Na primeira abertura de cada sessão, o app continuará em `ThemeMode.system`, refletindo o tema do sistema.
- Após a primeira interação, o controle alternará somente entre `ThemeMode.light` e `ThemeMode.dark`.
- O controle será uma cápsula de duas posições com sol, lua e a marca oficial do coelho como indicador animado.
- No menu expandido e no drawer mobile, a cápsula ficará horizontal.
- No menu recolhido, ficará vertical.
- Não haverá persistência entre sessões.

## Acessibilidade e testes

- Status e toggle funcionarão por mouse, teclado e toque, com semântica e tooltip.
- Divisores redimensionáveis terão cursor apropriado e área de interação maior que a linha visual.
- Testes cobrirão dimensões do status, espaçamento do card, contenção do banner/tabela, ordem das colunas, cópia, redimensionamento, hover dos ícones e toggle horizontal/vertical.
- A entrega será validada com análise estática, suíte Flutter e build web.

## Fora de escopo

- Persistir tema ou larguras de colunas.
- Ordenação de dados ao clicar no cabeçalho.
- Cadastro e edição da instituição.
- Alterações nas tabelas de endereço existentes no Supabase.
