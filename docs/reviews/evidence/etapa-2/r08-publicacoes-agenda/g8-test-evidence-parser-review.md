---
source: "C0 R08; commit d106ee5a5; logs commitados dos ciclos 30/60/90 e anonymous final"
status: "reviewed-read-only; anonymous-filter-defect-found"
generated_at: "2026-09-12"
---

# Revisão focal do parser de evidências G8

Recorte somente leitura: IDs, suite, nome e dupla contagem. Flutter, Chrome,
remoto e arquivos G8/C0 não foram alterados.

## JSONL dos ciclos

O vínculo `testStart.test.id -> testDone.testID` elimina a contagem dupla de
start e done. Filtrar `hidden`, `skipped` e o marcador cujo nome começa por
`loading <arquivo>` é correto nesse formato. A medição por `suiteID + nome`
confirma, no ciclo 90, 422 execuções, 410 chaves exatas e 12 ocorrências
duplicadas.

## Log compacto anônimo

O arquivo possui 301 linhas físicas:

- 1 aviso do RTK;
- 6 marcadores de carregamento de arquivo;
- 293 linhas de caso, com contador anterior à conclusão de `+0` até `+292`;
- 1 rodapé `+293: All tests passed!`, depois da última conclusão.

Portanto, `+0..+292` são 293 linhas inclusivas. O rodapé confirma o total, mas
não é um caso adicional.

O parser de `d106ee5a5` já exige `<path>/test/<arquivo>.dart: <nome>`, então os
seis marcadores de arquivo não casam. Mesmo assim, ele aplica
`name.startsWith('loading ')` e remove dois casos legítimos:
`loading at 200 percent in light` e `loading at 200 percent in dark`.
Daí o resultado incorreto 291/279. Remover somente esse filtro restaura:
**293 eventos observados, 281 chaves exatas e 12 duplicações**.

As 12 duplicações são ocorrências extras de quatro nomes parametrizados:

- `rejects malformed URL without exposing it`: 6 execuções, 5 extras;
- `rejects invalid expiry or TTL over 300 seconds`: 5 execuções, 4 extras;
- `expired receipt keeps the safe expired exception`: 2 execuções, 1 extra;
- `backend failure is sanitized without implicit retry`: 3 execuções, 2 extras.

Total: `5 + 4 + 1 + 2 = 12`. Não existe 13º caso nem duplicação atribuível ao
rodapé. Os mesmos quatro grupos explicam 422/410/12 no ciclo 90.

O achado e a correção mínima foram enviados ao C0 e diretamente ao G8.

## Revisão do corretivo final

Os commits `cc7e68703` e `cfc710b13` restauram os 293 eventos do log compacto,
mas ainda não fecham a matriz como prova comparativa:

- `jsonl()` continua classificando qualquer nome iniciado por `loading ` como
  marcador. O filtro precisa usar a relação estrutural entre o marcador e o
  caminho da suíte, não um prefixo que também pode ser nome legítimo de teste;
- a normalização preserva a raiz absoluta de cada worktree. Assim, o mesmo
  arquivo executado por G3 e C0 recebe chaves diferentes e as interseções ficam
  artificialmente zeradas; o caminho deve ser canônico a partir da raiz do
  repositório, por exemplo `apps/superadmin/test/...`;
- 281 é o número de chaves distintas `path + display name`, não o número
  demonstrado de casos. Testes parametrizados podem compartilhar o nome
  exibido. Os 12 excedentes são colisões dessa chave de exibição; os 293
  eventos observados continuam sendo a contagem fiel disponível.

O C0 e o G8 receberam essa distinção. Nenhum teste foi reexecutado nesta
revisão somente leitura.

## Estado às 14h00

A matriz de `7c2735a61` corrige os três pontos: compara o sufixo canonicalizado
do marcador com o caminho canonicalizado da suíte, devolve o contador real
`loaderMatched` e usa `uniqueDisplayKeys`/`displayKeyCollisions`. O diagnóstico
é 8/11/11 loaders; no ciclo 30 os outros dois eventos ocultos são `setUpAll` e
`tearDownAll`, portanto não devem ser chamados de loaders. O documento atual
foi reescrito sem a tabela obsoleta. Matriz aceita sem rerun Flutter.

O parser geral introduzido em `e22e4c126` ainda repete a comparação entre nome
absoluto e caminho canonicalizado e classifica os 11 loaders do ciclo 90 como
`hidden`. A correção solicitada é aplicar a mesma igualdade canonicalizada e
priorizar `loading` antes de `hidden` na classificação exclusiva. Esse parser
geral permanece pendente; a matriz aceita não depende dele.

O corretivo `122293fc6`, documentado em `29528d150`, aplica exatamente essa
regra no parser geral: canonicaliza o sufixo após `loading ` e classifica loader
antes de hidden. O reprocessamento do JSONL do ciclo 90, sem Flutter, devolveu
422 passed, 11 loading, 0 hidden e 0 órfãos. O parser geral está aceito por
conteúdo; seu `nativeExitCode=1` é o valor preservado da execução fonte, não uma
nova execução nem falha do reprocessamento.
