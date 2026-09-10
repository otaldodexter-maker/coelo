---
title: "Rodada noturna 09→10/09/2026 — relatório ao Owner"
source: "Coordenação e Integração — Claude; entregas dos oito grupos; inventario-etapa-2.json"
status: "em construção — fechado após o corte das 05:00 de 10/09"
generated_at: "2026-09-09"
timezone: "America/Sao_Paulo"
---

# Rodada noturna — relatório ao Owner

> Documento vivo. Os números são medidos, datados e reproduzíveis; onde falta
> medição, está escrito que falta.

## Como o trabalho foi verificado

Oito grupos trabalharam em worktrees isoladas a partir da base integrada
`d784462c1`. Todo lote entrou em `dev` por revisão de código mais verificação na
base conjunta, nunca por confiança no relato do autor. O padrão foi medir a mesma
seleção de testes **antes** e **depois** do merge, para separar falha
preexistente de regressão.

O método já evitou três enganos concretos:

- As falhas de golden que três frentes reportaram eram deriva da própria base.
  Reproduzi cada conjunto numa worktree destacada em `d784462c1` intocado e
  encontrei exatamente as mesmas falhas, com os lotes somando apenas casos que
  passam.
- Dois lotes adicionaram, cada um por sua conta, o mesmo parâmetro
  `principalCircularRepository` ao router, ao app, ao auth scope e ao `main`. O
  Git mesclou os dois lados limpo, porque as linhas não se sobrepõem, e só o
  analisador pegou os nove erros. **Merge limpo não é árvore que compila.**
- Três grupos escolheram independentemente o mesmo carimbo de migration, e um
  escolheu carimbos anteriores a migrations já existentes. Worktree separada não
  protege de colisão lógica; a ordem da fila é global e pertence ao integrador.

## Movimento medido da suíte

| Base | Hora | Resultado |
| --- | --- | --- |
| `ecc8eae2b` | 19:30 | 5707 PASS, 9 SKIP, 190 FAIL |
| `414b82b29` | 20:40 | 5871 PASS, 9 SKIP, 182 FAIL — 144 golden, 38 não |
| `b0f816560` | 21:40 | 6811 PASS, 9 SKIP, 156 FAIL — 127 golden, 29 não |
| `b4cf3664a` | 02:20 | **6344 PASS, 14 SKIP, 146 FAIL — 129 golden, 17 não** |

Nenhum número soma reexecuções, e cada linha é uma execução completa sobre a
base indicada. A queda de PASS entre a terceira e a quarta linha não é regressão:
a terceira medição rodou com um conjunto de suítes diferente. O que é comparável
entre elas, porque é a mesma pergunta feita do mesmo jeito, é a coluna de falhas.

**O número que importa é o segundo: as falhas que não são golden caíram de 38
para 17, e das 17 nenhuma é órfã.** Elas se distribuem assim:

| Falhas | Arquivo | O que é |
| ---: | --- | --- |
| 3 | `app/router/principal_real_route_test` | rota real do Principal, causa diagnosticada |
| 2 | `core/config/composition_root_sanitization_test` | contrato de composição |
| 2 | `core/config/unit_fail_closed_composition_source_test` | contrato de composição |
| 2 | `shared/.../superadmin_form_action_footer_adoption_test` | adoção do rodapé de ação |
| 3 | `app/dev_menu*`, `development_dataset_contract_test` | rota `/dev`, fora do MVP |
| 3 | `composition_root_fail_closed_routes`, `import_development_routes`, `prototype_navigation_routes` | mesma família de composição |
| 1 | `app/router/principal_mixed_feed_pagination_red_test` | **vermelho proposital**, escrito esta noite |
| 1 | `features/forms/.../forms_editor_page_test` | asserção estrutural de foco, preexistente |

**Correção de categoria, feita por conferência externa:** eu contava dois
vermelhos propositais e há **um**. O antigo,
`people_creation_requirements_red_test`, ficou verde em algum momento da noite —
o defeito que ele nomeava foi corrigido — e eu continuava classificando-o como
proposital. Se essa contagem tivesse chegado até aqui, **um defeito real passaria
por convenção**. Vermelho proposital é um teste escrito para falhar até que o
defeito que ele nomeia seja corrigido; quando fica verde, ele deixa de ser
proposital e vira cobertura comum.

**E dois dos dezessete valem uma explicação separada, porque produziram o pior
erro de leitura da noite — o meu.** `composition_root_fail_closed_routes_test`
afirma que a rota `/forms/form-1/files` não chama o backend. Eu li o código,
encontrei a cadeia que faz a chamada acontecer, e escalei como violação da
invariante de não chamar antes da autorização. Duas frentes mediram e acharam
`calls=1`. Eu reservei o arquivo, parei uma frente e mandei corrigir.

**Estava errado, e a correção veio de uma terceira medição.** Existe um segundo
teste, `forms_fail_closed_routes_test`, escrito uma semana depois do primeiro,
cujo commit se chama "vincula rotas normais e tempo de vida da mídia à
autorização", e que afirma o oposto de forma explícita: uma chamada para
`monitor`, `responses`, `response-1` e `files`, zero para mídia. Ele passa 7/7.
**`calls=1` não viola o contrato — `calls=1` é o contrato**, e as quatro rotas
estão no número exato. A asserção que falha é de sete dias antes da decisão que a
substituiu.

Nenhum dado esteve em risco em nenhuma das duas leituras. O que fica registrado é
**expectativa superada, não invariante violada** — e a correção é de uma linha no
teste antigo, com comentário datando a decisão.

**A lição é a mais cara da rodada e não é sobre Formulários.** Quando dois testes
afirmam contratos opostos sobre a mesma rota, o vermelho **não diz qual está
certo** — diz apenas que existe contradição, e é preciso datar as duas asserções.
E há um corolário que explica como isso sobreviveu sete dias: o teste antigo falha
na **primeira** asserção e nunca chega à segunda, então quem lê a falha conclui
"fail-closed quebrou" e não vê a contradição atrás dela. Três pessoas leram como
defeito de produto, e duas mediram números que pareciam confirmar. A frase que a
frente que me corrigiu usou é a que fica: **a cadeia provou o mecanismo e não
provou a infração.**

E vale dizer o que a parada evitou, porque a frente que eu mandei corrigir foi
medir antes de começar: **nenhuma das duas correções possíveis era implementável
sem inventar política.** Uma exigiria um sinal de capacidade no router que não
existe — `SuperadminSession` expõe apenas autenticação — e a outra exigiria que a
página soubesse qual capacidade governa uma superfície de leitura, quando o
contrato de Formulários só tem capacidades de gerenciar e publicar. A alternativa
real, às duas da manhã, era inventar um portão de autorização.

**As 129 falhas de golden são aceite visual e dependem de decisão sua**, não de
código. As duas maiores concentrações são `agenda_calendar` com 14 casos e as
três superfícies de prévia do Principal — Momentos 11, Acontece 10, Perfil 10.

Tudo isto significa que a leitura "o app tem 146 testes quebrados" seria falsa. O
que existe é **um aceite visual inteiro pendente da sua decisão, mais dezessete
casos de contrato e ambiente de desenvolvimento**. Duas dessas dezessete famílias
foram fechadas esta noite: as cinco falhas não-golden de Estrutura caíram todas
pela mesma causa, um toque de teste que não garantia visibilidade do rodapé.

## Conclusão certificada

| Camada | Antes | Agora |
| --- | --- | --- |
| Front-end `verified` | 7/230 | 11/230 |
| Back-end `done` | 0/223 | 0/223 |
| Integração `verified-e2e` | 0/198 | 0/198 |

Backend e integração não se moveram, e isso é esperado: **nada foi aplicado em
ambiente remoto**. O projeto Supabase `coelo` e os buckets R2 são produção, e
você ficou indisponível a partir das 18:26, portanto nenhuma autorização nominal
pôde ser concedida. Nenhuma rota rodou contra Supabase autenticado, e prova local
não promove E2E.

O que avançou além dos quatro certificados foi a honestidade do resto. Os
bloqueios agora estão separados entre `blocked-decision`, onde falta uma decisão
sua, e `blocked-environment`, onde o pacote está revisável e só falta a aplicação
remota que esta rodada proibiu.

## Por que a integração é 0/198, e por que não é falta de esforço

Esta seção responde antecipadamente a pergunta óbvia diante da tabela acima. A
leitura fácil de "0/198" é que ninguém rodou rota real contra Supabase
autenticado, o que soa como escolha de prioridade — e levaria à instrução
"então rodem". **A medição desta noite mostra que essa instrução não teria
efeito.** Não existe base reproduzível para exercitar rota real contra Postgres.
As frentes ficaram entre uma base que não existe e uma base onde não podem
tocar.

São **três buracos independentes** no mesmo caminho, cada um suficiente sozinho:

1. **A cadeia versionada não atravessa.** Das 186 migrations de
   `packages/coelo_database/migrations`, replayadas em ordem de nome numa base
   zerada, os arquivos 1 a 47 aplicam limpos e o **48 quebra**:
   `20260812002000_child_safety_schema.sql` insere códigos de permissão novos
   sem `module_label`, coluna que `20260811215451_access_profile_management_v2`
   criou como `NOT NULL` sem default. E não é a única barreira nem dentro do
   próprio arquivo: relaxando esse `NOT NULL`, ele falha em seguida em
   `column "updated_at" of relation "platform_role_permissions" does not exist`.

2. **O que `supabase start` aplicaria é outro conjunto, e é vazio.**
   `packages/coelo_database/supabase/migrations` tem 17 arquivos e **zero
   `create table`** — são `CREATE OR REPLACE` de função e ajustes de privilégio.
   Um ambiente local subido por esse caminho não tem o schema do Coelo.

3. **Oito domínios chamam objetos que o SQL versionado nunca cria.** O primeiro
   encontrado foi `profile_about`: sem `create table` para
   `profile_about_pages`, `_sections`, `_structured_fields`, `_revisions`, nem
   para `app_private.profile_about_command_receipts`; e `profile_about_can` e
   `profile_about_page_for` só aparecem **sendo chamadas**, dentro do corpo de
   `save_profile_about`.

   A frase confortável seria "`profile_about` é a exceção", e ela foi medida
   antes de ser publicada — e é **falsa**. O SQL versionado chama 605 objetos
   distintos de `app_private` e cria 527 funções mais 63 tabelas; **sobram 40
   objetos chamados e nunca criados**, em `student_tracking`, `routine`,
   `profile_about`, `meal_plan`, importação/exportação de unidades e mais alguns
   avulsos. Cinco foram conferidos individualmente com busca que pegaria `CREATE`
   e `DROP` — `profile_about_can`, `routine_receipt`,
   `student_tracking_can_read` e `normalize_person_handle` têm zero ocorrências.

   **E há a metade boa, que muda a decisão:** `child_safety` e `chat` estão
   versionados corretamente — todas as tabelas, os receipts internos e dezenas
   de funções `app_private` criadas em migration. O problema **não é sistêmico
   por incapacidade**: existe um padrão certo dentro da própria casa, e oito
   domínios saíram dele. A pergunta que isso coloca tem resposta possível.

   Ressalvas do método, que valem tanto quanto o número: 40 é contagem de
   **objetos**, não de defeitos, e alguns podem ser o mesmo helper compartilhado;
   35 dos 40 vêm do método e não de inspeção individual; e o método não distingue
   "nunca existiu" de "existe no remoto e nunca foi versionado" — para recriar a
   base dá no mesmo, para saber quem escreveu não dá.

**Ressalva que atravessa toda esta seção, e ela é a mesma evidência lida ao
contrário:** o repositório comprovadamente **não espelha produção**. A prova está
dentro do próprio achado — `app_private.unit_import_source_attestations` é
referenciada por uma migration versionada e criada por nenhuma, e produção
evidentemente a tem, senão aquela migration nunca teria sido aplicada lá. Logo,
**ausência no repositório não prova ausência em produção**. Tudo o que está
medido acima é sobre o repositório: a cadeia não replica, o conjunto local não
cria tabela, e há objetos chamados e nunca criados. Nada disso afirma que uma RPC
específica falta no banco remoto.

Isso foi encontrado por uma frente auditando as próprias afirmações: ela vinha
usando a cadeia quebrada como argumento para explicar por que não consegue provar
SQL, e ao mesmo tempo usando o repositório como espelho fiel de produção para
afirmar ausência. **Os dois usos são incompatíveis**, e ela tinha os dois fatos
sem os ter cruzado.

**A consequência é maior que E2E.** Recriar a base do zero — ambiente novo,
recuperação de desastre, homologação de verdade — não é difícil hoje, é
impossível sem um dump. E enquanto não houver caminho de recriação, homologação
não existe; sem homologação, a única base disponível é produção; e produção é
exatamente onde E2E não pode rodar sem autorização nominal sua. **A integração
continuará 0 por construção, e nenhum esforço de frente muda isso.**

Não proponho a solução, porque ela é de arquitetura: se o conjunto de 186 é
corrigido, se o de 17 é completado, ou se ambos são substituídos por um caminho
único — e a decisão precisa cobrir o schema que hoje só existe no remoto.

Limite desta afirmação, declarado: a frente que mediu verificou o próprio
domínio arquivo por arquivo e deduziu o resto do fato de o conjunto local ser o
mesmo para todas e não criar tabela nenhuma. Se alguma frente tiver um caminho
de seed não conhecido, é a exceção que muda o quadro.

## Nenhum teste conferia se a RPC chamada existe, e agora confere

Um teste novo, `apps/superadmin/test/contracts/rpc_contract_test.dart`, fecha uma
lacuna que atravessava a suíte inteira: **nenhum teste do app verificava se a RPC
que o cliente chama existe no pacote de banco**, porque todos usam cliente falso
ou interceptam transporte. Nome errado, parâmetro renomeado em migration
posterior ou função que nunca entrou no versionamento passavam por 6 mil testes
verdes e falhavam no primeiro uso real — chegando à tela como indisponibilidade
genérica, indistinguível de queda de rede. **A própria interface escondia o
defeito.**

Medidos os dois lados: 80 chamadas `.rpc`, 76 nomes distintos, contra 383 funções
declaradas no pacote. O teste roda em menos de um segundo, sem binding de
Flutter, e foi validado com controle negativo nos três casos.

**Achado 1, e é grave: cinco RPCs do diretório de Unidades não são criadas por
arquivo nenhum do repositório** — `create_unit_for_superadmin`,
`update_unit_for_superadmin`, `get_unit_form_for_superadmin`,
`list_units_for_superadmin` e `unit_directory_filter_options`. As outras 71
existem. E não é falha do varredor: a migration versionada `20260825180500`
**chama** `app_private.create_unit_for_superadmin` de dentro do confirmador de
importação, e o cabeçalho dela diz textualmente "Repair locally installed Unit
import/export worker functions". Uma migration do pacote depende de função que o
pacote nunca cria.

As duas leituras possíveis pedem decisões opostas: ou as funções existem em
produção instaladas fora do versionamento — e aí o pacote não descreve produção —
ou não existem, e **Unidades e os filtros de Turmas falham fechado no primeiro
uso**. Um `select` de catálogo resolve em segundos, e é o que a próxima janela
autorizada deve fazer **antes** de qualquer promoção de Unidades. Isto se soma
diretamente aos 40 objetos `app_private` chamados e nunca criados: é o mesmo
buraco, visto do lado do cliente.

**Achado 2: a guarda de concorrência de imagem de Cardápios nunca roda.**
`meal_plan_request_image_delete` tem duas formas — a migration de recibos
`20260820230000` criou a de três argumentos com `p_expected_revision` e manteve a
de dois por compatibilidade, cujo corpo lê a revisão corrente do próprio banco e
a repassa. **O cliente chama a de dois.** Para o banco a chamada é legítima, por
isso nenhum teste acusa, e o efeito é que uma exclusão disparada sobre lista
desatualizada remove a imagem corrente em vez de ser recusada por divergência.
Não foi corrigido por contrato, não por tempo: o domínio de imagem de Cardápios
não tem conceito de revisão de ativo, e ler a revisão no cliente logo antes do
delete reproduziria exatamente o furo que a guarda existe para fechar. Exige a
leitura expor a revisão que a pessoa viu — mudança de contrato de domínio, e
decisão sua.

**Achado 3, que é resultado e não ausência de medida:** zero divergência de nome
de parâmetro nas 80 chamadas. O pacote já tem teste próprio de nomes de
argumento, o que mostra que essa classe já cobrou preço antes; hoje está limpa.

O teste falha também **se uma das cinco ausências passar a existir e continuar na
lista** — sem isso a lista de exceções envelhece e passa a esconder o defeito
seguinte, que é como esse tipo de allowlist costuma morrer.

## Os 129 goldens não são um bloco, e rebaseline cego apagaria produto

Quatro conjuntos foram amostrados abrindo `masterImage` e `testImage` lado a lado.
Deram **três perfis distintos**, e a conclusão prática é forte: **na amostra, a
maioria dos casos tem componente que um rebaseline em bloco apagaria.**

**Agenda, 14 casos — deriva pura de shell, rebaseline seguro.** A 1440 o diff é
0,05% e **837 pixels**, nas duas variantes de tema, que é a assinatura exata do
commit que fundiu o rótulo do alternador da barra lateral com a ação. A 375 e 768
sobe para 10%–18%, e o diff isolado mostra **todo o conteúdo deslocado
verticalmente por poucos pixels**, do título ao último dia — nenhuma diferença de
conteúdo, a página inteira descendo. É o commit que "alinha o cabeçalho compacto
e reserva espaço de ação", que só muda a altura do cabeçalho nas larguras
compactas. Duas mudanças aprovadas, separadas por largura. Agenda não esconde
nada.

**Conta, 8 casos — tem mudança de produto, e era a família que eu apostava ser só
cabeçalho.** A 375 e 768, 44%–73%, até 503 mil pixels; a 1024 e 1440, 3,9%–5,1%,
de 36 mil a 63 mil. O que mata a hipótese: nas larguras largas o diff é **cem
vezes** a assinatura de 837 pixels. Se fosse cabeçalho puro, 1440 daria 837 como
em Agenda. O diff de configurações a 1440 mostra diferença no **corpo** — um
controle segmentado de três opções com a primeira realçada, e uma linha com
interruptor à direita.

**Cardápios, 6 casos — conteúdo puro, sem componente de shell visível.**
0,86%–8,70%. No diretório a 1440 a barra lateral não aparece no diff; o que difere
é um cartão, com um ponto de status trocando de cor e linhas de texto sobrepostas
onde um rótulo e uma data mudaram.

**Instituições, 4 casos** — já relatado antes: cabeçalho conhecido **mais** o
cartão tracejado "Criar instituição" presente na referência e ausente na captura
atual, com dados e paginação diferentes. Pode ser afordância de criação sumindo
de um diretório do MVP, ou apenas fixture diferente; barato de confirmar por quem
tem o recorte, e nenhuma das duas respostas aparece se os 129 forem tratados como
bloco.

**Atividades, 16 casos** — a maior das amostras, e falha em **todas** as
larguras: 19%–32% em 375 e 768, 12%–13% em 1024, 9,8%–20,5% em 1440. Nas larguras
largas o diff é centenas de vezes a assinatura de 837 pixels, então há conteúdo
aqui também.

**A proporção da amostra, cinco famílias e cerca de 48 casos: 14 são rebaseline
seguro e cerca de 70% carregam componente que um rebaseline cego apagaria.** Duas
horas antes, a hipótese de trabalho desta coordenação era que a deriva do
cabeçalho explicaria a maior parte dos 129. Ela explica **uma** família inteira e
a metade larga de outra.

**A recomendação que sai disso:** rebaseline por família, não em bloco, e cada
família com conteúdo passa antes pelo dono. Agenda pode ir hoje; Conta,
Cardápios, Instituições e Atividades, não. Se a decisão vier como "129 goldens,
deriva de shell, autorizo rebaseline", ela **apaga mudança de produto em pelo
menos quatro famílias**.

Ressalvas, e elas são da própria frente que mediu: cinco famílias não são as 129;
a amostra não é aleatória, porque duas foram escolha dela e três foram indicação
minha; "componente de conteúdo" é o que foi medido nas imagens, sem investigar
*qual* mudança; e parte do conteúdo pode ser fixture de teste e não produto — foi
o que ela mesma levantou em Instituições e continua valendo para as outras.

**Uma armadilha de ferramenta descoberta no caminho, que vale para quem repetir
isto:** quando o caminho do golden é longo, o Flutter quebra a mensagem em duas
linhas, e um `grep` de linha única devolve `Pixel test failed,` **sem percentual
nenhum** — aconteceu em oito casos de Atividades. Quem lesse só aquilo reportaria
a família como falha sem magnitude, ou contaria errado. É a terceira classe de
"verde ou vermelho que engana" catalogada nesta rodada, junto do teste que
sobrescreve outro e da string lida sem a asserção em volta.

## Três frentes mediram o mesmo buraco por três caminhos, e uma consulta o resolve

Este é o resultado que só apareceu quando uma frente leu as linhas de bloqueio
das outras duas — nenhuma delas podia enxergá-lo sozinha.

- Uma mediu, **pelo lado do SQL**, que o repositório chama 605 objetos
  `app_private` e cria 590: **40 chamados e nunca criados**.
- Outra mediu, **pelo lado do cliente**, que 5 RPCs do diretório de Unidades são
  chamadas e criadas por arquivo nenhum.
- A terceira mediu, **pelo lado de Assiduidade**, que 5 RPCs chamadas pelo
  cliente — detalhe de chamada, opções de contexto, criação, diretório e desfazer
  em lote — não são criadas por migration alguma.

**É o mesmo buraco.** `create_unit_for_superadmin` aparece em duas dessas listas
ao mesmo tempo, numa como RPC pública e noutra como helper `app_private`.

**E há uma assimetria dentro disso que muda a leitura de três linhas.** No ramo
autorizado da composição, Rotina e Alunos recebem explicitamente repositórios
indisponíveis — não é "falta implementar", é a composição de produção declarando
indisponibilidade de propósito, e o usuário vê degradação honesta. No **mesmo**
ramo, Assiduidade recebe o repositório Supabase real, e ele chama cinco RPCs que
nenhuma migration cria. **As duas situações falham de formas opostas:** uma é
degradação honesta; a outra é uma tela que parece pronta e quebraria no primeiro
uso real, com o erro chegando como indisponibilidade genérica. Lê-las juntas como
"sem backend" apaga essa diferença.

**A bifurcação, porém, não está resolvida — e o precedente pesa para o outro
lado.** Ou essas funções existem em produção instaladas fora do versionamento, e
então o pacote não descreve produção; ou não existem, e as superfícies quebram no
primeiro uso. **"Instalado fora do versionamento" é fenômeno medido neste
repositório**: `profile_about` prova, porque suas tabelas e sua função de guarda
não existem em migration nenhuma e existem em produção — a RPC de escrita, que é
versionada e está aplicada, lê e escreve nelas. Então a hipótese benigna é pelo
menos tão provável quanto a grave, e **nenhuma das três frentes deve ser lida
como "falta construir"** sem consultar o banco.

**Uma consulta resolve as três.** Um único `select proname from pg_proc` na
próxima janela autorizada responde de uma vez pelas cinco RPCs de Unidades, pelas
cinco de Assiduidade e pelos 40 objetos `app_private`. Segundos de execução, e
converte três blocos inteiros de bloqueio em fato. **Enquanto isso não acontecer,
a classificação honesta das três é falta de autorização para verificar, não
ausência** — e é assim que elas estão registradas.

## Três testes de fronteira vermelhos, três causas sem relação

A sequência do falso alarme acima produziu um resultado lateral melhor que o
alarme. Três testes que afirmam fronteiras de autorização estavam vermelhos, e a
tentação — a minha — foi tratá-los como uma família com uma causa. São três
causas sem nenhuma relação entre si:

- `/forms/form-1/files` — **expectativa superada**: o contrato mudou uma semana
  antes e o teste antigo não acompanhou.
- `/forms/media/asset-1` — **não havia nada**: `calls=0` e painel honesto
  presente. Estava correto o tempo todo, e só parecia quebrado porque o caso
  falhava antes de chegar nele.
- `/dev/imports` — **overflow de layout**: `RenderFlex` estourando 1409 pixels na
  superfície padrão de 800×600, e a exceção mata o caso antes de qualquer
  asserção ser avaliada. `calls=0` nas duas rotas; a fronteira de importação está
  intacta.

E o que as três compartilham não é a causa, é o modo de esconder: **em nenhuma a
mensagem vermelha nomeia a causa real.** Uma morre na primeira asserção, outra
morre atrás dela, a terceira morre numa exceção que nem é asserção. Quem
catalogar por nome de arquivo erra as três.

**Uma característica conhecida, medida no caminho e registrada como
característica e não como defeito:** a autorização de leitura das rotas de
Formulários é delegada **inteiramente ao servidor**. A sessão do teste concede
apenas `platform.read`, e a guarda do router consulta unicamente se há sessão
autenticada — não há verificação de capacidade no cliente. Isso é coerente com o
princípio de que a autoridade é o backend e de que esconder botão nunca foi
controle de acesso. Mas significa que **não existe segunda linha de defesa no
cliente**: se alguma RPC de Formulários for mais frouxa do que se supõe, nada a
segura antes. Verificar isso exige leitura autorizada das policies, que ninguém
pôde fazer nesta rodada — entra na lista da próxima janela autorizada, junto do
`select` de catálogo das cinco RPCs de Unidades.

## Bloqueio herdado é a espécie que mente

Perto do fim da rodada, uma frente descobriu que uma das próprias linhas de
bloqueio era falsa: a ação de imagem em pergunta de Formulários estava registrada
como esperando contrato de mídia de outro grupo, e o contrato **já existia,
aplicado, e era do próprio grupo** — a RPC de preparação com `grant` para
`authenticated`, a de finalização revogada porque é função de worker, a Edge
Function conferindo o MIME real dos bytes, e até o adaptador de cliente pronto. O
bloqueio existia apenas no registro.

Isso virou tarefa para todas as frentes: **cada linha de bloqueio é uma hipótese
que ninguém testou**, e ela é mais perigosa que um achado errado, porque bloqueio
declarado parece informação e não pergunta. Ninguém confere. E eu ia trazer essa
lista a você como se fosse fato — cada linha falsa aqui é uma decisão sua sobre
um problema que não existe, ou um trabalho que você adia sem motivo.

O reteste achou mais dois na mesma frente, e os dois mudam o que você decide:

**Pergunta de Local em Formulários não está esperando decisão para destravar
código pronto.** O registro dizia `blocked-decision`, sobre opções fixadas na
publicação contra catálogo dinâmico — o que sugere implementação à espera. Não
há: o domínio de Formulários não tem um `kind` de Local, a tela de resposta não
tem nenhuma ocorrência, e as quatro do editor são todas outra coisa
(`_validateLocally`, `_saveDraftLocally` e afins). O enunciado correto é **decida
e depois construa**, não "decida e sai".

**`care049` não espera autorização remota; espera aprovação de spec.** A
`specs/049-superadmin-internal-care-profile-crud-v2.md` está com status
`draft-for-review` — é rascunho não aprovado, e é ela que criaria o contrato real.
E a spec vigente, `specs/020-superadmin-health-care.md`, está como
`approved-for-demonstrative-ui`. Ou seja: **Saúde e Medicação não terem
repositório de produção não é omissão nem gate de implantação — é o escopo
aprovado.** São decisões diferentes, de pessoas diferentes, em prazos diferentes,
e a linha antiga levaria você a autorizar um pacote quando o que falta é aprovar
uma spec.

E a lição que a própria frente tirou é a generalização mais útil da noite: **dos
bloqueios dela, os três que estavam errados eram exatamente os três copiados do
rastreador sem teste. Nenhum bloqueio que ela mesma havia verificado estava
errado.** Bloqueio herdado é a espécie que mente.

E o exercício se repetiu em outra frente com o mesmo placar: **três de três
errados**, dois deles herdados da rodada anterior. Um superestimava o que faltava
— e teria feito você adiar algo que tem caminho. Um afirmava uma verificação que
nunca foi feita. E um inventava uma dependência de terceiro que não existe: a
materialização de publicação de Avisos estava registrada como dependente de
confirmar `pg_cron` e o consumidor `service_role`, e a migration de **20 de
agosto** já cria a extensão, define as duas funções restritas a `service_role`,
concede os grants e agenda o worker de minuto em minuto. Não há nada a confirmar
que seja específico de Avisos.

**A generalização final junta as duas metades desta noite**, e ela vale além de
bloqueios: contrato herdado do título de um teste e bloqueio herdado de um
handoff são a mesma coisa — **informação que parece verificada porque veio
escrita**. Foi essa espécie que produziu o falso alarme da seção anterior e as
seis linhas de bloqueio falsas destas duas frentes.

## Auditoria das onze certificações de Front-end

As onze ações com Front-end `verified` foram reauditadas nesta rodada, uma a uma,
conferindo se a evidência citada existe e o que ela de fato prova. **As onze
apontam para arquivos que existem.** Mas a qualidade da prova não é uniforme, e a
diferença importa:

- **Quatro de erros** (`errors.403/404/500/503`) apontam para um arquivo de teste
  no repositório. É a forma mais forte: a prova é reexecutável hoje.
- **Quatro de autenticação** e **uma de exportação de Assiduidade** apontam para
  documentos de reconciliação em `docs/reviews/evidence/`, que existem e estão
  versionados.
- **Duas — `profile-files.import` e `profile-files.export` — apontavam para um
  relatório que cita "24/24 testes de página/estados/componente" e um log num
  diretório temporário.** O log já não existe, e uma frente mediu esta noite que
  **as três ações de arquivo de perfil não tinham nenhum teste no app inteiro**.
  Os 24 testes cobriam a página; não cobriam essas ações, seus rótulos nem o
  estado adiado. A certificação não era falsa, mas era mais fraca do que o rótulo
  `verified` sugere.

Isso foi corrigido no mesmo turno em que foi descoberto: as três ações agora têm
teste próprio, que fixa a presença na tela, os rótulos e o estado adiado.

**A lição vale mais que a correção, e é uma lição sobre o meu próprio processo:**
uma certificação que aponta para um log em diretório temporário não é
verificável depois que a máquina reinicia. A regra que fica é que evidência de
certificação precisa ser um arquivo versionado no repositório — de preferência um
teste — e não um log, um caminho local ou uma contagem citada em prosa.

## Progresso por tela

As 230 ações da Etapa 2 em 39 famílias de tela, com o estado que o inventário
certifica agora. "FE em avanço" reúne o que está em `pending-verification`,
`audited`, `local-green` ou `fail-closed`: são telas com trabalho real feito e
sem certificação de conclusão. Bloqueio `environment` significa pacote revisável
esperando aplicação remota; `decision` significa que falta uma resposta sua.

| Tela (família) | Ações | FE `verified` | FE em avanço | Bloqueio FE | BE aplicável | Bloqueio BE | E2E |
| --- | ---: | ---: | ---: | --- | ---: | --- | ---: |
| access_models | 6 | 0 | 6 | — | 6 | environment 6 | 0 |
| access_profiles | 6 | 0 | 6 | — | 6 | — | 0 |
| account | 6 | 0 | 6 | — | 4 | — | 0 |
| acontece | 4 | 0 | 4 | — | 4 | environment 2 | 0 |
| activities | 7 | 0 | 7 | — | 7 | environment 2 | 0 |
| agenda | 7 | 0 | 7 | — | 7 | — | 0 |
| agora | 4 | 0 | 4 | — | 4 | environment 1 | 0 |
| assessments | 5 | 0 | 5 | — | 5 | — | 0 |
| attendance | 6 | 1 | 5 | — | 6 | decision 1 | 0 |
| audit | 4 | 0 | 4 | — | 4 | environment 3 | 0 |
| auth | 5 | 4 | 1 | — | 5 | — | 0 |
| catalog | 4 | 0 | 4 | — | 4 | — | 0 |
| chat | 7 | 0 | 6 | environment 1 | 7 | environment 4 | 0 |
| child_safety | 5 | 0 | 5 | — | 5 | environment 2 | 0 |
| circulars | 11 | 0 | 10 | decision 1 | 11 | decision 1 | 0 |
| daily_routine | 5 | 0 | 5 | — | 5 | — | 0 |
| error_pages | 6 | 4 | 1 | decision 1 | 6 | — | 0 |
| forms_authoring | 7 | 0 | 5 | decision 2 | 7 | — | 0 |
| forms_files | 5 | 0 | 5 | — | 5 | environment 5 | 0 |
| forms_responses | 6 | 0 | 5 | decision 1 | 6 | — | 0 |
| groups | 7 | 0 | 7 | — | 7 | environment 2 | 0 |
| health_care | 4 | 0 | 0 | decision 4 | 4 | environment 4 | 0 |
| imports | 7 | 0 | 7 | — | 7 | — | 0 |
| institutions | 13 | 0 | 13 | — | 13 | — | 0 |
| internal_users | 5 | 0 | 5 | — | 5 | — | 0 |
| invites | 5 | 0 | 5 | — | 5 | — | 0 |
| locations | 4 | 0 | 4 | — | 4 | environment 2 | 0 |
| meal_plans | 6 | 0 | 6 | — | 6 | — | 0 |
| medication | 5 | 0 | 3 | decision 2 | 5 | environment 5 | 0 |
| momentos | 4 | 0 | 4 | — | 4 | environment 1 | 0 |
| notices | 6 | 0 | 6 | — | 6 | environment 1 | 0 |
| people | 5 | 0 | 5 | — | 5 | — | 0 |
| plans | 5 | 0 | 5 | — | 5 | — | 0 |
| principal_profile | 3 | 0 | 1 | decision 2 | 3 | decision 3 | 0 |
| profile_files | 6 | 2 | 4 | — | 6 | — | 0 |
| shell | 5 | 0 | 5 | — | 0 | — | 0 |
| students | 5 | 0 | 5 | — | 5 | — | 0 |
| support | 6 | 0 | 3 | decision 3 | 6 | — | 0 |
| units | 13 | 0 | 13 | — | 13 | — | 0 |

Leitura honesta desta tabela: **a coluna que importa é a terceira, e ela soma
11.** As colunas de avanço descrevem trabalho feito, não conclusão — e a
diferença entre as duas é exatamente o que esta rodada passou a noite tornando
visível.

## O defeito mais grave encontrado: Segurança infantil não se dispõe em produção

Duas frentes mediram `/safety` de forma independente, e o diagnóstico mais
preciso mudou a categoria do problema. **Não é transbordamento: a grade de
cartões não se dispõe.** São vinte exceções de layout por largura, encabeçadas
por `LayoutBuilder does not support returning intrinsic dimensions` com
`IntrinsicHeight` como causador, seguidas de dezenove `RenderBox was not laid
out` em cascata.

A cadeia está rastreada até o fim: `safety_pages.dart:292` envolve cada linha da
grade em `IntrinsicHeight`; o cartão é `SafetyChildDirectoryCard`, que retorna
`CoeloAdminInteractiveCard`, que contém `CoeloAdminExpandableStatusIndicator`, e
esse é literalmente um `LayoutBuilder` na linha 42 do pacote. `IntrinsicHeight`
pergunta dimensões intrínsecas; `LayoutBuilder` não sabe responder; a asserção
dispara.

**E isso alcança produção.** `childSafetyRepository` é composto como
`SupabaseChildSafetyRepository` real, o controlador é construído em
`superadmin_app.dart:231`, a rota produtiva `/safety` monta `SafetyLandingPage`
com ele, e o modo de exibição padrão é cartões. Basta existir um registro para a
tela quebrar no primeiro carregamento. Não é protótipo com defeito: é MVP, com
repositório de produção ligado, sobre dados de criança.

Duas correções possíveis, e a escolha é sua com o `coelo-ui`: contida em
`safety`, deixando de envolver a linha em `IntrinsicHeight`; ou no componente
compartilhado, tirando o `LayoutBuilder` do indicador, o que resolve para todo
consumidor mas mexe no Design System e move goldens de outras telas. A primeira
está atribuída para execução; a segunda fica registrada, porque qualquer tela
que um dia envolver esse indicador em `IntrinsicHeight` cai no mesmo buraco.

A divergência de medição sobre acessibilidade nesta tela terminou num terceiro
lugar, e é o mais honesto: **nenhuma das duas medições vale**. Uma frente
reportou as três diretrizes reprovando, a outra reportou duas passando — e a
segunda foi verificar e mostrou que a asserção de layout dispara durante
`performLayout`, antes de qualquer avaliação. Mesmo drenando as exceções à mão, a
árvore de render continua marcada `NEEDS-LAYOUT`, então a semântica avaliada em
cima dela não representa a tela. Um alvo que não foi disposto pode medir zero e
reprovar, ou não ser visitado e passar: as duas coisas são artefato do mesmo
defeito.

Registro portanto a acessibilidade de `child_safety` como **não medida**, com o
motivo, a ser remedida depois da correção de layout.

E isso fecha as três observações iniciais sobre a tela — transborda, falha nas
três diretrizes, fica presa carregando — como **três sintomas da mesma causa**,
e a causa é uma linha. Não é uma tela com três problemas independentes; é uma
tela que não renderiza. A prioridade continua a mesma; a natureza do trabalho
não.

## O achado mais importante da rodada

Uma frente entregou 61 testes verdes de Suporte e reportou aceite funcional
exercitado. Depois voltou por conta própria, contra o próprio número e com o
delta já aplicado, para corrigir: **Suporte não tem camada de dados**. A pasta
tem apenas domain e presentation, sem data, sem repositório, sem sequer uma
interface, e nada em packages define SupportTicket. Em produção a rota nem abre:
nenhum ponto de composição injeta o controlador e o router devolve 503. Os 61
casos exercitavam um controlador de protótipo em memória.

Verde sobre protótipo não é verde sobre produção. A partir dessa correção, toda
promoção de estado passou a exigir três respostas por escrito: main.dart compõe o
caminho? o router monta a página produtiva? existe implementação de produção do
repositório, e não só a interface?

**Ao longo da noite a mesma pergunta pegou mais cinco casos independentes**, em
cinco formas diferentes, e é esse resultado que muda o significado do painel:

- `forms.respond`: a rota constrói a página sem api e descartando o
  `:occurrenceId` que o próprio path declara. A correção de limites numéricos
  está provada no widget e não é alcançável pela rota produtiva.
- `health-care` e `medication`: a rota produtiva monta o controlador com
  `UnavailableHealthCareRepository`, e o escopo autenticado injeta
  `UnavailableMedicationPlanRepository`. Não existe implementação Supabase de
  nenhum dos dois. Os 182 PASS de um e os 39 do outro são verdes sobre fixture.
- `daily_routine`: `RoutineRepository` só tem implementação Development e
  Unavailable.
- **Autosave do editor de Formulários**: existe, está testado, e só roda no
  construtor de autoria — `_scheduleAutosave` começa com
  `if (widget.authoringApi == null) return`, e `SupabaseFormsAuthoringApi` não é
  construído em lugar nenhum do app. Em produção o salvamento é sempre explícito.
  Este é o único caso em que **o rastreador afirmava algo falso** em vez de apenas
  omitir: a linha creditava o autosave como integrado. Já corrigida.

Cinco caminhos diferentes para o mesmo resultado — código pronto, testado e
inalcançável. E uma pergunta que nenhuma frente pode responder e que muda o valor
de tudo que está atrás daquele construtor: `SupabaseFormsAuthoringApi` nunca é
instanciado. Isso é **trabalho preservado para uma etapa futura, ou composição
que ficou faltando?** Se for o segundo, o autosave volta de graça.

E um caso pior que o de Suporte: em `attendance` a camada de dados **existe em
Dart, está ligada, e chama funções que não existem no servidor**. As RPCs
`superadmin_attendance_*` não aparecem em nenhuma das 173 migrations vivas, só em
`.recovery-archives`. Só não quebra porque a rota está fechada.

## O padrão que apareceu quatro vezes: cobertura que não cobre

Não é um defeito, é a forma de vários deles, e muda o que o painel significa:

- O teste de acessibilidade do shell verifica rótulo e **não verifica tamanho de
  alvo**. O shell tem teste de acessibilidade — e o app inteiro está sem essa
  verificação. O botão do menu do usuário expõe 44 px contra os 48 exigidos, mas
  **o item não é os 4 px, é a diretriz que nunca foi aplicada ali**.
- A Agenda tem um teste chamado "matriz a 200 por cento funciona em claro e
  escuro", verde, enquanto o calendário no shell a 375 transborda a 100%. O
  teste cobre outra superfície.
- Minha conta tem golden que amarra tema à largura — claro só abaixo de 1024,
  escuro só acima — então metade da matriz visual nunca foi renderizada.
- `errors.409` era cobrado por um golden cujo arquivo de referência nunca
  existiu.

E a variante mais cara, que apareceu quatro vezes em telas diferentes: **verde
sobre protótipo não é verde sobre produção**. Suporte, `forms.respond`,
`health-care` com `medication`, e `daily_routine` têm suítes verdes sobre
repositórios que não existem em produção.

## O problema não é falta de conhecimento no time

Este é o enquadramento que eu levaria primeiro, se você só lesse um parágrafo.

Os dois defeitos estruturais encontrados hoje **já tinham sido resolvidos neste
mesmo codebase**, em telas diferentes, por gente diferente, e nos dois casos com
um comentário explicando a razão:

- O controller que morre antes da transição de fechamento: Rotina tinha o
  defeito; `access_profiles` já o havia resolvido com um `DialogRoute` próprio
  que espera `route.completed`, com o comentário "The text controller must
  outlive the closing transition".
- O `IntrinsicHeight` sobre um `LayoutBuilder`: `safety` quebra por isso;
  `access_profiles` já o havia resolvido com `Table`, com o comentário dizendo
  que o status canônico usa `LayoutBuilder` e não pode participar de
  `IntrinsicHeight`.

Os defeitos que sobraram estão exatamente onde a solução existente não foi
transplantada. Isso é mais acionável que uma lista de bugs: **o problema não é
falta de conhecimento no time, é o conhecimento não chegar a todas as telas.**

E o caso mais literal apareceu dentro de **um único arquivo**. Em
`safety_pages.dart`, o assistente de criação guarda a intenção de escrita com
rigor — reusa o `requestId` enquanto a intenção não muda, e ainda relê para
confirmar se a escrita entrou antes de concluir — enquanto aprovar, rejeitar e
suspender usavam a versão ingênua, gerando identificador novo no instante do
toque. **Vinte linhas de distância.** O conhecimento não atravessou nem o arquivo
onde mora.

O mesmo vale pelo lado positivo, e é o que dá confiança nas correções: a forma
canônica de intenção de escrita **já existia** em Circulares e em Cardápios. As
correções desta noite em Acontece, Agora e Momentos não inventaram convenção —
trouxeram três famílias para a convenção que já era da casa.

**Um critério de decisão que a rodada produziu e que outras podem reusar:**
latente com custo de *crash* não é a mesma coisa que latente com custo de
*recusa*. Foi ele que separou o intervalo de datas invertido — que estoura o
seletor ao abrir e por isso foi corrigido — de três outras inconsistências
latentes cuja pior consequência seria o servidor recusar, e que ficaram apenas
registradas.

## O censo de `IntrinsicHeight`

Vale como exemplo do que uma varredura barata entrega. Há exatamente quatro usos
em `apps/superadmin`, e os quatro estados diferentes contam a história inteira:

- `access_profiles` **já bateu neste defeito, resolveu com `Table`** e deixou na
  linha 633 um comentário dizendo que o status canônico usa `LayoutBuilder` e não
  pode participar de `IntrinsicHeight`.
- `errors` é seguro: envolve apenas `Text` e `VerticalDivider`.
- `people` tem o padrão **idêntico** ao de `safety` e só não quebra porque o
  cartão de lá usa indicador próprio em vez do canônico. É uma armadilha armada:
  no dia em que alguém padronizar o indicador, quebra na hora.
- `safety` é a única vítima.

É o argumento mais forte para tirar o `LayoutBuilder` do componente
compartilhado, em vez de corrigir só a tela que quebrou.

## Decisões que dependem de você

0. **PERGUNTA BINÁRIA, e é a mais barata de responder: qual é, a partir de
   agora, a referência aprovada do Perfil do Principal?** A referência aprovada
   hoje contém um botão **"Acompanhar"** e uma faixa com **Seguidores,
   Seguindo**, Publicações, Localização, Fundação e Colaboradores. A composição
   atual tem apenas "Mensagem" e três métricas — Publicações, Momentos e
   Circulares. O resto da página é pixel a pixel idêntico.

   A pergunta é: **a referência aprovada continua sendo a que tem Acompanhar,
   Seguidores e Seguindo, ou a composição atual passa a ser a referência?** Se
   passa a ser, isso é **reaprovação administrativa** de dez referências e não
   há defeito. Se não passa, alguém mudou uma composição aprovada sem
   reaprovação. Nenhuma frente pode decidir.

   **Precisão que muda a forma da pergunta, e não o achado.** A frente que
   levantou isso corrigiu o próprio enunciado depois de verificar de onde vêm as
   métricas: a comparação é entre duas imagens da superfície de **preview**,
   montada com o fixture "Colégio Horizonte" — a mesma que a rota `/dev` monta —
   e não da rota de produção. Na rota real, o construtor que produção usa
   (`PrincipalProfilePreviewData.contextual`) traz `metrics`, `highlights` e
   `links` vazios e `nextEvent` nulo, e as quatro seções são guardadas por
   `isNotEmpty`. **Na rota real essas seções nunca aparecem, nem antes nem
   depois.** Ninguém tirou capacidade da tela que o usuário vê hoje.

   Isso não enfraquece a pergunta, porque os doze anexos que você aprovou são
   exatamente as referências dessas superfícies, e o golden é o que as protege.
   Mas acrescenta um fato que ajuda a responder: **manter Seguidores na
   referência seria aprovar uma referência que a rota real hoje não consegue
   preencher**, porque não existe fonte autorizada por trás de nenhuma das
   quatro seções.

   Uma inferência, identificada como inferência: seguidor e botão de seguir num
   perfil de escola é exatamente o que a visão do produto recusa — o Coelo não é
   rede social aberta e não deve transformar cuidado infantil em feed público.

1. **Goldens: não são uma população só.** Esta seção foi reescrita quatro vezes
   esta noite, sempre porque uma medição nova derrubou a leitura anterior, e a
   correção mais importante é a última: **há pelo menos duas causas distintas, com
   assinaturas opostas.** Numa, a diferença escala com a densidade da tela e
   correlaciona com a largura — assinatura de renderização. Na outra, medida em
   `principal_profile`, o número **absoluto** de pixels é praticamente constante
   entre 768, 1024 e 1440, o que é assinatura de elemento de tamanho fixo, e a
   inspeção confirmou: é mudança de conteúdo, tratada no item 0. Tratar as 144
   como um bloco só levaria a decidir errado em pelo menos uma delas.

   As **três assinaturas**, e o método barato que as separa sem abrir imagem —
   basta ler a linha `Pixel test failed, X%, Ypx` de cada caso:

   - **Y cresce com a área** → renderização global. É a maior população.
   - **Y praticamente constante entre larguras** → mudança de conteúdo, um
     elemento de tamanho fixo adicionado ou removido. `principal_profile`
     (~11,3 mil px) e `principal_happens` (~2,2 mil px).
   - **X perto de 100% com conteúdo idêntico** → mudança de geometria.
     `principal_moments`, onde a referência aprovada renderiza o viewer com
     letterbox e o código atual renderiza full-bleed. Mesma foto, mesmos
     contadores, mesma legenda; cada pixel deslocado.

   Cada frente vinha chamando o próprio conjunto de "deriva pré-existente", e
   **pelo menos três causas diferentes estavam sob esse nome**. Nenhuma delas se
   corrige regravando golden sem decisão.

   Há ainda uma quarta componente, menor e agora nomeada, que se soma a
   qualquer golden capturado **antes de 08/09**: `c4a7feff8` e `ec9826f3e`
   mexeram no cabeçalho compacto e no toggle da barra lateral. Já apareceu em
   nove goldens de Rotina e um de Assiduidade.

   O que vem abaixo vale para a população de renderização, que é a maior: Primeiro tratei tudo como deriva de ambiente; depois a
   magnitude — 21 de 28 comparações acima de 8%, máximo de 43,94% — me fez
   registrar que a população grande "só podia ser mudança visual real nunca
   reaprovada". Uma frente foi mais fundo, escreveu um decodificador de PNG e
   comparou master contra teste pixel a pixel, e desmontou a minha própria
   conclusão com três fatos medidos:

   - Em **355 pares comparados a dimensão da tela é idêntica em 100% deles**.
     Nenhum golden falha porque a tela mudou de tamanho.
   - Nas falhas grandes a diferença está **espalhada por quase toda a
     superfície**: em `forms_editor_dark_375`, 43,94% dos pixels atingindo 93,9%
     das linhas e 91,5% das colunas. Em `access_profile_cards_dark_375`, 91,90%
     dos pixels atingindo **100% das linhas e 100% das colunas**. Mudança de
     conteúdo atinge uma faixa, não a imagem inteira nos dois eixos.
   - A diferença **correlaciona com a largura**, na mesma tela e no mesmo
     estado: `forms_editor_light` dá 38,99% em 375, 14,38% em 768, 8,38% em 1440
     e 3,88% em 1024. Uma tela redesenhada não muda de gravidade conforme o
     viewport; uma mudança de métrica de texto muda, porque em 375 o texto quebra
     apertado, um delta mínimo reflui a coluna inteira e cascateia.

   O mesmo gradiente aparece em **quatro** features independentes, de donos
   diferentes, três delas intocadas por quem mediu. E o refinamento é mais forte
   que a confirmação cega: a assinatura de gradiente aparece nas quatro, mas a
   **magnitude escala com a densidade da tela**. Diretórios administrativos
   densos explodem — `access_profile_cards_dark_375` em 91,90%,
   `group_directory_cards_dark_375` em 17,37% — enquanto um feed do Principal,
   com poucos elementos grandes, quase não muda:
   `principal_happens dark_375` em 0,63%, caindo a 0,15% em 1440, na mesma ordem
   por largura. É exatamente o que uma mudança de métrica de renderização prevê,
   e encaixa com o harness carregar ícones do SDK local: tela com muito texto e
   muitos ícones sofre muito, tela com poucos sofre pouco.

   A causa provável está verificada e é simples: **não existe ambiente de
   referência fixado**. O `pubspec.yaml` declara `flutter: ">=3.38.0"` sem limite
   superior, não há `.fvmrc` nem `.tool-versions`, **não há CI** — nenhum golden
   foi gravado em ambiente controlado — e o histórico mostra que as referências
   foram atualizadas por commits locais comuns, o último em 01/09. A referência
   visual do projeto é comparada contra o que a máquina do momento tiver. **Isso muda a decisão de
   auditoria para decisão única:** você não precisa investigar 144 telas para
   descobrir o que mudou em cada uma. Precisa identificar a mudança de ambiente
   ou de toolchain entre `f71b6a9c5` e hoje, e reaprovar as referências em bloco.

   E a consequência que mais importa para o painel: **enquanto a referência não
   for reaprovada, todo golden do repositório está cego**. Não é só que 144 estão
   vermelhos — é que os verdes também não provam nada sobre aparência, porque a
   base de comparação não corresponde ao ambiente atual.

   Nenhuma imagem foi regravada fora do critério acordado. A causa raiz não foi
   identificada: o que está medido é dispersão, gradiente por largura e dimensão
   idêntica.
1b. **Pinar o SDK antes de regravar qualquer golden.** Uma frente foi atrás da
   causa e eu confirmei por conta própria no código: as suítes de golden carregam
   `MaterialIcons` do SDK **local**, por caminho relativo a
   `Platform.resolvedExecutable`, enquanto a Nunito Sans vem do repositório. E o
   `pubspec.yaml` declara só um piso, `flutter: ">=3.38.0"`, sem `.fvmrc`, sem
   `.flutter-version` e sem nenhum registro de qual SDK gravou as baselines. As
   referências estão presas a um SDK que o repositório não registra, então
   qualquer máquina em outro Flutter falha em bloco sem que feature nenhuma tenha
   causado nada. **Regravar sem pinar só transfere a deriva para a próxima
   máquina.** A ressalva do autor, que eu mantenho: vendorizar a fonte de ícones
   remove uma das duas variáveis, não as duas — o fantasma aparece também no
   texto em Nunito Sans, que já vem do repositório, então o rasterizador do
   engine também difere. Ambiente desta rodada: Flutter 3.44.2 stable, framework
   c9a6c48423, engine 04efd7c093, Dart 3.12.2, Windows.
2. **Baseline visual de `errors.409`**, que nunca existiu.
3. **Visibilidade do leitor Principal no Sobre.** Não existe token de leitura em
   `profiles.about.*`, apenas manage, publish e update_official_data.
4. **Contraste do chip DESTAQUE em Para Você**, agora medido dos dois lados e
   com a causa isolada. **Tema claro: 3,75:1** contra o mínimo AA de 4,5:1 — o
   número herdado estava certo. **Tema escuro: 6,25:1, passa** — e isso ninguém
   tinha dito, o defeito é só do tema claro.

   A causa não é escolha de valor, é estrutural: no tema claro **o véu e o texto
   são a mesma cor**, `onPrimary` branco. Qualquer véu branco aproxima o chip do
   texto. A curva foi medida: alfa 0 dá 4,66 e passaria; 0,08 dá 4,21; 0,16, que
   é o atual, dá 3,75; 0,24 dá 3,32. **Não existe alfa de véu branco que
   resolva** — só remover o véu, o que apaga o chip.

   O que resolveria mantendo o chip: inverter o véu para o tom escuro da própria
   marca. `orange950` a 16% sobre `orange500` dá **5,75:1**, usa token de paleta
   existente, e fica simétrico com o tema escuro, que já veda com `orange950`.

   Não foi aplicado porque o token é `scheme.onPrimary`, compartilhado — decisão
   do `coelo-ui`. E o custo foi medido em vez de estimado: a troca **quebra 13 de
   13 goldens** de `principal_for_you_preview_golden_test`. Revertida, árvore
   limpa conferida. **A decisão é entre uma tela que não cumpre AA no tema claro
   e treze referências aprovadas que precisam ser regravadas** — com o número dos
   dois lados, que é o que faltava.
5. **Contrato visual de Editar perfil.**
6. **Contrato de UX de Lançamentos** (`daily-routine.publish`): o comando existe,
   a tela não, e a spec 021 não cobre Lançamentos.
7. **Rota Testar de Formulários** como superfície de leitura autorizada: hoje é
   mantida sem leitura por um contrato de teste verde e deliberado.
8. **Navegação no editor de Rotina:** habilitar a guarda de saída pela barra
   lateral faz o shell desenhar sua navegação e move seis goldens. É decisão
   visual, não de fiação.
9. **Suporte entra no MVP?** Hoje não existe backend nenhum.
10. **Preflight de leitura em produção** para confirmar se as RPCs internas
    existem. A baseline `20260901101500` insere permissão sem os rótulos que
    passaram a ser NOT NULL: ou ela nunca aplicou, e o realm interno inteiro
    falha fechado contra gateway inexistente, ou alguém a ajustou fora do
    repositório. Não é distinguível sem acesso de leitura autorizado.
11. **Autorizações remotas nominais** para os pacotes preparados nesta rodada.

12. **Superfícies produtivas do Principal dizem ao usuário que ele está numa
    prévia.** Seis ocorrências em três telas — Acontece, Agora e Momentos —
    respondem a um toque com "indisponível **nesta prévia**" ou "estará
    disponível na **experiência completa**". Essas páginas *são* as rotas
    produtivas. Um responsável que toca em responder no Agora lê que o produto
    que ele está usando é um rascunho.

    **Correção da minha própria leitura, feita antes de isto chegar a você.** Eu
    havia escrito que o repositório tem as duas respostas contrárias — que o
    teste do Perfil proíbe a frase e o de Para Você a espera. **Está errado.** A
    ocorrência em Para Você está dentro de um `findsNothing`: o teste se chama
    "diz claramente que um atalho sem destino está indisponível", toca em
    Cardápio na rota real, e assere que aparece "Cardápio ainda não está
    disponível" e que **não** aparece "estará disponível na experiência
    completa", com o comentário "uma rota de produção nunca responde com a
    mensagem de prévia". Eu vi a string e li como expectativa; a asserção em
    volta dizia o oposto.

    Com isso o item **encolhe e melhora**. Não há duas filosofias no produto:
    Perfil e Para Você **já estão corrigidos e provados**, e Acontece, Agora e
    Momentos ficaram para trás — nessas três os testes de fato esperam a frase
    presente, com `findsOneWidget`. Então a decisão deixa de ser "escolher entre
    duas filosofias" e passa a ser **aplicar em três telas o que duas já fazem**,
    que é conserto com precedente e não escolha de linguagem.

    As opções continuam sendo a ação sumir quando não há capacidade — o que a
    galeria de Acontece já faz — ou a mensagem deixar de afirmar prévia. O patch
    das três telas está preparado e não mesclado, à espera da resposta; e não há
    versão de Para Você a fazer, porque a frase já é inalcançável na rota de
    produção.

13. **Três capacidades de Circulares travadas em graus diferentes, e nenhuma por
    falta de trabalho.** *Agendar* está desabilitada honestamente porque nenhum
    host fornece o seletor — o resto do caminho existe, incluindo o `timestamptz`
    aceito pela RPC; falta escolher entre um diálogo, padrão que o produto hoje
    não tem, e um campo inline como nas irmãs, que muda a composição. *Encerrar*
    está inerte com o backend completo. *Excluir* tem o método de repositório
    escrito e não declarado na interface, então ninguém o alcança — o que
    barateia a opção completa em relação ao que se supunha.

14. **O feed de Acontece tem teto de 20 itens e descarta a paginação que o
    servidor oferece.** A RPC devolve cursor, o repositório o monta corretamente,
    e a tela o joga fora. O efeito não é só "acervo antigo inalcançável": o feed
    é **misto**, então uma sequência de publicações empurra Circulares para fora
    da primeira página, e **uma Circular institucional recente some do Acontece
    sem aviso**. Há um teste vermelho proposital nomeando isto em
    `principal_mixed_feed_pagination_red_test`, escrito por uma frente vizinha
    sem tocar no código do dono. Se o teto for decisão consciente de MVP, ainda
    vale registrar que Circulares competem com publicações pelo mesmo espaço.

15. **Duas superfícies do Principal existem e ninguém as alcança.**
    `PrincipalCircularComposerPage` tem 750 linhas e 238 de teste próprio, e
    nenhuma rota a constrói — o que está roteado é o compositor administrativo. E
    `PrincipalProfileContentTabs` é uma segunda implementação das abas de
    conteúdo do Perfil, pública, sem consumidor, **e com golden aprovado**,
    enquanto a implementação viva é a cópia privada dentro da página do Perfil.
    O caso das abas é o pior dos dois: quem for mexer encontra primeiro a versão
    pública, com nome canônico e prova visual, muda, e nada acontece no produto.
    A pergunta é única: compor Circular e as abas do Perfil pertencem à
    superfície do Principal, ou são exclusivamente administrativas? Se são
    administrativas, as duas saem com seus testes; se não, falta rota, e aí é
    trabalho e não lixo.

## Pacotes remotos preparados e não aplicados

Ver [fila SQL serializada](NOTURNA-fila-sql-serializada.md), com a ordem
atribuída, os carimbos originais que os manifests dos grupos ainda citam, e o
hash que prova que só o nome mudou.

## Achados transversais distribuídos

- **Idempotência de escrita:** 13 sítios geram a chave inline, então o cliente
  perde a capacidade de repetir a mesma intenção. Publicação e criação são os
  casos graves, porque não há revisão esperada barrando a repetição.
- **Catálogo:** 16 divergências, contra 14 registradas. A ferramenta usa o mesmo
  caminho como entrada e saída, então regenerar o relatório versionado não
  subnotifica: **apaga o aviso** e deixa o catálogo verde no app com as 16
  divergências intactas no código.
- **Badge de não lidas:** medido, sem efeito observável em nenhuma rota de
  produção. Sai da fila um refactor de 44 arquivos.
- **Captura estreita de exceções:** repositórios que só capturavam
  `PostgrestException` deixavam falha de transporte escapar crua até a UI.
- **Guarda de mutação:** o risco real não é a chamada sem argumento, é alguém
  **adicionar** um ramo `/attendance` por simetria com invites, notices e
  circulars. O repositório injetado é real, então o ramo abriria as rotas contra
  RPCs que não existem.

## A classe de geometria fixa

Quatro telas transbordam porque a moldura não cresce: o cartão do diretório de
Planos tem `mainAxisExtent` fixo, a célula de Cardápios tem proporção quadrada, a
célula do calendário da Agenda tem altura fixa, e a tabela administrativa não rola
na vertical. Não é falta de `Flexible` num rótulo — esse caso existia e foi
corrigido em Planos, sem mudar nada a 100%.

Duas medições impedem a leitura confortável de que isso é problema de dados de
teste:

- Com a composição **padrão**, que é fail-closed e não injeta repositório nenhum,
  as oito rotas de produção passam a 100% em 375 e 1440 — 16 de 16. A 200%, duas
  falham. **Cardápios transborda os mesmos 37 pixels com e sem dados**, o que
  prova que a causa é a moldura e não o conteúdo.
- A Agenda a 375 transborda com texto a **100%**, no estado padrão de um
  telefone. Autorizei estender a adaptação que a própria tela já tinha
  (`occurrences.take(largeText ? 1 : 2)`) para largura estreita; foi medido e
  **não resolveu**: nem o número do dia com uma única marca cabe nos 39,6 de
  altura que o shell deixa. A alteração foi revertida em vez de escalar para
  geometria. A decisão volta a ser sua, e é a mais severa das quatro porque
  ocorre sem o usuário ampliar nada.

## Acessibilidade medida pelas diretrizes nativas

Depois de corrigido o instrumento, as reprovações reais de diretriz no app são
**13 e não 18**: sete de rótulo — todas já corrigidas por uma única linha —,
cinco de tamanho de alvo, e uma de contraste. A de contraste é o selo DESTAQUE
em Para Você, com razão 3,75 contra os 4,5 exigidos para 11 px, e é real.

`/dev/imports` reprova apenas **tamanho de alvo**, e não as três: rótulo e
contraste eram contaminação do transbordamento da própria tela.

Um candidato ficou sem identificação e está registrado como candidato, não como
defeito: um nó de 128×48 no cabeçalho de quatro telas expõe apenas `longPress`
sem rótulo. Sete hipóteses foram descartadas, seis delas por teste isolado, e o
nó só aparece na composição completa pelo router — nunca nos componentes
isolados. Quem retomar deve atacar pela composição.

## Duas decisões de componente e uma de segurança

**Tabela administrativa redimensionável.** O `SingleChildScrollView` de
`CoeloAdminResizableTable._tableBody` rola apenas na horizontal, então a coluna
que empilha cabeçalho e linhas não tem para onde rolar na vertical. A aritmética
fecha exatamente com o overflow relatado: 56 de cabeçalho mais 25 linhas de 65
dá 1681, contra 612 de altura disponível, o que produz os 1069 pixels. **As
linhas abaixo do corte não estão clipadas, estão inalcançáveis.** Não corrigi e
proibi a alternativa barata de limitar as linhas da tela de Importações: fechar a
suíte escondendo um defeito de acessibilidade real seria pior que a suíte
vermelha. A correção verdadeira exige sincronizar dois eixos entre corpo e coluna
fixada num Stack com posicionamento absoluto, atinge todos os diretórios
administrativos e é autoridade de `coelo-ui`. É decisão sua.

**Exposição de bucket e chave (severidade baixa, mas contraria a ADR 0032).**
`public.authorize_circular_media_read` está no grant para `authenticated` e
devolve `bucket_id` e `object_key`. Precisa ser chamável pelo usuário porque a
Edge Function usa o cliente dele para autorizar antes de assinar. Não concede
acesso — o bucket é privado e sem assinatura nada se lê — mas a ADR 0032 diz
para nunca expor bucket, chave ou provedor ao cliente. A correção seria devolver
um identificador opaco, o que muda o contrato entre a RPC e a Edge Function e
entra na fila SQL com autorização nominal. Nada foi aplicado.

**Redação corrigida no rastreador.** O inventário registrava
`save_circular_response_draft`, `submit_circular_response` e `delete_circular`
como ausentes no gateway. É verdade para o gateway administrativo v2 e falso
para o caminho Principal: as nove RPCs que os repositórios do Principal chamam
estão definidas em `20260821190000_circulars_production.sql`, com `revoke all`
seguido de grant a `authenticated`, 28 funções `security definer` e 29 com
`search_path` vazio. Isso prova **definição local, não aplicação remota** — a
lacuna muda de redação, não de estado.

## Verificações positivas registradas

O registro do que **não** é problema evita que o próximo revisor gaste o mesmo
tempo:

- O `file_picker` com leitura de bytes reais existe no assistente de importação,
  o que pareceria contrariar a política de importação adiada. Não contraria: a
  rota só monta o assistente sob a guarda de capacidade e a composição produtiva
  injeta o repositório indisponível nos dois pontos. Fail-closed em duas camadas,
  e o picker só vive em `/dev`.
- Acontece e Agora foram verificados contra o mesmo padrão de perda que atingiu
  Momentos, e já têm embedded e mediaPicker convivendo.
- `attendance.correct` e `attendance.finish` não têm lacuna de cliente: o
  conflito de versão tem exceção tipada, tratamento e dois testes.

## Como esta rodada encontrou o que encontrou

O método rendeu mais que qualquer lista de tarefas, e vale mais que os defeitos
individuais porque se repete:

**Reler a própria mudança já publicada e declarada provada.** Uma frente
encontrou assim quatro defeitos em código que ela mesma tinha entregue naquela
noite, nenhum deles pego pelos testes que ela havia escrito. Outra encontrou sete
do mesmo jeito. As perguntas que funcionaram foram três: **o que isso faz quando
há mais de um item** (cobertura com um elemento não exercita seleção), **o que
acontece quando duas coisas ocorrem ao mesmo tempo** (cobertura sequencial não
exercita entrelaçamento), e **o teste mede o efeito ou o mecanismo** (afirmar que
a lista foi relida não é afirmar que o composer sumiu).

**Comparar superfícies irmãs sobre o mesmo contrato.** Quando duas telas tratam o
mesmo risco de formas diferentes, uma das duas está errada. Foi assim que
apareceu a thread administrativa que nunca paginava, a retirada de Momento que
não sabia a que contexto pertencia, e a única superfície de mídia que não conferia
assinatura real de bytes.

**Procurar capacidade existente sem consumidor.** Além dos cinco casos de código
inalcançável, apareceu o inverso: `superadmin_circular_response_summary_v2`
existe no gateway, o repositório a expõe, há teste de dados — e nenhuma tela
chamava, num aceite que exige exatamente esse resumo. Havia uma segunda camada:
o leitor recebia o repositório tipado pelo contrato mais estreito, então mesmo
com o objeto certo em mãos o método era inalcançável pelo tipo. Nada falha nesse
caso; simplesmente não existe.

**Comparar duas telas que mostram o mesmo dado.** Em Formulários isso rendeu
três casos seguidos — dinheiro, data e escolha —, e nos três a superfície de
operações já fazia certo enquanto a de resposta carregava a versão antiga da
formatação. O último expunha identificador interno: a pessoa via
`Como foi: option-2` em vez de `Como foi: Difícil`, e o teste da outra superfície
**já proibia isso explicitamente**. Não é descuido pontual; é sedimentação — uma
tela escrita depois, com mais cuidado, e outra que ficou com as versões antigas
de cada formatação.

**Exigir ver o vermelho antes de aceitar o verde.** Três armadilhas diferentes
apareceram só por isso: literais `const` que o compilador canonicaliza, fazendo
uma guarda de igualdade passar contra o código defeituoso; `setSurfaceSize`
deixando o `MediaQuery` em 800 px, de modo que a medição lia o default achando
que era a largura real; e um widget que, por ser todo rolável ou `Wrap`, não tem
como transbordar — cinco casos verdes que não protegiam nada.

**E medir na base integrada, não na própria branch.** Duas vezes isso mudou o
resultado: uma frente materializou a base conjunta e encontrou a rota duplicada
que nenhuma branch isolada mostrava; outra ia regravar um golden **com
autorização em mãos**, foi medir sobre o integrado antes de executar e descobriu
que o golden já passava. Teria substituído uma referência correta pela foto de um
código desatualizado, com uma justificativa que parecia sólida.

**Comparar superfícies diferentes não autoriza conclusão — nem para refutar.**
Duas frentes bateram nisto em vinte minutos, por caminhos opostos. Uma comparou
a imagem de referência com a atual e escreveu "o código atual", sem perguntar
*qual* código: as duas vinham do mesmo widget montado com fixture, e não da rota
de produção. A outra mediu um widget de cartões isolado, viu passar, e quase
refutou um relato de acessibilidade que tinha medido a página inteira com o
shell. A metade que engana é a segunda: refutar *parece* seguro, e uma refutação
errada apaga um defeito real em vez de inventar um falso.

**Escrever o caso adversarial antes de saber se ele falha.** A correção do envio
no chat do Principal usava o último item da página como limite do que preservar.
O caso adversarial — escrito antes, sem saber o resultado — falhou: quando a
página encolhe porque algo foi removido, o último item passa a ser mais novo e a
cauda preservada traz de volta o que sumiu. O limite correto é o **cursor
devolvido pelo servidor**: dentro do alcance relido a página nova é a autoridade,
fora dele preserva-se o que o leitor já via. Foi o teste que trocou o desenho, e
não o contrário.

**Projetar o conhecimento e depois aplicá-lo como checklist.** Uma frente
corrigiu a mesma classe em quatro repositórios, escreveu o contrato de escrita
nomeando o quinto — Instituições — como referência já existente, e ao aplicar as
quatro perguntas do próprio artigo achou o sexto e o sétimo defeito, em arquivos
que ela já havia lido duas vezes na mesma noite sem ver. **O checklist viu o que
a leitura não viu**, e o artigo não é prescrição inventada: é a descrição do que
o repositório já faz certo em um lugar, para o próximo copiar em vez de
redescobrir.

**Distinguir "pendente de verificação" de "pendente de existir".** O aceite de
Avaliações pede conferir os goldens restantes e a família **não tem nenhum
golden**, nem nunca teve — verificado no histórico, e os artefatos de falha que
sugeriam o contrário vieram de uma branch que não está em `dev`. Cobertura
perdida e cobertura que nunca existiu pedem decisões opostas, e sem esse rastreio
a resposta teria sido a errada.

**Uma classe de teste que erra o diagnóstico de propósito.** Cinco falhas em
duas famílias tinham a mesma causa: o teste toca um botão de rodapé sem garantir
que ele esteja visível. Em 375 px, ou em 1440 com texto a 200%, o rodapé sai da
área visível, a etapa nunca avança, e tudo o que vem depois falha por motivos que
**parecem** distintos — um campo ausente aqui, um `Bad state` ali, uma contagem
de requisições errada acolá. O sintoma aponta para o controle de destino e a
causa está no toque anterior, então a frente dona investiga o lugar errado. É por
isso que essas falhas sobrevivem rodadas inteiras. O censo preventivo tem 67
arquivos e 337 toques nessa forma; **nenhum falha hoje**, e por isso nenhum foi
mexido nesta rodada.

## Higiene e preservação

- Os 90 artefatos de WIP ignorados na raiz do checkout integrador estão
  preservados por caminho e SHA256 em [manifesto](NOTURNA-wip-raiz-manifest.txt).
  Nada foi apagado.
- Os PNGs sob `test/**/failures/` ficam fora do índice: são diffs regenerados a
  cada execução e, rastreados, fazem qualquer frente aparecer no fechamento com
  alterações que não são trabalho.

## O que ainda falta

Esta seção é atualizada a cada ciclo e fechada no corte das 05:00.

**Nada foi aplicado em ambiente remoto.** Treze pacotes SQL estão preparados,
revisáveis e enfileirados em ordem forward-only, e nenhum foi executado em lugar
nenhum. Dois deles carregam condição registrada: a trinca de Circulares, que só
pode ser autorizada junto com a configuração do R2 e o deploy da Edge Function,
e `20260909214000`, que exige suíte mínima antes de aplicar.

**A prova SQL local está bloqueada por defeitos da própria cadeia, e a
medição melhorou duas vezes durante a noite.** A primeira frente relatou
`20260812002010_import_export_unit_source_retention.sql`, que declara uma
variável do tipo de uma tabela que nenhuma migration cria. Uma segunda medição,
feita por replay completo em Postgres 17, localizou uma parada **anterior**:
`20260812002000_child_safety_schema.sql`, o arquivo 48 de 186, viola o `NOT NULL`
de `module_label` que o arquivo anterior criou sem default — e, relaxado esse,
falha em seguida em `updated_at` ausente. Os arquivos 1 a 47 aplicam limpos.

As duas observações são compatíveis e a segunda é mais útil: não há um defeito,
há uma cadeia que deixou de ser replayável em algum ponto e acumulou os
seguintes sem que ninguém percebesse, porque **em produção a ordem real de
aplicação não foi a ordem de nome**. É por isso que cada candidato precisou de um
profile próprio de replay — não é preciosismo do harness, é contorno.

A verificação de sintaxe da fila inteira, essa sim, foi concluída: **13
candidatos e 6 arquivos de pacote sem nenhum erro de sintaxe em Postgres 17**, e
quatro deles aplicaram inteiros. Ver `NOTURNA-fila-sql-serializada.md`.

**As três medições não se movem sem decisão.** Front-end certificado em 11/230;
backend e end-to-end em zero, e assim permanecem enquanto não houver autorização
remota nominal. O que a rodada moveu foi o estado de bloqueio: agora separado
entre o que depende de você, o que depende de ambiente, o que depende de
implementação que não existe e o que depende de decisão de produto.

**O que depende só de você para destravar hoje**, em ordem de custo crescente:
a composição do Perfil (item 0, uma resposta binária); a baseline de
`errors.409`; o ambiente de referência dos goldens; as quatro geometrias fixas; a
rota Testar de Formulários; o contrato de Lançamentos; a navegação no editor de
Rotina; e se Suporte entra no MVP.

**O que nenhuma decisão resolve**, porque é ausência de implementação: Suporte
sem camada de dados, `health-care` e `medication` sem repositório de produção,
`RoutineRepository` e `StudentTrackingRepository` sem implementação, e
`account.sessions` sem tela. E `attendance`, que é o caso mais delicado dos
cinco, porque a camada de dados **existe, está ligada e chama funções que não
existem no servidor** — só não quebra porque a rota está fechada.
