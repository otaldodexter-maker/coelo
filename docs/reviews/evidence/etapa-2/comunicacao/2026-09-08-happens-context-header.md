---
title: "Acontece — medição real do header de contexto"
source: "Desenho e direção nominal do Coordenador; TDD; comparação visual local"
status: "local-green; baseline global e E2E abertos"
generated_at: "2026-09-08"
---

# Recorte autorizado

Somente header título/ação de ContextPanel em Acontece. Desenho aprovado pelo
Coordenador: OverflowBar, tokens/textos/callbacks preservados, sem mudar
PublishNowCard, Perfil ou baseline PNG. LayoutBuilder e threshold300 removidos.

# TDD e regressão

- Dois REDs válidos em 1440px, claro/escuro, texto100%: centros verticais
  separados em34px apesar de título/ação caberem. Correção mínima: OverflowBar.
- A primeira execução também tinha quatro expectativas incorretas do teste
  para1024px; corrigidas antes da implementação para usar o breakpoint large
  canônico. A coluna não deve existir em1024px. Não são REDs de produto.
- 16/16 na matriz375/768/1024/1440, claro/escuro, texto100/200%, Nunito real:
  coluna ausente onde previsto, linha quando cabe e empilhamento quando não
  cabe, callback da agenda e ausência de overflow.
- 50/50 funcionais principal_happens; analyzer2 sem issues, format e diff check.
- Revisão independente read-only sem bloqueantes. Removido LayoutBuilder
  redundante apontado pelo revisor. Touch target/foco preservados pelo diff,
  não medidos diretamente pela matriz nova.

# Comparação visual, sem promoção

Suite existente:10PASS (galeria/estado indisponível),10FAIL (feed/hover).
No light1440, baseline anterior documentado em bed43737 tinha3,81%/54850px;
após o ajuste:0,15%/2203px. Dark1440:0,15%/2202px. Hover1440:0,15%/2203px.
Light375 permanece0,63%/2122px. Inspeção de master/test/isolatedDiff light1440
confirmou painéis em linha e diferença remanescente no PublishNowCard.
Inspecionada também imagem compacta dark375/text200, sem coluna de contexto.
Empilhamento desktop/text200 foi verificado por geometria de widget, não PNG.

Artefatos diagnósticos gerados, não referências promovidas:
`apps/superadmin/test/features/principal_happens/presentation/failures/`
`principal_happens_light_1440_{masterImage,testImage,isolatedDiff}.png`.

# Limites

Não altera regra de produto, backend, mídia ou autorização. Não comprova E2E.
Sem novo conhecimento reutilizável para artigo: restauração responsiva da
composição já aprovada. Coordenador decide qualquer reconciliação de goldens.
