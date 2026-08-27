import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care_repository.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_controller.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty and error states keep the create action', (tester) async {
    for (final repository in [_DirectoryRepository.empty(), _DirectoryRepository.failure()]) {
      final controller = HealthCareController(repository);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: HealthCareProfileDirectoryPage(
            controller: controller,
            logout: unavailableSuperadminLogout,
            onCreate: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Criar perfil de cuidado'),
        240,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('health-care-profiles-directory-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    }
  });

  testWidgets('unavailable state is distinct and never exposes the create action', (tester) async {
    final controller = HealthCareController(const UnavailableHealthCareRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileDirectoryPage(
          controller: controller,
          logout: unavailableSuperadminLogout,
          onCreate: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Perfis de cuidado indisponíveis'), findsOneWidget);
    expect(find.byType(CoeloAdminListingToolbar), findsNothing);
    expect(find.byKey(const Key('health-care-profiles-directory-scroll')), findsNothing);
    expect(find.byType(CoeloAdminCreateAction), findsNothing);
  });

  test('stale directory response cannot replace a newer filtered response', () async {
    final repository = _RacingDirectoryRepository();
    final controller = HealthCareController(repository);
    addTearDown(controller.dispose);

    final first = controller.load();
    await Future<void>.delayed(Duration.zero);
    final second = controller.setSearch('Bia');
    await Future<void>.delayed(Duration.zero);
    repository.completeSecond('Bia');
    await second;
    repository.completeFirst('Ana');
    await first;

    expect(controller.query.search, 'Bia');
    expect(controller.items.single.displayName, 'Bia');
  });
}

final class _RacingDirectoryRepository implements HealthCareRepository {
  final _requests = <Completer<HealthCareDirectoryPage>>[];

  @override
  HealthCareActor get defaultActor =>
      HealthCareActor(id: 'test-actor', profile: HealthCareAccessProfile.owner);

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) {
    final completer = Completer<HealthCareDirectoryPage>();
    _requests.add(completer);
    return completer.future;
  }

  void completeFirst(String name) => _requests.first.complete(_page(name));
  void completeSecond(String name) => _requests.last.complete(_page(name));

  HealthCareDirectoryPage _page(String name) => HealthCareDirectoryPage(
    items: [
      HealthCareChildSummary(
        id: name,
        personId: name,
        displayName: name,
        operationalStatus: HealthCareOperationalStatus.active,
        medicationCount: 0,
        activeAllergyCount: 0,
        pendingAcknowledgementCount: 0,
      ),
    ],
    totalCount: 1,
    page: 0,
    pageSize: 11,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DirectoryRepository implements HealthCareRepository {
  _DirectoryRepository.empty() : fail = false;
  _DirectoryRepository.failure() : fail = true;

  final bool fail;

  @override
  HealthCareActor get defaultActor =>
      HealthCareActor(id: 'test-actor', profile: HealthCareAccessProfile.owner);

  @override
  Future<HealthCareDirectoryPage> fetchDirectory(
    HealthCareDirectoryQuery query, {
    required HealthCareActor actor,
  }) async {
    if (fail) throw StateError('test failure');
    return HealthCareDirectoryPage(items: const [], totalCount: 0, page: 0, pageSize: 11);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
