---
source: "user-approved redesign of specs/016-superadmin-support-prototype.md; screenshots supplied on 2026-07-27; docs/design/design-system.md; coelo-ui surface interaction contracts"
status: "approved"
generated_at: "2026-07-27"
---

# Redesenho operacional da tela de Suporte

## Objetivo

Alinhar a gestão de chamados do Superadmin às referências canônicas de
Instituições para filtros e tabela, e introduzir um Kanban operacional coerente
com o design system do Coelo. O protótipo continua local, sem I/O ou
persistência.

Este desenho complementa:

- `specs/016-superadmin-support-prototype.md`;
- `docs/superpowers/specs/2026-07-27-support-requester-context-design.md`;
- `docs/design/design-system.md`;
- o contrato de superfícies e interações da skill `coelo-ui`.

Em caso de divergência, este documento prevalece apenas para a composição
visual e para a atribuição local da equipe no protótipo.

## Decisões

### Estratégia de componentes

Filtros e tabela reutilizam os componentes administrativos existentes. Não será
criada uma tabela paralela nem uma API pública genérica de Kanban.

O Kanban será:

- documentado como padrão administrativo no design system e no catálogo;
- implementado como composição local da feature de Suporte;
- promovido a componente público somente depois de existir outro uso real que
  permita validar sua API.

A pilha de avatares da equipe também permanece local. Os avatares de chat não
serão reutilizados, pois carregam semânticas de presença e publicação que não
representam atribuição de trabalho.

### Responsabilidade pelo chamado

Cada chamado pode ter:

- um responsável principal;
- zero ou mais colaboradores.

O responsável principal representa quem responde pelo andamento. Colaboradores
representam participação complementar. Um chamado novo pode começar sem
responsável, mas a transição para `Em andamento` exige um responsável principal.

As fixtures terão pessoas demonstrativas vinculadas às funções:

- Suporte;
- Desenvolvimento;
- Customer Success;
- Qualidade.

Função e pessoa serão sempre exibidas juntas quando houver espaço. A função não
substitui a identidade de quem está executando o trabalho.

## Modelo local

Adicionar ao domínio local:

- `SupportTeamRole`: `support`, `development`, `customerSuccess` e
  `qualityAssurance`;
- `SupportTeamMember`: identificador, nome, iniciais e função;
- `ownerId` opcional em `SupportTicket`;
- `collaboratorIds` imutáveis em `SupportTicket`.

O controller continua sendo a fonte única da sessão e oferece:

- `assignOwner`;
- `setCollaborators`;
- validação da transição para `inProgress`;
- filtragem por responsável;
- as ações já existentes de criação, status, leitura e resposta.

Não haverá repository, sincronização, auditoria ou persistência.

## Toolbar e filtros

A composição seguirá a tela de Instituições:

- busca e gatilhos com altura mínima de 48 px;
- busca com largura explícita;
- filtros com largura explícita;
- ações no extremo direito;
- `Wrap` com quebras intencionais em larguras menores;
- seletor Kanban/Tabela por ícones com tooltips.

Os filtros visíveis serão:

- Status;
- Menu;
- Responsável;
- Leitura.

O filtro de Tela aparece após a seleção de Menu, seguindo a progressão usada em
Instituições para filtros dependentes.

`Leitura` substitui o `FilterChip` isolado e oferece o estado `Não lidas` sem
romper o padrão visual. Todos os filtros multi-select preservam rascunho até
`Aplicar`, com `Limpar`, busca interna quando necessária, `Esc` e retorno de
foco.

O componente compartilhado de filtro deve ser corrigido, se necessário, para
cumprir o contrato já aprovado:

- gatilho aberto com `primaryContainer`;
- texto e seta em `primary`;
- borda de foco ou menu aberto com 2 px em `primary`;
- sem overlay cinza adicional.

Essa correção não altera o domínio nem cria uma segunda variante visual.

## Tabela

A tabela usa `CoeloAdminResizableTable` com a mesma geometria de Instituições:

- cabeçalho de 56 px;
- linhas de 64 px mais divisor;
- primeira coluna fixa;
- superfície, borda, hover, foco e seleção canônicos;
- scrollbar horizontal visível;
- texto sem quebra e com reticências.

Colunas:

1. `Chamado`: ID e resumo, fixa;
2. `Origem`: `Menu > Tela`;
3. `Solicitante / contexto`: solicitante e trilha institucional compacta;
4. `Responsável`: responsável principal e colaboradores;
5. `Status`: chip e menu de alteração;
6. `Anexos`;
7. `Não lidas`;
8. `Atualizado em`.

As células usam alinhamento, densidade e padrões de truncamento equivalentes aos
de Instituições. Mudanças feitas na tabela aparecem imediatamente no Kanban e
no detalhe por compartilharem o mesmo controller.

## Kanban

O Kanban mantém as quatro colunas:

- Novo;
- Em andamento;
- Aguardando solicitante;
- Concluído.

Cada coluna contém:

- superfície de baixa ênfase associada ao status;
- label textual, contador e ação contextual;
- área de drop com estado de foco e arraste visível;
- lista vertical com espaçamento entre cards;
- estado vazio próprio.

A cor nunca será a única indicação de status.

Cada card contém:

- ID e título;
- resumo curto;
- origem `Menu > Tela`;
- solicitante e contexto compacto;
- data da última atualização;
- indicadores de anexos e mensagens não lidas;
- responsável principal;
- pilha de colaboradores;
- menu contextual.

O card inteiro pode ser arrastado com mouse no desktop. Teclado, toque e
viewports compactas usam o menu contextual equivalente para mudar status. O
menu também permite atribuir responsável e colaboradores.

Durante o arraste, a coluna de destino recebe realce semântico. Movimento
respeita `disableAnimations`.

## Detalhe do chamado

O detalhe preserva o painel lateral no desktop e a tela cheia no compacto.

Anatomia:

1. ID, título, status e ação de fechar canônica;
2. responsável principal e colaboradores editáveis;
3. solicitante e trilha completa
   `Usuário > Instituição > Unidade > Grupo > Atividade`;
4. relatório original;
5. evidências;
6. histórico de mensagens e estados de entrega/leitura;
7. composer de resposta.

Abrir o detalhe marca mensagens recebidas como lidas pelo suporte. `Esc` fecha o
painel ou diálogo e devolve o foco ao card ou linha de origem.

## Responsividade

### 1024–1440 px

- toolbar prioritariamente em uma linha;
- quebra somente quando a largura útil não comportar os controles;
- quatro colunas com rolagem horizontal;
- detalhe em painel lateral.

### 768 px

- toolbar em grupos coerentes;
- Kanban horizontal;
- detalhe sobreposto;
- menus substituem interações dependentes de hover.

### 375 px

- busca em largura total;
- filtros em duas colunas quando couberem;
- uma coluna de Kanban por vez;
- mudança de status por menu;
- detalhe em tela cheia.

## Estados e acessibilidade

Cobrir:

- conteúdo;
- vazio geral;
- nenhum resultado;
- coluna vazia;
- chamado selecionado;
- sem responsável;
- responsável com colaboradores;
- anexos;
- composer vazio e habilitado;
- mensagens lidas e não lidas;
- drag ativo e destino válido.

Requisitos:

- light e dark;
- texto a 200%;
- foco visível;
- alvos mínimos de 48 px;
- navegação por teclado;
- labels e contadores independentes de cor;
- tooltips para ações somente com ícone;
- `Esc` e retorno de foco.

## Catálogo, design system e skill

Atualizar o design system com um contrato de Kanban administrativo cobrindo:

- anatomia de coluna e card;
- status semântico;
- espaçamento;
- drag/drop e alternativa por menu;
- atribuição de equipe;
- responsividade e acessibilidade.

Registrar no catálogo um padrão administrativo de Kanban apontando Suporte como
referência implementada. O registro descreve um padrão, não exporta widget.

Atualizar a referência operacional da skill `coelo-ui` somente com regras
duráveis que ajudem futuras implementações a encontrar e cumprir esse contrato.

Filtros e tabela continuam apontando Instituições como referência canônica.

## Testes

### Unidade

- responsável principal e colaboradores imutáveis;
- atribuição e remoção;
- transição para `Em andamento` exige responsável;
- filtros por responsável;
- sincronização entre status, atribuição, leitura e resposta.

### Widget

- toolbar e filtros progressivos;
- estado aberto, aplicar, limpar, `Esc` e retorno de foco;
- tabela com geometria e colunas canônicas;
- atribuição pela tabela, card e detalhe;
- Kanban, drag/drop e alternativa por menu;
- detalhe, contexto, evidências, conversa e composer;
- navegação protegida e integração com o modal.

### Visual

Atualizar goldens de Kanban, tabela e detalhe em:

- 375 px;
- 768 px;
- 1024 px;
- 1440 px;
- light e dark.

Executar análise estática, testes focados, shell/router, catálogo, fronteiras e
validação visual no localhost informado pelo usuário.

## Fora de escopo

- Supabase, migrations, RLS e Realtime;
- persistência da equipe;
- convites, diretório real de colaboradores ou permissões por função;
- notificações e auditoria reais;
- SLA, prioridade, tags e notas internas;
- ações em massa;
- anexos nas respostas;
- componente público genérico de Kanban;
- componente público genérico de pilha de responsáveis.

## Critérios de aceite

- filtros e tabela são visual e comportamentalmente coerentes com Instituições;
- Kanban segue o novo contrato administrativo e mantém quatro estados;
- card, tabela e detalhe exibem o mesmo responsável e colaboradores;
- um ticket em andamento sempre possui responsável principal;
- contexto do solicitante aparece sem separadores ou níveis inexistentes;
- status e atribuição permanecem sincronizados entre todas as visualizações;
- desktop, tablet e mobile oferecem ações equivalentes;
- nenhum backend, I/O ou dependência é introduzido;
- o preview atualizado fica disponível em `http://127.0.0.1:8769/`.
