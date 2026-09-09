---
source: "ajustes visuais e anexos aprovados pelo usuario em 2026-09-01; docs/superpowers/specs/2026-08-28-coelo-visual-completion-stage-design.md; docs/design/design-system.md; specs/005-principal-app.md; specs/036-principal-now-publication-mvp.md"
status: approved
generated_at: 2026-09-01
---

# Fechamento UI/UX do Coelo Principal

## Objetivo e problema

Finalizar o acabamento visual responsivo das superficies Coelo (Principal)
dentro do Superadmin sem reconstruir os previews existentes. O recorte corrige chrome
duplicado, hierarquia insuficiente e inconsistencias entre viewers, feeds e
compositores, preservando identidade, privacidade e contratos do Coelo.

## Orçamento e ordem

O trabalho tem teto de quatro horas e segue esta ordem:

1. corrigir shell, cabecalho e launcher de mensagens duplicados;
2. tornar Momentos imersivo como Agora;
3. ajustar a entrada `Publicar agora` e o acabamento das telas principais;
4. refinar os compositores de Acontece, Agora e Momentos;
5. mover Circulares para Coelo (Principal), atualizar rastreadores e executar
   verificacoes direcionadas.

O criterio de parada e o fim do tempo aprovado ou a conclusao dos criterios de
aceite, o que ocorrer primeiro. Pendencias restantes nao podem ser ocultadas ou
declaradas concluidas.

Em 2026-09-01 o usuario reforcou que o teto nao reduz o criterio funcional:
`/dev` e apenas demonstracao fake. Conclusao ponta a ponta exige localhost em
rota sem `/dev`, composicao autenticada com Supabase, RLS/ownership no servidor,
persistencia e releitura da mutacao. O trabalho visual ja concluido permanece
classificado somente como Flutter local ate atravessar esse gate.

## Escopo

- Acontece, Para Voce, Momentos, Agora e Perfil.
- Chat contextual aberto pelos launchers do Coelo (Principal), consumindo o
  nucleo funcional mantido por Comunicacao.
- Subtelas de publicar Acontece, Agora e Momentos.
- Entrada e projecao de Circulares dentro de Coelo (Principal), removidas da
  secao Comunicacao.
- Estados responsivos de 375, 768 e 1440 px e escala de texto de 200% quando
  suportada pelos testes existentes.
- Rotas `/dev` com fixtures seguras e superficies reais sem fixtures.

## Fora de escopo

- Criar uma nova tela de Agenda; o ultimo anexo e referencia de densidade,
  hierarquia e acabamento de cards.
- Reconstruir o app Principal do zero ou refatorar dominios nao tocados.
- Alterar `apps/principal`, `apps/admin` ou `apps/site`.
- Duplicar repository, RPC, migration ou backend de Chat/Conversas.
- Reauditar as 229 unidades do projeto ou produzir uma matriz ampla de goldens.
- Simular sucesso remoto quando Supabase, R2 ou autorizacao estiverem ausentes.
- Alterar regras de produto, retencao ou audiencia sem decisao aprovada.

## Arquitetura visual

As rotas Coelo (Principal) pertencem a `apps/superadmin` e usam uma unica
composicao visual propria. O menu do Superadmin continua sendo o ponto de
descoberta, mas o cabecalho de pagina e o launcher de chat administrativos nao
podem competir com o cabecalho e as mensagens da superficie Principal. A
implementacao nao importa `SuperadminShell` para dentro das features Principal,
nao copia seu cabecalho e nao modifica os apps privados separados.

O dock canonico preserva Home, Para voce, a acao central de publicar no Agora,
Momentos e Pesquisar. Mensagens permanece launcher contextual separado e Perfil
permanece no cabecalho. Viewers imersivos suspendem cabecalho, shell, dock e
launchers ate o retorno contextual.

Componentes neutros podem permanecer em `coelo_ui_core`. Composicoes sociais do
Principal nao importam `coelo_ui_admin`; extracoes novas so sao feitas quando
eliminarem repeticao real dentro do recorte.

## Comportamento por superficie

### Entrada Publicar agora

O primeiro item do carrossel Agora usa a anatomia dos anexos 1 e 2 adaptada a
proporcao do carrossel: contorno tracejado arredondado, acao circular central,
icone vetorial e rotulo curto. O estado normal usa superficie neutra e icone
laranja; hover, foco e pressionado reforcam borda e acao em laranja sem depender
somente de cor.

### Acontece e Para Voce

Acontece preserva o carrossel Agora seguido pelo feed misto de publicacoes e
Circulares. Para Voce preserva a ordem hero, atalhos essenciais, conteudo
editorial, avisos e contexto atual. Ambos recebem espacamento, tipografia,
alinhamento, densidade, estados e adaptacao por largura coerentes com os anexos,
sem copiar navegacao ou linguagem visual de outro produto.

### Agora e Momentos

Agora continua imersivo. Ao abrir Momentos, a midia ocupa a tela inteira em
mobile, tablet e desktop e todo chrome externo e suspenso. O retorno contextual
restaura foco e posicao. Imagem e video preservam proporcao, controles legiveis,
contraste, alvos de toque e estados de carregamento, erro e indisponibilidade.

### Perfil

Perfil usa capa, avatar, identidade, contexto, metricas e abas Acontece,
Momentos, Circulares e Sobre. O acabamento segue a referencia rica de perfil,
mas nao introduz seguidores publicos, exposicao de criancas ou capacidades nao
aprovadas.

### Chat contextual

O launcher Mensagens e a acao Mensagem do Perfil abrem uma superficie propria
do Coelo (Principal), dentro de `apps/superadmin`. A superficie apresenta inbox,
thread e composer responsivos, com retorno contextual e estados carregando,
vazio, sem resultados, offline, falha e sem permissao. Abrir uma conversa marca
como lida somente apos o contrato compartilhado autorizar a thread; enviar usa
chave de idempotencia e recarrega a thread pela resposta normalizada.

O Principal consome `ChatRepository` e as excecoes tipadas mantidas pela frente
Comunicacao. Nao cria outro repository Supabase, nao importa widgets
`SuperadminChat*` ou `coelo_ui_admin` e nao assume autorizacao por ID de conversa.
Em `/dev`, usa a fixture deterministica entregue por Comunicacao; fora de
`/dev`, a composicao injeta o repository produtivo compartilhado ou falha
fechada quando o contrato nao estiver disponivel.

### Publicadores

Publicar Acontece, Agora e Momentos compartilham shell, insets, organizacao de
midia, contexto e rodape responsivo, mantendo regras de dominio independentes.
Desktop usa area editorial e preview proporcionais; tablet reduz colunas sem
perder contexto; mobile prioriza midia e acao primaria. Rascunho, agendamento,
audiencia, upload, publicacao, conflito, falha e falta de permissao devem ter
feedback verdadeiro.

## Dados, permissoes e seguranca

- O cliente nao decide tenant, instituicao, unidade, grupo, audiencia ou
  capacidade. IDs recebidos sao nao confiaveis e o backend revalida ator,
  recurso e escopo.
- Tabelas expostas permanecem com RLS deny-by-default e operacoes usam os
  contratos autenticados existentes. Nenhuma `service_role` entra no Flutter.
- `/dev` usa apenas fixtures inequivocas; rotas reais nao fazem fallback para
  dados falsos.
- Midia operacional segue as ADRs vigentes. Este recorte nao transforma URL
  privada em publica nem contorna tickets ou URLs assinadas.
- Apenas os CRUDs e policies diretamente exercitados pelas telas alteradas sao
  verificados dentro do teto; ausencia de evidencia permanece pendencia.
- Chat revalida inbox, thread, envio, leitura e refresh no servidor. Eventos
  realtime nunca sao renderizados diretamente antes da reautorizacao.

## Estados de UX

Cada superficie tocada cobre, conforme aplicavel: carregando, vazio, conteudo,
erro recuperavel, sem conexao, sem permissao, enviando, sucesso confirmado,
conflito e indisponibilidade. A interface nao exibe sucesso antes da resposta
autorizada do backend.

## Eventos, logs e notificacoes

Este recorte nao cria nova taxonomia de eventos. Publicar, salvar rascunho,
agendar, remover e editar continuam usando auditoria e notificacoes definidas
pelos contratos de cada dominio. Falhas de autorizacao nao registram PII nem
conteudo de midia em logs de cliente.

## Criterios de aceite

- Nao existe cabecalho duplo nem dois launchers de mensagens nas rotas do
  Principal.
- Momentos abre em tela inteira como Agora e retorna ao ponto de origem.
- `Publicar agora` possui estados normal, hover/foco e pressionado coerentes com
  os anexos 1 e 2.
- Acontece, Para Voce, Perfil e os tres publicadores apresentam hierarquia e
  densidade coerentes em 375, 768 e 1440 px, sem overflow relevante.
- Circulares aparece em Coelo (Principal) e deixa de aparecer em Comunicacao.
- Launchers do Principal abrem Chat funcional; abertura, envio, retorno, reload
  e negacao possuem evidencia sem duplicar repository/backend de Comunicacao.
- Rotas `/dev` continuam deterministicas; rotas reais nao exibem fixtures.
- Cada superficie possui rota real sem `/dev`; abrir a rota real usa contexto
  autorizado e repository produtivo, nunca `.demo`, InMemory ou fallback fake.
- Publicar Acontece, Agora e Momentos persiste no backend e reaparece apos
  reload; Circulares exercita o CRUD suportado; Chat consome o backend central.
- Pelo menos um caso permitido, negado, revogado e cross-tenant adulterado e
  comprovado no backend para os fluxos sensiveis tocados.
- `local-green`, schema local ou backend remoto parcial nao contam como E2E.
- Operacoes remotas tocadas falham fechadas e respeitam RLS, tenant, audiencia
  e ownership.
- Rastreadores Flutter, Supabase e integrado registram evidencia, bloqueios e
  trabalho restante sem promover `local-green` a E2E.

## Verificacoes direcionadas

- Analise estatica somente nos pacotes e arquivos afetados.
- Testes de widget/rota existentes para shell, Acontece, Para Voce, Agora,
  Momentos, Perfil, Circulares, Chat contextual e publicadores; novos testes apenas para
  regressao concreta.
- Smoke visual responsivo em 375, 768 e 1440 px.
- Provas Supabase focadas nos comandos realmente tocados, incluindo acesso
  cruzado negado quando houver ambiente e fixture autorizados.
- Revisao do diff staged para segredos, imports administrativos e alteracoes
  fora do recorte.

## Evidencias esperadas

- Diff pequeno e rastreavel na worktree isolada.
- Capturas das tres larguras para as mudancas estruturais.
- Saida dos checks direcionados e estado real dos CRUDs/RLS exercitados.
- Rastreadores atualizados no mesmo commit das correcoes correspondentes.

## Riscos e pendencias

- `apps/principal` ainda nao e um app Flutter executavel; parte da experiencia
  vive em superficies do Superadmin e permanece fora desta etapa. Isso impede
  declarar o app Principal separado completo E2E.
- A integracao de Chat depende do handoff commitado de Comunicacao. Ausencia do
  contrato/fixture produtiva compartilhada bloqueia E2E, mas nao autoriza copia.
- Contratos remotos ausentes ou nao implantados para Agora/Momentos podem limitar
  a validacao produtiva dentro do teto e devem permanecer explicitamente
  bloqueados.
- Se a remocao do chrome duplicado exigir mudanca ampla no shell do
  Superadmin, deve ser preferida uma variacao confinada as rotas Principal.
