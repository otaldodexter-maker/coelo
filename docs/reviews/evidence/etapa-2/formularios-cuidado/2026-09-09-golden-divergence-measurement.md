---
title: "Goldens — medição de magnitude, dispersão e gradiente por largura"
source: "flutter test nas suítes de golden; decodificador de PNG em Python puro sobre os pares masterImage/testImage"
status: "measured-not-diagnosed"
generated_at: "2026-09-09"
---

# Recorte e limites

Medição de **como** os goldens divergem, não de **por que**. Nenhum golden foi
regravado, nenhuma baseline foi tocada e nenhuma imagem foi aberta — a leitura
de imagem falha por timeout de hook neste ambiente, o que também ocorreu no
checkout do coordenador. Não afirmo causa raiz.

O objetivo era responder uma pergunta que decide o trabalho do Owner: as
falhas de golden são telas redesenhadas sem aprovação, ou um efeito global?

## Método

Para cada par `*_masterImage.png` e `*_testImage.png` gerado pelas execuções,
um decodificador de PNG em Python puro (`zlib` da biblioteca padrão, sem
dependência externa) descompacta e desfiltra as duas imagens e compara pixel a
pixel, produzindo quatro números: percentual de pixels diferentes, percentual
de **linhas** atingidas, percentual de **colunas** atingidas e a faixa vertical
entre a primeira e a última linha diferente.

Percentual sozinho não distingue redesenho de renderização. Dispersão e
gradiente distinguem.

## Fato 1 — nenhuma tela mudou de tamanho

355 pares comparados no `apps/superadmin` inteiro: dimensão **idêntica em
100%** deles. Nenhuma falha vem de superfície que cresceu ou encolheu.

## Fato 2 — a diferença cobre quase toda a superfície

| Golden | Pixels | Linhas | Colunas |
| --- | ---: | ---: | ---: |
| `access_profile_cards_dark_375` | 91,90% | 100,0% | 100,0% |
| `access_profile_cards_dark_768` | 80,84% | 100,0% | 100,0% |
| `forms_editor_dark_375` | 43,94% | 93,9% | 91,5% |
| `forms_directory_dark_375` | 27,01% | 87,4% | 96,0% |
| `group_directory_cards_dark_375` | 17,37% | 81,7% | 92,0% |

Mudança de conteúdo de uma tela atinge uma faixa. Não existe mudança de produto
que atinja literalmente toda linha **e** toda coluna.

## Fato 3 — a gravidade cai conforme a largura cresce

Mesma tela, mesmo estado, só mudando o viewport:

| Largura | `forms_editor_light` | `access_profile_cards_dark` | `principal_happens_dark` |
| ---: | ---: | ---: | ---: |
| 375 | 38,99% | 91,90% | 0,63% |
| 768 | 14,38% | 80,84% | 0,28% |
| 1024 | 3,88% | 27,42% | 0,24% |
| 1440 | 8,38% | 23,82% | 0,15% |

Uma tela redesenhada não muda de gravidade conforme o viewport. Uma mudança de
métrica de texto muda: em 375 px o texto quebra apertado, uma diferença mínima
reflui a coluna inteira e cascateia; em 1440 há folga.

`principal_happens` é o caso que **não** confirma cegamente e por isso vale
mais: o gradiente aparece na mesma ordem, mas a magnitude é minúscula. A
magnitude escala com a densidade de texto e de ícones da tela — diretório
administrativo denso explode, feed com poucos elementos grandes quase não muda.
O efeito varia com a quantidade de coisa desenhada, não com a feature nem com
o dono.

## Distribuição no recorte formularios-cuidado

28 comparações falhas medidas nas suítes de Formulários, Saúde e Cuidado e
Medicação: 7 abaixo de 5%, 9 entre 5% e 15%, 8 entre 15% e 25% e 4 acima de
25%, com máximo de 43,94%. Há duas populações, e elas pedem decisões
diferentes.

## O que a medição sustenta

Quatro features independentes, de donos diferentes, exibem a mesma assinatura:
dimensão idêntica, dispersão por toda a superfície e gradiente por largura.
Isso é compatível com uma mudança **global** de renderização amplificada por
refluxo em larguras estreitas, e não com telas redesenhadas sem aprovação.

Uma condição verificada que ajuda a explicar como o ambiente entra: o asset
Nunito Sans não muda desde o commit de fundação; `pubspec.yaml` declara
`flutter: ">=3.38.0"` com piso e **sem teto**; não existe `.fvmrc`, não existe
`.tool-versions` e não existe `.github/workflows`. As referências foram
gravadas por commits locais comuns, o último em 2026-09-01. A referência visual
do projeto é comparada contra o que a máquina do momento tiver.

## Consequência que muda o painel

Enquanto a referência não for fixada e reaprovada, os goldens **verdes** também
não provam nada sobre aparência: a base de comparação não corresponde ao
ambiente atual. Não é só que há falhas; é que a cobertura visual do projeto
está sem base confiável.

A decisão do Owner deixa de ser auditar tela por tela e passa a ser de
engenharia: fixar um ambiente de referência de golden, por pino de versão ou
gravação em container, e só então reaprovar em bloco. Reaprovar antes disso
congela a aparência de uma máquina qualquer como se fosse a aprovada.
