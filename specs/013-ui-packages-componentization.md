---
title: "Pacotes UI, Catalogo e Governanca de Componentes"
source: "docs/design/design-system.md; specs/007-design-system-base.md; decisions/0012-contextual-experiences-and-conversation-history.md; apps/superadmin/lib/app/shell/superadmin_shell.dart; apps/superadmin/lib/features/institutions/presentation/screens/institution_directory_page.dart"
status: "implemented-foundation-with-operational-gates"
generated_at: "2026-07-27"
---

# Pacotes UI, Catalogo e Governanca de Componentes

## Objetivo

Transformar os padroes visuais ja aprovados do Coelo em uma fundacao
reutilizavel, consultavel por pessoas e agentes de IA, sem alterar a aparencia
das telas de referencia nem criar abstracoes de dominio como se fossem
componentes universais.

## Decisao

O Coelo usa cinco camadas Flutter de UI:

- `packages/coelo_tokens`: tokens, temas, breakpoints, motion e cores semanticas.
- `packages/coelo_ui_core`: componentes sem dominio, reutilizaveis por qualquer app.
- `packages/coelo_ui_admin`: componentes densos comuns ao Admin e Superadmin.
- `packages/coelo_ui_superadmin`: componentes especificos da operacao global Coelo.
- `packages/coelo_ui_principal`: componentes especificos do app principal.

O futuro site Astro nao importa widgets Flutter. Ele devera receber uma
implementacao web propria, derivada da mesma fonte neutra de design tokens e dos
mesmos contratos visuais. A primeira versao do catalogo cobre Flutter e reserva
explicitamente a futura secao Astro.

`apps/superadmin` continua podendo manter widgets privados enquanto o padrao
ainda estiver em validacao. Um componente visual generico ja aprovado como
padrao oficial, porem, pode subir imediatamente para o pacote compartilhado
correto, mesmo antes de uma segunda tela consumidora.

O Gate 1 desta spec foi aprovado em 2026-07-22. A primeira implementacao
materializa somente `coelo_ui_core` e `coelo_ui_admin`. Os pacotes
`coelo_ui_superadmin` e `coelo_ui_principal` continuam reservados ate uma spec
consumidora justificar sua materializacao. O plano detalhado recebeu o Gate 2 e
a fundacao foi implementada conforme o status registrado ao final desta spec.

## Regra De Promocao

1. Mantenha local enquanto o padrao for experimental ou estiver ligado a uma
   unica entidade, rota, permissao ou fluxo de produto.
2. Promova para `coelo_ui_core` quando for um componente visual generico e
   aprovado, sem dependencia de dominio, rota ou permissao.
3. Promova para `coelo_ui_admin` quando for um padrao administrativo aprovado e
   compartilhavel entre Admin e Superadmin.
4. Promova para `coelo_ui_superadmin` quando depender da operacao global Coelo.
5. Promova para `coelo_ui_principal` quando depender da experiencia contextual,
   social ou familiar do Principal.
6. Exija dois usos reais para abstracoes experimentais ou especulativas, nao
   para componentes oficiais ja validados pelo Design System.

Antes de propor um componente novo, verificar composicao com componentes
existentes. Se nenhum atender, apresentar proposta com problema, justificativa,
anatomia, estados, variantes, tokens, responsividade, acessibilidade, pacote de
destino e testes. A proposta deve preservar criatividade, mas aguardar aprovacao
antes da implementacao.

Variantes que alterem aparencia, dimensoes, comportamento, API, responsividade,
estados ou acessibilidade tambem exigem aprovacao. Refatoracoes estritamente
internas podem seguir sem nova aprovacao quando nao mudarem contrato ou resultado
visual.

## Padrao Superadmin Atual

`SuperadminShell` e a composicao padrao das rotas protegidas do Superadmin:
menu, header, perfil, tema, responsividade e area de conteudo. Novas telas
devem entrar como conteudo do shell e nao recriar navegacao propria.

O diretorio de instituicoes valida os primeiros candidatos a componente:
toolbar de filtros, menu multiselect, card/lista administrativa, tabela densa,
chip de status, botao de copiar e paginacao.

A tela de instituicoes e a referencia visual principal para inputs, busca,
filtros, menus, submenus, botoes, cards, tabelas, status, popups, hover, foco,
selecao e responsividade. Sua primeira migracao para componentes deve ser
visualmente neutra: mesmos valores, estados, comportamento e layout.

Login, esqueci minha senha e redefinicao de senha sao referencias secundarias.
Elas devem ser revisadas depois da fundacao extraida da tela de instituicoes e
adaptadas aos componentes oficiais sem perder a identidade do contexto de auth.

Admin pode compartilhar a familia de shell e os padroes densos do Superadmin,
com navegacao e permissoes limitadas ao contexto institucional. Principal
compartilha primitives e padroes de interacao, mas possui composicao propria:
mobile-first e social, com adaptacao web coerente. `principal` nao importa
componentes administrativos.

## Catalogo Flutter

O Coelo possui uma ferramenta independente de catalogo, capaz de ser
publicada em endereco privado e apresentada na area de conteudo do Superadmin em
`Governanca > Catalogo`. O catalogo permanece desacoplado do ciclo do
Superadmin, ainda que use a autenticacao Coelo e seja acessivel por usuarios
internos autorizados.

A primeira versao e interativa para demonstracao, mas nao edita codigo,
documentos ou aprovacoes. Ela permite clicar, digitar, abrir menus, testar
hover/foco, alternar tema e viewport e interagir com os comportamentos reais.
Controles de variantes aparecem somente quando o componente possuir variantes
oficialmente aprovadas. Cada componente deve mostrar um exemplo minimo e
copiavel de uso correto, coerente com sua API publica atual, sem transformar o
catalogo em editor de codigo. Quando houver erro comum relevante, a pagina deve
mostrar comparacao visual entre uso correto e incorreto, explicando objetivamente
qual regra foi violada. Nao criar comparacoes decorativas ou obvias sem valor de
orientacao.

Organizacao minima:

- fundamentos: cores, temas, tipografia, espacamento, dimensoes, forma, motion e
  acessibilidade;
- componentes: compartilhados, Admin + Superadmin, exclusivos de Superadmin,
  exclusivos de Admin, exclusivos de Principal e auth;
- padroes: filtros, busca, menus, formularios, tabelas, listagens, feedback,
  navegacao e troca de contexto;
- produtos: Superadmin, Admin, Principal mobile, Principal web e Astro
  planejado;
- governanca: propostos, aprovados, implementados, descontinuados e historico.

Componente substituido permanece visivel como `descontinuado` enquanto houver
qualquer consumidor no projeto. Sua pagina identifica o substituto recomendado,
o motivo da mudanca, o impacto e a orientacao de migracao. A entrada so pode ser
removida do catalogo depois que nao houver uso restante e o historico continuar
consultavel.

O showroom atual do Superadmin deve ser tratado como fonte de migracao. Remover
somente depois que o conteudo util estiver representado e validado no catalogo
independente.

### Arquitetura Aprovada Para Planejamento

A ferramenta independente fica em `apps/catalog` e gera um artefato Flutter Web
proprio. Ela pode importar `coelo_tokens`, `coelo_ui_core`, `coelo_ui_admin`,
`coelo_ui_superadmin` e `coelo_ui_principal` conforme esses pacotes forem
materializados. O Superadmin nao importa o registro do catalogo nem componentes
exclusivos do Principal.

`Governanca > Catalogo` usa uma pagina host local do Superadmin para incorporar
o endereco privado do catalogo. A incorporacao deve restringir origens e manter
um link de abertura direta como fallback. O catalogo autentica separadamente
com `coelo_auth` e exige a permissao server-side existente `platform.read`; uma
sessao autenticada sem essa permissao recebe acesso negado. SSO transparente
entre origens e uma permissao mais granular que `platform.read` ficam para uma
spec de autenticacao/permissoes futura, caso se tornem necessarios.

O indice canonico inicial usa JSONL versionado em
`apps/catalog/assets/coelo-ui.index.jsonl`, com uma entrada curta por componente.
Um registro Dart mantido pelo app associa cada `id` implementado ao builder que
renderiza o componente real. O indice nao tenta serializar widgets nem duplica
sua implementacao.

A primeira validacao de sincronizacao e nao bloqueante. Ela compara exports
publicos, indice, arquivos, variantes, exemplos, registro do catalogo e
substitutos de componentes descontinuados. Divergencias preservam o status
`catalogo desatualizado` e exibem persistentemente: "Componente implementado;
indice e catalogo desatualizados."

## Consulta Por Agentes De IA

Manter um indice compacto e versionado com nome, finalidade, pacote
proprietario, consumidores, status, variantes, estados, tokens, acessibilidade,
arquivos, testes e exemplos de cada componente.

Toda tarefa que criar ou alterar UI deve carregar automaticamente a futura skill
`coelo-ui`, informar a consulta e ler primeiro apenas o indice relevante. Nao e
necessario pedir permissao para essa consulta somente leitura. Aprovacao e
obrigatoria para aprofundamento que proponha ou altere componente, variante ou
padrao oficial.

Fluxo obrigatorio para criar ou alterar interface:

1. identificar produto, tela, contexto ativo e superficies afetadas;
2. carregar a skill `coelo-ui` e consultar o indice compacto relevante;
3. localizar tokens, componentes e padroes existentes;
4. reutilizar ou compor antes de propor componente novo;
5. quando faltar algo, apresentar justificativa, anatomia, estados, impacto,
   pacote e testes e aguardar aprovacao;
6. registrar componente ou variante aprovada no Design System/spec antes do
   codigo;
7. implementar preservando referencias visuais aprovadas;
8. atualizar indice, catalogo, exemplos e orientacoes de uso;
9. executar analise estatica, testes de widget, responsividade, acessibilidade e
   regressao visual proporcionais ao risco;
10. informar explicitamente pendencias ou divergencias restantes.

Esse fluxo nao limita propostas criativas. Ele impede apenas que uma proposta
seja transformada silenciosamente em novo padrao oficial.

Uma validacao automatica deve comparar componentes publicos, indice e catalogo.
Se um componente tiver sido implementado ou alterado sem a atualizacao
correspondente, a mensagem deve distinguir claramente: componente implementado;
indice/catalogo desatualizado. A mudanca permanece incompleta ate a sincronizacao,
sem ocultar que a implementacao de codigo ja existe. Essa inconsistencia nao
bloqueia entrega ou publicacao na primeira versao; gera alerta visual persistente
e status `catalogo desatualizado` ate a correcao.

## Criterios De Aceite

- Nenhuma tela declara HEX local ou escala propria quando token existente cobre.
- Toda tela protegida do Superadmin usa `SuperadminShell`.
- Componentes promovidos possuem README, API pequena e teste minimo.
- Admin e Superadmin compartilham componentes densos via `coelo_ui_admin`.
- `principal` nao importa componentes administrativos.
- A tela de instituicoes permanece visualmente identica durante a extracao.
- O indice permite localizar o componente correto sem ler o catalogo inteiro.
- O catalogo renderiza os componentes reais e identifica pacote, produtos e
  status.
- Cada componente publicado oferece exemplo minimo e copiavel de uso correto.
- Erros comuns relevantes possuem exemplos visuais de usar e nao usar, com a
  regra violada identificada.
- Componentes descontinuados permanecem localizaveis enquanto houver consumidores
  e indicam substituto e orientacao de migracao.
- Componente ou variante nova nao e implementado antes de proposta e aprovacao.
- O futuro Astro permanece registrado como proxima implementacao, sem tentar
  reutilizar widgets Flutter diretamente.

## Status Da Primeira Implementacao

A fundacao Flutter foi implementada e verificada em 2026-07-27 conforme
`docs/superpowers/plans/2026-07-22-coelo-ui-foundation-componentization-catalog.md`.

- `coelo_tokens`, `coelo_ui_core` e `coelo_ui_admin` possuem APIs e testes
  publicos iniciais;
- `coelo_ui_superadmin` e `coelo_ui_principal` permanecem reservados, sem
  promover composicoes especulativas;
- a tela de instituicoes foi componentizada mantendo os goldens aprovados;
- o indice compacto, o catalogo Flutter independente e a skill project-local
  `coelo-ui` foram implementados;
- `Governanca > Catalogo` usa rota protegida e origem independente, sem importar
  o registry ou componentes exclusivos do Principal no Superadmin;
- o consumidor `astro-planned` identifica somente fundamentos neutros futuros;
  nenhum arquivo ou componente Astro foi implementado.
- a verificacao final aprovou 425 testes sem skips, tres validadores sem
  diagnosticos e revisao independente sem achados criticos ou importantes.

Antes de publicar o catalogo, continuam obrigatorios a autenticacao Coelo sobre
todos os arquivos estaticos no host/edge e CSP com `frame-ancestors` restrito ao
Superadmin. Nenhum deploy foi realizado por esta spec.

## Testes Exigidos

- `dart analyze` no pacote alterado.
- Teste unitario/widget minimo para componente promovido.
- Widget tests de viewports 375, 768, 1024 e 1440 quando o componente for layout.
- Golden apenas para componente visual critico ou regressao visual ja observada.
- Testes de nao regressao da tela de instituicoes antes e depois da migracao.
- Testes de catalogo para filtros por pacote, produto, status e contexto.
- Teste que toda entrada implementada do indice aponta para componente e
  documentacao existentes.
- Teste que componente publico novo ou alterado nao seja considerado completo
  enquanto indice e catalogo estiverem desatualizados, com diagnostico explicito.

## Fora De Escopo

- Alterar visualmente as telas de referencia durante a primeira extracao.
- Criar Figma como dependencia da fonte de verdade.
- Criar componentes especulativos sem proposta e aprovacao.
- Implementar a biblioteca Astro na primeira versao Flutter do catalogo.
- Transformar o catalogo inicial em CMS ou editor de codigo.
- Alterar arquitetura de dados, RLS ou permissao.
