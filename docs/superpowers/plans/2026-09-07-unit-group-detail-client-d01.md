---
title: "D01 — cliente de detalhe/reload de Unidades e Grupos"
source: "specs 043/045; autorização local E2E2-D01 transmitida pelo Coordenador em 2026-09-07"
status: "approved-local; implementation-in-progress"
generated_at: "2026-09-07"
---

# D01 — plano de implementação

Objetivo: consumir exclusivamente as RPCs internas de detalhe/reload aprovadas,
sem reutilizar gateway legado nem inferir campos ausentes.

## Desenho aprovado e alternativas

Escolha: DTOs de detalhe independentes por domínio e repositories somente
leitura. Reutilizar UnitRecord/GroupRecord de edição exigiria fabricar valores
de branding, plano ou agregados fora do payload; descartado. Conectar adapters
legados restauraria autoridade people-based; proibido.

As specs 043/045 continuam delimitando o pacote backend original. A autorização
cliente D01 é separada e não altera capability, role, AAL, schema, provenance ou
grants. Nenhum deploy ou cutover remoto integra este plano.

## Etapas e critérios de parada

- [x] Grupos: criar `features/groups/domain/group_detail.dart` e
  `features/groups/data/supabase_group_detail_repository.dart`, com teste em
  `test/features/groups/data/supabase_group_detail_repository_test.dart`.
  RED antes de código, GREEN após; método único `fetchById(String)`.
  Usar HTTP mock do SupabaseClient, confirmar endpoint e único p_group_id;
  reload deve observar segunda resposta e revogação. UUID inválido não faz
  chamada. Envelope inválido, payload errado e ID divergente falham fechado.
- [x] Unidades: equivalente em `features/units/domain/unit_detail.dart`,
  `features/units/data/supabase_unit_detail_repository.dart` e teste paralelo.
  Preservar address/contact/effective_plan anuláveis e inherited server-side;
  não inferir tipo físico nem plano no cliente.
- [ ] Testes focados, analyzer e review independente; commit e handoff.
- [ ] Propor reserva nominal de composição/router antes de editar arquivos
  compartilhados. UI read-only usa somente os campos aprovados e controles
  canônicos; estados loading/denied/unavailable e reload removem payload antigo.
  Não reaproveitar formulário editável como detalhe.

Comandos por teste, dentro de `apps/superadmin`:

```text
rtk flutter test --no-pub test/features/groups/data/supabase_group_detail_repository_test.dart
rtk flutter test --no-pub test/features/units/data/supabase_unit_detail_repository_test.dart
rtk flutter analyze --no-pub lib/features/groups/domain/group_detail.dart lib/features/groups/data/supabase_group_detail_repository.dart lib/features/units/domain/unit_detail.dart lib/features/units/data/supabase_unit_detail_repository.dart
```

Parar somente a fatia que exigir decisão nova, reserva não concedida ou recurso
remoto; continuar as etapas independentes. Limite global: 08/09 03:20 BRT.
Evidência local não promove verified/done/verified-e2e. Trackers são atualizados
exclusivamente pelo Coordenador via handoff por ação.
