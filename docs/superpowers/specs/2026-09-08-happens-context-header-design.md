---
title: "Acontece — cabeçalho responsivo dos painéis de contexto"
source: "Direção nominal do Coordenador em 2026-09-08; Spec 050; inspeção visual e git blame"
status: "design pontual para revisão; sem aprovação global de goldens"
generated_at: "2026-09-08"
---

# Problema e direção autorizada

ContextPanel usa width<300 para empilhar título/ação, mas a coluna tem largura
286 antes dos gutters. Assim, empilha sempre. O PNG histórico possui linha
compacta. A coordenação autorizou medir espaço real, manter Row quando cabe e
empilhar quando constraints/texto ampliado exigirem, preservando textos,
ações, tokens e acessibilidade. PublishNowCard e Perfil ficam fora desta edição.

# Alternativas e decisão proposta

1. OverflowBar mede os render boxes reais de título e TextButton: mantém linha
   com spaceBetween, empilha alinhado ao início quando a soma excede a largura.
   Recomendado: respeita tema, escala e dimensões efetivas sem duplicar cálculos.
2. TextPainter e cálculo manual de padding/minWidth: preciso se todos os estilos
   forem duplicados corretamente, mas aumenta acoplamento ao tema do botão.
3. Outro breakpoint fixo: rejeitado pela direção nominal e por não medir texto.

# Contrato e aceite

Substituir apenas a seleção Row/stack por OverflowBar dentro do padding atual.
Não alterar textos, ordem, callbacks, font weights, cores, bordas ou controles.
Testes devem provar título/ação na mesma linha quando couberem, empilhados com
texto 200% quando não couberem, ausência de overflow e preservação das ações.
Cobrir larguras 375/768/1024/1440 (coluna só nas superfícies onde já existe),
claro/escuro e escala 1/2. Comparação visual antes/depois deve ser entregue sem
promover ou substituir PNGs canônicos automaticamente. Nada de backend/mídia.

# Autorrevisão

Escopo único, sem placeholders ou alteração de produto. A direção responsiva
foi autorizada; a escolha concreta OverflowBar e os resultados visuais seguem
para revisão nominal, sem equivaler a aprovação global das referências.
