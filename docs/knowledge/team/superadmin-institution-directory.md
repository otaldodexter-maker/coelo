---
title: Diretório de instituições do Superadmin
knowledge_id: superadmin-institution-directory
source: docs/design/design-system.md
status: validated
generated_at: 2026-07-29
revised_at: 2026-08-04
audience: team
surfaces: [superadmin, institutions]
visibility: internal
review_owner: Coelo Product
---

# Diretório de instituições do Superadmin

A paginação do diretório de Instituições usa `CoeloAdminPagination` nos modos de
cards e tabela. O conjunto completo fica centralizado e mantém cada quebra
responsiva centralizada.

O seletor de itens por página é compacto, usa gatilho pill e menu neutro com a
mesma largura do gatilho. A opção selecionada, hover e foco usam
`primaryContainer` e `primary`, sem check ou checkbox. Cards oferecem
`11, 20, 50, 100`; tabela oferece `8, 20, 50, 100`.

Nos diretórios do Superadmin, a paginação sticky reutiliza uma composição
app-local, com inset medido para impedir que o último card ou linha seja
coberto. A faixa não possui borda ou linha superior; usa `surface` translúcida
a 84% no tema claro e 88% no escuro e blur `CoeloSpacing.space3`. Isso não cria
variante pública e não se aplica à paginação inline não sticky. Quando o
launcher de mensagens está disponível, ele recebe o inset medido e permanece
acima do rodapé, sem cobrir a paginação.

O contrato reutilizável está em `admin.pagination` e
`pattern.selection-controls` no índice Coelo UI. Não existe variante pública
específica de Instituições.

A composição completa do diretório usa toolbar, busca, filtros, toggle
cards/tabela e arquivos; há `space4` entre toolbar e conteúdo. Cards usam
`space6` nos dois eixos, mínimo de referência de 340 px por coluna, altura
mínima de 216 px e padding horizontal `space6`/vertical `space4`. No modo
tabela, a faixa de criação precede `space4` e a tabela redimensionável.

O status não concorre com a toolbar em um dropdown. Entre toolbar e resultados,
tabs lineares exclusivas oferecem `Todos`, `Ativos`, `Em Implantação` e
`Inativos`. `Todos` não aplica filtro e continua exibindo também rascunhos,
suspensas e arquivadas; as demais tabs correspondem, respectivamente, a
`active`, `onboarding` e `inactive`.

Cada segmento do toggle Cards/Tabela mede 64 × 48 px. O menu de visões
reutiliza `CoeloAdminFlyout`: cada item mantém a largura útil padrão de 220 px
em painel de 236 px, sem recorte pelo padding, e itens interativos
consecutivos têm `CoeloSpacing.space1` de separação, impedindo que seleção e
hover laranja se unam. Na tabela, a largura natural nasce centralizada quando
for menor que a viewport; quando ocupar ou exceder a área, preenche e rola
normalmente. Scrollbar e track horizontais permanecem visíveis desde a primeira
coluna e são pintados acima da cópia visual fixa. A faixa de criação continua
em largura total.

Hover do card preserva `surface` e enfatiza borda/sombra com `primary`; hover de
linha usa `primaryContainer` sem raio ou gap. O toggle segmentado usa
`surface`/`outlineVariant`, com seleção, hover e foco em
`primaryContainer`/`primary`. Clicar diretamente em Tabela ou ativá-la com
Enter/Espaço abre `Agrupado`; as visões detalhadas abrem por hover no segmento
inteiro, pressão longa em toda a área de 64 × 48 px ou `Alt+↓` com foco. `Esc`
fecha e devolve foco ao gatilho, e a opção atual expõe `selected` semanticamente.
Arquivos reutiliza `CoeloAdminFileActions`.

## Regras canônicas e pontos de integração

Diretórios administrativos do Superadmin mantêm os botões de ação principais acima
da lista e abaixo do bloco de criação de contexto: `Criar`, `Convidar` e
`Cadastrar` aparecem antes dos resultados de cards/tabela, seguidos por busca,
filtros pequenos e paginação.

A referência visual de Instituições é a baseline congelada de cards, tabela e fluxo
de criação/edição; integração de dados não pode redesenhar ou alterar composição
sem aprovação explícita.

Na composição de diretório, estados de `loading`, `erro`, `retry`, `vazio`,
`sem resultados`, `not-found` e `unauthorized` preservam a composição existente.

Mídia privada permanece com metadados em Supabase e armazenamento privado em
Cloudflare R2 por decisão arquitetural (0010), sem destino Supabase Storage como
padrão da família.
