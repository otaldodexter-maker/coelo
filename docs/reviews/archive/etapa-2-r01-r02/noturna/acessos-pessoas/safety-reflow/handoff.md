---
source: "coordenacao r18; E2-noturna-reflow-app-20260909.md e2739adc9; 3a96ca535"
status: "reflow local confirmado; sem alteracao de produto neste lote"
generated_at: "2026-09-09"
---

# Safety: carga e alcance nas duas larguras

apps/superadmin -> Acessos -> Seguranca infantil -> diretorio /dev/safety -> child-safety.list. Base conjunta6aa materializada; HEAD de inicio c526307dd. A triagem coordenada usou d784462c1, anterior a nossa correcao3a96ca535. Essa correcao ja substituiu IntrinsicHeight/Row por Wrap, pois o status compartilhado usa LayoutBuilder, incompatibilidade registrada em safety-visual/handoff.md. Tambem recuperou tratamento de erro/carga e lifecycle. Nao se reabre nem refaz a correcao aprovada.

Novo teste de rota safety_reflow_test.dart: 375 e1440 por texto100% e200%, altura900, tema claro. Pumps limitados; exige ausencia de excecao, controller ready, contagem Todos164, Alice alcancavel por rolagem e ausencia de loading. Sem mock de controller: usa a composicao de desenvolvimento real e suas fixtures sinteticas.

Primeira sonda probe.txt:3P/1F. Nenhuma excecao de overflow. F375/200 veio do instrumento exigir Alice antes de rolar; o ListView nao havia construido o card fora do viewport. Ajustado somente o teste para conferir controller ready e rolar ate Alice. green-375-200.txt:1P focal. Como as assercoes de carga e rolagem foram fortalecidas no corpo comum dos quatro casos, final.txt executou os quatro novamente: **4P/0F/0S**, exit0. Contagem unica4, nao8 nem soma dos reruns. Nenhum produto ou golden alterado.

Loading eterno e transbordamento da triagem antiga nao reproduzidos na base conjunta. Isso nao resolve os quatro resultados de diretrizes compartilhadas em safety-accessibility/handoff.md nem certifica a rota produtiva com adapter legado, contratos remotos ou persistencia. Proximo passo: coordenador atualizar a leitura da triagem com a base e separar reflow aprovado dos alvos/contrastes abertos.

Runners40077,21302,73905 encerrados. Nenhuma chamada remota, SQL, porta ou servidor. Sem nova regra de produto para memoria.
