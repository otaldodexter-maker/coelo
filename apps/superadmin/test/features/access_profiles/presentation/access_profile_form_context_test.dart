import 'dart:async';

import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('old completion cannot release the replacement save lock', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pendingA = Completer<AccessProfile>();
    final pendingB = Completer<AccessProfile>();
    final first = _Repository('A', saving: pendingA.future);
    final second = _Repository('B', saving: pendingB.future);
    final saved = <String>[];
    await tester.pumpWidget(_app(first));
    await tester.pumpAndSettle();
    await _submit(tester);
    await tester.pumpWidget(_app(second, onSaved: (profile) => saved.add(profile.id)));
    await tester.pumpAndSettle();
    await _submit(tester);
    pendingA.complete(_profile('A'));
    await tester.pump();
    final button = find.byKey(const Key('access-profile-save'));
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false); // Intentionally blocked by the pending save.
    expect(second.saves, 1);
    expect(saved, isEmpty);
    pendingB.complete(_profile('B'));
    await tester.pumpAndSettle();
    expect(saved, ['B']);
    expect(tester.takeException(), isNull);
  });

  for (final denied in [false, true]) {
    testWidgets('form replaces context and discards old load denied=$denied', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final firstLoad = Completer<AccessProfile>();
      final first = _Repository('A', load: firstLoad.future);
      final second = _Repository('B');
      await tester.pumpWidget(_app(first));
      await tester.pump();
      await tester.pumpWidget(_app(second));
      await tester.pump();
      expect(second.reads, 1);
      if (denied) {
        firstLoad.completeError(const AccessProfileUnauthorizedException());
      } else {
        firstLoad.complete(_profile('A'));
      }
      await tester.pumpAndSettle();
      expect(find.text('Nome B'), findsOneWidget);
      expect(find.text('Nome A'), findsNothing);
      expect(find.text(const AccessProfileUnauthorizedException().message), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final conflict in [false, true]) {
    testWidgets('old save cannot complete in the replacement form conflict=$conflict', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final pending = Completer<AccessProfile>();
      final first = _Repository('A', saving: pending.future);
      final second = _Repository('B');
      final saves = <String>[];
      await tester.pumpWidget(_app(first, onSaved: (_) => saves.add('A')));
      await tester.pumpAndSettle();
      await _submit(tester);
      expect(first.saves, 1);
      await tester.pumpWidget(_app(second, onSaved: (_) => saves.add('B')));
      await tester.pump();
      if (conflict) {
        pending.completeError(const AccessProfileConflictException());
      } else {
        pending.complete(_profile('A'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(saves, isEmpty);
      expect(find.text('Alterações em conflito'), findsNothing);
      expect(find.text('Nome B'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _app(_Repository repository, {ValueChanged<AccessProfile>? onSaved}) => MaterialApp(
  theme: CoeloTheme.light,
  home: AccessProfileFormPage(
    repository: repository,
    domain: AccessProfileDomain.platform,
    profileId: repository.id,
    logout: unavailableSuperadminLogout,
    onCancel: () {},
    onSaved: onSaved ?? (_) {},
  ),
);

Future<void> _submit(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(CoeloFormTextField, 'Nome do perfil'),
    'Nome revisado',
  );
  for (var step = 0; step < 3; step++) {
    await tester.ensureVisible(find.byKey(const Key('access-profile-continue')));
    await tester.tap(find.byKey(const Key('access-profile-continue')));
    await tester.pumpAndSettle();
  }
  await tester.enterText(
    find.widgetWithText(CoeloFormTextField, 'Motivo da alteração'),
    'Motivo sintético',
  );
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('access-profile-save')));
  await tester.tap(find.byKey(const Key('access-profile-save')));
  await tester.pump();
}

AccessProfile _profile(String id) => AccessProfile(
  id: id,
  domain: AccessProfileDomain.platform,
  code: 'profile.${id.toLowerCase()}',
  name: 'Nome $id',
  description: 'Descrição sintética.',
  status: AccessProfileStatus.active,
  maxScope: AccessProfileScope.platform,
  version: 1,
  membershipCount: 0,
);

final class _Repository implements AccessProfileRepository {
  _Repository(this.id, {this.load, this.saving});
  final String id;
  final Future<AccessProfile>? load;
  final Future<AccessProfile>? saving;
  var reads = 0;
  var saves = 0;
  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async {
    reads++;
    return load ?? _profile(id);
  }

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async {
    saves++;
    return saving ?? draft;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
