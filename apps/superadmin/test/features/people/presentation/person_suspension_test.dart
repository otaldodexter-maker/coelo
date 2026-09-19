import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart'
    hide PersonDirectoryPage;
import 'package:coelo_superadmin/features/people/domain/person_suspension.dart';
import 'package:coelo_superadmin/features/people/presentation/person_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/people/fake_person_directory_repository.dart';

// spec 066 §3 (lote 98/101): ⋯ do card suspende com motivo e reativa.
void main() {
  final person = PersonDirectoryItem(
    id: 'person-1',
    displayName: 'Ana Pessoa 1',
    type: PersonType.adult,
    status: PersonStatus.active,
    updatedAt: DateTime.utc(2026, 9, 19),
  );
  final suspended = PersonDirectoryItem(
    id: 'person-2',
    displayName: 'Bia Pessoa 2',
    type: PersonType.adult,
    status: PersonStatus.active,
    suspendedNow: true,
    suspendedFrom: DateTime.utc(2026, 9, 1),
    suspendedUntil: DateTime.utc(2026, 12, 31, 3),
    updatedAt: DateTime.utc(2026, 9, 19),
  );

  Widget app(FakePersonDirectoryRepository repository, _Commands commands) => MaterialApp(
    theme: CoeloTheme.light,
    home: PersonDirectoryPage(
      repository: repository,
      suspension: commands,
      logout: () async => const LogoutResult.success(),
      onEdit: (_) {},
    ),
  );

  testWidgets('parses suspension fields from the list item', (tester) async {
    final item = PersonDirectoryItem.fromJson({
      'id': 'p',
      'display_name': 'P',
      'person_type': 'adult',
      'status': 'active',
      'suspended_now': true,
      'suspended_from': '2026-09-01T00:00:00Z',
      'suspended_until': null,
      'updated_at': '2026-09-19T00:00:00Z',
    });
    expect(item.suspendedNow, isTrue);
    expect(item.suspendedFrom, DateTime.utc(2026, 9, 1));
    expect(item.suspendedUntil, isNull);
  });

  testWidgets('suspends with a reason and shows the label after reload', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakePersonDirectoryRepository(seed: [person]);
    final commands = _Commands(repository);
    await tester.pumpWidget(app(repository, commands));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('person-suspension-person-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suspender por período…'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-suspension-dialog')), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('person-suspension-confirm'))).onPressed,
      isNull,
    );
    await tester.enterText(find.byKey(const Key('person-suspension-reason')), 'Apuração');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-suspension-confirm')));
    await tester.pumpAndSettle();

    expect(commands.suspended, [('person-1', 'Apuração', null)]);
    expect(find.text('Ana Pessoa 1 suspensa até reativar.'), findsOneWidget);
    expect(find.byKey(const Key('person-suspension-label-person-1')), findsOneWidget);
    expect(find.text('Suspensa até reativar'), findsOneWidget);
  });

  testWidgets('reactivates a suspended person from the menu', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakePersonDirectoryRepository(seed: [suspended]);
    final commands = _Commands(repository);
    await tester.pumpWidget(app(repository, commands));
    await tester.pumpAndSettle();

    expect(find.text('Suspensa até 31/12/2026'), findsOneWidget);
    await tester.tap(find.byKey(const Key('person-suspension-person-2')));
    await tester.pumpAndSettle();
    expect(find.text('Suspender por período…'), findsNothing);
    await tester.tap(find.text('Reativar'));
    await tester.pumpAndSettle();

    expect(commands.reactivated, ['person-2']);
    expect(find.text('Bia Pessoa 2 reativada.'), findsOneWidget);
    expect(find.byKey(const Key('person-suspension-label-person-2')), findsNothing);
  });
}

final class _Commands implements PersonSuspensionCommands {
  _Commands(this.repository);
  final FakePersonDirectoryRepository repository;
  final suspended = <(String, String, DateTime?)>[];
  final reactivated = <String>[];

  @override
  Future<PersonSuspensionResult> suspend(
    String personId, {
    required String requestId,
    required String reason,
    DateTime? from,
    DateTime? until,
  }) async {
    suspended.add((personId, reason, until));
    _replace(personId, suspendedNow: true, from: from ?? DateTime.now().toUtc(), until: until);
    return PersonSuspensionResult(personId: personId, suspendedNow: true, suspendedUntil: until);
  }

  @override
  Future<PersonSuspensionResult> reactivate(
    String personId, {
    required String requestId,
    String? reason,
  }) async {
    reactivated.add(personId);
    _replace(personId, suspendedNow: false);
    return PersonSuspensionResult(personId: personId, suspendedNow: false);
  }

  void _replace(String id, {required bool suspendedNow, DateTime? from, DateTime? until}) {
    final index = repository.people.indexWhere((item) => item.id == id);
    final current = repository.people[index];
    repository.people[index] = PersonDirectoryItem(
      id: current.id,
      displayName: current.displayName,
      type: current.type,
      status: current.status,
      suspendedNow: suspendedNow,
      suspendedFrom: from,
      suspendedUntil: until,
      updatedAt: current.updatedAt,
    );
  }
}
