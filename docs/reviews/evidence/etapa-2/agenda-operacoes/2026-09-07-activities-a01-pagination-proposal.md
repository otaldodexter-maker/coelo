---
title: "A01 — reforço proposto de paginação e cardinalidade"
source: "packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql"
status: "prepared; SQL não executado"
generated_at: "2026-09-07"
---

Enquanto a base nominal permanece no gate Eng1, o pgTAP preparado recebeu
fixture institucional com duas unidades e três turmas, mais turma autorizada
sem vínculo com atividade. Reforços: total independente de limit/offset,
página além do total vazia, offset reportado, ASC/DESC por nome, agregados sem
multiplicação, opções incluindo estrutura desvinculada e unidade seletiva.

Review independente estático confirmou hierarquia e expectativas AND/OR,
compatibilidade da fixture local 703 e execução sob authenticated. Nenhum SQL
executado; não há RED/GREEN de banco declarado. Migration A01 continua vazia
e fora do commit. A receita FoundationOnly antiga permanece suspensa; somente
Eng1, após fechamento da base nominal e dos hashes, pode executar o replay.

Nenhum action_id promovido, schema novo, restore histórico ou acesso remoto.
Este reforço de testes não autoriza ampliar a lease nem iniciar Docker paralelo.
