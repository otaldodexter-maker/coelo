---
title: "Para Você — seletor acessível em pouca altura"
source: "Overflow observado durante TDD de ownership; quatro reproduções e regressão local"
status: "local-green; not E2E"
generated_at: "2026-09-08"
---

# Correção restaurativa

Quatro REDs com altura600:375px/text100→135px overflow;375/text200→951px;
800/text100→47px;800/text200→495px. O Column não rolável ultrapassava a
altura permitida pelo bottom sheet. Inserido SingleChildScrollView(primary:false)
ao redor do Padding/Column existentes. Sem mudar constraints, tokens, dados,
texto, cards ou comportamento de autorização/contexto.

# Verificação

- Quatro GREENs rolam até a última opção e selecionam Lucas por toque real.
- Reabrem, focam primeira opção, Tab chega à segunda e Enter seleciona Beatriz.
  O fluxo passa nas quatro combinações, sem exceção.
- 55/55 feature completa incluindo13goldens existentes antes do complemento
  de teclado; os quatro focais passaram novamente com Tab/Enter.
- Analyzer2, format, diff check, validador visual e revisão read-only verdes.
  Nenhum PNG promovido. Pendência de overflow da evidência de ownership resolvida.

# Limites

Fixture local de projeção. Não comprova troca de contexto/autorização no servidor,
Supabase, mídia ou E2E. Sem nova decisão de produto para memória reutilizável.
