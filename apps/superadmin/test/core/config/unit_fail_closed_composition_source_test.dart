import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final authScope = File('lib/core/config/superadmin_auth_scope.dart').readAsStringSync();
  final app = File('lib/app/superadmin_app.dart').readAsStringSync();
  final router = File('lib/app/router/superadmin_router.dart').readAsStringSync();
  final unavailableComposition = File(
    'lib/features/units/data/unavailable_unit_composition.dart',
  ).readAsStringSync();

  test('only the configured auth scope constructs Supabase Unit adapters', () {
    // Desde 58bfe1fed (ADR 0034) o auth scope configurado liga os adapters
    // reais; app e router continuam recebendo-os por injecao, com o padrao
    // indisponivel, e o scope sem configuracao segue fail-closed.
    expect(authScope, contains('SupabaseUnitDirectoryRepository(client)'));
    expect(authScope, contains('SupabaseUnitBackendCommandsGateway(client)'));
    for (final source in [app, router]) {
      expect(source, isNot(contains('supabase_unit_directory_repository.dart')));
      expect(source, isNot(contains('supabase_unit_backend_commands_gateway.dart')));
      expect(source, isNot(contains('SupabaseUnitDirectoryRepository(')));
      expect(source, isNot(contains('SupabaseUnitBackendCommandsGateway(')));
    }
    for (final source in [authScope, app, router]) {
      expect(source, contains('unavailable_unit_composition.dart'));
    }
  });

  test('production and development Unit composition stays explicit', () {
    expect(
      RegExp(
        r'backendCommands: hasStructureMutationCapability\(\) \? unitBackendCommands : null',
      ).allMatches(router),
      hasLength(1),
    );
    expect(RegExp(r'backendCommands: null').allMatches(router), hasLength(1));
    expect(RegExp(r'UnitFormPage\(').allMatches(router), hasLength(4));
    expect(
      RegExp(r'UnitFormPage\(\s*repository:[\s\S]{0,100}backendCommands:').allMatches(router),
      isEmpty,
    );
    expect(router, contains('FakeUnitDirectoryRepository(institutionPreviewRepository())'));
    expect(
      app,
      contains('this.unitBackendCommands = const UnavailableUnitBackendCommandsGateway()'),
    );
    expect(
      authScope,
      contains('unitBackendCommands: const UnavailableUnitBackendCommandsGateway()'),
    );
    expect(unavailableComposition, contains('UnavailableUnitDirectoryException'));
    expect(unavailableComposition, isNot(contains('noSuchMethod')));
    expect(unavailableComposition, isNot(contains('Supabase')));
  });
}
