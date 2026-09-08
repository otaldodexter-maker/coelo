---
title: "Agora — opções isoladas por contexto e rota"
source: "Três REDs locais, regressão completa e revisão independente read-only"
status: "local-green; not E2E"
generated_at: "2026-09-08"
---

# Reprodução e correção

O sheet antigo chamava o novo onCreate após troca de callback da página.
Com outra rota acima, Publicar no Agora capturado fechava a rota alheia,
tanto com a origem viva como descartada. Três testes falharam antes da correção.

Agora há uma única rota própria de opções, geração e callback capturado.
Mudança de data/repository/scope/onCreate e dispose invalidam e removem somente
o sheet próprio pós-frame. A ação exige geração atual e rota no topo.
Conclusão obsoleta não muda a pausa ou o callback do contexto novo.

# Verificação e limites

- 54/54 testes da feature Agora, incluindo goldens existentes, passaram.
- Analyzer dos dois arquivos e format passaram; revisão independente sem P1/P2.
- Sem novo PNG, contrato, SQL, backend ou mutation remota.
- Não comprova criação persistida, gateway, R2/Stream nem E2E.
- Correção restaurativa; nenhuma nova regra de produto para memória reutilizável.
