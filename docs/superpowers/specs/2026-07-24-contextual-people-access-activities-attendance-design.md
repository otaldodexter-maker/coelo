---
title: "Pessoas, Acessos Contextuais, Atividades, Chat E Assiduidade"
source: "AGENTS.md; docs/product/prd-master.md; docs/product/prd-admin.md; docs/product/prd-app.md; docs/security/auth-multitenant-permissions.md; docs/data/data-model.md; decisions/0012-contextual-experiences-and-conversation-history.md; decisions/0014-contextual-activities-and-delegated-unit-creation.md; validacoes do usuario em 2026-07-24"
status: "draft-for-written-review"
generated_at: "2026-07-24"
---

# Objetivo

Consolidar o modelo funcional de pessoas, instituicoes, unidades, grupos,
atividades, criancas, responsaveis, profissionais, chat e assiduidade antes de
alterar o Supabase.

Esta especificacao registra as decisoes de produto validadas. Ela nao autoriza
migrations, mudancas de RLS, telas ou implementacao. A materializacao tecnica
deve nascer de um plano posterior, depois da revisao escrita deste documento.

# Principios Centrais

- Pessoa e global; papeis, acessos e experiencias sao contextuais.
- Instituicao e o tenant e a proprietaria dos dados institucionais.
- Unidade, grupo, atividade, crianca e pessoa representada refinam o escopo.
- Autenticacao prova a identidade; vinculos e capacidades autorizam cada acao.
- Experiencia familiar e experiencia profissional permanecem separadas.
- Nenhuma permissao e inferida apenas de um nome de papel ou de um controle
  visivel no cliente.
- Restricoes e revogacoes devem produzir efeito imediato no backend, RLS,
  realtime, notificacoes e caches.
- Acoes sensiveis preservam ator, papel, escopo, sujeito, motivo e historico.
- O desenho deve reduzir duplicidade e favorecer reutilizacao dentro do tenant.

# Identidade E Experiencias

## Pessoa Global

Adultos e criancas pertencem a uma unica raiz de identidade. A mesma pessoa
pode acumular relacoes familiares, papeis profissionais e memberships em
instituicoes diferentes sem duplicacao.

Uma pessoa pode existir sem credencial. Convite e Auth ativam uma forma de
acesso, mas nao concedem dados por si mesmos.

## Crianca

A crianca nao possui login no MVP. O modelo deve permanecer preparado para:

- perfil proprio;
- credencial opcional futura;
- experiencia infantil separada;
- consentimento, faixa etaria e permissoes proprias;
- ativacao somente apos spec e revisao LGPD especificas.

`people`, `child_contexts` ou `@username` infantil nao ativam login ou
visibilidade automaticamente.

## Experiencia Familiar E Profissional

Uma unica credencial pode oferecer experiencias distintas:

- `Ver como responsavel`;
- `Ver como profissional`;
- outros contextos futuros autorizados.

A troca recompõe navegacao, dados e acoes. A interface deve manter visiveis:

- instituicao atual;
- experiencia atual;
- unidade, grupo, atividade ou crianca selecionada;
- papel exercido;
- motivo de uma acao estar indisponivel.

Permissoes familiares e profissionais nunca sao somadas entre experiencias.
Uma pessoa pode conversar consigo mesma em papeis diferentes, preservando o
contexto de cada participante.

# Hierarquia E Escopos

```text
Instituicao
└── Unidade
    └── Grupo/Turma
        └── Atividade
            └── Criancas participantes
```

- Todo grupo pertence obrigatoriamente a uma unidade.
- Toda unidade pertence obrigatoriamente a uma instituicao.
- Toda atividade pertence a uma instituicao, mesmo quando criada por unidade.
- Uma autorizacao concedida por unidade nao alcanca unidade irma.
- Um escopo pode incluir todos os descendentes atuais e futuros ou somente
  contextos selecionados.
- Escopo selecionado nao se expande silenciosamente quando novos objetos sao
  criados.

Exemplos de escopo profissional:

- toda a instituicao;
- uma unidade inteira;
- grupos selecionados;
- uma turma e todas as suas atividades;
- atividades selecionadas;
- uma ou mais criancas especificas.

# Papeis Profissionais E Capacidades

O Coelo oferece modelos iniciais, mas a instituicao pode criar papeis
personalizados. Exemplos:

- diretor;
- administrador;
- coordenador;
- professor;
- professor auxiliar;
- auxiliar de turma;
- secretaria;
- recepcao;
- equipe de apoio;
- terapeuta;
- nutricionista;
- monitor;
- tecnico esportivo;
- outros papeis locais.

O nome do papel e descritivo. O acesso efetivo combina:

1. membership institucional ativa;
2. um ou mais papeis atribuidos;
3. escopo de cada atribuicao;
4. capacidades herdadas;
5. overrides individuais;
6. restricoes do recurso e do contexto.

Capacidades permitidas por papeis ativos sao aditivas. Ausencia de uma
capacidade nao e uma negacao. Uma negacao individual explicita prevalece sobre
allows herdados, sempre no escopo em que foi criada.

A experiencia profissional consolida os papeis da pessoa dentro da instituicao,
mas cada consulta e comando continua validando o contexto selecionado.

Profissionais podem ser vinculados diretamente a criancas especificas. Esse
vinculo nao revela as outras criancas do grupo e deve declarar quais modulos e
acoes sao permitidos.

# Autonomia Da Unidade

Uma unidade com capacidades adequadas pode, dentro do proprio escopo:

- criar e editar grupos;
- vincular criancas aos grupos;
- convidar responsaveis;
- convidar e atribuir profissionais;
- criar atividades locais;
- administrar capacidades operacionais permitidas.

A instituicao nao aprova cada acao individualmente, mas mantem propriedade,
visibilidade, auditoria e poder de restringir, suspender, corrigir ou desativar.

# Responsaveis Com Acesso Ao Coelo

## Relacao Familiar E Acesso Contextual

A relacao familiar global e separada do acesso institucional. O catalogo
inicial deve incluir:

- pai e mae;
- pai socioafetivo e mae socioafetiva;
- padrasto e madrasta;
- avô e avó;
- bisavô e bisavó;
- irmao e irma;
- tio e tia;
- primo e prima;
- sobrinho e sobrinha;
- padrinho e madrinha;
- tutor e tutora;
- guardião e guardiã;
- responsavel legal;
- outros.

O modelo permite mais de um vinculo do mesmo tipo. `Outros` exige detalhe
livre, como `Vizinho`, `Baba` ou `Amigo da familia`.

Fisicamente, catalogo e detalhe devem permanecer separados:

- referencia ao tipo catalogado;
- detalhe livre opcional, obrigatorio para `Outros`.

Isso permite BI sobre o catalogo e analise dos detalhes recorrentes sem
duplicar o valor conhecido em duas colunas.

## Convite E Escopo

Somente instituicao ou unidade pode cadastrar e convidar responsavel. Um
responsavel nao convida outro responsavel.

- Convite institucional concede acesso aos contextos da crianca no tenant.
- Convite de unidade concede acesso somente a essa unidade e descendentes.
- Um convite pode selecionar varias criancas.
- Relacao familiar e permissoes sao persistidas separadamente por crianca.
- A mesma pessoa pode ter relacoes e capacidades diferentes para irmaos.
- Nao existe limite tecnico ou regra comercial de quantidade nesta spec.

Ao ativar o acesso, o responsavel acompanha automaticamente grupos e atividades
da crianca dentro do escopo concedido. Entradas e saidas da crianca atualizam a
visibilidade sem liberacoes manuais por turma ou atividade.

## Capacidades Familiares

Na tela de convite, todas as capacidades familiares nascem como `Sim`.
Instituicao ou unidade pode desmarcar antes do envio e editar posteriormente.

O catalogo inicial de capacidades deve cobrir ao menos:

- ver rotina;
- ver fotos e midia;
- ver comunicados;
- ver agenda;
- responder RSVP;
- assinar autorizacoes;
- conversar;
- reagir;
- gerenciar pessoas autorizadas.

As capacidades pertencem ao vinculo com a crianca e ao escopo concedido, nao a
uma caracteristica global da pessoa.

## Revogacao

- Instituicao pode alterar ou revogar qualquer acesso familiar no tenant.
- Unidade pode alterar ou revogar acessos concedidos no proprio escopo.
- Unidade pode suspender localmente um acesso institucional por seguranca, sem
  revoga-lo nas outras unidades.
- Responsaveis nao alteram acesso de outros responsaveis.
- Mudancas notificam o responsavel afetado e a instituicao.

Quando a crianca sai da instituicao, o responsavel perde imediatamente acesso
a Flow, rotina, agenda, midia, atividades, turmas e novos comandos. Conversas
das quais participou permanecem somente leitura enquanto a politica de
retencao aplicavel as preservar.

# Pessoas Autorizadas Sem Acesso Ao Coelo

Pessoas autorizadas sao registros operacionais, nao usuarios do aplicativo.
Elas podem representar:

- contato de emergencia;
- pessoa autorizada para retirada;
- pessoa autorizada para transporte;
- acompanhamento especifico;
- outros tipos institucionais.

Dados esperados:

- nome;
- CPF protegido;
- contato;
- tipo de vinculo e detalhe quando `Outros`;
- foto opcional;
- tipos de autorizacao;
- criancas;
- unidades;
- inicio e fim de validade;
- status;
- observacoes;
- origem, autor e aprovador/suspensor.

Responsavel com `Gerenciar pessoas autorizadas = Sim` pode cadastrar uma pessoa
uma vez e selecionar uma ou varias criancas e unidades. A autorizacao entra em
vigor imediatamente.

Instituicao ou unidade pode suspender imediatamente por seguranca, registrando
motivo. Somente responsaveis com a capacidade podem ver a lista e receber
notificacoes detalhadas. Responsaveis sem a capacidade nao veem lista, nomes,
documentos, historico ou notificacoes relacionadas.

Profissionais recebem apenas os dados estritamente necessarios para executar a
operacao autorizada.

# Transferencia Entre Unidades

Uma unidade pode iniciar transferencia individual ou em lote para outra unidade
da mesma instituicao.

Fluxo:

1. origem seleciona criancas, destino e data;
2. origem pode sugerir grupo de destino;
3. destino aceita, rejeita ou solicita correcao;
4. aceite encerra vinculos antigos e cria o novo vinculo atomicamente;
5. sem grupo, a crianca entra como `Aguardando alocacao`;
6. instituicao acompanha e pode intervir;
7. envolvidos recebem notificacoes;
8. todo o processo fica auditado.

Acessos institucionais acompanham a crianca. Acessos exclusivos da unidade
anterior nao migram. Pessoas autorizadas tambem nao sao copiadas
silenciosamente; responsavel autorizado pode selecionar quais deseja recriar.

# Atividades

## Propriedade, Origem E Disponibilidade

Toda atividade pertence a instituicao. Uma unidade autorizada pode criar
atividade local, mas o servidor deriva `institution_id`, registra a origem e
cria o primeiro vinculo com a unidade.

O modelo separa tres dimensoes:

| Dimensao | Valores conceituais |
| --- | --- |
| Origem | instituicao ou unidade |
| Disponibilidade | padrao institucional ou especifica de unidade |
| Politica | opcional, obrigatoria ou fixa |

- Origem e historica e nao muda.
- Atividade local nasce disponivel somente para a unidade criadora.
- A instituicao pode promover a mesma atividade para padrao institucional.
- Promocao reutiliza o ID e preserva historico, professores e vinculos.
- Padrao pode ser distribuido a todas ou somente algumas unidades.
- Opcional permite que a unidade decida se ativa.
- Obrigatoria exige adocao pelas unidades aplicaveis, com ajustes permitidos.
- Fixa bloqueia configuracoes determinadas pela instituicao.

Antes de criar, a interface procura nomes e definicoes semelhantes dentro do
tenant para incentivar reutilizacao e evitar duplicidade.

## Participacao

Cada atividade dentro de um grupo usa um dos modos:

- toda a turma;
- criancas selecionadas.

No primeiro modo, entradas e saidas do grupo atualizam participantes. No
segundo, cada participacao e explicita. Professor exclusivo da atividade ve
somente os participantes.

## Capacidades Da Atividade

Presenca, rotina, agenda, midia, Now e chat continuam pertencendo aos seus
dominios, mas podem usar atividade como contexto.

A instituicao configura cada capacidade como:

- obrigatoria;
- ativada por padrao e editavel;
- desativada por padrao e editavel;
- proibida.

A unidade administra a configuracao operacional dentro desses limites.

# Chat Contextual

Conversas podem pertencer a:

- instituicao;
- unidade;
- grupo;
- atividade.

Cada mensagem preserva:

- pessoa autora;
- papel/membership usado;
- entidade representada;
- instituicao, unidade, grupo e atividade aplicaveis;
- crianca ou criancas relacionadas;
- data, horario e contexto historico.

Mensagens institucionais ou de unidade mostram o nome da pessoa que respondeu,
nao uma autoria anonima da entidade.

Responsavel pode iniciar conversa:

- sem crianca, para assunto geral;
- sobre uma crianca;
- sobre varias criancas.

Em grupo e atividade, as criancas selecionaveis ficam limitadas aos
participantes daquele contexto.

## Configuracao Institucional

A instituicao pode escolher:

- chat institucional unificado;
- chat institucional e chats de unidade separados;
- somente chat institucional;
- somente chats de unidade;
- unidades especificas sem chat.

Instituicao com uma unica unidade pode unificar a entrada sem perder o contexto
historico. A configuracao pode mudar quando a estrutura crescer.

Chats institucionais e de unidade sao recebidos somente por equipes de
atendimento configuradas. Pessoas e papeis podem receber capacidades distintas
para receber, responder, atribuir, encaminhar ou supervisionar.

Professor exclusivo de atividade conversa apenas com responsaveis das criancas
participantes e nao acessa chat ou historico geral do grupo. Quando sai do
contexto, perde acesso; novo profissional autorizado pode consultar o historico
institucional aplicavel.

# Presenca E Assiduidade

## Registros Separados

Presenca geral do grupo e presenca de atividade sao registros diferentes. Uma
crianca pode estar presente na unidade e ausente em uma atividade.

O registro oficial pode representar:

- presente;
- ausente;
- atraso;
- saida antecipada;
- status pendente de revisao;
- justificativa pendente, aceita ou rejeitada.

Somente profissional com `Gerenciar presenca` confirma ou altera o registro
oficial. Alteracoes e desfazimentos preservam historico.

## Avisos Do Responsavel

Responsavel pode informar:

- ausencia;
- presenca esperada;
- chegada atrasada;
- saida antecipada;
- periodo de ausencias;
- periodo de atrasos;
- periodo de saidas antecipadas.

O aviso aceita:

- uma ou varias criancas;
- data ou periodo;
- horario previsto;
- motivo catalogado;
- detalhe para `Outro`;
- texto;
- anexo;
- grupo ou atividade aplicavel.

Aviso e intencao, nao registro oficial. Uma ausencia informada aparece na lista
do profissional como `Ausencia informada - aguardando confirmacao`. O
profissional pode confirmar falta, marcar presenca, atraso ou saida antecipada.
Se nao revisar, permanece pendente e nunca vira oficial automaticamente.

## Pendencias, Lembretes E Chat

- Pop-up pode resumir avisos do dia.
- Fechar o pop-up nao remove a pendencia.
- Pendencias continuam no sino, lista de presenca e historico da crianca.
- Avisos futuros geram lembrete no dia anterior e no dia do evento.
- Responsavel, profissionais autorizados, grupo e unidade recebem notificacoes
  conforme escopo.
- Um card pode aparecer no chat contextual.
- Resposta pelo card gera mensagem no chat correto.
- Chat aponta para o registro; nao substitui a fonte oficial.

## Catalogo De Motivos

Catalogo institucional inicial pode incluir:

- doenca;
- consulta medica;
- viagem;
- compromisso familiar;
- problema de transporte;
- ferias;
- outro.

Unidades autorizadas podem ampliar o catalogo. `Outro` exige detalhe livre. Um
motivo pode indicar que normalmente exige documento, mas nao transforma a falta
automaticamente em justificada.

## Dashboards

Assiduidade deve oferecer indicadores por:

- crianca;
- grupo;
- atividade;
- unidade;
- instituicao;
- periodo.

Indicadores incluem percentual de presenca, faltas justificadas e nao
justificadas, faltas consecutivas, atrasos, saidas antecipadas e evolucao.
Registros oficiais alimentam percentuais; pendencias aparecem separadamente.

# Notificacoes E Auditoria

Eventos sensiveis devem registrar:

- pessoa autora;
- experiencia e papel;
- instituicao e escopo;
- crianca ou sujeito;
- valores anteriores e novos;
- motivo;
- data e horario.

Notificacoes respeitam capacidade e minimizacao. CPF completo, anexos sensiveis
e detalhes de autorizacao nao devem aparecer em payload de push.

Eventos relevantes incluem:

- convite, aceite, alteracao, suspensao e revogacao de responsavel;
- inclusao, alteracao, suspensao e remocao de pessoa autorizada;
- transferencia de crianca;
- alteracao de papel, escopo ou capacidade;
- criacao, promocao e configuracao de atividade;
- mudanca de participantes;
- aviso e confirmacao de presenca;
- alteracao e desfazimento de registro oficial.

# Estados E Tratamento De Erros

- Convite pendente nao libera dados.
- Contexto revogado desaparece da navegacao e invalida operacoes em andamento.
- Tentativa cross-tenant ou cross-unit falha sem revelar existencia do alvo.
- Transferencia rejeitada preserva os vinculos atuais.
- Transferencia parcial em lote informa cada resultado sem mover crianca
  silenciosamente.
- Atividade semelhante encontrada oferece reutilizacao antes da criacao.
- Configuracao fixa mostra o bloqueio e a origem da politica institucional.
- Aviso de presenca sem revisao permanece pendente.
- Anexo indisponivel nao impede leitura dos dados nao sensiveis permitidos.
- Falhas de notificacao nao revertem a transacao, mas geram retry e evidencia.

# Criterios De Aceite Conceituais

- Uma pessoa atua como responsavel e profissional sem mistura de experiencias.
- Dois papeis profissionais somam allows e um deny individual prevalece.
- Admin de unidade pode abranger todos os grupos ou somente grupos selecionados.
- Profissional acessa somente atividade ou criancas para as quais foi atribuido.
- Unidade nao concede acesso a unidade irma.
- Convite de varias criancas cria relacoes e capacidades independentes.
- Responsavel acompanha automaticamente os vinculos da crianca no seu escopo.
- Responsavel sem `Gerenciar pessoas autorizadas` nao descobre a lista.
- Transferencia depende de aceite do destino e preserva auditoria.
- Atividade local e promovida sem duplicar definicao ou historico.
- Atividade pode abranger toda a turma ou criancas selecionadas.
- Chat preserva pessoa, papel, escopo e criancas relacionadas.
- Equipe nao configurada nao le chat institucional ou de unidade.
- Aviso de ausencia preenche a lista como pendencia, nao como oficial.
- Somente `Gerenciar presenca` confirma ou corrige presenca.
- Dashboards nao tratam pendencias como presenca ou falta oficial.
- RLS bloqueia consultas e comandos fora de tenant, unidade, grupo, atividade,
  crianca e capacidade.

# Lacunas Confirmadas No Supabase Atual

A fundacao existente e parcial. O plano tecnico posterior deve confrontar:

- `groups.unit_id` ainda permite nulo, apesar da regra de grupo por unidade;
- `institution_memberships.role_code` e escopo legado se sobrepoem a
  `institution_role_assignments` e grants;
- familia e papeis possuem principalmente policies de leitura do Superadmin,
  sem operacao final de Admin e Principal;
- `guardian_context_permissions` nao representa toda a matriz validada;
- nao existe catalogo normalizado de relacoes familiares;
- nao existem pessoas autorizadas e autorizacoes por crianca/unidade;
- nao existe transferencia transacional entre unidades;
- nao existe atribuicao profissional direta por crianca;
- Atividades nao possuem participacao individual de crianca;
- Atividades nao possuem classificacao completa de disponibilidade, promocao e
  politica institucional;
- chat atual nao representa a mesma pessoa em dois papeis na mesma conversa;
- mensagens nao preservam todos os snapshots contextuais aprovados;
- nao existe equipe de atendimento configuravel por contexto;
- nao existe dominio fisico de presenca, avisos, justificativas, sessoes,
  lembretes e assiduidade;
- RLS e RPCs finais ainda precisam ser desenhadas por dominio.

Nenhuma dessas lacunas deve ser corrigida antes da aprovacao documental e de
um plano de migrations pequenas, versionadas e testadas.

# Fora De Escopo E Decisoes Adiadas

- modelo comercial ou cobranca por quantidade de responsaveis;
- prazo juridico de retencao de chat e dados infantis;
- experiencia infantil e login de crianca;
- desenho visual final do seletor de contexto;
- telas finais de Admin e Principal;
- implementacao dos dominios Flow, rotina, agenda e midia;
- migration ou alteracao imediata do Supabase.
