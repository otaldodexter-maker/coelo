---
fonte: medicao propria sobre a worktree e2-noturna-operacoes-sistema
status: medido
data: 2026-09-10
base: b1ec93103
autor: executor operacoes-sistema (Claude)
---

# Contrato RPC entre o Superadmin e o pacote de banco

## Por que esta classe nao aparece em suite verde

Todo teste de repositorio do Superadmin usa cliente falso ou intercepta o
transporte. Nenhum deles confere se o nome da RPC chamada existe no banco, nem
se os parametros enviados correspondem a assinatura declarada. Um nome errado,
um parametro renomeado numa migration posterior ou uma funcao que nunca entrou
no versionamento atravessam a suite inteira e falham apenas no primeiro uso
real, como `PGRST202` ou `undefined_function`. No cliente esse erro vira
indisponibilidade generica, que e indistinguivel de queda de rede — ou seja, a
propria UI esconde o defeito.

## Como medi

Comparei os dois lados do contrato estaticamente, sem tocar em banco remoto:

- lado cliente: toda chamada `.rpc(...)` em `apps/superadmin/lib`, com o nome e,
  quando o mapa de parametros e literal, as chaves de primeiro nivel;
- lado banco: toda `create [or replace] function` em `packages/coelo_database`,
  com os nomes dos parametros e quais tem `default`, ignorando `tests/` porque
  pgTAP cria funcoes auxiliares que nao fazem parte do contrato.

Medida: **80 chamadas, 76 nomes distintos** contra **383 funcoes** declaradas no
pacote.

## Achado 1 — cinco RPCs de Unidades nao existem em nenhuma migration do pacote

| RPC | Quem chama |
| --- | --- |
| `create_unit_for_superadmin` | `units/data/supabase_unit_directory_repository.dart` |
| `update_unit_for_superadmin` | idem |
| `get_unit_form_for_superadmin` | idem |
| `list_units_for_superadmin` | idem e `groups/data/supabase_group_directory_repository.dart` |
| `unit_directory_filter_options` | idem e `groups/data/supabase_group_directory_repository.dart` |

As outras 71 existem. Varri o repositorio inteiro, nao apenas o pacote: nenhum
`.sql` em qualquer diretorio cria essas cinco funcoes.

O que confirma que a ausencia e drift e nao descuido do meu varredor: a
migration `20260825180500_repair_unit_import_export_runtime_contract.sql`, que
esta no pacote, **chama** `app_private.create_unit_for_superadmin` de dentro do
confirmador de importacao de unidades, e o cabecalho dela diz textualmente
"Repair locally installed Unit import/export worker functions". Isto e, uma
migration versionada depende de uma funcao que o versionamento nunca cria.

Consequencia, nas duas leituras possiveis, ambas reportaveis:

1. as funcoes existem em producao instaladas fora do versionamento, e entao o
   pacote nao descreve producao e nao ha como revisar o que esta instalado; ou
2. nao existem, e entao o diretorio de Unidades e os filtros de instituicao e
   unidade de Turmas falham no primeiro uso real, fail-closed.

### Qual das duas leituras e mais provavel

Continuo sem escolher, mas a plausibilidade deixou de ser simetrica, e o dado vem
de outra frente. A hipotese "instalado fora do versionamento" e **fenomeno medido
neste repositorio**, e nao especulacao: a frente perfil-para-voce mostrou que as
tabelas `profile_about_*` existem em producao e em migration nenhuma, provado pela
RPC de escrita versionada que le e escreve nelas. Ha precedente comprovado do
mesmo padrao no mesmo pacote.

A consequencia pratica para a decisao do Owner: se a leitura benigna for a
correta, `blocked-environment` descreve a coisa certa pelo motivo errado — a
superficie funciona e o que falta e revisabilidade do que esta instalado. As duas
leituras pedem acoes opostas, e e por isso que a pergunta precisa ser respondida
antes de promover qualquer coisa.

E ela se resolve de uma vez para tres frentes: um unico `select proname from
pg_proc` responde pelas cinco RPCs de Unidades deste relatorio, pelas cinco de
Assiduidade levantadas por alunos-rotina e pelos 40 objetos `app_private` que o
SQL versionado chama e nao cria, medidos por perfil-para-voce. E leitura, nao
mutacao.

Nao e possivel decidir entre as duas daqui: a rodada decidiu nao executar
operacao remota e nao ha autorizacao nominal do Owner para leitura de producao.
Um `select` de catalogo resolveria em segundos e e exatamente o que a proxima
janela autorizada deve fazer antes de qualquer promocao de Unidades.

## Achado 2 — Cardapios chama a forma legada do delete de imagem, sem guarda de revisao

`meal_plan_request_image_delete` tem duas formas no pacote:

- `20260820171000_meal_plan_private_images.sql` cria `(p_asset_id, p_idempotency_key)`;
- `20260820230000_meal_plan_media_lifecycle_receipts.sql` cria
  `(p_asset_id, p_idempotency_key, p_expected_revision)` e mantem a forma de dois
  argumentos como compatibilidade, cujo corpo **le a revisao corrente do proprio
  banco** e repassa.

O cliente em `supabase_meal_plan_image_repository.dart:117` envia apenas
`p_asset_id` e `p_idempotency_key`. Para o banco a chamada e legitima, e por isso
nenhum teste a acusa; o efeito e que a guarda de concorrencia introduzida pela
migration de recibos **nunca roda em producao**. Uma exclusao disparada sobre uma
lista desatualizada remove a imagem que estiver corrente naquele instante, em vez
de ser recusada por divergencia de revisao.

Nao corrigi, e a razao e de contrato e nao de tempo: `MealPlanImageRepository` e
todo o dominio de imagem de Cardapios nao tem o conceito de revisao de ativo. Para
enviar `p_expected_revision` de forma honesta, a leitura de imagem precisa passar a
expor a revisao que o usuario viu. Isso muda o contrato de dominio e pertence ao
Owner do recorte de Cardapios, nao a uma correcao noturna. Inventar a revisao no
cliente, lendo-a imediatamente antes do delete, reproduziria exatamente o furo que
a guarda existe para fechar.

## Achado 3 — nenhuma chave enviada esta fora da assinatura

Zero divergencias de nome de parametro entre cliente e banco nas 80 chamadas.
Isto e resultado, nao ausencia de medida: o pacote tem teste proprio de nomes de
argumento (`access_profile_model_rpc_argument_names_test.sql`), o que mostra que a
classe ja cobrou preco antes, e hoje ela esta limpa.

Tres chamadas de Agenda montam os parametros por espalhamento
(`superadmin_agenda_save`, `superadmin_agenda_command`,
`superadmin_agenda_decide_publication`) e ficam fora da verificacao de omissao,
porque o conjunto de chaves nao e decidivel estaticamente. Estao declaradas como
tal no teste, nao silenciadas.

## O que passa a impedir a regressao

`apps/superadmin/test/contracts/rpc_contract_test.dart`, 4 PASS, roda em menos de
um segundo e sem binding de Flutter. Ele falha se alguem chamar uma RPC que o
pacote nao cria, se enviar chave fora da assinatura, se omitir parametro
obrigatorio de todas as sobrecargas, ou se o cliente ler direto por PostgREST uma
relacao que o pacote nao cria — as tres tabelas `profile_about_*` estao nessa
quarta lista, com o plano de leitura autorizada citado. As cinco ausencias do Achado 1 estao numa
lista nomeada com motivo, e o teste **tambem falha se uma delas passar a existir**
e continuar na lista — sem isso a lista envelheceria e passaria a esconder o
proximo defeito.

Controle negativo rodado nos quatro casos: removi um nome da lista e o primeiro
teste acusou `list_units_for_superadmin`; troquei `p_import_job_id` por um nome
inexistente numa chamada real e o segundo e o terceiro testes acusaram a chave
extra e a obrigatoria omitida, com arquivo e linha. Revertidos em seguida.

A verificacao de omissao usa a **intersecao** das sobrecargas declaradas, entao
acusa so a chamada que nao satisfaz nenhuma forma existente. O Achado 2 fica
deliberadamente fora do teste e dentro deste relatorio: escolher qual sobrecarga
o produto deve usar e decisao de produto, nao invariante estatica.

## Deltas propostos

| action_id | camada | estado proposto | motivo |
| --- | --- | --- | --- |
| `units.list`, `units.create`, `units.edit`, `units.filters` | backend | `blocked-environment` | cinco RPCs sem definicao no pacote; decidir entre drift e ausencia exige leitura de catalogo autorizada |
| `groups.filters` | backend | `blocked-environment` | reusa `list_units_for_superadmin` e `unit_directory_filter_options` |
| `meal-plans.image-delete` | backend | `blocked-decision` | guarda de revisao existe no banco e nao e usada; fechar exige expor revisao no dominio de imagem |
