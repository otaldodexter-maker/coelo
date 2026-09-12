---
title: "R08 G8 — matriz de evidências por arquivo e SHA"
source: "logs commitados em origin/dev e refs R08"
status: "checkpoint documental; sem execução nesta frente"
generated_at: "2026-09-12T13:25:00-03:00"
---

# Matriz de evidências R08

As contagens abaixo são evidências de arquivos/logs, não um novo censo. Reruns,
tentativas interrompidas e conjuntos sobrepostos não são somados.

| Ciclo/pacote | Arquivo de evidência | SHA do arquivo/commit | Resultado medido | União/interseção |
|---|---|---|---|---|
| 30 | `r08-coordenacao/flutter-integrado-ciclo30.jsonl` e `ciclo30.md` | `67bdf9128214d0e52eb72e938a7750aa7ffb12df` | conforme checkpoint do ciclo 30 | o resumo não expõe IDs por caso suficientes para interseção exata |
| 60 | `r08-coordenacao/flutter-integrado-ciclo60.jsonl` e `ciclo60.md` | `2d97892d96bf9877d992e9b5443d56e2159bfbb7` | `238 PASS / 0 FAIL / 0 SKIP`, 11 arquivos | execução focal única; não somar reruns nem com ciclos anteriores |
| 90 | `r08-coordenacao/flutter-integrado-ciclo90.jsonl` e `ciclo90.md` | `2441725d5cd7631ba5ee6288c06b448ed6a0f808` | `422 PASS / 0 FAIL / 0 SKIP`, 11 arquivos | pacote próprio; não somar ao ciclo 60 |
| 120 Principal | `r08-coordenacao/flutter-principal-integrado.jsonl` e `ciclo120.md` | `7cc6d4e7b2d3f4f1145c4c7dd8ab8f28249e0bb4` | `79 PASS`, 3 arquivos, base `b85fd00e0` | separado de Forms e dos pacotes autorais |
| 120 Forms | `r08-coordenacao/flutter-forms-h12-h26-integrado.jsonl` e `ciclo120.md` | `7cc6d4e7b2d3f4f1145c4c7dd8ab8f28249e0bb4` | `273 PASS`, 2 arquivos, base `f11eb76b8` | não somar ao Principal 79 |
| 120 Grupos/H19 | `flutter-grupos-h19-integrado.jsonl`, `flutter-grupos-h19-final.jsonl`, `ciclo120.md` | `7cc6d4e7b2d3f4f1145c4c7dd8ab8f28249e0bb4` | tentativa `60/1`; H19 `32`; retry Grupos `29/0` | sobreposição explícita; não somar `60+32+29` |
| 120 form-media | `r08-coordenacao/deno-form-media-integrado.log` | `7cc6d4e7b2d3f4f1145c4c7dd8ab8f28249e0bb4` | `54/0` Deno | distinto do autoral `53`; não somar |
| 150 P51/anônimo | `r08-coordenacao/ciclo150.md`, `p51-auth-allowlist.json`, `p51-link-*.json` | `7e889abac336875e975f52184d8b361de8c3ec1b`, pacote anônimo `8b9e784e5` | P51 sete invariantes pós-allowlist; anônimo `293 PASS` autorais em 6 arquivos | snapshot posterior; não reclassifica ciclos 120 nem promove E2E |
| G1 45 A | `r08-estrutura/handoff.md`, `rodape-modelo-teste.md` | `5b79c1150ed58768646b2f424f5011abce7372c6`, prova nominal `41d3c518a` | 45 PNGs comparados/regravados; 3 testes proprietários `20/20 PASS` | visual focal; não E2E; sem interseção de casos Flutter fornecida |
| Anônimo | `r08-formularios-cuidado-rotina/07-anonymous-tests-final.log` e `07-anonymous-edit.md` | fonte final `72e6e6f22`; reconciliação `8344cb98a`/`e9c30f765` | `293 casos únicos / 0 falhos`; decomposição `7+40+17+154+21+54` | 18 novos; demais sobrepostos a pacotes anteriores; caminhos identificados abaixo |

## Caminhos e união/interseção observáveis

O log anônimo final identifica estes seis caminhos: `test/features/forms/data/forms_anonymous_edit_secret_store_test.dart` (7),
`test/features/forms/data/forms_media_reader_test.dart` (40), `test/features/forms/data/forms_gallery_upload_test.dart` (17),
`test/features/forms/presentation/response/form_response_page_test.dart` (154),
`test/features/forms/presentation/operations/forms_media_reader_test.dart` (21) e
`test/features/forms/data/supabase_forms_api_test.dart` (54). A soma é 293; os 18 novos e a sobreposição restante são
declarações do recibo autoral, não devem ser somados aos ciclos anteriores.

Os JSONL de ciclos 30/60/90 estão publicados no snapshot C0 `27f44fccf`; seus caminhos e casos
podem ser enumerados por `suite.path` e `test.name`. A matriz não afirma interseção semântica
entre nomes de casos de ciclos diferentes quando não existe um identificador de caso estável comum.

## Lacunas de contagem

- A base integrada atual contém os arquivos `07-anonymous-*`; a fonte final `72e6e6f22` e o recibo corrigido `8b9e784e5` confirmam os 293 casos. Não é lacuna de existência.
- A interseção semântica entre casos dos ciclos 30/60/90 e o pacote anônimo continua não demonstrável sem um identificador estável comum; nomes parecidos não serão tratados como o mesmo caso.
- O pacote G1 informa o conjunto nominal de 45 PNGs e 20/20 nos três testes, mas não fornece uma tabela de IDs de teste compartilhados com os ciclos integrados; não há interseção visual inventada.
- O `diff-check` com whitespace nativo preservado é observação de formatação/proveniência, não falha de teste.

## Pedidos focais

- C0/G1: anexar ou apontar o JSONL final dos três testes dos 45 PNGs se a interseção por caso for exigida.
- C0/G3: anexar os seis logs finais `07-anonymous-*` à base integrada ou fornecer seus SHAs de arquivo para fechar a auditoria dos 293.
- C0: preservar os JSONL dos ciclos 30/60/90 no mesmo snapshot se a matriz precisar de união exata por caminho e caso.

## Comparação reproduzível

`matriz-exata.js` extraiu nomes dos JSONL 30/60/90 e do log anônimo final.
O resultado está em `matriz-exata-result.json` e o resumo em `matriz-exata.md`:
245/476/820 chaves únicas nos ciclos, 293 eventos anônimos com 281 chaves
únicas e 12 duplicatas; interseção sintática 60∩90 de 224. Caminhos
`package:flutter_test/src/widget_tester.dart` permanecem marcados como
observação sintática, não equivalência semântica.
