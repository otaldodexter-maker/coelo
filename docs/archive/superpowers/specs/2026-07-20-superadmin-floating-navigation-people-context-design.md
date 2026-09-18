---
title: "Navegacao flutuante e contextos globais de pessoas no Superadmin"
source: "docs/product/prd-superadmin.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md; specs/011-superadmin-database-rls.md; specs/012-superadmin-mvp.md; decisoes do usuario em 2026-07-20"
status: "approved-design"
generated_at: "2026-07-20"
---

# Objetivo

Definir a navegacao compartilhada do Superadmin e preparar o modelo de dados necessario para uma futura tela global de Pessoas. O Superadmin deve operar acima dos tenants, sem duplicar identidades e sem obrigar o suporte autorizado a entrar no Admin de cada instituicao.

# Escopo desta entrega de implementacao

Esta especificacao orienta duas frentes sequenciais:

1. ajustar a fundacao Supabase de identidades, vinculos, contextos infantis, solicitacoes e convites;
2. refatorar a shell compartilhada e o menu do Superadmin.

A tela global de Pessoas sera uma entrega posterior. Nesta etapa, o menu pode expor destinos futuros como desabilitados ou com feedback seguro, seguindo o comportamento atual da shell.

# Fora de escopo

- Construir a tela global de Pessoas.
- Construir cadastros de unidades, grupos, planos, usuarios internos, perfis, convites, avisos, suporte ou auditoria.
- Criar dados ficticios no Supabase real.
- Implementar publicacao, agendamento ou automacao de perfis oficiais.
- Criar credenciais compartilhadas para perfis oficiais.
- Alterar a arquitetura dos apps Admin ou Principal.

# Decisoes de identidade

## Pessoa global

`people` permanece como raiz unica para adultos, criancas e contas de servico. Professores, coordenadores, responsaveis e usuarios internos nao ganham tabelas de identidade separadas.

Uma pessoa adulta pode ter um unico vinculo Auth ativo e acumular simultaneamente:

- papeis profissionais em varias instituicoes;
- papeis diferentes dentro da mesma instituicao;
- escopos em instituicao, unidade e grupo;
- relacoes de responsabilidade com uma ou mais criancas;
- membership interna do Coelo, quando autorizada.

O mesmo login alterna contexto e papel. Autorizacao nunca depende somente do papel escolhido no cliente.

## Criancas

Criancas tambem pertencem a `people`, diferenciadas por `person_type = 'child'`. Uma crianca pode existir sem login e possuir contextos independentes em varias instituicoes.

# Modelo de vinculos

## Vinculo profissional

Cada instituicao controla e convida seus proprios membros. Uma pessoa pode manter varios vinculos institucionais simultaneos.

O modelo deve representar separadamente:

- membership da pessoa na instituicao;
- um ou mais papeis atribuidos;
- escopo de cada atribuicao na instituicao, unidade ou grupo;
- permissoes herdadas do perfil;
- excecoes individuais, temporais e auditadas.

O aceite ocorre uma vez por instituicao. Alterar unidades, grupos ou papeis dentro da mesma instituicao nao exige novo convite, mas exige autorizacao e auditoria.

A migration deve revisar `institution_memberships` e `institution_role_grants` sem apagar ou reinterpretar silenciosamente dados existentes. O desenho fisico final deve incluir um catalogo reutilizavel de perfis institucionais, permissoes, permissoes por perfil e atribuicoes de papel com escopo.

## Vinculo familiar

O modelo deve materializar:

- `guardian_links`: relacao global entre adulto responsavel e crianca;
- `child_contexts`: crianca dentro de uma instituicao;
- `child_unit_links`: crianca dentro de uma unidade;
- `child_group_links`: crianca dentro de um grupo;
- `guardian_context_permissions`: autorizacao do responsavel em um contexto institucional da crianca.

Uma crianca pode ser aceita na unidade sem grupo imediato. Nesse caso, `child_unit_links` deve representar o estado exibido como "Aguardando alocacao" ate a vinculacao a um grupo.

## Acesso social e perfis

A visibilidade de conteudo restrito nao nasce de um follow livre.

- Para profissionais, ela deriva do membership, papel, escopo e permissao.
- Para responsaveis, ela deriva das criancas autorizadas e dos contextos ativos delas.
- Acompanhar um grupo autorizado implica visibilidade herdada da unidade e da instituicao.
- Revogar o contexto da crianca ou do responsavel remove a visibilidade derivada.

Essa heranca deve ser calculada, evitando registros redundantes de follow para grupo, unidade e instituicao.

Perfis oficiais pertencem ao Coelo, instituicao, unidade ou grupo. Pessoas autorizadas atuam em nome deles; nenhum perfil oficial recebe login compartilhado.

# Solicitacoes e convites

## Solicitacao iniciada pelo responsavel

1. O responsavel pesquisa unidades disponiveis para descoberta.
2. O resultado identifica a unidade e sua instituicao, sem expor grupos ou dados privados.
3. O responsavel seleciona uma ou mais criancas para as quais possui `guardian_links` ativo.
4. Ele pode escrever uma mensagem e enviar a solicitacao.
5. Um membro autorizado da unidade aceita ou recusa.
6. O aceite cria ou ativa o contexto institucional e o vinculo com a unidade.
7. A unidade pode alocar a crianca em um ou mais grupos imediatamente ou depois.

Solicitacoes devem registrar solicitante, unidade, criancas, mensagem opcional, status, decisor, datas e auditoria. Os estados minimos sao pendente, aceita, recusada e cancelada.

## Convite iniciado pela instituicao ou unidade

O convite deve aceitar destinatario ja cadastrado ou ainda nao cadastrado. Deve registrar instituicao, unidade opcional, finalidade ou papel, emissor, destino protegido, expiracao, reenvio, revogacao, aceite e auditoria.

Convites profissionais sao independentes por instituicao. Um convite para unidade significa convidar uma pessoa para atuar ou vincular-se naquele contexto; unidades nao recebem login.

Solicitacao e convite sao fluxos diferentes e nao devem compartilhar estados ambiguos, mesmo que usem componentes ou servicos comuns.

# Mudancas esperadas no Supabase

## Objetos a preservar

- `people`
- `person_auth_links`
- `person_contacts`
- `platform_roles`
- `platform_permissions`
- `platform_role_permissions`
- `platform_memberships`
- `platform_member_permission_overrides`
- `institutions`
- `units`
- `groups`

## Objetos a criar ou evoluir

- contexto infantil por instituicao;
- vinculo infantil explicito por unidade;
- vinculo infantil por grupo;
- relacao global responsavel-crianca;
- permissoes do responsavel por contexto;
- catalogo de perfis e permissoes institucionais;
- atribuicoes de papel e escopo por membership;
- solicitacoes de vinculacao iniciadas pelo responsavel;
- itens de crianca associados a cada solicitacao;
- convites com escopos e destinatarios suficientes;
- views globais minimizadas para futuras listagens do Superadmin.

Os nomes fisicos finais devem ser em ingles e definidos no plano de implementacao. A UI permanece em portugues.

## Integridade

- Uma unidade deve pertencer a instituicao do contexto.
- Um grupo deve pertencer a unidade e instituicao do contexto.
- Apenas `people.person_type = 'child'` pode receber contexto infantil.
- Apenas um responsavel ativo pela crianca pode inclui-la em uma solicitacao.
- Uma membership institucional pode conter varios papeis e escopos sem duplicar `people`.
- Convite profissional ativo nao deve duplicar o mesmo destinatario e instituicao.
- Aceitar solicitacao ou convite deve ser transacional e idempotente.

## Seguranca e acesso

- RLS habilitada em todas as novas tabelas expostas.
- Nenhum acesso anonimo a dados privados.
- Grants explicitos e separados de RLS.
- Views expostas com `security_invoker`.
- Leitura global exige permissao de plataforma apropriada.
- Operacoes sensiveis usam RPC, Edge Function ou camada server-side equivalente.
- Dados infantis e destinos de convite seguem minimizacao e mascaramento.
- Acoes de convite, aceite, recusa, mudanca de papel, escopo e permissao geram auditoria.
- FKs e colunas de filtro recebem indices adequados.
- Policies evitam autorizacao baseada apenas em `TO authenticated`.

# Tela futura de Pessoas

A futura rota global usara uma unica tela e a mesma raiz `people`, com filtros para todas as pessoas, adultos e criancas. Nao havera telas duplicadas por tabela.

Filtros previstos incluem tipo, instituicao, unidade, grupo, papel, acesso Auth, convite e status. O detalhe da pessoa deve reunir dados basicos, contextos institucionais, criancas e responsaveis, papeis, permissoes, acesso e convites, sempre conforme permissao.

# Navegacao do Superadmin

## Hierarquia

### Estrutura

- Instituicoes
- Unidades
- Grupos

### Acessos

- Pessoas
- Usuarios internos
- Perfis e permissoes

### Operacao

- Planos
- Importacoes

### Comunicacao

- Convites
- Avisos

### Governanca

- Suporte
- Auditoria

Perfis oficiais nao aparecem no menu nesta etapa. Operacao editorial institucional e automacoes serao planejadas no Admin. Perfil e Configuracoes permanecem no menu do usuario no cabecalho.

## Shell flutuante

`SuperadminShell` permanece como composicao compartilhada por todas as rotas protegidas e previews correspondentes.

No desktop, sidebar e area principal se tornam superficies flutuantes sobre o fundo do scaffold. Ambas usam espacamento externo, cantos arredondados, borda e sombra sutis do design system. O conteudo deve respeitar o espaco ocupado pela navegacao sem sobreposicao ou scroll horizontal global.

No mobile, a mesma hierarquia aparece no drawer. O conteudo da pagina continua responsivo e independente do estado do menu.

## Categorias e submenus

- Categorias principais funcionam como acordeoes.
- A categoria da rota atual permanece aberta e usa o laranja primario.
- Submenus aparecem sobre a superficie do menu.
- O submenu ativo usa indicacao laranja secundaria e texto com contraste adequado.
- Abrir outra categoria nao altera a rota ate um submenu ser escolhido.
- No menu recolhido, clicar uma categoria abre um flyout ancorado ao lado, sem expandir inesperadamente a sidebar.
- Rotas ainda nao implementadas apresentam estado desabilitado ou feedback seguro, sem parecerem ativas.

## Hover, foco e divisores

- Itens inativos transitam diretamente de transparente para `primaryContainer` no hover/foco.
- Nenhum overlay cinza intermediario deve aparecer.
- Item ativo permanece `primary` com `onPrimary`.
- Focus ring e navegacao por teclado devem continuar visiveis.
- Transicoes nao podem mover o layout.
- Divisores da marca, rodape do menu e cabecalho da pagina sao recuados e nao alcancam as bordas do container.
- O titulo, subtitulo e divisor das paginas seguem o mesmo gutter compartilhado.

## Toggle de tema

- Controle binario entre claro e escuro.
- A primeira carga de cada sessao continua seguindo o tema do sistema.
- Versao horizontal no menu expandido e vertical no recolhido.
- O controle horizontal sera menor, com thumb e marca Coelo mais sutis, sem brilho excessivo.
- O controle fica em um rodape interno proprio, separado da navegacao por divisor recuado.
- Tooltip, Semantics e alvo de interacao acessivel permanecem.

## Menu do usuario

- O popup abre abaixo do acionador.
- Perfil e Configuracoes usam estados neutros arredondados.
- Sair usa `colorScheme.error` e hover derivado de `errorContainer`/cores semanticas do tema.
- Nenhuma cor hexadecimal local sera introduzida.

# Estados e acessibilidade

- Menu expandido, recolhido, drawer e flyout.
- Categoria ativa, inativa, aberta, fechada, hover, foco e desabilitada.
- Tooltips para navegacao recolhida.
- Semantics para categorias, submenus, toggle e perfil.
- Operacao por teclado e foco previsivel.
- Alvos de toque adequados.
- Respeito a movimento reduzido.
- Light e dark mode nos viewports 375, 768, 1024 e 1440.

# Testes e validacao

## Supabase

- Tabelas, enums, FKs, constraints e indices.
- Pessoa com varios papeis e varias instituicoes sem duplicacao.
- Mesma pessoa como profissional e responsavel.
- Crianca em unidade sem grupo com estado de aguardando alocacao.
- Solicitacao com varias criancas autorizadas.
- Rejeicao de crianca sem guardian link ativo.
- Convites independentes por instituicao.
- Hierarquia invalida entre instituicao, unidade e grupo rejeitada.
- RLS anonima, autenticada sem permissao e plataforma autorizada.
- Idempotencia e auditoria dos fluxos sensiveis.
- Advisors de seguranca e performance.

## Flutter

- Shell compartilhada em todas as rotas.
- Superficies flutuantes sem overflow.
- Acordeoes, submenu ativo e flyout recolhido.
- Hover sem camada cinza intermediaria.
- Divisores recuados e gutters alinhados.
- Popup do usuario abaixo do acionador e Sair em erro semantico.
- Toggle horizontal e vertical em claro e escuro.
- Navegacao por teclado, tooltips e Semantics.
- Viewports 375, 768, 1024 e 1440.
- Analise estatica, testes Flutter e build web.

# Sequencia de implementacao

1. Especificar e aplicar a migration Supabase com testes SQL.
2. Confirmar historico remoto e executar advisors.
3. Refatorar a shell e o menu compartilhado.
4. Atualizar testes de widget e rotas.
5. Executar analise estatica, suite Flutter e build web.
6. Somente em entrega posterior, projetar e implementar a tela global de Pessoas.

# Criterios de aceite

- Uma pessoa global acumula papeis profissionais e familiares com o mesmo login.
- Varios vinculos institucionais nao duplicam identidade.
- Responsavel acessa somente contextos derivados de criancas autorizadas.
- Crianca pode permanecer na unidade aguardando grupo.
- Solicitacoes e convites possuem direcao, escopo e auditoria claros.
- O menu reflete a hierarquia aprovada e funciona em todas as paginas.
- Sidebar e area principal parecem flutuantes e preservam responsividade.
- Hover, divisores, toggle e Sair seguem apenas tokens semanticos do Coelo.
- Nenhum dado ficticio e inserido no Supabase real.
