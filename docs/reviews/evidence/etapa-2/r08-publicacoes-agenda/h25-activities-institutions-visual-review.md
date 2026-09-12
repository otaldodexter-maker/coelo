---
source: "C0 integrated golden failures after H25; approved masters; G3 paint/hitbox correction"
status: "reviewed-read-only; focal-correction-sufficient"
generated_at: "2026-09-12"
---

# Revisão visual independente H25

Recorte: comparar por inspeção direta os `masterImage`, `testImage` e
`isolatedDiff` gerados na integração C0 para os diretórios de Atividades e
Instituições, nas larguras 768, 1024 e 1440 e nos temas claro/escuro. Nenhum
PNG foi alterado e Flutter não foi executado por G6.

O delta está restrito aos glifos dos títulos de colunas. Em Atividades ele é
mais visível em `Unidades`; em Instituições aparece, conforme a largura, em
`Unidades`, `Turmas`, `Atividades`, `Representantes legais` e
`Administradores`. Linhas, filtros, navegação, contêineres e cores não mudam.

A causa coincide com o código integrado: reservar 48 px à direita no
`Positioned.fill` da camada que também pintava o conteúdo reduziu em 36 px a
largura visual anterior, pois 12 px já pertenciam ao indicador. Isso antecipou
o ellipsis sem existir decisão visual para mudar os goldens aprovados.

O corretivo focal de G3 é suficiente para essa regressão: pinta o conteúdo na
largura integral sob `IgnorePointer`, exclui sua semântica duplicada quando o
botão de ordenação já fornece o rótulo e mantém duas áreas interativas
disjuntas — sort até o início da faixa e resize nos 48 px finais. O handle
continua como última camada, sem reduzir alvo, ampliar coluna ou alterar a
referência A. O novo teste mede 136 px de pintura numa coluna de 160 px, resize
de 48 px e separação dos taps; os 16 casos de golden informados por G3 passaram
sem rebaseline.

Limite: a pendência já registrada de alvos sort com 32/42 px em colunas muito
estreitas não é resolvida nem mascarada por esse corretivo e continua separada.
