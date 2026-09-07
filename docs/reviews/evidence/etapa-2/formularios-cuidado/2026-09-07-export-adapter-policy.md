---
title: "Formulários — restrição local de exportações adiadas"
source: "Prompt 5; ADR 0032; apps/superadmin/lib/features/forms/data/supabase_forms_api.dart"
status: "local-green-partial"
generated_at: "2026-09-07"
---

# Pacote do adapter de exportação

Branch `codex/e2e-formularios-cuidado`; base
`1150ca30cb5fe414bf28b4aadabb3abcc85d4dec`. Somente Superadmin.

Action ID canônico: `forms.responses.export`; alias histórico: `forms.export`.
O alias foi comunicado ao Coordenador, sem editar rastreadores.

O adapter produtivo agora recusa CSV, ZIP e participação anônima nominal antes
de RPC, com erro `unavailable` e mensagem `Disponível depois do MVP`.
A entrada específica de exportação nominal anônima recusa todos os formatos.
O contrato e o payload XLSX preexistentes permanecem inalterados. Nenhuma rota,
UI, API pública, migration, gateway ou configuração remota foi conectada.

## Evidência local

- RED: quatro testes novos falharam; nove testes anteriores passaram.
- GREEN: 13/13 testes do adapter após a correção.
- Regressão com teste adicional de preservação XLSX: 22/22 testes de
  `test/features/forms/data` passaram.
- Analyzer dos dois arquivos Dart: sem issues.
- `git diff --check`: sem erros.
- Dados dos testes são sintéticos; nenhuma chamada remota foi realizada.

Comandos, a partir de `apps/superadmin`:

```powershell
rtk proxy flutter test --no-pub test/features/forms/data
rtk proxy flutter analyze --no-pub lib/features/forms/data/supabase_forms_api.dart test/features/forms/data/supabase_forms_api_test.dart
```

## Limites e atualização central solicitada

Front-end: `local-green` parcial permanece; a restrição do adapter está provada,
mas UI, composição produtiva e arquivo real continuam abertos.
Back-end: `fail-closed`/pendente permanece. Integração: sem promoção E2E.

O SQL local `20260813155124_forms_jobs_notifications_and_exports.sql` recebe
`form_id`, `occurrence_id`, `kind` e `justification`, sem `response_id`.
Isso comprova somente compatibilidade do payload preservado no código local.
Não comprova o contrato implantado, o realm interno, RLS, o worker XLSX,
armazenamento R2, reautorização, expiração, revogação ou cleanup.

Próximo gate: contrato nominal de exportação por formulário e Media Gateway
da E2E 3, seguido por wiring autorizado e negativos por ator/tenant.
A preparação local não concede lease remoto.

Memória de conhecimento: `no-op`; a regra durável já consta na ADR 0032 e em
`docs/knowledge/team/superadmin-forms-production.md`.

Recuperação: pacote local sem migration ou mutation remota; eventual reversão
deve ocorrer por commit inverso revisado, sem reset destrutivo da worktree.
