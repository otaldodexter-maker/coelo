---
title: "Toque em controle sem garantir visibilidade — inventário por dono"
source: "execução própria; classe identificada ao resolver as cinco falhas não-golden de estrutura"
status: "medição e inventário; corrigido apenas onde havia falha real"
generated_at: "2026-09-10"
group: "operacoes-sistema (com residual estrutura)"
---

# Toque em controle sem garantir visibilidade

## A classe, e por que ela engana o diagnóstico

`tester.tap` num controle que está fora da área visível não avança o fluxo. O que
falha depois aparece com sintoma **no lugar errado**: o controle de destino não
existe, um `ensureVisible` posterior estoura `Bad state: No element`, uma contagem
de requisições fica um abaixo do esperado. Quem investiga vai para a tela de
destino e não para o toque anterior.

Foi o que aconteceu com as cinco falhas não-golden de estrutura. Eu as tratei como
quatro ou cinco problemas distintos na primeira leitura, e eram **uma classe**:

| Sintoma aparente | Causa real |
| --- | --- |
| `institution-field-postalCode` ausente em 375 | o rodapé `institution-form-continue` ficou fora da vista |
| `Bad state: No element` num `ensureVisible` a 200% | idem |
| 1 requisição IBGE em vez de 2 | idem |
| `group-invite-add` nunca montado | o rodapé `group-form-continue` ficou fora da vista |

Também explica por que elas sobrevivem rodadas: o teste passa enquanto o layout
couber, e quebra quando **alguém insere conteúdo acima** — que foi o caso com
`LocationsMapSection` entrando em `_LocationSection`. O autor da inserção não
errou e o autor do teste não errou; a falha é na interação, e só aparece na base
conjunta.

## O que foi corrigido

Apenas onde havia falha real, e todas no recorte que me pertence:

| Commit | Arquivo | Antes | Depois |
| --- | --- | --- | --- |
| `174883c4f` | `institution_form_page_test.dart` (caso IBGE) | 42 PASS / 4 FAIL | — |
| `741459f27` | `institution_form_page_test.dart` (12 toques) | — | 46 PASS / 0 FAIL |
| `9a5081dfc` | `group_form_page_test.dart` (13 toques) | 1 não-golden vermelha | 156 PASS, só goldens |

Zero alteração de produto nos três.

## Inventário do restante — prevenção, não defeito

**Nada do que segue está falhando hoje.** É exposição futura: no dia em que alguém
inserir conteúdo acima desses controles, a suíte quebra apontando para o lugar
errado. Ordenado por dono e por volume.

| Dono provável | Arquivos | Toques | Em suítes que varrem breakpoint ou escala |
| --- | ---: | ---: | ---: |
| estrutura | 13 | 130 | 8 |
| formularios-cuidado | 8 | 63 | 6 |
| publicacoes-midia ou perfil-para-voce | 12 | 56 | 9 |
| acessos-pessoas | 13 | 37 | 6 |
| operacoes-sistema | 5 | 26 | 2 |
| alunos-rotina | 4 | 7 | 2 |
| chat-comunicacoes | 3 | 7 | 1 |
| a definir | 9 | 11 | 3 |

Os cinco arquivos de maior exposição, todos em suítes que varrem breakpoint ou
escala de texto — onde o limiar se move e portanto onde a bomba estoura primeiro:

1. `features/forms/presentation/response/form_response_page_test.dart` — 46 toques
2. `features/principal_moments_publication/.../principal_moments_publication_page_test.dart` — 26
3. `features/activities/presentation/activity_form_page_test.dart` — 20
4. `features/units/presentation/unit_form_page_test.dart` — 18
5. `features/locations/location_form_panel_test.dart` — 10

## Critério de triagem, para não inflar

Nem todo `tap` sem `ensureVisible` é problema. O filtro usado aqui foi duplo:
**controle de rodapé ou de confirmação** — `continue`, `save`, `submit`, `confirm`,
`next`, `publicar`, `finalizar` — **e** suíte que exercita múltiplos breakpoints ou
escala de texto. Toque em controle que está comprovadamente visível em todos os
tamanhos que o teste exercita não entra, e ali o `ensureVisible` seria ruído.

## Por que eu não corrigi os 130 de estrutura

Porque nenhum está falhando, e porque eu já não tenho tempo de rodar cada suíte
afetada antes do congelamento. Mexer em 130 toques sem medir cada suíte depois
trocaria uma exposição conhecida por um risco não medido, o que é pior.
