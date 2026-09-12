---
source:
  - docs/reviews/etapa-2-operacao/next-round/R07-decisoes-owner-20260912.md
  - docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/circular-web-1440.png
  - apps/superadmin/test/features/principal_circulars/presentation/principal_circular_golden_test.dart
status: reviewed-r-preserved-host-and-visual-decision-pending
generated_at: 2026-09-12T12:53:20-03:00
---

# Mapa final dos seis R de Publicacoes/Agenda

## Identidade do componente

Os quatro nomes 768/1024 da lista do Owner existem somente em
`apps/superadmin/test/features/principal_circulars/presentation/goldens/` e sao
gerados por `PrincipalCircularComposerPage`, o compositor antigo mantido apenas
por testes. Os nomes 1440 existem tanto nesse diretorio quanto em
`features/circulars`, onde a rota produtiva usa `SuperadminCircularComposerPage`.

A tabela nominal registra apenas o basename, sem path ou componente. Alem
disso, o HTML apresentado ao Owner aponta explicitamente o render A
`circular_composer_light_1440.png` para `features/circulars`, nao para
`principal_circulars`. Assim, a serie 768/1024 sugere o legado, mas as entradas
1440 e a origem da comparacao permanecem ambiguas.

A observacao funcional sobre texto, midia e pergunta intercalados foi corrigida
e provada no host produtivo, preview e leitor. Ela nao transforma estes seis R
do host antigo em aprovacao visual.

## Mapa nominal

| Arquivo R | Tela / estado | Hash preservado | Correcao atual | Evidencia ainda faltante |
| --- | --- | --- | --- | --- |
| `circular_composer_light_768.png` | compositor legado; claro; web 768 | `337fb636db13d9e3733ec4e09de9c7182a951f6b` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo aprovado que defina a geometria/corte do rodape e o destino visual do host somente de teste |
| `circular_composer_light_1024.png` | compositor legado; claro; web 1024 com preview lateral | `7aa2084ae7885becd6a2852804eb1793a7a11b90` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo aprovado que defina a geometria/corte do rodape e o destino visual do host somente de teste |
| `circular_composer_light_1440.png` | basename ambiguo: legado e produtivo; claro; web 1440 | legado `a859d49ecf5f5a383823f00913f1ddbed7764836`; produtivo `8282078dabd65dec25aa408d8f27db27fd36f3d5` | nenhum R regravado; o HTML compara a referencia diretamente ao produtivo | path/componente nominal e decisao focal sobre rodape: a referencia inclui shell completo e rodape no limite do conteiner, enquanto os goldens usam recortes diferentes |
| `circular_composer_dark_768.png` | compositor legado; escuro; web 768 | `2a659de7360a9936ce8b9080adc2ad3a40f4f594` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo escuro aprovado e definicao da geometria/corte do rodape para o host somente de teste |
| `circular_composer_dark_1024.png` | compositor legado; escuro; web 1024 com preview lateral | `dec24993023afc95b9fd37f7056851a706d2b27d` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo escuro aprovado e definicao da geometria/corte do rodape para o host somente de teste |
| `circular_composer_dark_1440.png` | basename ambiguo: legado e produtivo; escuro; web 1440 | legado `0b2aa0113de373d48e371257741127c9c2bdb22d`; produtivo `073b73ee693676f31391092b9750a16af0fad550` | nenhum R regravado; ordem intercalada corrigida no host produtivo | path/componente nominal, alvo escuro aprovado e decisao focal de rodape equivalente ao caso claro 1440 |

## Conclusao

A inspecao final confirmou que a serie legado continua exibindo secoes separadas
de texto, arquivos e perguntas e rodape fixo de largura total. A referencia
aprovada 1440 mostra o host produtivo dentro do shell e tambem mostra um rodape
com `Cancelar`, `Salvar rascunho` e `Publicar circular`. Isso contradiz a leitura
literal da observacao nominal de que o rodape da referencia web "nao existe".
O design system e a ADR0034/P15 ainda exigem rodape ancorado em formularios.

Como a lista nao identifica path/componente e nao define recorte/crop ou
geometria substituta, ela nao autoriza remover ou redesenhar o rodape de nenhum
host. A pergunta focal ao Owner continua necessaria. Nenhum PNG R foi regravado
e nenhum teste golden foi reexecutado sem delta material.

Os tres A+ pertencem ao compositor produtivo e foram corrigidos separadamente;
a aprovacao escura 375 continua restrita ao componente identificado na lista do
Owner e nao foi generalizada para outro host.
