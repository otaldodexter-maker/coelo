---
fonte: rodada noturna Etapa 2, grupo formularios-cuidado
status: registro duravel de metodo
data: 2026-09-10
branch: work/etapa2-noturna-formularios-cuidado
---

# O que achou os defeitos, e o que me fez errar

Este arquivo existe porque a maior parte do que aprendi nesta rodada estava
apenas em mensagens para o coordenador. Se a sessao dele caisse, sumia. O que
segue e o metodo, nao o inventario; o inventario esta no handoff da rodada e no
JSON do grupo.

## As tres perguntas que renderam

Nenhum dos defeitos desta rodada apareceu por leitura linear do codigo. Todos
apareceram por uma destas tres perguntas.

### O que isso faz com mais de um item?

Quase toda logica de formulario e escrita olhando para uma pergunta. O defeito
mora na segunda. O conjunto de IDs numericos invalidos era global, entao recusar
um campo contaminava os outros; virou mapa de motivo por item. A guarda de
limites foi escrita campo a campo e so a fatia vertical, um formulario com texto,
inteiro, dinheiro e escala ao mesmo tempo, provou que elas convivem.

### O que acontece com duas coisas ao mesmo tempo?

Duas superficies que mostram o mesmo valor envelhecem separadas. Isso rendeu
tres correcoes seguidas — dinheiro, data e escolha — e em todas a superficie de
operacoes ja fazia certo e a de resposta carregava a versao antiga. Nao e
descuido pontual, e sedimentacao: quem corrige uma tela nao sabe que a outra
existe.

O mesmo vale para duas pontas de uma regra. Dinheiro autorado em unidades e
gravado em centavos passa em todo teste isolado e erra por cem no unico lugar
que importa.

### O teste mede o efeito ou mede o mecanismo?

Um teste que conta quantos widgets de um pacote alheio aparecem na arvore nao
mede foco, mede a implementacao daquele pacote. Ele quebra quando o pacote muda
e fica verde quando o foco vaza. Trocado por afirmacao de intencao — no estado
fail-closed nada esta focavel e as duas regioes do editor estao excluidas — com
o registro dentro do proprio teste de que o ExcludeFocus do componente esta
CERTO, para ninguem "consertar" o componente daqui a um mes.

A forma mais util dessa pergunta e escolher o que o teste NAO afirma. Ao cobrir
`HealthCareResponsiveSurface` eu medi antes o que ela muda de fato: sob o tema
do app, `scaffoldBackgroundColor` ja e `colorScheme.surface` e o
`surfaceTintColor` da AppBar ja e transparente. Duas das quatro linhas do
`copyWith` sao redundantes, e uma afirmacao sobre elas passaria mesmo com a
superficie inteira removida. As que atuam sao `canvasColor` e o fundo da AppBar.
O teste olha so para essas duas, e uma das afirmacoes confere explicitamente que
o tema de origem era diferente, para a prova nao se tornar vazia se o tema mudar
depois.

Verde de primeira nao prova nada. Essa cobertura foi verificada por MUTACAO:
removendo a condicao de claro cai o caso escuro e estreito; removendo a de
largura cai o caso claro e expandido.

## Duas hipoteses minhas desfeitas por medicao

Estas valem mais que os commits, porque sao o custo do proprio metodo.

**O horario da medicacao.** O diretorio imprime `HH:mm` cru; a ficha usa
`TimeOfDay.format(context)`, que depende do locale e do relogio do aparelho. A
hipotese era boa: o mecanismo existe, a divergencia e plausivel, e eu ja tinha
corrigido tres divergencias exatamente dessa familia na mesma noite. Sondei
antes de corrigir e sob pt-BR o app devolve `08:05` nos dois modos de
`alwaysUse24HourFormat`. Nao ha divergencia, e a correcao teria sido de problema
inexistente.

Este e o inverso exato do que rendeu. Ter o padrao certo nao dispensa medir a
ocorrencia, e uma frente que achou muitos defeitos da mesma familia e justamente
a que corre risco de aceitar o proximo por semelhanca.

**A escolha orfa.** Achei que uma opcao respondida que nao existisse mais
renderizaria vazia, silenciosamente. O servidor recusa opcao desconhecida no
envio, escopada por `item_id` — migration `20260813155121`, linhas 1700 a 1705 —
e as duas superficies filtram igual. Sem defeito.

## Nove erros meus, e o que cada um ensinou

Achados por releitura do proprio diff antes de entregar, nao por teste vermelho.

1. Adicionei `pubspec.lock` duas vezes ao dar `git add` num diretorio depois de
   rodar a suite. Regra que ficou: nunca `git add` de diretorio depois de rodar
   testes.
2. Carimbei revisoes com horario estimado, duas vezes. Passei a ler o relogio
   antes de cada escrita. `date` puro do Git Bash e local e correto; o erro
   aparece quando se passa `TZ=`, porque sem tzdata ele devolve UTC.
3. Disse ao coordenador "confirmei por inspecao" ANTES de rodar a conferencia.
   Ela acabou verdadeira. Reportei como sorte, nao como metodo — uma afirmacao
   verdadeira por acaso ainda e uma afirmacao sem base.
4. Propus um hunk de router para `/forms/:formId/test`. A medicao deu 33 falhas
   sem ele e 34 com ele. Retirei em vez de entregar um commit com armadilha.
5. Propus alargar a alca de redimensionamento para 48px. Ao inspecionar, a
   celula inteira do cabecalho e o botao de ordenacao, entao a alca opaca
   roubaria 36px dela. Devolvi a reserva.
6. Um teste dependia de autosave no caminho de api; investigando, `_scheduleAutosave`
   retorna quando `authoringApi == null`. Troquei pelo botao explicito e reportei
   o autosave como inalcancavel em producao.
7. Um teste de data usava o finder errado. Corrigi e entao guardei a correcao de
   produto para provar RED de verdade, em vez de aceitar o verde.
8. Assumi que `HealthCareProfileFormPage` nao monta o shell. Monta. Registrei a
   suposicao errada no commit em vez de apagar o rastro.
9. Assumi que o DTO descartaria `max_length` num texto curto. Ele RECUSA o
   payload. Mudei o teste para documentar o comportamento melhor, que era o real.

## Tres linhas de bloqueio minhas que estavam erradas

Uma linha de bloqueio parece informacao e por isso ninguem a testa, mas e uma
hipotese nao verificada. Auditei todas as minhas. Tres estavam erradas, e as tres
eram exatamente as que eu havia copiado do rastreador sem testar. Nenhuma que eu
mesmo verifiquei estava errada. Estao detalhadas no handoff da rodada; a que mais
muda quem age e `care049`: a spec 049 esta `draft-for-review` e a spec vigente
020 esta `approved-for-demonstrative-ui`. Saude e Medicacao nao terem repositorio
produtivo nao e omissao nem gate de implantacao, e o escopo aprovado. Como a
linha estava, o Owner autorizaria um pacote quando o que falta e aprovar uma spec.

## A distincao onde o registro mente com mais facilidade

Entre "o caminho funciona quando o dado existe" e "o dado pode ser criado".

Foi a forma do bloqueio falso de Local, onde "esperando decisao" sugeria codigo
pronto e nao havia implementacao nenhuma. E reapareceu na ultima correcao da
noite, a dos limites de selecao: o DTO transporta `min_selections` e
`max_selections` nos dois sentidos e o editor PRESERVA o que veio da definicao,
entao uma definicao com limites autorados chega a resposta e agora se comporta
certo — mas o editor nao tem CONTROLE para autorar esses limites. Isso e lacuna
de autoria, separada, e a correcao nao a fecha.

Da isso uma pergunta aberta que o Owner precisa ver: se nenhum autor define
esses limites pela interface, de onde vem uma definicao que os tenha? Ou existe
caminho de autoria fora do editor, ou eles so existem em dados de migration e
seed. Nos dois casos a guarda do cliente tem de existir, porque o servidor
recusa de qualquer forma; mas o controle de autoria e o proximo passo, nao um
detalhe.

## A bateria de mutacao, e o que ela achou que a leitura nao acha

Depois de terminar as correcoes, submeti as guardas que escrevi nesta rodada a
uma bateria de mutacao em vez de reler o diff outra vez. Quebrar o produto de
proposito e ver qual prova cai. Nove mutacoes: sete pegas, uma lacuna real, uma
inconclusiva.

Pegas: faixa numerica desligada, guarda de tamanho de texto desligada, dinheiro
deixando de virar centavos, seletor de data ignorando o intervalo autorado,
intervalo invertido deixando de ser recusado, rotulo de escolha voltando a
mostrar o ID interno, e o mapeamento de falha de transporte.

A LACUNA REAL foi `_serverDefaultTextLength`. Baixar de 1000 para 999 nao
derrubava nenhuma prova. E o detalhe que generaliza: essa constante esta no
MESMO arquivo dos padroes de selecao que eu tinha acabado de fixar, poucos
minutos antes, e eu nao reparei no vizinho descoberto. A bateria encontra o que
a leitura nao encontra mesmo no arquivo que voce acabou de ler.

Um numero espelhado do servidor sem afirmacao e um numero que ninguem percebe
mudar. Fechei a borda nos dois lados e tambem a contagem por code points —
trocar `runes.length` por `length` passava batido e recusaria mil emojis que o
servidor aceita, porque um emoji fora do plano basico ocupa duas unidades em
Dart e conta como um caractere no `char_length` do servidor.

E a bateria pegou dois testes MEUS verdes pelo motivo errado, na mesma leva em
que eu os escrevi. Eu afirmara que anexo vazio nao satisfaz um item
obrigatorio, e o caso passava; quebrei de proposito a clausula de anexo de
`_hasAnswer` e ele continuou passando. O que guarda foto e galeria obrigatorias
e um ramo anterior de `_itemValidationMessage`, que nem consulta `_hasAnswer`.
Meus testes mediam o efeito e nao o mecanismo — a terceira pergunta deste mesmo
documento, aplicada contra mim e falhada na primeira tentativa. O metodo nao
protege automaticamente quem o escreveu.

### A ressalva que impede o placar de vender demais

Mutacao responde uma pergunta estreita: *este arquivo de teste protege esta
linha?* Um "nao pegou" e ambiguo entre lacuna real e mira errada.

Aconteceu comigo. A bateria acusou que o mapeamento de falha de transporte nao
estava protegido, e eu quase registrei como segunda lacuna. A regra esta
coberta; eu e que apontei a bateria para o arquivo de teste vizinho. Contra o
arquivo certo, a mutacao cai.

Entao sete em nove vale como evidencia de que aquelas guardas estao protegidas.
NAO vale como medida de cobertura, e um "nao pegou" so vira achado depois de
responder onde aquela regra deveria estar coberta.

### O terceiro modo de falha: o mutante equivalente

Depois de corrigir o recorte, apliquei a bateria a uma invariante de seguranca
que passa a ser minha: `SuperadminMediaScope` declara, em comentario, que *False
is sticky — a failed purge cannot be bypassed by a later transition*. Uma purga
de midia que falhou nao pode ser contornada por uma transicao posterior.

Mutei a composicao para que so o ultimo resultado contasse, e os DOIS arquivos
de teste que tocam essa classe continuaram verdes. Parecia lacuna grave: uma
garantia fail-closed de midia sem protecao.

Nao e. A mutacao e **inobservavel**. `_publishAfterPurge` retorna cedo quando o
dreno falhou, entao `_current` permanece nulo para sempre; `_retire` passa a ver
sempre `previous == null` e nunca reatribui `_drained`. Nao existe estado
alcancavel com uma falha seguida de um sucesso para o `.every` distinguir do
`.last`. A invariante e garantida pela guarda de publicacao, e o `.every` e
cinto e suspensorio de um estado que o desenho ja proibe.

Isso da a terceira forma de um "nao pegou" enganar, e as tres sao diferentes:
mira errada (o teste que protege a linha esta em outro arquivo), lacuna real (o
padrao de tamanho de texto), e mutante equivalente (aqui). Antes de registrar
uma lacuna e preciso responder duas perguntas, nao uma: *onde essa regra deveria
estar coberta?* e *esse estado e alcancavel?*

## Uma verificacao que nunca passa nao esta rigorosa, esta quebrada

A lei acima apareceu por um caminho e se confirmou por outro no mesmo turno.

Testei a existencia de todo hash e todo caminho citado nas evidencias do grupo.
A primeira versao da checagem usava `git cat-file -e <sha>^{commit}` com shell
no Windows. O circunflexo e escape no `cmd` e some, entao TODO objeto retornava
inexistente. A saida trazia "SHAs conferidos OK: 0" e cinquenta citacoes
supostamente quebradas — incluindo o SHA da base do proprio recorte, que eu
sabia que existia. Foi so isso que me segurou. Se a lista tivesse vindo com
quarenta e nove reprovadas e a base aprovada, eu teria mandado a lista.

A segunda versao corrigiu o shell e passou a exigir tipo `commit`. Reprovou
quinze blobs, que sao referencias legitimas de objeto de arquivo e estao
rotuladas como blobs no proprio texto. Rigor que reprova o correto nao e rigor.

So a terceira versao respondeu a pergunta certa, que nao e "o comando acusou" e
sim *o leitor copiando isto chega ao objeto?*. Resultado: trinta caminhos
alcancaveis, nenhum quebrado; vinte e nove hashes de commit e quinze de blob
validos; e um unico identificador que nao resolve para nada, anotado ao lado em
vez de apagado.

Um resultado que reprova tudo merece a mesma desconfianca que um que aprova
tudo. O controle, nos dois casos, e testar o instrumento contra um caso cujo
resultado voce ja conhece. E a mesma disciplina da mutacao um nivel acima: la
se quebra o produto para ver o teste falhar, aqui se aponta a verificacao para
um caso conhecido para ve-la passar. O que se verifica e o instrumento, nao o
objeto.

## O autosave do editor nao roda no aplicativo

Eu havia relatado isto durante a rodada e voltei a verificar antes de entregar,
porque afirmacao repetida nao vira verdade por repeticao.

`_scheduleAutosave` retorna imediatamente quando `widget.authoringApi == null`.
E `authoringApi` aparece **vinte e duas vezes dentro de
`forms_editor_page.dart` e em nenhum outro lugar de `lib/`**. Nenhuma
composicao produtiva o fornece — nem o roteador, nem o `main`, nem a rota do
editor. Em producao ele e sempre nulo, e portanto o autosave nunca dispara.

O que esta inalcancavel nao e um detalhe: sao quarenta e tres pontos de codigo
entre temporizador, pausa, marca de rascunho alterado e guarda de salvamento
pendente, construidos em `e9e7a282a`, "autosave nominal drafts through receipt
queue". O unico lugar que fornece `authoringApi` e um arquivo de teste.

Isso e a mesma classe do botao Criar que nunca aparece no diretorio produtivo e
das acoes de Local sem kind no dominio: **a capacidade existe, e completa, e
ninguem chega nela**. A diferenca e o tamanho — aqui e uma funcionalidade
inteira, testada e verde, que nao existe para quem usa o produto.

Registro sem corrigir. Ligar o autosave em producao e decisao de produto, nao
conserto: significa gravar rascunho de formulario sem acao explicita do autor, e
quem decide isso e o Owner. O que nao pode continuar e o registro dizer que o
autosave existe sem dizer que ele nao roda.

## A varredura das dependencias que ninguem fornece

O autosave foi achado por acaso. Depois transformei o mesmo raciocinio em
varredura: para cada pagina publica do recorte, quais parametros do construtor
NENHUM arquivo de `lib/` fornece.

A primeira versao devolveu setenta e oito nomes e era inutil, por um falso
positivo previsivel: componentes internos sao construidos dentro do proprio
arquivo, entao "ninguem de fora fornece" e o normal deles. Restringindo as dez
paginas publicas do recorte, sobram duas, e as duas dizem algo.

`FormsDirectoryPage` nunca recebe `visualMetadata` nem `onLifecycleCompleted`.
`HealthMedicationPlanFormPage` nunca recebe `responsibleOptions`,
`onChangeChild`, `onPickMedicationImage` nem `onPickPrescription`.

A consequencia de `responsibleOptions` fecha um circulo com outro achado desta
noite: a lista de responsaveis chega vazia, entao o formulario de plano de
medicacao nao oferece ninguem para escolher, e o diretorio — que resolve o
rotulo pela mesma lista — mostra "Responsavel indisponivel". Os dois sintomas
tem uma raiz so, e ela e o escopo demonstrativo aprovado em `specs/020`.

### O contraste que vale mais que a lista

`visualMetadata` e do tipo `Map<String, DevelopmentFormVisualMetadata>`. O
**nome do tipo** diz que aquilo e de desenvolvimento. Quem le a pagina sabe, sem
investigar nada, que a coluna Agendamentos nao tem numero em producao porque
nao deveria ter.

`authoringApi` nao tem marca nenhuma. Le-se como dependencia de producao que
alguem esqueceu de ligar — e por isso o autosave parecia funcionalidade viva, e
por isso levou uma rodada inteira para alguem notar que nao roda.

A licao e de nomeacao, e e barata: **quando uma dependencia so existe para
desenvolvimento ou demonstracao, o tipo ou o nome deve dizer isso**. O custo de
nao dizer nao e confusao momentanea; e um registro que afirma, com razao, que a
funcionalidade esta implementada e coberta, enquanto ninguem a alcanca.

## Censo dos formatadores de data inline

Medicao, nao alteracao. Contei os literais que montam data ou hora a mao com
`padLeft`, fora de testes: **25 formas distintas em 50 arquivos**.

Ressalva de metodo: parte dessas formas sao FRAGMENTOS de um mesmo formato
quebrado em varias linhas. `dd/` em 7 arquivos e `MM/` em 2 remontam
`dd/MM/yyyy`; `HH:` em 4 remonta `HH:mm`. O censo conta literais, nao intencoes.

O que decide prioridade, depois de descontar os fragmentos:

- **`dd/MM/yyyy`**, em 19 arquivos, e o formato civil dominante e e consistente.
  Sozinho, ele nao e divida: e uma convencao repetida.
- **`yyyy-MM-dd`**, em 9 arquivos, e formato de fio, em DTOs e chaves. Proposito
  legitimamente diferente. Nao deve ser unificado com o anterior.
- **Data com hora diverge de verdade, em tres separadores diferentes**:
  `dd/MM/yyyy · HH:mm` em 3 arquivos, `dd/MM/yyyy às HH:mm` em 1, e a forma longa
  `<dia> de <mes> de <ano>, às HH:mm` em 1. `coelo_date_time_field.dart` sozinho
  contem DUAS dessas formas.

A conclusao util e que a divida nao esta na data simples, esta na data com hora.
Um passe dedicado que unificasse `dd/MM/yyyy` mexeria em 19 arquivos para
padronizar o que ja esta padronizado; um passe sobre os cinco pontos de data com
hora resolveria a divergencia real com risco muito menor. Nao toquei em nada.

## Estado medido do recorte

`test/features/forms`: **808 PASS / 8 FAIL / 1 SKIP**, e as oito falhas sao
TODAS comparacao de golden, sob a politica desta rodada de nao regravar golden.
Nenhuma falha de logica restante no recorte. Medido em `b4d0e6af7`.
