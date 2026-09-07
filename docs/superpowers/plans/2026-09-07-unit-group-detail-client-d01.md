---
title: "D01 — cliente de detalhe/reload de Unidades e Grupos"
source: "specs 043/045; autorização local E2E2-D01 transmitida pelo Coordenador em 2026-09-07"
status: "approved-local; implementation-in-progress"
generated_at: "2026-09-07"
---

# D01 — plano de implementação

## Passos visíveis por tela — execução contínua

| Tela / subtela / ação | Passo | Camada e BD efetivamente trabalhado | Responsável | Evidência | Próximo gate |
| --- | --- | --- | --- | --- | --- |
| Grupos / detalhe e reload | 5/6 local; gate 4 real aberto | Flutter + adapter RPC `superadmin_group_detail_v2`, HTTP mock; sem BD acessado | principal; review_file_actions | suíte D01 combinada 123 GREEN; 12 goldens | logout desktop compartilhado, produção |
| Unidades / detalhe e reload | 5/6 local; gate 4 real aberto | Flutter + adapter RPC `superadmin_unit_detail_v2`, HTTP mock; sem BD acessado | principal; review_file_actions | suíte D01 combinada 123 GREEN; analyzer zero | logout desktop compartilhado, produção |
| Instituições / edição e reload | 6/6 do pacote corretivo, não da tela | controller + RPC mock `superadmin_institution_edit_core_v2` / `superadmin_institution_detail_v2` | principal; inspect_institution_reload | commit52be4fc5; 36 testes | validação core e reidratação produtiva |
| Unidades e Grupos / import-export | 6/6 do pacote corretivo, não da tela | nenhum BD nesta fatia | principal; review_file_actions | commitd60f23b4; 38 testes | comprovação composição produtiva |
| Locais / contrato compartilhado de seleção | 1/6 | fontes SQL lidas: `public.activity_locations`; nenhum BD acessado | locations_contract_crosswalk | crosswalk read-only | reserva e decisão de schema/autoridade |

Marcos por tela: 1 contrato/inventário; 2 backend/segurança/negativas;
3 cliente/estados; 4 integração real/persistência/reload; 5 regressão/visual;
6 review/evidências/commit. Nenhum percentual fictício ou conclusão E2E.
Não há API de plano nativo disponível nesta tarefa; este arquivo não altera o
contador de arquivos da interface.

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
- [x] Testes focados123, analyzer zero, validador visual e review independente.
- [ ] Commit e handoff D01-UI; logout desktop compartilhado e produção abertos.
- [x] Propor reserva nominal de composição/router antes de editar arquivos
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
