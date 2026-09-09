---
title: "C04 — método e armadilhas, para quem pegar Estruturas depois"
source: "erros próprios desta rodada, cada um com o custo que teve"
status: "escrito em 2026-09-09 03:20 -03:00"
generated_at: "2026-09-09T03:20:00-03:00"
timezone: "America/Sao_Paulo"
---

# Para que serve

Errei sete vezes nesta rodada de formas que custaram tempo e, em dois casos,
quase custaram uma afirmação falsa publicada. Todas são repetíveis por quem vier
depois, porque nenhuma é sobre distração — são sobre **instrumentos que mentem
com confiança**.

Está separado do inventário de propósito. O inventário diz o que existe; isto diz
como não medir errado o que existe.

# As armadilhas de medição

## 1. Lista truncada lida como completa

O relatório do `flutter test` corta a lista de falhas com "... and 5 more". Li a
parte visível, vi só golden e concluí que os não-golden passavam. Não passavam:
um teste meu estava vermelho desde que eu o escrevera.

**O que fazer:** extrair pelo marcador `[E]`, que não trunca.

```bash
flutter test <alvos> 2>&1 | grep -E "\[E\]" | sed 's|.*test/|test/|;s|:.*||' | sort | uniq -c
```

## 2. Regex de censo com ponto cego

Contei as RPCs sem definição com um padrão que só conhecia `rpc('nome')`. O
gateway de Unidade passa o nome para um ajudante — `_request('nome', ...)` — e o
padrão passou direto por dez chamadas. Nome escondido **não pode faltar em lugar
nenhum**, então a ausência sumia junto. Publiquei "cinco" e o número era quinze.

**O que fazer:** toda medição por padrão textual precisa de **prova de
cobertura**. O teste `rpc_definition_reach_test.dart` faz isso: todo arquivo que
menciona `.rpc` tem de render pelo menos um nome, senão a leitora ficou cega.

## 3. `findsNothing` dentro de `ListView`

O conteúdo do detalhe de Locais é um `ListView`. Seção abaixo da dobra **não é
construída**, e `findsNothing` responde "ausente" para o que está apenas fora da
tela. Quinze asserções de ausência passaram pelo motivo errado.

**O que fazer:** ampliar a superfície antes de afirmar ausência.

```dart
await tester.binding.setSurfaceSize(const Size(1400, 2400));
addTearDown(() => tester.binding.setSurfaceSize(null));
```

## 4. Recriar o dublê entre reconstruções

Num teste de `didUpdateWidget`, recriei o leitor falso ao reconstruir a página.
Os testes passariam sem provar nada: página nova começa sem formulário aberto de
qualquer jeito.

**O que fazer:** reusar o mesmo dublê entre as reconstruções, e responder as
leituras pendentes antes de `pumpAndSettle` — senão ele estoura esperando um
spinner que ninguém vai parar.

## 5. Adivinhar o terminador ao extrair SQL

Extraí chaves de `jsonb_build_object` procurando `))`. O do cursor fecha com `);`
e o palpite pegou o bloco seguinte, misturando as chaves de duas construções.

**O que fazer:** balancear parênteses. E lembrar que **as migrations são CRLF**:
`indexOf(')\nreturns')` não casa, `RegExp(r'\)\s*returns')` casa.

## 6. Contagem sem lista

Comparei "35 golden / 29 não-golden" de ontem com "36 / 28" de hoje e não
consegui explicar a diferença de um arquivo, porque guardei o número e não a
lista.

**O que fazer:** guardar a lista nominal. Está em
`2026-09-09-falhas-do-app-inteiro.md`, para a próxima medição ser um diff.

## 7. Afirmar causa sem verificar

Disse a C06 que a lacuna entre turnos "foi cadência de turno" sem nunca ter
conferido se o meu agendamento estava vivo. Não estava: `CronList` respondia
"No scheduled jobs", e quem vinha me acordando eram as mensagens dela. Enunciei
uma causa plausível com a confiança de quem mediu.

**O que fazer:** o mesmo que eu cobrava do código. Antes de afirmar por que algo
aconteceu, medir.

# Armadilhas do ambiente

- **`/tmp` do Git Bash não é visível ao Python do Windows.** Script que lê um
  arquivo escrito por comando bash falha com `FileNotFoundError`. Passar por
  stdin ou fazer tudo no mesmo interpretador.
- **`flutter test` em paralelo na mesma pasta quebra a ferramenta**
  (`PathNotFoundException: NativeAssetsManifest.json`). Validar em série.
- **O relógio.** `TZ=America/Sao_Paulo date` no Git Bash devolve GMT; três horas
  a mais. `powershell.exe -Command "Get-Date -Format 'HH:mm'"` devolve o
  horário certo. Ler o relógio **no mesmo comando** que escreve o carimbo — errei
  duas vezes lendo antes e escrevendo depois.
- **Rodar goldens suja a árvore com arquivos rastreados.** Uma rodada completa
  reescreve ~62 PNGs em `test/**/failures/`. Restaurar **um a um** a partir do
  `git status`, nunca com `checkout` amplo, `clean` ou `reset`.

# Armadilhas de linguagem e framework

- **`on Exception` não pega `Error`.** Foi a causa de três defeitos distintos
  nesta rodada: uma recusa de salvamento que caía fora de todo `catch`, e dois
  view models que engoliam falha. Onde o código captura para mostrar erro na
  tela, capturar `on Object`.
- **`SuperadminFormActionFooter` exige ao menos uma ação de continuação**
  (`assert(continuationActions.length > 0)`). Remover o último botão de um
  rodapé quebra a asserção — foi o que me obrigou a **desabilitar** em vez de
  ocultar o retry no estado negado.
- **Repetir o pump da mesma página reaproveita o `State`.** Para forçar estado
  novo, pumpar `SizedBox.shrink()` antes.
- **`hasFlag` está obsoleto**; usar `flagsCollection.isLiveRegion`.

# Duas regras de processo que eu adotei depois de me queimar

## Nunca colocar em segundo plano um comando que reescreve a árvore

Rodei `git checkout <baseline> -- apps/superadmin && flutter test && git checkout HEAD -- ...` em segundo plano **enquanto editava**. O baseline restaurou
arquivos antigos e eu editei a versão errada. Recuperei, mas por pouco.

Desde então: nada que mexa na árvore vai para segundo plano, e **não tento
atribuição por baseline**. É por isso que os 19 arquivos de router que falham
estão registrados como "não são das minhas famílias, atribuição em aberto" em vez
de "pré-existentes".

## Commitar e empurrar a cada mudança material

Nada de acumular para o fechamento. Se a sessão morrer, o pior caso é o
fechamento formal não ser escrito — o código e a evidência já estão no remoto.
Os mecanismos de continuidade são todos de sessão e um deles já morreu uma vez
esta noite.

# O padrão que mais rendeu

Comparar **os dois lados do contrato**: o que o cliente envia contra o que a
função aceita, lendo o texto da migration em vez de confiar na memória de quem
escreveu.

Cinco contratos medidos assim, **quatro tinham problema**:

| Contrato | O que apareceu |
|---|---|
| escrita de `people.links` | a lista que não casa com o tipo gravado é descartada em silêncio |
| filtros de `people.list` | quatro filtros sem parâmetro nem opção no servidor |
| `institutions.edit` | 14 de 39 strings chegam; 25 descartadas sem sinal |
| save de Unidade | `unit_status` viaja para uma função que não existe |
| leitura CHILD | íntegro nas duas pontas — o único escrito com conjunto fechado desde o início |

O quinto é a lição: **quem escreve o decodificador com conjunto de chaves fechado
não entra nesta lista.**
