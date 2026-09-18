---
title: "LOC-CONTRACT01 — implementation plan"
source: "design local aprovado; reserva nominal LOC-CONTRACT01 do Coordenador"
status: "implemented-local; tests-green; not-verified-e2e"
generated_at: "2026-09-07"
---

# Location selection Implementation Plan

> Execução inline pelo único writer conforme contrato operacional; review
> independente read-only. Aplicar executing-plans e TDD, sem teste paralelo.

**Goal:** compartilhar seleção catalogada/pontual sem autorização implícita.

**Architecture:** classes const finais, união selada para escopo e seleção;
snapshot final. Barrel dedicado, sem dependência de Flutter/API.

**Tech Stack:** Dart3.8+, package:test já instalado, nenhuma dependência nova.

## Global constraints

Só os três arquivos LOC-CONTRACT01 e documentação própria. Sem consumidor,
RPC, banco, R2, URL, UI ou barrel geral. Não criar limites ou normalização.
Ausência continua nullable no consumidor. ID representa local, não reserva.

## Task1 — contrato puro

Files: criar lib/locations.dart, lib/src/locations/location_selection.dart e
test/locations/location_selection_test.dart sob packages/coelo_domain.

Interfaces produzidas, todas com construtores const:

```dart
sealed class LocationScope {
  const LocationScope();
  const factory LocationScope.institution({required String institutionId}) = InstitutionLocationScope;
  const factory LocationScope.unit({required String institutionId, required String unitId}) = UnitLocationScope;
  String get institutionId;
}
final class InstitutionLocationScope extends LocationScope {
  const InstitutionLocationScope({required this.institutionId});
  @override
  final String institutionId;
}
final class UnitLocationScope extends LocationScope {
  const UnitLocationScope({required this.institutionId, required this.unitId});
  @override
  final String institutionId;
  final String unitId;
}
enum LocationKind { internal, external }
final class LocationReferenceSnapshot {
  const LocationReferenceSnapshot({required this.id, required this.scope, required this.kind, required this.label});
  final String id;
  final LocationScope scope;
  final LocationKind kind;
  final String label;
}
sealed class LocationSelection {
  const LocationSelection();
  const factory LocationSelection.catalogued(LocationReferenceSnapshot snapshot) = CataloguedLocationSelection;
  const factory LocationSelection.oneOff(String text) = OneOffLocationSelection;
}
final class CataloguedLocationSelection extends LocationSelection {
  const CataloguedLocationSelection(this.snapshot);
  final LocationReferenceSnapshot snapshot;
}
final class OneOffLocationSelection extends LocationSelection {
  const OneOffLocationSelection(this.text);
  final String text;
}
```

- [x] Escrever testes importando package:coelo_domain/locations.dart antes da
  fonte. Cobrir dois escopos, dois kinds, seleções separadas, snapshot preservado
  após variável consumidora receber outro snapshot e nullable fora da união.
  Exemplo concreto:

  ```dart
  test('unit scope retains explicit owner', () {
    const scope = LocationScope.unit(institutionId: 'institution-a', unitId: 'unit-a');
    expect(scope.institutionId, 'institution-a');
    expect((scope as UnitLocationScope).unitId, 'unit-a');
  });
  ```

- [x] RED em packages/coelo_domain:
  `rtk proxy C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe test test/locations/location_selection_test.dart`;
  esperado import/tipos ausentes, não falha ambiental.
- [x] Implementar tipos acima e documentação dos limites; barrel contém
  `export 'src/locations/location_selection.dart';` como profile_about existente.
- [x] GREEN no mesmo comando. Rodar `dart test` e `dart analyze` via mesmo
  prefixo RTK/runtime; exigir nenhuma falha nova. Não rodar pub upgrade.
- [ ] Review independente de spec e qualidade, gate de memória/evidência,
  diff sem consumidor/segredo, commit nominal e handoff antes de integração.

## Self-review

Contrato limitado à referência e seleção. Proveniência, endereço, visibilidade,
reserva, atualidade e autorização não são propriedades inferidas. Não há novo
produto ou nome físico de tabela. ETA local20–35min; não certifica E2E.
