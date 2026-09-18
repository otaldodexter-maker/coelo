---
title: "LOC-STATUSA11Y01 — status compartilhado"
source: "reserva exclusiva da coordenação em2026-09-08; diagnóstico LOC-READUI01 faabe918"
status: "approved-local-implementation"
generated_at: "2026-09-08"
---

# Recorte

Componente CoeloAdminExpandableStatusIndicator, testes diretos e evidência.
Preservar API, cores/tokens, ponto visual24px e aparência normal quando possível.
Nunca reduzir textScale ou fonte. Sem alteração de consumidores fora da reserva,
sem sobrescrever goldens históricos. Locais/Atividades/Users serão verificados.

## Contrato e sequência

1. RED direto: label Suspenso integral200%, área interativa48px, Enter/Space
   alternam estado persistente, sem alteração de cores/raio; foco/hover continuam.
2. Medir texto real com TextPainter, estilo e TextScaler do contexto. Expandir
   pill até caber texto/padding; hitbox mínimo usa CoeloSize.touchMin.
3. Preservar superfície visual24px recolhida e API surfaceKey; caixa interativa
   maior pode mudar ocupação de layout e isso será reportado, não mascarado.
4. Verificar testes package, consumidores nominais, animação reduzida,
   labels/contraste/foco/toque e candidatos Locais. Diagnóstico antigo permanece
   evidência histórica, não recebe update silencioso para ficar verde.
5. Analyzer, gate visual, memória, revisão readonly e commit separado do LOCUI.

Critério de parada desta fatia: controles íntegros em200%, teclado e toque,
regressões reais explicitadas e revisão. Não equivale ao escopo E2E original.
Estimativa local1–2h, exclui integração coordenada e novas correções de consumers.
