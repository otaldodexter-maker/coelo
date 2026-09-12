---
source:
  - C:/Users/adrie/Documents/Coelo.worktrees/e2-r08-coordenacao/apps/superadmin/lib/features/groups/presentation/group_form_page.dart
  - apps/superadmin/lib/features/locations/presentation/location_selection_field.dart
  - apps/superadmin/lib/features/locations/presentation/location_selection_controller.dart
status: reviewed-no-concrete-defect-not-executed
generated_at: 2026-09-12T12:58:00-03:00
---

# Revisao read-only do cache de source em `groups.location`

O WIP do C0 troca a criacao de `CatalogLocationSelectionSource` dentro de
`build` por uma instancia criada em `initState` e substituida em
`didUpdateWidget` somente quando muda a identidade de
`locationCatalogReader`.

Nenhum defeito concreto foi encontrado:

- rebuilds comuns preservam a identidade do source e deixam de reiniciar a
  carga do `LocationSelectionField`;
- a troca real de reader cria novo source durante `didUpdateWidget`; o build
  subsequente entrega a instancia ao filho, que recarrega;
- o controller incrementa epoch em cada carga e descarta resposta tardia;
- a chave do field inclui instituicao e unidade, portanto a troca de escopo
  recria o estado e nao carrega a selecao anterior;
- os guardas posteriores ao recibo continuam bloqueando mudanca de contexto
  sem descartar `groupId` e `managementVersion` confirmados;
- o valor vazio do `CoeloAdminSingleSelectField<String>` e `''`, logo o oraculo
  `isEmpty` e coerente e `isNull` nao era.

Flutter nao foi executado por G6. O teste de retry exercita a estabilidade do
source indiretamente; nao ha, neste WIP, um teste isolado de substituicao do
reader, mas isso nao constitui defeito observado.
