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
