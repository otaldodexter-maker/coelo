---
title: "Atividades A01 — contrato cliente e pacote RED para operador serial"
source: "packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql"
status: "prepared; SQL não executado"
generated_at: "2026-09-07"
---

# Pacote A01

Somente activities.list, Superadmin. Adapter usa directory_v2 e options_v2
nominais, envelope estrito, filtros completos e projeção mínima com hierarquia.
37/37 testes HTTP simulados passaram. Editor/detalhe continuam fail-closed.
Isso não comprova banco nem integração. Migration nominal A01 ainda vazia,
fora deste pacote RED e não aplicada.

## Replay solicitado ao Eng1

Operador único conforme Coordenador. Nenhum Docker iniciado por E2E5.

```powershell
./packages/coelo_database/scripts/Invoke-SafeLocalMigrationReplay.ps1 `
  -FoundationOnly -TargetVersion 20260901200206 `
  -TestPath packages/coelo_database/supabase/tests/superadmin_internal_activities_v2_directory_contract_test.sql
```

Omitir AdditionalMigration. Manifesto foundation atual tem 67 entradas, incluindo
cadeia Atividades v2 de agosto, diretório 20260831234307, auditoria de negativas
20260901124500 e gate AAL1 20260901200206. Teste usa fixtures sintéticas isoladas,
transação/rollback, papel authenticated e helpers invoker. RPC options ausente
gera falhas TAP via helper NULL, não erro de resolução antes dos asserts.

RED esperado: filtros arrays/cliente, projeção completa e opções. Registrar
asserts executados, fixture válida e teardown. Após RED válido, root implementa
20260907222911_superadmin_activity_directory_v2_client_contract.sql e entrega
novo SHA nominal para GREEN. Não interpretar falha de infraestrutura como RED.

Review detectou Test-FoundationReplayProfile.ps1 desatualizado (65 entradas e
alvo 20260901191921); wrapper não o chama. Operador deve registrar divergência,
sem editar manifesto ou escolher outro perfil por inferência.

Nenhuma nova regra durável de produto: memória no-op. Próximo gate é SQL local;
produção e E2E continuam abertos, sem promoção de action_id.
