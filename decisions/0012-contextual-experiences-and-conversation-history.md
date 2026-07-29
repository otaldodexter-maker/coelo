---
title: "Experiencias Contextuais E Continuidade De Conversas"
source: "AGENTS.md; docs/architecture/macro-architecture.md; docs/data/data-model.md; docs/security/auth-multitenant-permissions.md; specs/012-superadmin-mvp.md; decisoes de produto validadas em conversa em 2026-07-22"
status: "Accepted for planning"
generated_at: "2026-07-22"
---

# Experiencias Contextuais E Continuidade De Conversas

## Contexto

O Coelo usa pessoa global e papeis contextuais. A mesma pessoa pode ser
responsavel, professora, coordenadora, proprietaria, integrante de equipe ou
usuario interno Coelo em instituicoes, unidades e grupos diferentes. Criancas
tambem podem participar de varios grupos, unidades e instituicoes sem duplicar
`people`.

Uma arvore fixa de perfis nao representa essas combinacoes. A experiencia deve
se adaptar aos vinculos e permissoes vigentes sem misturar dados ou poderes
entre contextos.

## Decisao

### Troca Explicita De Experiencia

- Uma credencial autentica a pessoa global.
- A pessoa troca explicitamente de experiencia contextual, de forma semelhante
  a troca de perfil no Instagram.
- Cada experiencia combina papel/persona, instituicao e, quando aplicavel,
  unidade, grupo e crianca representada.
- A troca recompoe navegacao, dados, acoes e permissoes e invalida caches
  sensiveis do contexto anterior.
- O contexto ativo permanece visivel e a troca e auditavel.
- Contextos autorizados podem ser favoritados e priorizados no seletor.
- A opcao "Ver como responsavel" separa a experiencia familiar das experiencias
  profissionais ou institucionais.

O modelo nao fecha combinacoes em uma lista rigida. Uma pessoa pode acumular
varios papeis e escopos; uma crianca pode estar em varios grupos da mesma
unidade, em unidades diferentes ou em outras instituicoes. Novos papeis e
escopos devem ser derivados de dados e permissoes, nao de condicionais fixas na
interface.

### Acoes Em Nome De Criancas

- O responsavel pode agir separadamente em nome de cada crianca autorizada.
- A auditoria registra a pessoa adulta como ator e a crianca/contexto
  representado como sujeito da acao.
- O sistema nao atribui falsamente a acao a crianca quando foi executada pelo
  adulto.
- Conteudo publicado pela mesma pessoa em contexto profissional continua
  visivel no contexto de responsavel.
- Confirmacoes e autorizacoes familiares, como viagem escolar, continuam
  permitidas mesmo quando o responsavel tambem foi o autor profissional do
  comunicado.

### Conversas Entre Contextos Da Mesma Pessoa

Conversas entre a mesma pessoa fisica sao permitidas quando os participantes
representarem contextos diferentes, por exemplo professora de um grupo e
responsavel por uma crianca desse grupo. A interface deve informar claramente
que a pessoa conversa consigo mesma em papeis distintos e que isso e permitido
para preservar o historico institucional.

Cada mensagem preserva:

- pessoa autora;
- membership, vinculo ou experiencia usada;
- papel/cargo apresentado naquele momento;
- instituicao, unidade e grupo aplicaveis;
- crianca representada, quando aplicavel;
- data, horario e contexto historico.

### Continuidade E Revogacao

- A conversa pertence ao contexto institucional, grupo, crianca ou assunto, e
  nao exclusivamente ao profissional que ocupa o papel atual.
- Uma nova professora autorizada pode consultar todo o historico anterior.
- Mensagens antigas continuam exibindo o nome e o cargo corretos de quem as
  enviou; nenhuma autoria e reatribuida.
- Ao sair de uma turma, a profissional perde imediatamente leitura e operacao
  naquele contexto, inclusive mensagens, publicacoes, dados, arquivos,
  notificacoes, realtime e caches.
- As mensagens enviadas por ela permanecem para participantes que continuam
  autorizados.
- Vinculos em outras turmas, instituicoes ou na experiencia de responsavel
  permanecem independentes.

### Grupos Manuais Cross-Tenant Do Superadmin

- O Superadmin pode compor um grupo manual com participantes de instituicoes
  diferentes quando a operacao Coelo exigir coordenacao entre contextos.
- O grupo e um fio coletivo: participantes autorizados veem o grupo, seus
  membros e as instituicoes/origens apresentadas no momento da composicao.
- Cada membro preserva a pessoa ou entidade selecionada, papel apresentado,
  instituicao e contexto de origem; a inclusao no grupo nao funde memberships
  nem amplia acesso a outras superficies.
- Um Admin institucional futuro fica limitado a participantes da propria
  instituicao e nao recebe a excecao cross-tenant do Superadmin.
- Envio em massa nao e grupo nem fio coletivo. Ele produz entregas privadas
  independentes e deduplicadas por destinatario.
- A autorizacao de produto acima nao autoriza implementacao fisica. Producao
  permanece bloqueada ate spec aprovada de autorizacao, auditoria, revogacao,
  retencao e notificacao dos participantes.

## Consequencias

- Autorizacao final deve ocorrer no backend/RLS/caminho server-side; esconder
  controles no cliente nao basta.
- Chat, notificacoes, navegacao, cache e analytics devem carregar contexto e
  escopo explicitos.
- Mudanca ou revogacao de membership precisa atualizar sessoes e assinaturas em
  tempo real.
- Testes devem cobrir multi-papel, multi-instituicao, crianca multi-grupo,
  conversa entre contextos da mesma pessoa, troca de professora, acesso ao
  historico, grupos cross-tenant do Superadmin, isolamento do Admin, entregas
  privadas em massa e revogacao imediata.
- A implementacao fisica depende de specs tecnicas pequenas e aprovadas.

## Fora De Escopo Desta Decisao

- Definir schema final de conversas e participantes.
- Definir retencao legal de mensagens.
- Definir o desenho visual final do seletor de contexto.
- Autorizar implementacao de chat, notificacoes ou troca de contexto.
- Definir schema, RLS ou operacao fisica de grupos cross-tenant do Superadmin.
