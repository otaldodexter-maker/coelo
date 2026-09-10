---
title: "Achado — o pacote de Turmas não tem posição na fila SQL serializada"
source: "docs/reviews/etapa-2-operacao/reports/NOTURNA-fila-sql-serializada.md; packages/coelo_database/migrations"
status: "achado do executor; a fila é escrita pelo coordenador"
generated_at: "2026-09-10"
timezone: "America/Sao_Paulo"
---

# O que está faltando

A fila serializada numera doze pacotes. Ela vai da posição 6,
`20260909200000_superadmin_activity_location_create_v2.sql`, direto para a
posição 7, `20260909211000_now_publication_expiry_transition_v1.sql`.

`20260909210000_superadmin_group_location_create_v2.sql` **não recebe posição
nenhuma**. O arquivo existe em `packages/coelo_database/migrations/`, está
íntegro, e acabou de passar em pgTAP local junto com os outros dois do grupo.

O documento sabe que ele existe: a linha 60 explica que os prefixos de L01 foram
escolhidos "para ficar depois da cauda `20260909210000`". Ou seja, ele foi usado
como referência de ordenação e não foi inscrito na fila.

# Por que isso importa

Um coordenador que aplique a fila na ordem, item por item, aplica os doze e
**pula** o de Turmas. Como ele é a última migration de Estrutura por carimbo,
nada quebra visivelmente: as migrations seguintes aplicam normalmente. O sintoma
aparece só depois, quando `groups.create` e `groups.location` continuarem
fail-closed sem motivo aparente, porque `superadmin_group_location_create_v2`
não existe no banco.

# O que peço ao coordenador

Inscrever `20260909210000_superadmin_group_location_create_v2.sql` na fila, entre
a posição 6 e a 7, com o SHA256 CRLF `3e76d07f…c2e1e4`. Os três pacotes de
Estrutura formam um conjunto e foram qualificados juntos, na ordem
`192000 → 200000 → 210000`, no perfil `StructureLocationConsumersV1`.

Vale lembrar o pré-requisito do segundo: `20260909200000` aborta com
`SQLSTATE 55000` se o agregado de Atividades v2 não estiver aplicado antes.
