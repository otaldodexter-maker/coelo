---
source:
  - docs/reviews/etapa-2-operacao/next-round/R07-decisoes-owner-20260912.md
  - docs/reviews/evidence/etapa-2/referencias/publicacao/aprovadas-20260911/circular-web-1440.png
  - apps/superadmin/test/features/principal_circulars/presentation/principal_circular_golden_test.dart
status: reviewed-r-preserved-visual-decision-pending
generated_at: 2026-09-12T12:53:20-03:00
---

# Mapa final dos seis R de Publicacoes/Agenda

## Identidade do componente

Os seis nomes da lista do Owner resolvem para
`apps/superadmin/test/features/principal_circulars/presentation/goldens/` e sao
gerados por `PrincipalCircularComposerPage` em
`principal_circular_golden_test.dart`. Esse e o compositor antigo mantido apenas
por testes. A rota produtiva de autoria administrativa usa
`SuperadminCircularComposerPage`, em `features/circulars`, e seus goldens ficam
em outro diretorio apesar dos nomes homonimos.

A observacao funcional sobre texto, midia e pergunta intercalados foi corrigida
e provada no host produtivo, preview e leitor. Ela nao transforma estes seis R
do host antigo em aprovacao visual.

## Mapa nominal

| Arquivo R | Tela / estado | Hash preservado | Correcao atual | Evidencia ainda faltante |
| --- | --- | --- | --- | --- |
| `circular_composer_light_768.png` | compositor legado; claro; web 768 | `337fb636db13d9e3733ec4e09de9c7182a951f6b` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo aprovado que defina a geometria/corte do rodape e o destino visual do host somente de teste |
| `circular_composer_light_1024.png` | compositor legado; claro; web 1024 com preview lateral | `7aa2084ae7885becd6a2852804eb1793a7a11b90` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo aprovado que defina a geometria/corte do rodape e o destino visual do host somente de teste |
| `circular_composer_light_1440.png` | compositor legado; claro; web 1440 com preview lateral | `a859d49ecf5f5a383823f00913f1ddbed7764836` | sem regravacao; comparado diretamente a `circular-web-1440.png` | decisao focal sobre rodape: a referencia inclui shell completo e rodape no limite do conteiner, enquanto o golden isola a superficie e sobrepoe rodape de largura total |
| `circular_composer_dark_768.png` | compositor legado; escuro; web 768 | `2a659de7360a9936ce8b9080adc2ad3a40f4f594` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo escuro aprovado e definicao da geometria/corte do rodape para o host somente de teste |
| `circular_composer_dark_1024.png` | compositor legado; escuro; web 1024 com preview lateral | `dec24993023afc95b9fd37f7056851a706d2b27d` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo escuro aprovado e definicao da geometria/corte do rodape para o host somente de teste |
| `circular_composer_dark_1440.png` | compositor legado; escuro; web 1440 com preview lateral | `0b2aa0113de373d48e371257741127c9c2bdb22d` | sem regravacao; ordem intercalada corrigida no host produtivo | alvo escuro aprovado e decisao focal de rodape equivalente ao caso claro 1440 |

## Conclusao

A inspecao final confirmou que os seis arquivos continuam exibindo o compositor
legado com secoes separadas de texto, arquivos e perguntas e com rodape fixo de
largura total. A referencia aprovada 1440 mostra o host produtivo dentro do shell
e um rodape no limite inferior do conteiner. Como o recorte/crop e a geometria
substituta nao foram decididos inequivocamente, alterar o legado agora inventaria
uma decisao visual. Nenhum dos seis PNGs foi regravado e nenhum teste golden foi
reexecutado sem delta material.

Os tres A+ pertencem ao compositor produtivo e foram corrigidos separadamente;
a aprovacao escura 375 continua restrita ao componente identificado na lista do
Owner e nao foi generalizada para outro host.
