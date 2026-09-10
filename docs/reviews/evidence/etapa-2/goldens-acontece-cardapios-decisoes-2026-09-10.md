---
title: "Decisões do Owner sobre os 26 goldens divergentes de Acontece e Cardápios"
source: "Página de comparação lado a lado publicada pelo grupo principal-chat-sistema em 10/09/2026 (referência guardada, render atual, diferença), sobre a base 1adb070c9 da Fase 0; resposta do Owner na mesma data"
status: "approved"
generated_at: "2026-09-10"
---

# Decisões do Owner sobre os goldens de Acontece e Cardápios

Em 10/09/2026 o Owner revisou as 26 comparações restantes das famílias Acontece
e Cardápios e decidiu arquivo por arquivo. Esta página é a fonte dessas
decisões e **substitui**, para os arquivos aqui listados, o que a
[lista de 10/09](goldens-claro-decisoes-2026-09-10.md) dizia.

A legenda é a mesma: **R** mantém a imagem guardada como referência e o código
volta a ela; **A** promove o render atual a referência. Observação presente
significa que a correção vem **antes** da regravação.

## Mudanças em relação à lista anterior

Quatro goldens de Cardápios estavam decididos como **R com observação ARQUIVO**
e passaram a **A com observação**, porque o composto de diretório da Fase 0
mudou o render. Os cinco de Acontece que estavam **A com SHELL; MAIS**
continuam **A**, agora sem observação: SHELL veio do composto e MAIS foi
aplicada pelo grupo.

## Galeria do Acontece — 10 arquivos, todos R

A galeria passou a divergir por causa da decisão D3, que desabilitou
Compartilhar mídia e Salvar mídia em vez de anunciar prévia. O Owner manteve a
**referência guardada** e acrescentou correções que valem para todos os dez.

| Golden | Decisão |
| --- | --- |
| principal_happens_gallery_light_1024 | R |
| principal_happens_gallery_light_1440 | R |
| principal_happens_gallery_light_375 | R |
| principal_happens_gallery_light_768 | R |
| principal_happens_gallery_video_unavailable_light_375 | R |
| principal_happens_gallery_dark_1024 | R |
| principal_happens_gallery_dark_1440 | R |
| principal_happens_gallery_dark_375 | R |
| principal_happens_gallery_dark_375_text_200 | R |
| principal_happens_gallery_dark_768 | R |

Correções pedidas, na íntegra:

1. **GALERIA-ALINHAMENTO** — a paginação ("1 de N") fica **alinhada à direita**;
   compartilhar, salvar e baixar ficam **alinhados à esquerda**.
2. **GALERIA-BAIXAR** — a lista de ações passa a citar **baixar**, além de
   compartilhar e salvar. Hoje a galeria só tem compartilhar e salvar.
3. **GALERIA-DISTORÇÃO** — "parece que a imagem está distorcendo". Conferir o
   ajuste da mídia: a imagem não pode ser esticada para preencher a área.
4. **GALERIA-MOBILE** — em 375 "a imagem fica pobre, pensar mais no Instagram".
   O visualizador mobile precisa de composição própria, mais próxima de um
   visualizador de mídia de rede social do que da moldura atual.

## Cardápios — 5 arquivos

| Golden | Decisão | Observação |
| --- | --- | --- |
| meal_plan_directory_card_hover_light_1440 | A | o botão de arquivos fica **depois do toggle** e tem que ser similar à tela de Instituições |
| meal_plan_directory_flyout_light_1440 | A | tem que ter **editar, duplicar, arquivar e excluir** |
| meal_plan_directory_light_1440 | A | tem que ter editar, duplicar, arquivar e excluir |
| meal_plan_directory_light_375 | A | tem que ter editar, duplicar, arquivar e excluir |
| meal_plan_wizard_new_light_375 | R | |
| meal_plan_directory_dark_1440 | A | segue o claro de mesmo nome |

O menu de ações de Cardápios hoje traz editar, duplicar, enviar revisão e
publicar. **Arquivar** e **excluir** precisam entrar. Arquivar já tem caminho de
servidor: `public.meal_plan_archive(text, uuid, integer)`, com recibo e revisão
otimista, ligada ao cliente em 10/09.

## Feed do Acontece — 11 arquivos, todos A, sem correção pendente

| Golden | Decisão |
| --- | --- |
| principal_happens_light_1024 | A |
| principal_happens_light_1440 | A |
| principal_happens_light_375 | A |
| principal_happens_light_768 | A |
| principal_happens_now_hover_light_1440 | A |
| principal_happens_dark_1024 | A |
| principal_happens_dark_1440 | A |
| principal_happens_dark_375 | A |
| principal_happens_dark_375_text_200 | A |
| principal_happens_dark_768 | A |
| meal_plan_directory_dark_1440 | A |

`principal_happens_light_375` trazia, na lista anterior, a observação de que o
contêiner das imagens estava fora do padrão de `coelo-ui`. A decisão nova é
**A sem observação**, o que encerra aquele item para o feed.

## Como executar

1. Regravar os 11 goldens **A sem observação**, no SDK registrado, conferindo
   antes que o render aprovado ainda é o render atual da base.
2. Em Cardápios, aplicar as duas correções e só então regravar os 5.
3. Na galeria, aplicar as quatro correções e voltar o código à referência
   guardada; a regravação só acontece se a correção mudar o render de propósito,
   e nesse caso a nova imagem volta ao Owner.
4. Registrar no rastreador Front-end, por tela, o que foi regravado e o que
   voltou à referência, com o SHA.
