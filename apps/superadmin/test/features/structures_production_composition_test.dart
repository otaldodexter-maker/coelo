import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What production actually hands to Estruturas, held still.
///
/// Five of the seven families are fail-closed in production and two are not,
/// and the difference is one word per line in a single file. Nothing was
/// watching those words. Flipping any of them is a decision - some of them a
/// large one - and a decision should not be able to happen by editing a
/// constructor call.
///
/// The one that matters most is `structureMutationsEnabled`. Turning it on does
/// not "switch on the unit CRUD": it opens fifteen calls that have no function
/// behind them in this repository, transfer between institutions and the whole
/// unit identity media cycle among them. That is measured in
/// `rpc_definition_reach_test.dart`; this test is what makes the flip visible.
///
/// A composition test reads source text, which is brittle by nature. It is
/// worth it here because the failure it guards against is silent: a directory
/// that starts answering with real data looks like progress until someone asks
/// which function answered.
const _scope = 'lib/core/config/superadmin_auth_scope.dart';

/// The live branch, the one that builds real Supabase clients.
String _liveBranch(String source) {
  final start = source.indexOf('institutionDirectoryRepository: SupabaseInstitutionDirectoryRepository(');
  if (start == -1) {
    throw StateError('the live composition moved; point this test at it');
  }
  final open = source.lastIndexOf('return SuperadminAuthScope(', start);
  final close = source.indexOf('\n    );', start);
  if (open == -1 || close == -1) {
    throw StateError('could not bound the live composition block');
  }
  return source.substring(open, close);
}

/// What each family is handed, and whether that is a real client or a refusal.
const _expected = <String, String>{
  // Reads that work in production.
  'institutionDirectoryRepository': 'SupabaseInstitutionDirectoryRepository(client)',
  'personDirectoryRepository': 'SupabasePersonDirectoryRepository(client)',
  'personDetailReader': 'SupabasePersonDetailReader(client)',
  'groupDetailRepository': 'SupabaseGroupDetailRepository(client)',
  'unitDetailRepository': 'SupabaseUnitDetailRepository(client)',

  // Refusals. Each one is why an action_id reads "blocked" and not "broken".
  'groupDirectoryRepository': 'const UnavailableGroupDirectoryRepository()',
  'unitDirectoryRepository': 'const UnavailableUnitDirectoryRepository()',
  'studentTrackingRepository': 'const UnavailableStudentTrackingRepository()',

  // Real, and reachable only through the router's capability gate.
  'unitBackendCommands': 'SupabaseUnitBackendCommandsGateway(client)',
};

void main() {
  final live = _liveBranch(File(_scope).readAsStringSync());

  test('the block was found and is the live one', () {
    expect(live, contains('SupabaseInstitutionDirectoryRepository(client)'));
    expect(
      live,
      isNot(contains('const UnavailableInstitutionDirectoryRepository()')),
      reason: 'this is the fallback branch, not the live one',
    );
  });

  _expected.forEach((argument, composition) {
    test('$argument is composed as $composition', () {
      expect(
        live,
        contains('$argument: $composition'),
        reason: 'production now hands Estruturas something else for $argument; '
            'that is an inventory change and has to be written down',
      );
    });
  });

  test('structure mutations are off, and turning them on is not a small edit', () {
    expect(
      live,
      contains('structureMutationsEnabled: false'),
      reason: 'this flag guards fifteen calls with no function behind them, not '
          'just the unit CRUD; see rpc_definition_reach_test.dart',
    );
  });

  test('the reason for the refusals is still written beside them', () {
    // The comment naming OQ-032/OQ-043 is the only place the reader learns that
    // the refusal is a decision rather than an oversight.
    expect(live, contains('OQ-032'));
    expect(live, contains('OQ-043'));
  });
}
