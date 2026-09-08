import 'dart:async';

import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_detail_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('delete preparation permits only one catalog request and confirmation', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_page(GlobalKey(), repository, 'a'));
    repository.a.complete(_profile('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.tap(find.text('Excluir'));
    final calls = repository.listCalls;
    repository.page.complete(
      const AccessProfilePage(items: [], totalCount: 0, page: 0, pageSize: 100),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Excluir perfil', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repository.deletedIds, isEmpty);
  });

  for (final changeResource in [false, true]) {
    testWidgets('sent delete completion respects current resource: $changeResource', (
      tester,
    ) async {
      final repository = _Repository();
      final key = GlobalKey();
      var previousCallback = 0;
      var nextCallback = 0;
      await tester.pumpWidget(_page(key, repository, 'a', onDeleted: () => previousCallback++));
      repository.a.complete(_profile('a'));
      repository.page.complete(
        const AccessProfilePage(items: [], totalCount: 0, page: 0, pageSize: 100),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(CoeloFormTextField, 'Motivo da exclusão'),
        'Motivo sintético',
      );
      await tester.pump();
      await tester.tap(find.text('Excluir e realocar'));
      await tester.pumpAndSettle();
      expect(repository.deletedIds, ['a']);
      if (changeResource) {
        await tester.pumpWidget(_page(key, repository, 'b', onDeleted: () => nextCallback++));
        repository.b.complete(_profile('b'));
        await tester.pumpAndSettle();
      }
      repository.deleteGate.complete();
      await tester.pumpAndSettle();
      expect(previousCallback, changeResource ? 0 : 1);
      expect(nextCallback, 0);
      expect(repository.deletedIds, ['a']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('confirmation from an old detail cannot dispatch deletion after resource change', (
    tester,
  ) async {
    final repository = _Repository();
    final key = GlobalKey();
    await tester.pumpWidget(_page(key, repository, 'a'));
    repository.a.complete(_profile('a'));
    repository.page.complete(
      const AccessProfilePage(items: [], totalCount: 0, page: 0, pageSize: 100),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(CoeloFormTextField, 'Motivo da exclusão'),
      'Motivo sintético',
    );
    await tester.pumpWidget(_page(key, repository, 'b'));
    repository.b.complete(_profile('b'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir e realocar'), findsNothing);
    repository.deleteGate.complete();
    await tester.pumpAndSettle();
    expect(repository.deletedIds, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail reloads the same ID on repository change and ignores old errors', (
    tester,
  ) async {
    final previous = _Repository();
    final replacement = _Repository();
    final key = GlobalKey();
    await tester.pumpWidget(_page(key, previous, 'a'));
    await tester.pumpWidget(_page(key, replacement, 'a'));
    replacement.a.complete(_profile('a'));
    await tester.pumpAndSettle();
    previous.a.completeError(const AccessProfileUnauthorizedException());
    await tester.pumpAndSettle();
    expect(replacement.calls, ['a']);
    expect(find.text('Identidade a'), findsWidgets);
    expect(find.text('Não foi possível carregar o perfil'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail reloads the same ID after domain change', (tester) async {
    final repository = _Repository();
    final key = GlobalKey();
    await tester.pumpWidget(_page(key, repository, 'a'));
    repository.a.complete(_profile('a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_page(key, repository, 'a', domain: AccessProfileDomain.institution));
    await tester.pumpAndSettle();
    expect(repository.domains, [AccessProfileDomain.platform, AccessProfileDomain.institution]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('old delete preparation cannot open a dialog for a replacement resource', (
    tester,
  ) async {
    final repository = _Repository();
    final key = GlobalKey();
    await tester.pumpWidget(_page(key, repository, 'a'));
    repository.a.complete(_profile('a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pump();
    expect(repository.listCalls, 1);
    await tester.pumpWidget(_page(key, repository, 'b'));
    repository.b.complete(_profile('b'));
    await tester.pumpAndSettle();
    repository.page.complete(
      const AccessProfilePage(items: [], totalCount: 0, page: 0, pageSize: 100),
    );
    await tester.pumpAndSettle();
    expect(find.text('Excluir perfil'), findsNothing);
    expect(find.text('Identidade b'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('equivalent detail rebuild preserves one successful read', (tester) async {
    final repository = _Repository();
    final key = GlobalKey();
    await tester.pumpWidget(_page(key, repository, 'a'));
    repository.a.complete(_profile('a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_page(key, repository, 'a'));
    await tester.pumpAndSettle();
    expect(repository.calls, ['a']);
    expect(find.text('Identidade a'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail replaces resource and rejects late previous response', (tester) async {
    final repository = _Repository();
    final key = GlobalKey();
    await tester.pumpWidget(_page(key, repository, 'a'));
    await tester.pump();
    expect(repository.calls, ['a']);
    await tester.pumpWidget(_page(key, repository, 'b'));
    await tester.pump();
    repository.b.complete(_profile('b'));
    await tester.pump();
    await tester.pump();
    repository.a.complete(_profile('a'));
    await tester.pumpAndSettle();
    expect(repository.calls, ['a', 'b']);
    expect(find.text('Identidade a'), findsNothing);
    expect(find.text('Identidade b'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail clears loaded previous resource while replacement is pending', (
    tester,
  ) async {
    final repository = _Repository();
    final key = GlobalKey();
    await tester.pumpWidget(_page(key, repository, 'a'));
    repository.a.complete(_profile('a'));
    await tester.pumpAndSettle();
    expect(find.text('Identidade a'), findsWidgets);
    await tester.pumpWidget(_page(key, repository, 'b'));
    await tester.pump();
    final oldVisible = find.text('Identidade a').evaluate().isNotEmpty;
    repository.b.complete(_profile('b'));
    await tester.pumpAndSettle();
    expect(oldVisible, isFalse);
    expect(repository.calls, ['a', 'b']);
    expect(find.text('Identidade b'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

Widget _page(
  Key key,
  AccessProfileRepository repository,
  String id, {
  AccessProfileDomain domain = AccessProfileDomain.platform,
  VoidCallback? onDeleted,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: AccessProfileDetailPage(
    key: key,
    repository: repository,
    domain: domain,
    profileId: id,
    logout: unavailableSuperadminLogout,
    onBack: () {},
    onEdit: () {},
    onDeleted: onDeleted ?? () {},
  ),
);

final class _Repository implements AccessProfileRepository {
  final calls = <String>[];
  final domains = <AccessProfileDomain>[];
  final a = Completer<AccessProfile>();
  final b = Completer<AccessProfile>();
  final page = Completer<AccessProfilePage>();
  int listCalls = 0;
  final deletedIds = <String>[];
  final deleteGate = Completer<void>();

  @override
  Future<void> deleteAndReassign({
    required String requestId,
    required AccessProfileDomain domain,
    required String profileId,
    required int expectedVersion,
    required String? replacementProfileId,
    required String reason,
  }) async {
    deletedIds.add(profileId);
    await deleteGate.future;
  }

  @override
  Future<AccessProfilePage> fetchProfiles(AccessProfileQuery query) {
    listCalls++;
    return page.future;
  }

  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) {
    calls.add(profileId);
    domains.add(domain);
    return profileId == 'a' ? a.future : b.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AccessProfile _profile(String id) => AccessProfile(
  id: id,
  domain: AccessProfileDomain.platform,
  code: id,
  name: 'Identidade $id',
  description: 'Registro sintético.',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
);
