---
title: "Pré-entrega — grupo publicacoes-midia (rodada noturna 09-10/09/2026)"
source: "Formato obrigatório de pré-entrega definido pela coordenação da rodada; itens 1 a 7, com 2b e 2c"
status: "pré-entrega; medição final concluída; campos voláteis reconferidos no congelamento"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# Pré-entrega — publicacoes-midia

Recorte: Acontece, Agora, Momentos e Circulares em `apps/superadmin`, mais a
plataforma comum de mídia que os quatro consomem.

## 1. Residual por SHA

Testado com `git merge-base --is-ancestor <sha> origin/dev`, e **não** com
`git cat-file -e`: um hash existe no object store local mesmo sem ter sido
publicado, então `cat-file` responde a outra pergunta.

Base de comparação: `origin/dev` em `2ae5b760d`, lida na mesma checagem.

| SHA | Estado |
| --- | --- |
| `b69c7d00f` | **pendente** — `docs(e2): the recorte is eight feature directories, not nine` |

Todos os demais commits do grupo são ancestrais de `origin/dev`. O único
pendente é de documentação: não toca código, migration nem edge function.

`HEAD` = `b69c7d00f`; upstream `origin/work/etapa2-noturna-publicacoes-midia`
em 0/0; worktree limpa; sem stash.

Esta seção é volátil e será reconferida no congelamento das 04:40.

## 2. Dois números de teste, com os caminhos que os produziram

Cada caminho foi verificado com teste de existência **antes** da execução, e não
depois. Isso importa porque `flutter test` não avisa caminho errado: ele conta
cada caminho inexistente como **uma falha**, indistinguível de um teste que
quebrou.

A conferência prévia já rendeu uma correção: são **oito** diretórios de feature,
não nove. Eu vinha contando `app/router` como se fosse feature na frase ao lado
do número.

### Número 1 — o recorte: 758 PASS, 26 FAIL, 784 testes

Três execuções, somadas com sobreposição declarada zero (ver 2c): a do recorte
declarado, a dos cinco arquivos que o item 2b revelou estarem fora dele, e a de
um sexto arquivo que só a varredura **por import** encontrou.

**Execução principal — 684 testes, 661 PASS, 23 FAIL.** Única, denominador
único, zero testes sem resultado. Vinte caminhos, todos existentes na
conferência prévia.

Oito diretórios de feature:

```
test/features/circulars
test/features/principal_circulars
test/features/principal_happens
test/features/principal_happens_publication
test/features/principal_moments
test/features/principal_moments_publication
test/features/principal_now
test/features/principal_now_publication
```

Doze arquivos de rota:

```
test/app/router/circular_routes_test.dart
test/app/router/principal_circular_reader_route_test.dart
test/app/router/principal_circular_reader_responsive_test.dart
test/app/router/principal_moments_feed_route_test.dart
test/app/router/principal_happens_composition_gaps_test.dart
test/app/router/principal_happens_preview_route_test.dart
test/app/router/principal_moments_publication_media_union_test.dart
test/app/router/principal_moments_publication_route_test.dart
test/app/router/principal_moments_route_states_test.dart
test/app/router/principal_now_authorization_revision_test.dart
test/app/router/principal_now_preview_route_test.dart
test/app/router/route_name_uniqueness_test.dart
```

**Complemento do item 2b — 96 testes, 96 PASS, 0 FAIL**, em cinco arquivos do
meu escopo que nunca tinham entrado em número nenhum meu:

```
apps/superadmin/test/features/principal_shared/presentation/principal_publication_frame_test.dart
packages/coelo_api/test/media/media_reader_test.dart
packages/coelo_api/test/media/media_session_test.dart
packages/coelo_api/test/media/media_upload_contract_test.dart
packages/coelo_api/test/media/media_uploader_test.dart
```

**Complemento por import — 4 testes, 1 PASS, 3 FAIL:**

```
apps/superadmin/test/app/router/principal_real_route_test.dart
```

Este arquivo é o assunto da seção 3b, e é o motivo de este documento ter sido
republicado.

Números anteriores desta noite — 636, 638, 671 e 780 — mediam conjuntos menores
que a frase ao lado deles dizia. Este substitui todos.

### Número 2 — a plataforma comum de mídia: 82 PASS, 0 FAIL

Quatro gateways Deno, medidos separadamente porque são outro runtime.
`circular-media` 27, `moments-media` 26, `happens-media` 15, `now-media` 14.

```
packages/coelo_database/supabase/functions/circular-media   (index_test.ts, media_contract_test.ts)
packages/coelo_database/supabase/functions/moments-media    (index_test.ts, migration_contract_test.ts, r2_s3_test.ts, stored_bytes_test.ts)
packages/coelo_database/supabase/functions/happens-media    (index_test.ts, r2_branch_test.ts)
packages/coelo_database/supabase/functions/now-media        (index_test.ts, r2_branch_test.ts)
```

## 2b. Existe teste do meu escopo fora da minha lista?

Sim: **seis arquivos, 100 casos**, e três deles falham.

A pergunta foi respondida duas vezes, por dois métodos, e os dois erram em
direções diferentes. Por **nome de arquivo**: 15 fora da lista, dos quais cinco
meus, 96 casos, todos verdes. Por **import**: 23 fora, incluindo um que a busca
por nome tinha perdido porque o nome não diz Acontece nem Agora —
`principal_real_route_test`, com três falhas reais.

Nenhum dos dois métodos sozinho fecha a pergunta. Nome perde quem não se
anuncia, e pega quem só se parece: `coelo_state_panel_test` entrou porque o
caminho contém `feedback`, que contém `feed`. Import pega dependência sem ser
sujeito, e por isso exige classificação por consumidor depois. O que fecha é o
segundo filtrando o primeiro.

Conferir que os caminhos declarados existem prova que a lista é **válida**, não
que é **completa**. São duas perguntas, e só a primeira tem verificação óbvia.

O método foi varrer o **repositório inteiro**, e não apenas `apps/superadmin`,
porque a fronteira da minha árvore não é a fronteira do meu escopo. Dos 91
arquivos de teste cujo nome toca o domínio, 15 caíam fora dos meus 20 caminhos.
Classifiquei por **consumidor**, e não por nome, porque nome não decide dono. Dos
15 achados por nome:

**Meus — cinco.** `PrincipalPublicationFrame` é consumido por três das minhas
páginas de publicação e pelo compositor de Circular, e vive em `principal_shared`
— a árvore de componente compartilhado. E quatro arquivos meus importam as
classes de mídia de `coelo_api`: os repositórios de publicação de Acontece e
Agora, o coordenador de upload de Circular e o host produtivo. O pacote
`coelo_api` nunca tinha entrado em número meu.

**De outras frentes — sete.** `forms_media_composition`,
`superadmin_chat_media_composition`, os três de `forms/*media*`, e
`superadmin_media_scope_test` em `test/core/config`, que importa o resolver de
export de formulários e não superfície minha.

**Fronteira — três**, dono provável `perfil-para-voce`:
`principal_profile_circulars_projection`, `principal_profile_happens_tab` e
`principal_profile_happens_tab_responsive`. Projetam features minhas, mas testam
a tela do Perfil. Inspecionei o `_Metric` do último durante a noite e não achei
overflow. Se aquela frente não os mede, ficam sem dono.

**Um falso positivo meu — um**, e da mesma família que a noite inteira ensinou:
`coelo_ui_core/test/feedback/coelo_state_panel_test.dart` entrou na varredura
porque o **caminho** contém `feedback`, que contém `feed`. Padrão largo demais
também mente, só que na direção oposta.

Dos 23 achados por import, além dos cinco já contados, um é meu —
`principal_real_route_test`, seção 3b — dezesseis são de outras frentes que
importam features minhas sem que elas sejam o sujeito do teste, e **quatro são
compartilhados que eu deliberadamente não reivindiquei**:
`principal_global_navigation`, `principal_preview_app_bar`,
`supabase_principal_runtime_context_repository` e `persistent_shell_routes`. São
a moldura Principal comum a cinco superfícies. Consumo os quatro e não sou dono
exclusivo de nenhum; adotá-los inflaria o meu número às custas da clareza sobre
quem responde por eles. Ficam registrados como **sem dono**, que é o estado
honesto.

**A direção do erro não é garantida, e no meu caso não foi benigna.** Os 96
casos dos cinco primeiros arquivos subestimavam aprovados e não escondiam nada.
Mas a varredura seguinte, por import, achou um sexto arquivo com **três falhas
reais** que nenhuma medição desta noite via. Eu havia afirmado, antes de medir
esse sexto, que no meu caso o furo só subestimava aprovados. Era falso, e a
afirmação precedia a medição que a testaria.

## 2c. Sobreposição entre os números

**Zero**, e por três razões verificadas, não presumidas:

- Entre o número 1 e o número 2: runtimes diferentes, Flutter e Deno, execuções
  diferentes. Nenhum caso pode aparecer nos dois.
- Dentro do número 1, entre as três execuções: os cinco arquivos do 2b e o sexto
  achado por import não caem sob nenhum dos 20 caminhos declarados — foi
  exatamente esse o critério que os identificou. E o sexto não está entre os
  cinco: a busca por nome nunca o tinha alcançado.
- Dentro da execução principal: os doze arquivos de rota vivem em
  `test/app/router`, fora das oito árvores de feature; foi execução única e a
  contagem é por **id de teste**, não por linha de log.

Podem ser somados no consolidado sem desconto.

## 3. As 26 falhas, uma a uma

Vinte e três de golden, mais três de rota. **Todas precedem esta rodada**, e as
duas populações têm histórias diferentes o bastante para serem separadas.

### 3a. As 23 de golden



Todas de golden, e todas dentro dos meus próprios arquivos — nenhuma é de
fronteira com outro grupo, portanto nenhuma precisa de dono provável.

**Nenhuma foi causada por esta rodada**, e isso é medido, não afirmado: rodei os
mesmos três arquivos na base pré-rodada `d784462c1`, num checkout separado, e
comparei as duas listas **nominais**, extraídas dos marcadores `[E]` e não do
resumo do `flutter`, que trunca em quatro e escreve "and 19 more". Conjuntos
idênticos, teste a teste. Não é o mesmo número de falhas — são as mesmas 23.

`circular_directory_golden_test.dart` (2)

1. directory matches the approved responsive matrix
2. directory remains usable at 200 percent text

`principal_happens_preview_golden_test.dart` (10)

3. matches Acontece at 200 percent text with reduced motion
4. matches canonical Acontece composition dark_375
5. matches canonical Acontece composition dark_768
6. matches canonical Acontece composition dark_1024
7. matches canonical Acontece composition dark_1440
8. matches canonical Acontece composition light_375
9. matches canonical Acontece composition light_768
10. matches canonical Acontece composition light_1024
11. matches canonical Acontece composition light_1440
12. matches the approved orange hover for an Agora card

`principal_moments_preview_golden_test.dart` (11)

13. matches approved Momentos composition dark_375
14. matches approved Momentos composition dark_768
15. matches approved Momentos composition dark_1024
16. matches approved Momentos composition dark_1440
17. matches approved Momentos composition light_375
18. matches approved Momentos composition light_768
19. matches approved Momentos composition light_1024
20. matches approved Momentos composition light_1440
21. matches approved Momentos composition text_200_dark_1440
22. matches approved Momentos composition text_200_light_375
23. matches the approved Coelo like hover state

Nenhum golden foi regravado, por decisão da coordenação. Portanto nenhuma das
23 está resolvida, e a **causa visual** delas não foi diagnosticada: provei que
não fui eu, não o que mudou nas imagens.

### 3b. As 3 de rota, e a retratação que elas exigem

`principal_real_route_test.dart` (3)

24. production Principal keeps its host at Size(1440.0, 900.0)
25. production Principal keeps its host at Size(390.0, 844.0)
26. real Acontece resolves authenticated context and never uses demo fixtures

**Causa, diagnosticada e não conjecturada.** `StateError: Bad state: No element`
em `tester.widget<PrincipalHappensPreviewPage>(...)`. Na rota real, com contexto
autenticado, a página do Acontece **não é encontrada na árvore**. O quarto caso
do arquivo, `real route fails closed when actor has multiple active contexts`,
**passa** — então o caminho de negação funciona e o de sucesso não monta.

**Procedência, medida nos três lugares:** falha `+1 -3` na base pré-rodada
`d784462c1`, na `origin/dev` integrada e na minha branch. Não é regressão desta
rodada nem de ninguém desta noite. Mas é do meu escopo e está na dev agora.

**A retratação.** A coordenação havia me atribuído exatamente estes três
vermelhos. Eu refutei dizendo que o arquivo "não aparece entre as 33 falhas da
base", e a atribuição foi retirada. A refutação era **vazia**: o arquivo não
aparecia naquela lista porque a medição da base **não o cobria**. Tratei
ausência de uma lista como prova de ausência do defeito, sem verificar se a
lista podia contê-lo — a mesma armadilha do "log não é inventário", mas desta
vez o custo não foi um número, e sim a retirada de uma atribuição correta.

O agravante está na ordem dos fatos: uma hora antes eu havia recuperado essa
mesma refutação do canal para arquivo, argumentando que evidência de uma
**recusa** vale mais que evidência de um achado, porque achado alguém reproduz e
recusa é palavra contra palavra. O princípio está certo e eu arquivei a
evidência errada. Uma recusa mal fundamentada e bem arquivada é pior que não
arquivada: ela deixa de ser reexaminada.

**Não corrigidas, deliberadamente.** O defeito é de composição da rota real do
Acontece. Diagnosticá-lo levou dez minutos e consertá-lo a esta altura seria
abrir frente nova às vésperas do congelamento. Entrego localizado, com causa e
com a prova de que precede a rodada.

## 4. Recursos, por lista

**Worktrees criadas ou usadas por mim — três, todas limpas:**

| Caminho | Estado |
| --- | --- |
| `Coelo.worktrees/e2-noturna-publicacoes-midia` | `b69c7d00f`, a minha, limpa |
| `%TEMP%/coelo-base-check` | `d784462c1` destacada, base pré-rodada, limpa |
| `%TEMP%/coelo-copia-previa` | `80f160599`, WIP retido, publicada, 0/0, limpa |

**Branches publicadas — duas:** `origin/work/etapa2-noturna-publicacoes-midia` e
`origin/work/etapa2-noturna-copia-previa`.

**Stash:** vazio.
**Containers:** nenhum.
**Portas abertas por mim:** nenhuma.
**Agendamentos:** nenhum.
**Processos filhos e tarefas em segundo plano:** nenhum em execução; as medições
desta pré-entrega terminaram e seus esperadores saíram.

## 5. Hora

Saída crua do comando, lida na mesma chamada em que este documento foi escrito,
e não estimada a partir de leitura anterior:

```
PS> Get-Date -Format 'yyyy-MM-dd HH:mm:ss K'
2026-09-10 03:25:56 -03:00
```

A regra existe porque eu mesmo a quebrei: as revisões 28, 29 e 30 do meu canal
saíram carimbadas 02:05, 02:20 e 02:28 quando o horário real das três estava
entre 01:40 e 02:00. Eu media o relógio uma vez e projetava os carimbos
seguintes para a frente — estimativa vestida de medição, no campo que existe
justamente para dizer quando. Os carimbos errados ficaram onde estão; reescrever
carimbo passado é a mesma espécie de apagar história que reescrever branch
publicada.

Nota de ferramenta, medida nesta máquina: no Git Bash, `date` **nu** devolve o
horário local correto (`-0300`), e forçar `TZ=America/Sao_Paulo date` devolve
UTC (`+0000`, três horas a mais) por falta de tzdata. A forma explícita é a que
mente, o que torna a correção intuitiva pior que o problema.

## 6. Citações seguidas, não relidas

Cada hash e cada caminho citado nos meus documentos foi **testado por
existência**, a partir da raiz do repositório. Isso achou três defeitos que
várias releituras não tinham achado, porque ler não segue o ponteiro:

- `b0a11y` na linha 26 da tabela de lotes — um marcador provisório que nunca
  substituí. Não é commit nenhum, e estava justamente na única correção de
  acessibilidade da tabela. Corrigido para `f989b5063`.
- catorze referências a nomes de migration que não existem mais, porque a
  serialização renumerou os seis candidatos de `2026090913xxxx` para
  `2026090921xxxx`. Corrigidas, com o mapa no topo do documento em vez de troca
  silenciosa de dígitos — quem conhece o documento pelos carimbos antigos
  precisa ver que são os mesmos seis arquivos.
- um caminho sem o prefixo `apps/superadmin/lib/features/` no **documento de
  decisão do Owner**, que não resolvia para quem copiasse. É o sétimo ponto de
  decisão, o das abas duplicadas.

A primeira versão desta conferência usava `find -name`, que responde "existe um
arquivo com esse nome em algum lugar" e não "existe **este** caminho" — a mesma
substituição de pergunta que passei a noite catalogando nas ferramentas dos
outros, rodando dentro da minha própria auditoria. O terceiro defeito só
apareceu na versão estrita.

Um ponteiro válido mas não resolvível para o leitor foi qualificado em vez de
corrigido: `3697dd49e`, a entrega autoral L01, existe em
`origin/codex/e2-r02-l01-publicacoes` e **não** na dev, então `git show` falha
para quem só tem dev. A linha agora diz onde ele está.

## 7. O que eu NÃO verifiquei

Declarado, não omitido. Escrito antes do número final, para não ser aparado por
ele.

**Banco de dados.** Nenhuma suite pgTAP foi executada. O harness sancionado não
replica a cadeia canônica: falha na 53ª migration, `20260812002010`, porque
`app_private.unit_import_source_attestations` nunca é criada. Sem banco de pé,
nenhum teste de RPC, RLS ou policy do recorte foi exercido. Os seis candidatos
SQL foram revisados linha a linha e **nunca executados em lugar nenhum** —
inclusive as correções que eu mesmo propus, como a unificação da negação em
`withdraw_happens_post`. Acesso cruzado entre tenants não foi testado em tempo
de execução; o que li foi o texto das funções, não um servidor respondendo.

**Produção e remoto.** Nenhuma mutação remota foi aplicada; nenhum pacote
nominal foi autorizado a mim. Não afirmo nada sobre comportamento em produção de
nada do recorte — onde eu havia afirmado, retratei durante a noite e a ressalva
está propagada no relatório, nos 30 deltas e nos achados. As quatro edge
functions foram testadas com dependências **injetadas** e nunca exercidas contra
um R2 real; o ramo R2 de `happens-media` e `now-media` está pronto e **retido**
até a RPC devolver `storage_provider`.

**As três falhas de rota, diagnosticadas e não corrigidas.** A causa está
localizada e provada preexistente (seção 3b), mas **eu não corrigi** e não sei
por que a página não monta na rota real com contexto autenticado — sei apenas
onde o teste quebra e que o caminho de negação do mesmo arquivo funciona.
Consertar exigiria abrir frente nova às vésperas do congelamento.

**WIP retido.** O patch de cópia prévia está preparado em
`work/etapa2-noturna-copia-previa` @ `80f160599`, publicado, **não mesclado** e
não testado sobre a dev atual. O documento de catálogo de mídia é desenho: não
existe implementação correspondente e eu não a escrevi.

**Limites do meu próprio método.** A conferência de citações cobre os meus quatro
documentos e o meu JSON, não os de outras frentes. O censo de goldens mede
reachability de **widget** — se o router constrói a página — e **não** se um
golden retrata um **estado** que nenhuma rota consegue produzir; um golden pode
guardar composição inalcançável dentro de página alcançável e eu não teria
contado. A primeira varredura do 2b usou nome de arquivo e caminho, e eu
declarei aqui, como hipótese, que um teste do meu escopo com nome que não tocasse
o domínio ficaria invisível. A hipótese **se realizou na mesma noite**:
`principal_real_route_test` é exatamente esse caso, e carregava três falhas. A
segunda varredura, por import, o encontrou — mas ela tem o limite simétrico, de
pegar dependência sem ser sujeito. Um teste do meu escopo que nem se chame como o
domínio nem importe minhas árvores continuaria invisível para as duas. As nove
dimensões varridas são as que eu escolhi; não afirmo que sejam as nove certas
nem que sejam suficientes.
