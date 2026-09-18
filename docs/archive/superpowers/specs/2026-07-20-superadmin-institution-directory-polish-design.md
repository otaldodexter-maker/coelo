---
source: solicitação aprovada do usuário
status: approved-design
generated_at: 2026-07-20
---

# Refinamento visual do diretório de instituições

## Objetivo

Refinar cards, tabela, filtros, cabeçalho e menu lateral do diretório de instituições sem alterar a arquitetura de dados já implementada.

## Card de instituição

- O status nasce como um círculo usando a cor semântica atual.
- Hover e foco expandem o círculo para o chip arredondado com o texto completo.
- Em dispositivos de toque, o status pode ser expandido por toque para não depender exclusivamente de hover.
- O estado recolhido deve preservar espaço para o nome da instituição.
- O conteúdo do card será centralizado verticalmente, reduzindo o vazio inferior.
- Ícone e textos de cada categoria serão centralizados entre si.
- Tipo, Plano, Unidades e Grupos (Turmas) usarão o peso `FontWeight.w700` da tipografia do tema.
- Cores, sombras, tipografia, raios e espaçamentos continuarão vindo exclusivamente do design system Coelo.

## Tabela

- O contêiner externo da tabela e o banner “Criar instituição” nunca ultrapassarão a largura útil da página.
- A tabela interna poderá continuar mais larga para preservar todas as colunas.
- A navegação horizontal ficará dentro do contêiner, com barra de rolagem e suporte a arraste por mouse e toque.
- O banner e a tabela compartilharão o mesmo viewport horizontal.

## Cabeçalho, perfil e interações

- O menu do usuário abrirá abaixo do acionador, sem cobrir avatar ou nome.
- O acionador e as opções terão cantos arredondados e estados de hover/foco usando tokens do tema.
- Sino e reporte de bug continuarão usando `IconButton`, com hover/foco Material e cores semânticas Coelo.
- Os itens dos filtros usarão hover laranja suave, sem modificar a seleção ou provocar deslocamento de layout.

## Tema no menu lateral

- O controle ficará na parte inferior do menu lateral.
- Terá três opções: Seguir o sistema, Claro e Escuro.
- No menu expandido, as três opções serão identificadas por texto e ícone.
- No menu recolhido, haverá um acionador compacto que abre as mesmas três opções.
- O modo será compartilhado por todo o app para permanecer consistente entre rotas.
- Nenhuma preferência será persistida. Cada nova sessão começará em `ThemeMode.system`.

## Arquitetura

- Um pequeno `InheritedWidget` disponibilizará o modo atual e o callback já existente de alteração de tema abaixo do `MaterialApp.router`.
- O shell consumirá esse escopo, evitando propagar o estado por todos os construtores e rotas.
- A tela continuará usando os mesmos modelos, view model e repositórios; não haverá alteração no Supabase.

## Acessibilidade e responsividade

- Hover nunca será o único caminho para revelar o status: foco e toque também funcionarão.
- Estados de foco permanecerão visíveis.
- A tabela será rolável nos viewports estreitos sem criar overflow na página.
- O seletor de tema funcionará com menu aberto, recolhido e drawer mobile.

## Testes

- Testar status circular em repouso e expandido em hover, foco e toque.
- Testar alinhamento e pesos tipográficos do card.
- Testar que banner e viewport da tabela não excedem a página e que a rolagem interna alcança as colunas finais.
- Testar posição e forma do menu de perfil.
- Testar hover dos filtros e ações do cabeçalho.
- Testar as três opções de tema no menu aberto, recolhido e drawer.
- Executar testes Flutter, análise estática, build web e inspeção visual em light e dark.

## Fora de escopo

- Persistência da preferência de tema.
- Mudanças no banco de dados, contatos ou catálogo de tipos.
- Novas ações reais para notificações, reporte de bug, perfil ou configurações.
