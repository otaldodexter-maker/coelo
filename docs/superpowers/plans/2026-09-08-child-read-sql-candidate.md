---
title: "CHILD-READ01 SQL Implementation Plan"
source: "CHILD-READ01; f84d0631; reserva nominal da coordenação em 2026-09-08"
status: "approved-candidate-only-no-sql-execution"
generated_at: "2026-09-08"
---

# CHILD-READ01 SQL Implementation Plan

Goal: preparar gateway mínimo auditado de contextos infantis, sem wiring.
Architecture: um gateway público; Auth039, envelope e audit13 existentes.
Tech Stack: Postgres/Supabase, pgTAP e guard estático PowerShell.

## Restrições globais

Uma linha por contexto ativo; cinco campos do DTO a9a5974; keyset lower/C/UUID;
limit20, intervalo1–50, cursor8192 bytes. Owner interno/people.read, escopo
platform/institution. Sem capability nova, audit14, E5, alteração046 ou Locais.
Catálogo RED original f84 permanece intacto. Eng1 executa todo SQL/replay.
Root escreve sozinho, revisores somente leitura. Não afirmar runtime verde.

## Arquivos e sequência

- [x] Criar `packages/coelo_database/scripts/tests/Test-ChildDirectoryCandidate.Tests.ps1`:
  exigir candidato existente, assinatura, cinco campos, cursor/limite,
  auditoria13, negativaNULL, locks/revalidação e ausência de superfície E5.
  Rodar antes do SQL e observar falha específica por arquivo ausente.
- [x] Criar primeiro `packages/coelo_database/supabase/tests/superadmin_child_context_directory_v2_test.sql`:
  fixtures sintéticas transacionais, Owner A/institucional e Owner platform,
  criança repetida em dois contextos, sem unidade, empates e casos excluídos;
  chamadas authenticated, assertions postgres, negativos e falha de auditoria.
  Não executar. RED/verde comportamental continua reservado ao Eng1.
- [x] Criar `packages/coelo_database/migrations/20260908051500_superadmin_child_context_directory_v2.sql`:
  preflight físico/pins de corpos canônicos normalizados LF, owner/ACL/metadata,
  capability Owner, ausência do gateway; criar somente a assinatura aprovada.
  Autorizar antes de cursor/query, bloquear atores e linhas relevantes,
  revalidar após esperas, montar página e auditar antes de devolver.
- [x] Rodar o guard estático, rever código/contratos com revisores independentes,
  executar gates de memória/diff/segredos, registrar limitações e commit nominal.

Comando local permitido:
`rtk proxy powershell -NoProfile -File packages/coelo_database/scripts/tests/Test-ChildDirectoryCandidate.Tests.ps1`.
Resultado inicial esperado: erro `child candidate missing`; depois somente
PASS estático. Nenhum comando deste plano executa SQL.

Gate operacional seguinte: coordenação reserva perfil nominal Auth+envelope e
alvo51500 ao Eng1; primeiro catálogo14 sem alvo, depois migrations/testes
comportamentais com alvo. Só após essas provas considerar transporte/wiring.
