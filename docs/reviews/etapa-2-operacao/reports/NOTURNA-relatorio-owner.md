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

## O essencial, em uma página

Este documento tem duas mil linhas porque a rodada mediu muito. **Se você ler só
esta seção, terá o que decide.**

**O que a noite moveu.** Seis frentes trabalharam da meia-noite às 05:00 sobre uma
base integrada continuamente. A suíte fechou em **6370 casos que passam e 144 que
falham** — e das 144, **129 são referências visuais** que dependem de decisão sua,
não de código. Das 15 restantes, **cinco foram medidas na base anterior à rodada e
falham lá idênticas**: são anteriores, não introduzidas.

**Front-end certificado subiu de 7 para 11 de 230.** Backend e integração
permanecem em zero, e a seção seguinte explica por quê — não é falta de esforço,
não existe base reproduzível para exercitar rota real contra Postgres.

**Três defeitos de produto foram encontrados; dois corrigidos.** A grade de
Segurança infantil não se dispunha em produção, sobre dados de criança — corrigida
e verificada por quem não a corrigiu. Um cardápio encerrado aparecia como
rascunho, e filtrar por encerrado devolvia lista vazia — corrigido. E Importações
transborda por número de linhas, com a causa num componente de tabela
compartilhado que já está na sua lista de decisão.

**A ação de maior retorno que você pode autorizar é uma consulta.** Um
`select proname from pg_proc` no banco de produção responde de uma vez por cinco
RPCs de Unidades, cinco de Assiduidade e quarenta objetos internos que o
repositório chama e nunca cria. **Três blocos inteiros de bloqueio viram fato em
segundos.** Enquanto ela não acontecer, esses blocos estão classificados como
falta de autorização para verificar — não como ausência.

**As decisões que só você pode tomar**, em ordem de custo crescente: a referência
aprovada do Perfil (uma resposta binária); a cópia de três telas que se declaram
uma prévia ao usuário, com patch preparado e não mesclado; o véu do chip de
destaque, que custa treze referências visuais; o rebaseline por família, com uma
liberada e quatro não; se o Superadmin de produção deve poder reportar bug — que é
a mesma decisão de se Suporte recebe camada de dados; e o que acontece com as
demais regras de público quando um formulário é reagendado.

**Uma leitura honesta sobre o método, porque ela muda como você lê o resto:** a
maior parte do valor desta noite não veio de código escrito. Veio de **medição que
desfez conclusões** — inclusive cinco afirmações desta coordenação, derrubadas por
conferência externa antes de chegarem até você. O documento registra os erros com
o mesmo cuidado que os acertos, e é isso que torna o resto verificável.

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
| `b4cf3664a` | 01:20 | 6344 PASS, 14 SKIP, 146 FAIL — 129 golden, 17 não |
| `8e230b15a` | 02:25 | **6370 PASS, 14 SKIP, 144 FAIL — 129 golden, 15 não** |

Nenhum número soma reexecuções, e cada linha é uma execução completa sobre a
base indicada. A queda de PASS entre a terceira e a quarta linha não é regressão:
a terceira medição rodou com um conjunto de suítes diferente. O que é comparável
entre elas, porque é a mesma pergunta feita do mesmo jeito, é a coluna de falhas.

**O número que importa é o segundo: as falhas que não são golden caíram de 38
para 17, e das 17 nenhuma é órfã.** Elas se distribuem assim:

| Falhas | Arquivo | O que é |
| ---: | --- | --- |
| 3 | `app/router/principal_real_route_test` | **teste desatualizado pela integração do feed misto**: a rota passou a exigir dois repositórios e o teste injeta um, então cai em indisponível. Produção compõe os dois e o fail-closed está correto |
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

**E as não-golden são anteriores à rodada, medido e não deduzido.** Os mesmos
arquivos foram executados em três pontos: a base do início da noite, uma
intermediária e a base entregue. Em `d784462c1`, **antes de a rodada começar,
falhavam exatamente as mesmas cinco, com os mesmos nomes de caso**; nenhuma foi
introduzida esta noite, e uma que falhava lá **passa agora**. Isso é diferente de
"são conhecidas" — quem vê cinco vermelhos de rota numa base entregue de
madrugada assume que a madrugada os produziu.

O motivo técnico também as separa do bloco visual: uma morre com
`RenderFlex overflowed by 1409 pixels`, porque o teste não fixa o tamanho da view
e cai no padrão de 800×600; as outras quatro morrem com `Bad state: No element`,
ou seja, o widget procurado nunca chegou a existir. **É falha de layout em
ambiente de teste, não de renderização.**

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
   zerada **com um shim mínimo de Supabase** — os schemas, os papéis, a extensão
   de criptografia no schema certo e stubs de usuários e storage — os arquivos 1 a
   47 aplicam limpos e o **48 quebra**:
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

**Achado 3, que é resultado e não ausência de medida, com a ressalva que a
transcrição tinha perdido:** zero divergência de nome de parâmetro **entre as
chamadas cuja assinatura existe no pacote**. O teste pula, por construção, toda
chamada cuja função não está declarada — é a única coisa que ele pode fazer sem
assinatura — e isso significa que **as cinco de Unidades, que são as que mais
poderiam divergir, ficam fora do exame**. A cobertura é de no máximo 75 das 80. O
pacote já tem teste próprio de nomes de argumento, o que mostra que essa classe já
cobrou preço antes; onde é examinável, hoje está limpa.

O teste falha também **se uma das cinco ausências passar a existir e continuar na
lista** — sem isso a lista de exceções envelhece e passa a esconder o defeito
seguinte, que é como esse tipo de allowlist costuma morrer.

## Importações transborda em produção, e a causa é um componente que você já tem para decidir

**Esta seção foi reescrita três vezes, cada uma derrubando a anterior por
medição, e a terceira é a que decide.**

**A primeira leitura** foi que um teste de fronteira falhava por artefato de
ambiente — o teste não fixa o tamanho da view, cai no padrão de 800×600, e o
conteúdo não cabe. A correção óbvia eram três linhas fixando um viewport maior, e
ela teria escondido um defeito de produto dentro de uma correção de teste. A
frente que a encontrou não escreveu esse patch, e por isso o resto existe.

**A segunda leitura**, medida em três viewports, foi que a página não cabe em
tela nenhuma e que a rota de produção monta a mesma página — logo, produção
quebraria assim que houvesse dados. Uma varredura de 67 rotas de desenvolvimento
mostrou que a classe tem uma instância só.

**A terceira leitura, também medida, derruba a segunda e é a correta.** A página
**isolada** não transborda em nenhum viewport com três trabalhos. Pelo router, a
rota de desenvolvimento transborda **com número idêntico para zero ou três
trabalhos injetados** — e número que não muda com o dado injetado não vem do dado
injetado: aquela rota usa o próprio repositório de desenvolvimento. E a rota de
**produção**, com um repositório devolvendo dados, passa nos três viewports.

**O que realmente governa é a altura disponível e o número de linhas, não a
largura.** Medido linha a linha: 800×600 aguenta quatro linhas e transborda com
cinco; 390×844 aguenta cinco e transborda com seis; 1440×900 aguenta oito e
transborda com dez, por 70 pixels, crescendo cerca de 65 por linha — exatamente
uma altura de linha. **A tela estreita aguenta mais que a de 800×600**, porque a
barra de ferramentas empilha diferente, o que encerra qualquer explicação por
largura.

**Então: produção transborda, só não com três linhas. Com dez importações reais,
transborda.**

**E a causa, agora localizada, já está na sua lista de decisão.** O componente
compartilhado de tabela redimensionável envolve as linhas numa rolagem
**horizontal** e as monta numa coluna de altura mínima: **não existe rolagem
vertical**. O `Expanded` na página de Importações está correto — ele limita a
altura; quem transborda é a coluna de linhas dentro do componente. Importações
não é achado novo: **é a sexta tela da mesma causa**, e é a que dá o número mais
limpo, porque a altura de linha fixa torna o limiar contável.

**Não foi corrigido, e a recusa tem motivo:** a correção é rolagem vertical num
componente que sustenta **todos** os diretórios administrativos. Mexer nele de
madrugada mudaria o layout de uma dúzia de telas e invalidaria as referências
visuais de todas, no dia em que a medição de fechamento já havia rodado. Não é
correção contida — é a decisão que você já tem em aberto.

**E a varredura que essa investigação gerou produziu um achado próprio, sobre
instrumentos.** Ao estendê-la para rotas com parâmetro, a sonda reportou **vinte
de vinte passando**. Ao conferir os identificadores que ela havia colhido, vários
não eram identificadores de registro: eram chaves de modo de exibição. A rota
respondia "cheguei" e "sem exceção" porque renderizava o **estado vazio** do
detalhe. Endurecido o critério para aceitar apenas chaves que declaram uma linha
de dado, restaram quatro. **Dezesseis daqueles vinte eram verde de página
vazia** — e uma guarda contra a tela de erro não pegaria isso, porque nenhum
caminho de erro é acionado: aparece o detalhe legítimo de um registro que não
existe. **Sonda com entrada errada produz verde confiante.**

E a razão de os dezesseis não terem sido resolvidos é ela mesma um achado:
**dezesseis listagens em grade de cartões não têm chave de linha.** Sem ela não há
como colher o identificador de um registro que existe para depois abrir o detalhe.

**E não é apenas testabilidade.** A frente que levantou o achado foi medir a
própria listagem e encontrou a mesma classe nela: no estreito, a tela troca a
tabela por cartões e **perde a identidade das linhas no caminho**. A lista funciona
— foi verificado que os cartões trazem título, público, datas, recorrência,
contadores e paginação — mas **uma lista que muda de forma não deveria mudar de
identidade**: quem escreve teste, automação ou atendimento não deveria precisar
saber a largura da tela para falar da mesma comunicação.

Essa frente corrigiu a própria, em seis linhas somadas e nenhuma removida, com o
teste medindo o **efeito** e não a chave — todo item visível na largura corrente é
alcançável pelo identificador, o toque abre o item certo, e o identificador
sobrevive à troca de apresentação. E verificou a discriminação: removida a
correção, dois dos três casos caem, e o de tabela continua passando, porque a
tabela já tinha identidade. **Teste que passa com e sem a correção não prova
nada.** As quinze restantes ficam registradas.

**O sinal foi preservado nos dois sentidos:** três casos verdes fixam o que
funciona hoje — quatro linhas em 800×600, cinco em 390×844, oito em 1440×900 — e
um caso carrega os números do defeito, suspenso com a razão **no próprio nome**.
Remover a suspensão é o teste de aceite quando a decisão sair. E o arquivo explica
por que "consertar" fixando o viewport esconderia o defeito, para que ninguém o
faça.

## Triagem dos 129 goldens: a maior parte é rebaseline seguro

**Esta seção foi reescrita depois de a própria medição que a sustentava se
inverter, e a inversão é o resultado mais importante dela.** A primeira leitura
concluía que cerca de 70% dos casos amostrados escondiam mudança de produto e que
um rebaseline em bloco apagaria trabalho. **A leitura correta é o contrário: cerca
de 83% são deslocamento e podem ser regravados com segurança.**

**O que estava errado no método:** duas das seis famílias foram classificadas
**só por magnitude** — "nas larguras largas o diff vale centenas de vezes a
assinatura do shell, logo há conteúdo". Esse *logo* é falso. **Deslocamento em
bloco também produz magnitude grande**, porque cada elemento aparece duas vezes na
imagem de diferença. Só a comparação **elemento a elemento** classifica; o número
não classifica nada.

O contra-exemplo numérico que fecha o argumento: uma captura de diretório a 375 px
diverge **22,24% e é deslocamento puro**, sem um único elemento diferente. Não é a
causa que muda com a largura, é a **densidade** — dezesseis pixels de deslocamento
num viewport estreito e cheio de linhas de texto atingem quase toda linha; os
mesmos dezesseis pixels em 1440 encontram espaço vazio.

**Daí saem três discriminadores baratos, e nenhum deles é o valor absoluto:**

- **O gradiente de largura.** Percentual que **cai** conforme a tela alarga é
  deslocamento: a mesma causa produziu 43,94% em 375, 17,01% em 768 e 4,08% em
  1024.
- **Forma e cor.** Um elemento que apenas se moveu aparece **duas vezes, iguais**.
  Se a cor muda — um ponto de status rosa na referência e verde agora — ou se a
  forma muda, não é deslocamento.
- **Quantas vezes o elemento aparece.** Deslocado, aparece duas vezes; **novo,
  aparece uma vez**, numa região onde a referência não tinha nada.

Reabertos os diffs um a um:

| Família | Casos | Leitura final |
| --- | ---: | --- |
| Agenda | 14 | deslocamento — duas mudanças aprovadas de shell, separadas por largura |
| Atividades | 16 | deslocamento — cada item da barra lateral e cada cartão aparece em dobro |
| Conta | 8 | deslocamento — composição idêntica, empurrada em bloco pelo shell |
| Formulários | 12 casos, **23 imagens** | deslocamento e mudança deliberada — nenhuma regressão, nenhuma perda de cobertura. O chevron não era estado: são dois controles diferentes, um deles acrescentado por um commit nomeado |
| Cardápios | 6 | **conteúdo** — todo o cartão desceu doze pixels, mas o ponto de status é rosa na referência e verde agora. Duas cores diferentes não são deslocamento |
| Instituições | 4 | **conteúdo** — o cartão de criação ausente, outro fixture, outra paginação |

**Cerca de 50 casos de 60 são deslocamento; cerca de 10 têm componente de
conteúdo, e nos dois casos o conteúdo é pequeno e identificável** — uma cor de
status e um cartão de criação com dados de fixture.

**A recomendação, corrigida:** a maior parte dos 129 é provavelmente rebaseline
seguro, e a revisão humana deve se concentrar nas famílias onde a comparação
elemento a elemento mostra diferença que **não** é deslocamento. Regravar em bloco
sem essa triagem continua sendo errado — mas o custo de fazer a triagem é muito
menor do que a primeira leitura sugeria.

**E o erro que produziu a leitura invertida merece nome próprio, porque é o mais
perigoso desta rodada: medir certo e concluir errado.** Todos os percentuais
reportados na primeira leitura estavam corretos — 44%, 73%, 32%, cem vezes a
assinatura do shell. O que estava errado era a **inferência** tirada deles. Isso é
pior que medir errado, porque **os números conferem quando alguém checa**, e a
conferência natural — refazer a medida — confirma a leitura errada.

Se a quarta categoria não tivesse aparecido, você receberia a recomendação de
revisar humanamente 129 referências visuais quando cerca de 107 delas são
provavelmente rebaseline seguro.

**E há um caso que inverte o risco do rebaseline, encontrado na triagem de outra
família: dois goldens protegem hoje o estado ERRADO.** Um exige um rótulo que o
produto abandonou de propósito, por estar incorreto. O outro — com **0,72% de
divergência**, a menor das larguras largas, a mais fácil de descartar como ruído —
afirma um menu de ações **sem** um item que existe hoje. **Quem lesse esses
vermelhos como defeito desfaria uma mudança correta ou apagaria uma ação.** Nesses
casos, não regravar é o risco, e não a prudência.

**As duas famílias com conteúdo continuam pedindo o dono antes do rebaseline**, e
uma delas pela razão descrita adiante: em Instituições o que se perdeu não foi
afordância, foi cobertura.

**Instituições, 4 casos — resolvido, e a resposta é a terceira possibilidade.**
O cartão tracejado "Criar instituição" está presente na referência e ausente na
captura atual, e a pergunta era se a afordância havia sumido do produto. **Não
sumiu.** O cartão é renderizado apenas quando o callback de criação é fornecido,
e em produção o router o fornece condicionado à capacidade de estrutura. O que
mudou foi a **composição do teste**: o `_goldenApp` atual monta a página sem esse
callback. O fixture inteiro também trocou — outros nomes de instituição, outra
contagem de turmas, "Página 1 de 1" em vez de "1 de 2" — o que confirma que é
outro seed do repositório falso, não outra tela.

**Mas há uma perda real, e ela não é a que se procurava: perdeu-se cobertura.** A
referência aprovada protegia o cartão de criação e hoje não protege mais, porque
o teste parou de fornecer o callback. **Se alguém remover a afordância amanhã,
este golden não acusa.** Então a ação correta não é "regravar e seguir": é decidir
se o golden de Instituições volta a exercitar a criação — o que é uma linha no
próprio teste.

Isso responde à pergunta que abriu a triagem: o rótulo "deriva de golden" estava
mesmo escondendo algo real, só que o algo real é **cobertura perdida, não
afordância perdida** — e a diferença muda quem age. Não é a frente de Estrutura
consertando tela; é quem mantém o golden restaurando a composição do teste.

**E a correção não foi a linha que eu supus.** Medida antes de escrita, ela é
assimétrica: restaurar o callback nas capturas de cartões aproxima o diff em
dezessete pontos percentuais — o que **prova** que aquela referência foi
capturada com a afordância — mas na captura de tabela do mesmo caso o diff
**sobe**, porque essa referência é anterior ao banner. **As duas metades vivem no
mesmo teste e têm histórias diferentes.** E aplicar o callback ao helper inteiro
derrubaria cinco imagens de estado interativo que passam hoje — criar vermelho
novo para restaurar cobertura é a troca que a rodada recusou em toda parte. A
correção final passa o callback só onde a referência prova que a afordância
pertence.

**Isso também rebaixa a gravidade do achado, e é justo dizer:** nada ficou
desprotegido no intervalo. A suíte funcional já guarda as duas direções da
afordância — presença quando o callback existe, ausência quando as ações estão
desligadas. A perda era **exclusivamente visual**.

**A classe que isto nomeia vale mais que o caso:** um arranjo de golden composto
de forma diferente da produção **apaga afordâncias da referência sem que nada
fique vermelho**. O golden continua passando, ou falha por outro motivo, e ninguém
percebe que ele parou de proteger um elemento. É parente de "suíte verde não é
produção", com um agravante próprio: aqui a referência *é* a evidência do que
existia, e só comparando o diff com e sem o callback se descobre o que ela
continha.

**E o método que resolveu vale para os outros pares:** a imagem levantou a
pergunta, o código respondeu. Abrir as duas capturas diz *onde* olhar; só a cadeia
no código diz *o que* aconteceu. Foi a mesma sequência que corrigiu a leitura do
golden do Perfil horas antes.

**Atividades, 16 casos** — a maior das amostras, e falha em **todas** as
larguras: 19%–32% em 375 e 768, 12%–13% em 1024, 9,8%–20,5% em 1440. Nas larguras
largas o diff é centenas de vezes a assinatura de 837 pixels, então há conteúdo
aqui também.

**A proporção da amostra, cinco famílias e cerca de 48 casos: 14 são rebaseline
seguro e cerca de 70% carregam componente que um rebaseline cego apagaria.** Duas
horas antes, a hipótese de trabalho desta coordenação era que a deriva do
cabeçalho explicaria a maior parte dos 129. Ela explica **uma** família inteira e
a metade larga de outra.

**E há uma pergunta anterior ao rebaseline, que o censo de uma frente acabou de
quantificar: 12 de 105 goldens do recorte dela — 11,4% — guardam superfície que
nenhuma rota constrói.** Dez defendem um compositor de Circular do Principal que
existe com 750 linhas e nenhum consumidor, e dois defendem uma composição cuja
espinha são abas de Perfil públicas, sem consumidor, duplicando as que a página
do Perfil já implementa em privado. Os 93 restantes foram verificados um a um e
correspondem a páginas que o router de fato constrói.

O que muda com o denominador: **ter golden não é evidência de que a superfície
exista para o usuário.** Um golden prova que o desenho foi aprovado alguma vez,
não que alguém consiga chegar nele — e esses doze passam verdes para sempre,
somando à cobertura visual sem defender nada. A medição é de um recorte só; o
número do app inteiro não foi levantado.

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

## O defeito mais grave encontrado, e ele foi corrigido nesta rodada

**Estado: fechado.** Corrigido às 23:35 em `089c1fafc`, integrado em `dev`, e
verificado depois por uma frente que não o corrigiu.

**O que era.** Duas frentes mediram `/safety` de forma independente, e o
diagnóstico mudou a categoria do problema: não era transbordamento — **a grade de
cartões não se dispunha**. Vinte exceções de layout por largura, encabeçadas por
`LayoutBuilder does not support returning intrinsic dimensions`, seguidas de
dezenove `RenderBox was not laid out` em cascata.

A cadeia foi rastreada até o fim: cada linha da grade era envolvida em
`IntrinsicHeight`; o cartão contém um indicador de status canônico que é
literalmente um `LayoutBuilder`. `IntrinsicHeight` pergunta dimensões
intrínsecas, `LayoutBuilder` não sabe responder, e a asserção dispara.

**E alcançava produção.** O repositório de Segurança infantil é composto real, a
rota produtiva monta a mesma página, e o modo de exibição padrão é cartões —
bastava existir um registro para a tela quebrar no primeiro carregamento. Não era
protótipo com defeito: era MVP, com repositório de produção ligado, **sobre dados
de criança**.

**A correção** trocou o `IntrinsicHeight` por uma composição de tabela com
alinhamento vertical intrínseco, e deixou no código o comentário explicando a
causa — o que impede a próxima pessoa de reintroduzir o padrão.

**A verificação, feita por outra frente sobre a base entregue:** a mesma página
montada em 1440, 1024, 768 e 375 renderiza **onze cartões em cada largura e zero
exceção de layout**. E não é verde vazio: os cartões foram **contados antes** de
ler as exceções, justamente porque uma grade vazia não exercita o defeito e
produziria um verde que não prova nada.

Limite declarado dessa verificação: ela usou o controlador de desenvolvimento, e
não a rota de produção com o repositório real. A correção é estrutural e não
depende de dados, então vale para as duas — mas a prova sobre a rota produtiva
não foi feita.

**Uma consequência que muda de categoria junto.** A acessibilidade desta tela
estava registrada como *não medida*, e o motivo era que a asserção de layout
disparava durante o `performLayout`, antes de qualquer avaliação — a árvore
continuava marcada como precisando de layout, então a semântica avaliada em cima
dela não representava a tela. **Com a correção, ela deixou de ser impossível de
medir e passou a ser apenas ainda não medida.** São coisas diferentes: a primeira
pedia consertar antes; a segunda pede apenas medir.

**Fica registrada a segunda correção possível**, que não foi feita: tirar o
`LayoutBuilder` do indicador compartilhado resolveria para todo consumidor, mas
mexe no Design System e move referências visuais de outras telas. **Qualquer tela
que um dia envolver esse indicador em `IntrinsicHeight` cai no mesmo buraco** — e
o censo desta rodada encontrou uma tela com o padrão idêntico, hoje segura apenas
porque usa um indicador próprio.

E o que isto fechou continua valendo como método: as três observações iniciais
sobre a tela — transborda, falha nas três diretrizes, fica presa carregando — eram
**três sintomas da mesma causa**, e a causa era uma linha.

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

## O censo de `IntrinsicHeight`, recontado

**A primeira versão deste censo contava quatro usos e estava errada nos dois
sentidos** — contava a mais e a menos. Contava como uso duas ocorrências que são
**comentários**, deixados por quem já havia convertido aquelas telas; e deixava de
fora um uso real. Provável causa: uma busca por texto, que não distingue código de
comentário. Recontado, há **três** usos:

- **`errors` é seguro**: envolve apenas texto e um divisor vertical.
- **`people` é armadilha armada**: tem o padrão idêntico ao que quebrou, e só não
  quebra porque o cartão de lá usa um indicador próprio em vez do canônico. No dia
  em que alguém padronizar o indicador, quebra na hora.
- **`principal_for_you` é a segunda armadilha armada**, e não estava no censo. Ali
  o `LayoutBuilder` é **pai** e não descendente, então o arranjo perigoso não se
  forma — o defeito é `IntrinsicHeight` com `LayoutBuilder` na subárvore, porque é
  a subárvore que ele interroga. Está seguro hoje **por medição, não por
  dedução**: as referências visuais e o teste responsivo exercitam aquele herói em
  quatro larguras e a 200% de escala, e a asserção não dispara. Mas entra na mesma
  lista pelo mesmo motivo de `people`: no dia em que aquele conteúdo passar a
  incluir o indicador canônico, quebra.

**E duas telas já bateram no defeito e resolveram do mesmo jeito** — ambas
trocando `IntrinsicHeight` por uma composição de tabela com alinhamento vertical
intrínseco, e ambas deixando o comentário que explica a causa. Isso **fortalece** o
argumento de tirar o `LayoutBuilder` do componente compartilhado, em vez de
enfraquecê-lo: não é uma tela azarada, é um padrão que já cobrou duas vezes e tem
duas armadilhas armadas esperando a terceira.

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

    **O custo não é uniforme entre as três, e isso decide se o patch entra num
    movimento ou em dois:** três asserções em Acontece e Agora fixam a frase e
    precisam ser atualizadas junto — trocar a mensagem sem trocá-las deixa três
    vermelhos. **Momentos não tem teste que espere a frase**, então lá a troca não
    quebra nada e pode ir primeiro.

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

    **Verificado depois de esta seção ser escrita, e confirmado:** a
    implementação duplicada das abas tem zero consumidores no código de produção,
    e seus dois testes — incluindo a referência visual — passam, 19 de 19. É
    exatamente o caso descrito: implementação pública, com nome canônico,
    protegida por um golden verde, e inerte.

    **E há um risco de execução que vale nomear junto:** o componente morto vive
    no arquivo de uma frente e o vivo no de outra. **Dono ambíguo foi o que deixou
    parados, nesta rodada, o alvo de toque pequeno, a deriva de cabeçalho e o
    ícone que sumiu** — três achados reais que ninguém assumiu porque nenhum
    pertencia claramente a alguém. Se a resposta vier, ela precisa nomear quem
    executa, ou volta órfã.

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
- **O envio de resposta de formulário trata simultaneidade melhor do que o chat
  tratava** — e o chat foi corrigido nesta rodada exatamente nessa classe. Uma
  frente foi procurar ali o defeito espelho do que tinha acabado de corrigir e
  encontrou a solução superior: o envio retém o comando pendente **e** a revisão
  das respostas juntos, então uma repetição após falha completa a intenção
  original sem trocar o conteúdo no meio, e depois avisa que há alterações locais
  não salvas. Não sobrescreve a edição da pessoa com o eco do servidor, e não
  finge ter salvo o que não salvou.
- **O caminho de mídia de Circular é seguro contra repetição nos três elos:** a
  chave do upload é estável e vem do próprio arquivo, o preparo devolve o ativo
  existente em vez de criar outro, o finalize é idempotente pelo estado do ativo,
  e o controlador recusa identificador repetido. Uma falha no meio do fluxo e uma
  nova tentativa não produzem anexo duplicado.
- **Zero divergência de nome de parâmetro nas 80 chamadas de RPC do app.** O
  pacote de banco já tem teste próprio de nomes de argumento — sinal de que essa
  classe já cobrou preço antes — e hoje está limpa.
- **Nenhum texto de erro do servidor vaza para a interface** nas cinco famílias
  varridas. Os pontos que pareciam suspeitos não são: um usa o nome do tipo e não
  a mensagem, e outro transforma a mensagem crua em código de falha que nenhuma
  tela renderiza.
- **Os 16 formulários de criação não transbordam** em 375 e 1440, a 100% e 200%
  de escala: 64 casos, zero exceções. Isso localiza os transbordamentos desta
  rodada em telas de diretório e lista, e poupa a próxima varredura.
- **Nenhum comando de domínio ficou sem qualquer referência em teste** depois que
  a última lacuna foi fechada: 149 métodos verificados, zero órfãos.
- **Não há repositório de produção implementado duas vezes** em Rotina,
  Acompanhamento e Crianças, com produção usando o outro — o padrão que existe em
  Assiduidade não se repete ali.
- **O relógio de medicação não diverge** entre o diretório e a ficha, apesar de
  uma usar formatação crua e a outra depender de locale: sob português do Brasil
  as duas devolvem o mesmo valor. Era uma hipótese boa, da mesma família de três
  defeitos reais desta rodada, e a correção teria sido de problema inexistente.

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

**Duas lacunas do processo de integração desta rodada, encontradas por
conferência externa e registradas para a próxima.** Eu fui o único integrador e o
único escritor do inventário e dos rastreadores, o que significa que ninguém
conferia o integrador. Duas frentes foram encarregadas de conferir, e acharam:

- **O gate de integração não pega arquivo de teste sobrescrito.** Eu rodo a suíte
  e comparo o total; quatro casos a menos em sete mil não aparecem. Uma frente
  criou um teste com o nome de um arquivo existente, substituiu quatro casos que
  passavam por dois seus, e **a suíte continuou verde**. O que pegou foi
  aritmética por arquivo — 223 antes, dois acrescentados, 221 depois — e foi
  hábito dela, não do processo.
- **O gate inspeciona merges com resolução e não inspeciona auto-merges.** São
  riscos diferentes: o primeiro arrisca escolher o lado errado; o segundo arrisca
  os dois lados tocarem linhas próximas e não sobrepostas, e o resultado ser
  sintaticamente válido e semanticamente errado. **Nenhum diff combinado mostra o
  segundo** — só leitura mostra. Os quatro merges com resolução da rodada foram
  inspecionados; os demais, não.

**A primeira lacuna foi fechada com uma varredura própria, e o resultado é uma
linha de garantia que antes não existia:** comparando a base pré-rodada com a base
entregue, **187 arquivos de teste foram tocados, 100 adicionados, nenhum deletado,
nenhum renomeado, e dos 87 modificados 48 ganharam casos, 39 mantiveram e
nenhum perdeu.** O instrumento foi validado antes de ser confiado — um detector
que sempre responde "limpo" não vale nada, e este discrimina, com 148 arquivos de
delta positivo.

E a varredura fechou uma lacuna que eu não havia pedido: **contagem igual não
prova conteúdo igual.** Nos 39 arquivos de contagem estável, cinco tinham nomes
de caso diferentes. Os cinco foram abertos: quatro são renomeações acompanhando
mudança deliberada — inclusive a asserção de fronteira que mudou porque o
contrato mudou — e o quinto é falso positivo do extrator, um caso parametrizado
cujo nome deixou de ser literal.

**O buraco que permanece, declarado em vez de omitido:** um teste cujo *corpo*
foi esvaziado mantendo nome e contagem não é detectado por nada disto. Fechar
isso exigiria contar asserções por caso em vez de casos por arquivo.

Três verificações fecharam o que era verificável: nenhum commit publicado por
frente ficou fora da base — conferido commit a commit nos 2305 das sete branches;
os 762 goldens da base pré-rodada continuam 762; e nenhum arquivo de coordenação
teve seu número de revisão diminuído entre commits, que é o único detector de
cópia velha sobrescrevendo nova em documentação. **Esse detector só funciona onde
há contador monotônico**, então relatório, evidência e artigo de conhecimento
permanecem sem auditoria dessa classe — declarado aqui em vez de omitido.

**Uma ferramenta que responde outra pergunta é indistinguível de uma medição.**
Esta classe apareceu quatro vezes, e três delas quase produziram decisão errada:

- Uma varredura de "capacidade sem consumidor" que só enxergava o que estava
  **declarado na interface** escondia um método público existente só na
  implementação; outra, que só contava referências em **outro arquivo**,
  inventava cinco capacidades mortas — uma delas o tipo que faz cumprir limite de
  plano por vídeo. Erros em direções opostas, mesma causa: "consumidor" nunca foi
  definido.
- "Essa branch tem *upstream*?" e "esse trabalho está *preservado*?" parecem a
  mesma pergunta. A primeira marcaria três branches íntegras como trabalho em
  risco. O critério correto é conteúdo alcançável a partir de qualquer referência
  remota.
- Um caminho de golden longo faz a mensagem quebrar em duas linhas, e um `grep`
  de linha única devolve `Pixel test failed,` **sem percentual**.
- O resumo do runner trunca a lista de falhas e escreve "e mais 19", e o reporter
  expandido imprime o teste **em execução**, não todos: uma frente extraiu 34 de
  105 nomes acreditando ter o inventário. **Log não é inventário — os dois
  parecem listagem e são amostra.**
- E a mais fina: um arquivo de relatório em JSON parseado **antes do evento de
  encerramento** é JSON válido, com todas as linhas corretas, e devolve um total
  errado, porque o processo ainda escrevia. **Arquivo completo e arquivo pronto
  são coisas diferentes.**
- E o relógio: `date` com `TZ=America/Sao_Paulo` dentro do Git Bash devolve UTC,
  porque não há base de fusos ali. Três horas a mais, com aparência de leitura
  local. Isso quase encerrou a rodada **uma hora e quarenta antes do horário
  combinado**, com três frentes ainda trabalhando.

**Aviso de leitura sobre os carimbos de hora desta rodada.** A deriva de fuso
descrita acima não ficou só nas conversas: **ela foi gravada** no campo de data de
várias revisões dos arquivos de coordenação, algumas com até uma hora e vinte de
adiantamento. Uma entrega registrada como 03:35 foi escrita antes das 02:00.
Quem reconstruir a linha do tempo por esses carimbos concluirá que frentes
entregaram depois do congelamento; **não entregaram**. Os carimbos não foram
reescritos de propósito — corrigir registro passado para ficar coerente é o mesmo
tipo de coisa que se recusou a fazer com o histórico de commits. A deriva fica
declarada aqui, uma vez, para quem ler saber descontar.

E há uma **segunda** deriva, de outra natureza e com outro conserto. A primeira é
de ferramenta e produz erro constante e detectável — três horas exatas, sempre.
A segunda é humana: ler o relógio uma vez e depois **estimar** os carimbos
seguintes, empurrando o horário para a frente a cada mensagem. **Aconteceu com
três frentes e comigo.** Uma acumulou quarenta minutos e se corrigiu sozinha;
outra corrigiu os próprios carimbos no arquivo; e **eu acumulei trinta e sete
minutos**, depois de ter registrado a correção das outras duas e ter mandado uma
delas parar de se desculpar por isso. Fui pego por uma frente que mediu e
comparou.

**No meu caso a consequência é de outra ordem**, e é por isso que está aqui: quem
chama o congelamento e a entrega sou eu. Com trinta e sete minutos de
adiantamento, eu teria encerrado a rodada às 04:03 reais acreditando que eram
04:40 — **cortando mais de meia hora de trabalho de seis frentes**, e pela mesma
falha que quase me fez encerrá-la uma hora e quarenta cedo pelo caminho da
ferramenta.

**Erro de ferramenta se conserta trocando o comando; erro de estimativa só se
conserta lendo antes de escrever** — e ele cresce, o que o torna mais plausível
quanto pior fica.

**E ele é uma classe à parte das outras três armadilhas de instrumento desta
rodada, e é pior.** Nos outros casos — o fuso sem base de dados, a pergunta
trocada sobre publicação, a mensagem cortada por quebra de linha — a ferramenta
estava sendo usada e devolvia número errado para a pergunta certa. Aqui **a
ferramenta estava disponível, correta, e ninguém perguntou**. Nenhuma verificação
de instrumento pega isso: só medir de novo pega.

**A lição operacional que fecha o assunto**, e ela veio de quem cometeu o erro
três vezes: a regra "hora só medida" pegou onde a leitura virou **comando** — no
script que escreve o registro — e não pegou onde ainda se digita, que são as
mensagens. **Regra que depende de disciplina no momento da escrita não pega; a que
vira comando pega.**

**Mensagem não é registro.** Duas frentes descobriram, perto do fim, que trabalho
real delas existia apenas nas mensagens trocadas com a coordenação: uma
amostragem de goldens de cinco famílias, num caso, e um handoff de 27 revisões
que existia como modificação não commitada, no outro. Nenhum dos dois estava
perdido — mas nenhum dos dois estava salvo pelo caminho que seus autores
acreditavam. **Um artefato só está entregue quando existe no destino que o leitor
abre**, e o canal de coordenação não é esse destino.

E um terceiro caso, mandado conferir e encontrado em tempo real, explica **por
que** isso acontece de forma sistemática. A frente conferiu item a item e achou
que tudo o que ela havia produzido estava no arquivo — exceto as **duas
auditorias que ela tinha acabado de fazer para a coordenação**, que viviam apenas
nas mensagens. O padrão que ela nomeou: *registro o que pareço dono; conferência
parece pertencer a quem pediu*. Ela escrevia no próprio arquivo antes de reportar
enquanto o trabalho era dela, e parou de escrever exatamente quando o trabalho
virou verificação para outro — que é justamente o trabalho que o outro não tem
como refazer sozinho.

## Uma proposta de processo para os goldens, e ela é nova — não é o que a casa faz

O dilema que a triagem expôs é real: **regravar apaga a referência anterior, e não
regravar deixa a suíte vermelha**. Nos casos de Instituições e de Conta isso ficou
concreto — regravar carimba, como estado aprovado, uma perda de cobertura num caso
e a ausência de uma afordância no outro.

A saída natural é não substituir: **criar a próxima versão da referência e manter a
anterior**, de modo que a comparação entre versões mostre o que mudou e quando.
Isso dissolve o dilema, porque a referência antiga deixa de ser algo que se perde
ao aprovar a nova.

**Três famílias parecem já fazer isso**, com sufixos de versão nos nomes dos
arquivos de golden. Fui verificar antes de recomendar como prática existente, e
**não é.** Não há documento, spec ou nota de design que defina o esquema; os
sufixos aparecem apenas dentro de três arquivos de teste, como texto fixo. Os
números não correspondem às specs das famílias que os carregam. E o decisivo:
**nenhuma versão jamais subiu.** Um dos arquivos foi criado uma vez e
**sobrescrito no lugar** duas vezes, sempre com o mesmo nome; e o caso que mais
parecia incremental entrou no repositório já com o número final, sem que a versão
anterior tivesse existido.

Portanto: **a proposta é nova.** O sufixo existente é, na melhor hipótese,
evidência de que alguém teve a mesma intuição e não a levou adiante. Recomendá-la
como prática da casa afirmaria que um problema já está resolvido quando não está —
e essa afirmação, num relatório de estado, é pior que a ausência da recomendação.

## A dívida de formatação está no lugar oposto ao que o número sugere

Um censo mediu 41 arquivos com formatação de data escrita à mão, e a leitura
natural — "41 cópias da mesma regra, unifique" — está errada. O detalhamento
inverte a decisão:

- **`dd/MM/aaaa` aparece em 19 arquivos e é consistente.** Sozinho não é dívida, é
  convenção repetida. Um passe que "unificasse" isso mexeria em 19 arquivos para
  padronizar o que já está padronizado, com risco proporcional e ganho nenhum.
- **`aaaa-MM-dd` aparece em 9 arquivos e é formato de fio**, em DTOs e chaves.
  Propósito legitimamente diferente, e **não deve** ser unificado com o anterior.
- **A divergência real está na data com hora, em três separadores diferentes** —
  um ponto médio, um "às", e a forma longa por extenso — espalhados por cinco
  arquivos. E um único componente compartilhado contém **duas** dessas formas.

**A recomendação é o passe pequeno:** cinco pontos de data com hora resolvem a
divergência que uma pessoa consegue ver na tela, com risco muito menor que os 19.

E a dívida não é teórica: **três das correções de leitura desta rodada saíram
exatamente dela** — dinheiro formatado numa tela e cru na outra, data com zeros
num lugar e sem zeros no outro, e escolha exibida por identificador interno em
vez de rótulo. Cada uma existia porque a mesma regra de apresentação estava
escrita duas vezes e as duas cópias envelheceram diferente. O custo aparece do
jeito mais caro: não quebra teste, não quebra build, só mostra o mesmo dado de
dois jeitos para a pessoa.

Ressalva do método, que a própria frente declarou: o censo conta **literais, não
intenções**. Parte das formas distintas são fragmentos do mesmo formato quebrado
em várias linhas, e foram descontados à mão.

## Por que o escritor único precisou de conferentes

Fui o único integrador de `dev` e o único escritor do inventário e dos três
rastreadores — o que dá consistência e cria um ponto cego: **ninguém confere o
integrador.** Duas frentes foram encarregadas de me conferir, e o resultado
justifica a decisão. **Quatro afirmações minhas foram derrubadas antes de
chegarem a você:**

1. **A contagem de vermelhos propositais.** Eu contava dois e havia um: o antigo
   ficou verde durante a noite e eu continuava classificando-o pela categoria
   antiga. Se tivesse chegado assim, **um defeito real passaria por convenção.**
2. **O falso alarme de rota chamando o backend sem capacidade.** Li o código,
   achei a cadeia, escalei como prioridade um, reservei um arquivo e mandei uma
   frente corrigir. Um teste mais novo afirma exatamente aquela chamada como o
   contrato, e passa. Nada esteve em risco.
3. **A premissa de que o produto estava dividido sobre a cópia de prévia.** Eu
   havia lido uma string sem a asserção em volta, que dizia o oposto.
4. **A recomendação de um esquema de golden versionado como prática existente.**
   Nenhuma versão jamais subiu; o sufixo é nome, não processo.

As quatro vieram de alguém verificando o que eu afirmei em vez de aceitar, e três
delas eu tinha ferramenta para checar sozinho e não usei. **O padrão é o mesmo
que a rodada catalogou nas frentes:** informação que parece verificada porque veio
escrita — inclusive quando quem escreveu fui eu.

## O que cada frente entregou

Seis frentes Claude trabalharam da meia-noite ao corte, em worktrees isoladas,
integradas continuamente por revisão mais verificação na base conjunta.

**Estrutura e operações do sistema.** Fechou as cinco falhas não-golden da própria
área, todas pela mesma causa — um toque de teste que não garantia visibilidade do
rodapé — e produziu o censo preventivo dessa forma no app inteiro sem tocá-la.
Projetou o contrato de escrita de repositório como artigo, nomeando o arquivo que
já fazia tudo certo como referência, e ao aplicar o próprio checklist achou mais
dois defeitos em arquivos que já havia lido duas vezes. E escreveu o teste de
contrato de RPC que ninguém tinha: 80 chamadas contra 383 funções declaradas.

**Formulários e cuidado.** Treze lotes, e **nove defeitos encontrados relendo o
próprio diff já publicado** — nenhum deles pego pelos testes que a própria frente
havia escrito. Fechou a última divergência de leitura entre superfícies, cobriu um
componente que seis telas usam e nenhuma prova tocava, e desfez duas hipóteses
próprias por medição antes de corrigir problema inexistente. Três das próprias
linhas de bloqueio caíram no reteste.

**Publicações e mídia.** Revisou os seis candidatos SQL da plataforma, achou e
corrigiu um vazamento de existência em um deles, deixou dois ramos de R2 prontos e
retidos, e varreu nove dimensões do próprio recorte registrando o resultado de
cada uma. Encontrou **um bloqueio declarado que não era real** — o contrato que
outra frente esperava já existia, aplicado, e era dela.

**Chat e comunicações.** Corrigiu a preservação do que o leitor carregou usando o
cursor do servidor como limite, depois que o caso adversarial derrubou o desenho
anterior. Aplicou a própria lente como diagnóstico em três frentes vizinhas sem
tocar em arquivo alheio, e escreveu o teste vermelho que nomeia a lacuna de
paginação do feed misto. Fez a conferência externa da integração e me corrigiu
duas vezes.

**Alunos e rotina.** Levou o próprio recorte a verde e recuperou Segurança
infantil de 27 para 170 casos, com uma tela que não se dispunha em produção
voltando a se dispor. Amostrou seis famílias de golden abrindo referência e
captura lado a lado, o que produziu a triagem que muda a decisão de rebaseline. E
varreu o app inteiro atrás de arquivo de teste que tivesse perdido casos.

**Perfil e Para Você.** Integrou a composição herdada sobre a base conjunta,
resolvendo cinco conflitos, e com isso **tirou três telas do Principal do estado
fechado**. Ligou a leitura do Sobre a uma RPC autorizada, com um caminho de
contingência que nunca confunde negação com ausência, e conectou a aba de Momentos
à projeção autorizada, fechando uma pendência herdada de que outras dependiam. Dez
defeitos corrigidos com controle negativo, entre eles a saudação que chamava todo
usuário real pelo nome de um fixture, um diálogo que se fechava sozinho a cada
reconstrução, e conteúdo autorizado para outro vínculo permanecendo na tela depois
da troca de contexto.

Além do próprio recorte, foi a frente que mais serviu às outras: verificou a fila
SQL inteira na versão de produção do Postgres, mediu onde a cadeia de migrations
para de replayar, encontrou os 40 objetos chamados e nunca criados, fez o reteste
externo das linhas de bloqueio de duas frentes, triou três pares de referência
visual — e uma dessas triagens terminou no botão de reportar bug que não existe em
produção.

**Duas leituras honestas sobre este conjunto.** A primeira: a maior parte do valor
da noite não veio de código escrito, veio de **medição que desfez conclusões** —
minhas e das frentes. A segunda: cada frente encontrou defeitos no próprio
trabalho recente que os próprios testes não pegavam, e o método que os achou foi
sempre o mesmo — reler o que já foi entregue, com três perguntas: o que isso faz
com mais de um item, o que acontece com duas coisas ao mesmo tempo, e o teste
mede o efeito ou o mecanismo.

## A bateria de mutação, e a ressalva que impede o número de vender demais

Uma frente quebrou de propósito, uma a uma, as guardas que havia escrito, para ver
cada teste falhar. **Nove mutações: sete pegas, uma lacuna real, uma inconclusiva.**

As sete que caíram — faixa numérica desligada, guarda de tamanho de texto
desligada, dinheiro deixando de virar centavos, seletor de data ignorando o
intervalo autorado, intervalo invertido deixando de ser recusado, rótulo de
escolha voltando a exibir o identificador interno, e o mapeamento de falha de
transporte — são a prova de que aquelas guardas protegem o que dizem proteger.

**A lacuna real é a mais instrutiva:** baixar de mil para novecentos e noventa e
nove um limite espelhado do servidor **não derrubava nada**. Número espelhado sem
afirmação é número que ninguém percebe mudar — e ele estava no mesmo arquivo dos
padrões que a frente acabara de fixar, sem que ela tivesse reparado no vizinho
descoberto. Fechada, junto com a contagem por pontos de código: trocar a contagem
de caracteres passava batido e recusaria mil emojis que o servidor aceita.

**E a ressalva, que a própria frente exigiu que fosse junto:** mutação responde
apenas "**este arquivo de teste** protege esta linha". Um "não pegou" é ambíguo
entre lacuna real e mira errada — e aconteceu: uma mutação foi reportada como não
pega e a regra estava coberta, em outro arquivo. Apontada para o arquivo certo, a
mutação cai. **O placar vale como evidência de que as guardas estão protegidas;
não vale como medida de cobertura.** A pergunta que desambigua é sempre a mesma:
antes de acreditar no veredito, onde essa regra *deveria* estar coberta?

A inconclusiva ficou inconclusiva de propósito, porque a âncora aparecia duas
vezes e mutar as duas mudaria o significado do teste — **não contar como pega o
que não foi medido** é o que mantém o placar utilizável.

## A classe que este relatório mais teve foi tempo verbal

Este documento foi relido de ponta a ponta por uma frente que não o escreveu, com
a mesma pergunta que a rodada aplicou às linhas de bloqueio: **qual é a fonte, e a
fonte diz isso?** Cinco correções saíram, e estão todas aplicadas acima.

**Quatro das cinco são a mesma classe, e não é número errado — é tempo verbal.**
Afirmações escritas cedo, verdadeiras sobre o mundo de quando foram escritas e
falsas sobre o mundo agora. A pior delas descrevia em presente, na seção que o
próprio documento chama de defeito mais grave, um problema **corrigido às 23:35 e
integrado horas antes** — e teria feito você priorizar um trabalho já feito.

Não é descuido: é o custo previsível de um documento que cresce por acréscimo
durante uma noite em que o código muda debaixo dele.

**A prática que sai disso, para a próxima rodada:** seções que afirmam **estado** —
o que existe, o que quebra, o que está atribuído — carregam o SHA da base em que
foram medidas, como as medições de suíte já carregam. A defasagem fica visível sem
depender de alguém reler tudo no fim. Seções que afirmam **método** ou **decisão**
não precisam, porque não envelhecem.

**A quinta correção era de outra natureza e vale por si:** uma afirmação de
cobertura — "zero divergência nas 80 chamadas" — quando o instrumento examina no
máximo 75, porque pula toda chamada cuja assinatura não existe. E as que ele pula
são exatamente as que mais poderiam divergir. O teste estava certo; a transcrição
para cá é que perdeu a ressalva do instrumento.

## Um cardápio encerrado aparecia como rascunho, e nada falhava

**Corrigido nesta rodada**, e é o segundo defeito de produto visível ao operador
que a noite encontrou.

**A pergunta que ninguém fazia:** nenhum teste confere se os valores que uma
coluna do banco aceita são os que o enum do cliente sabe mapear. É o mesmo desenho
do contrato de RPC — a carga de teste é escrita à mão e só contém os valores que o
cliente já conhece, então **o valor desconhecido nunca aparece**.

**O defeito, nas duas direções.** Na leitura, o banco grava `closed` e o cliente
só conhecia `ended`: o valor não casava com ramo nenhum e caía no padrão de
rascunho. **Rótulo de rascunho, cor de rascunho e filtro de rascunho para um
cardápio encerrado.** No filtro, o cliente enviava `ended`, um valor que a coluna
nunca contém, então **filtrar por Encerrado devolvia lista vazia** em vez dos
planos encerrados. Nada falhava em lugar nenhum.

As duas consequências são de operação: o operador vê um estado que o plano não
tem — e pode editar ou republicar um cardápio encerrado acreditando ser rascunho —
e quem procura os encerrados conclui que não existem.

Corrigido com uma conversão única usada pelos dois lados, com controle negativo
nos dois casos. **E o que não foi corrigido ficou declarado em teste:** valor
desconhecido continua caindo em rascunho, porque transformar desconhecido em
exceção derrubaria a listagem inteira por causa de uma linha — que é exatamente o
modo de falha de outra família, e não se traz isso para cá sem decisão.

**A varredura ampla que a classe gerou encontrou um defeito real no aplicativo
inteiro, e ele estava no recorte de quem varreu.** Os outros pares suspeitos são
falsos positivos previsíveis: enums quase iguais do mesmo domínio se cruzando, e
domínios diferentes com o mesmo vocabulário.

**E o instrumento foi corrigido em público no meio do caminho:** a primeira versão
lia apenas o corpo da criação da tabela e ignorava as restrições acrescentadas
depois por alteração, o que subcontava — 82 colunas viraram 93. Foi descoberto por
um caso escrito esperando falhar, que passou. **Restrição de coluna também muda
por alteração, e medir só a criação subconta.**

## Cobertura ausente contada como falha some no meio das falhas

Uma frente vinha reportando, a noite inteira, o número da suíte "das oito famílias
que encostei". Duas dessas oito **nunca entraram na conta**: os caminhos passados
ao executor estavam no singular e os diretórios existem no plural, e o executor
**contou cada caminho inexistente como uma falha** em vez de avisar que o caminho
estava errado.

O texto exato era "falhou ao carregar — não existe", e ele ficou escondido no
meio de dezesseis falhas, das quais catorze eram reais e conhecidas de outras
frentes. **Se as catorze fossem zero, duas falhas isoladas teriam sido
investigadas na hora. Foi a companhia que as escondeu.**

E a consequência é maior que o número: **cobertura ausente contada como falha é
pior que contada como zero**, porque zero chama atenção e um a mais numa lista de
falhas conhecidas não chama. A frente suspendeu as próprias afirmações anteriores
de linha de base até remedir com os nomes corretos — que é a resposta certa, já
que não dá para saber de memória quais execuções usaram o nome certo.

**Remedido, o tamanho apareceu: 512 casos nunca entravam em conta nenhuma, e eles
escondiam oito falhas reais.** Com os caminhos corretos, aquelas famílias dão 1091
casos que passam contra 579 antes. As oito falhas não são regressão — são
referências visuais de outra família, já documentadas pela frente dona no mesmo
dia, e a contagem independente reproduz a dela. **Mas ninguém podia saber, porque
ninguém as via.**

**E a regra que sai disso vale para toda medição desta rodada:** um número de suíte
só significa alguma coisa junto da **lista de caminhos que o produziu**. Total sem
denominador não é verificável — nem por outra pessoa, nem pelo próprio autor uma
hora depois. Passou a ser exigência da entrega.

**Há um agravante estrutural que a rodada criou sem perceber:** conviver com
vermelho conhecido de outra frente é razoável e foi a prática da noite inteira —
e cria um esconderijo de graça. **Ruído conhecido é um bom lugar para uma falha
nova se perder.** Foi o mesmo mecanismo que quase deixou passar quatro casos de
teste apagados no meio de sete mil.

## Uma pergunta sobre distribuição de formulário, e ela é sua

O diálogo de agendamento de Formulários monta a aplicação com **exatamente uma
regra de público**, reaproveitando apenas o identificador da primeira que existia.
E o servidor, ao salvar, **apaga todas as regras da aplicação e reinsere a partir
do que recebeu** — confirmado nas três migrations que reescrevem essa função.

Somando: abrir o diálogo numa aplicação com mais de uma regra de público e salvar
**apaga todas menos a primeira, sem aviso e sem erro**.

**Alcance, com a mesma precisão exigida em toda parte:** o único escritor de regras
no Superadmin é esse diálogo, e ele escreve uma. Então, por esta superfície, a
aplicação nunca chega a ter duas. O estado perigoso só existe se as regras vierem
de carga inicial, migration ou outro caminho.

**E a correção óbvia não é livre de decisão — por isso não foi feita.** Preservar
as demais regras faria o formulário **chegar a mais gente do que a tela mostra**.
Trocar apagar em silêncio por ampliar em silêncio é escolher qual dos dois males, e
isso é decisão de produto sobre **quem recebe formulário**.

A pergunta, portanto: **quando uma aplicação tem várias regras de público, o
diálogo edita qual, e o que acontece com as demais?**

Registrado junto, como lacuna latente e não como defeito: três limites do servidor
— cinquenta regras de público, três lembretes e vinte agendamentos ativos por
aplicação — não estão espelhados no cliente. Nenhum é violável hoje, porque o
diálogo cria uma regra e um agendamento, e **lembrete não tem nenhuma tela que o
referencie**, apesar de existir no domínio e na API.

## Ler não pega; seguir pega

Perto do fim, uma frente aplicou aos próprios documentos a pergunta que vinha
aplicando ao código: **o leitor que seguir o ponteiro chega em algum lugar?** Não
releu — extraiu cada hash e cada caminho citado e testou existência. Achou dois
defeitos que sobreviveram a várias releituras:

- **Um identificador de commit que nunca existiu**, um marcador provisório digitado
  enquanto o lote estava aberto e nunca substituído. Estava justamente na única
  linha de correção de acessibilidade da tabela — a linha em que alguém de fato
  iria olhar.
- **Catorze referências a arquivos que não existem mais**, porque a serialização da
  fila renomeou os candidatos e o documento continuava citando os carimbos
  originais.

E o segundo caso quase virou um erro pior. A frente ia corrigir tudo como erro de
digitação. **O que a segurou foi a tabela da fila mostrar os dois carimbos lado a
lado**, sob o cabeçalho "arquivo final / carimbo original": era renomeação
deliberada, não descuido. Se ali estivesse registrado apenas o nome final, uma
decisão de coordenação teria sido "consertada" de volta, com boa-fé e com método.

**A lição de registro que sai disso:** anotar a decisão *e* o estado anterior, lado
a lado, é o que impede outra pessoa de desfazer a decisão. **Só o estado final não
carrega a informação de que houve escolha.**

A verificação foi repassada às demais frentes — custa segundos e não exige contexto
— e aplicada também aos documentos desta coordenação, que saíram limpos. Os
alarmes iniciais eram prefixos de checksum, identificadores de sessão, caminhos
citados por nome-base, e duas revisões de framework que pertencem a outro
repositório e nunca resolveriam neste.

**E há uma variante da mesma classe, encontrada por outra frente auditando o
próprio arquivo: registro publicado que foi destruído por reescrita.** A lista dos
próprios erros existia havia dez revisões, dentro de um bloco que foi reescrito
inteiro para consolidar a pré-entrega, e foi junto — sem que ninguém notasse,
inclusive quem a escreveu. **A correção certa não foi restaurar o conteúdo, foi
mudar o lugar:** dado durável guardado dentro de um bloco que se reescreve inteiro
é o defeito, e restaurá-lo sem mover seria consertar o sintoma.

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
a referência aprovada do Perfil (item 0, uma resposta binária); a baseline de
`errors.409`; a cópia das três telas que se chamam de prévia — com patch já
preparado; o véu do chip DESTAQUE, sabendo que custa treze goldens; o rebaseline
por família, com Agenda liberada e as demais não; a rota Testar de Formulários; o
contrato de Lançamentos; e se Suporte recebe camada de dados no MVP.

**O que uma única consulta autorizada resolve, e é a ação de maior retorno da
lista:** um `select proname from pg_proc` responde de uma vez pelas cinco RPCs de
Unidades, pelas cinco de Assiduidade e pelos 40 objetos `app_private` chamados e
nunca criados. Enquanto ela não for feita, três blocos inteiros de bloqueio
permanecem classificados como **falta de autorização para verificar**, e não como
ausência.

**O que nenhuma decisão resolve**, porque é ausência de implementação: Suporte
sem camada de dados — a rota de produção devolve 503 hoje, e os 61 testes verdes
exercitam um protótipo em memória; `RoutineRepository` e `StudentTrackingRepository`
recebendo repositórios indisponíveis **por composição deliberada** no ramo
autorizado; e `account.sessions` sem tela.

**Duas linhas mudaram de dono depois do reteste de bloqueios e valem repetir
aqui**, porque a versão antiga levaria a decisão errada: `health-care` e
`medication` não terem repositório de produção **não é omissão nem gate de
implantação — é o escopo aprovado**, porque a spec vigente está aprovada para
interface demonstrativa e a que criaria o contrato real é rascunho em revisão. E
a pergunta de Local em Formulários não é código pronto esperando decisão: não
existe o tipo de pergunta no domínio, então é **decida e depois construa**.

E `attendance` continua o caso mais delicado, agora com a assimetria medida: no
mesmo ramo autorizado onde Rotina e Alunos recebem indisponibilidade honesta,
Assiduidade recebe o repositório real, que chama cinco RPCs que nenhuma migration
cria. Se elas também não existirem em produção, **a tela parece pronta e quebraria
no primeiro uso**, com o erro chegando como indisponibilidade genérica.
