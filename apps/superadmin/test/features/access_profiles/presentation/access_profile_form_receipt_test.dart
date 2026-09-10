import 'package:coelo_superadmin/features/access_profiles/domain/access_profile.dart';
import 'package:coelo_superadmin/features/access_profiles/presentation/access_profile_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final editing in [false, true]) {
    testWidgets(
      'confirmed receipt prevents second write after callback failure editing=$editing',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final repository = _Repository('A');
        var deliveries = 0;
        await tester.pumpWidget(
          _app(
            repository,
            editing: editing,
            onSaved: (_) {
              deliveries++;
              if (deliveries == 1) throw const AccessProfileUnavailableException();
            },
          ),
        );
        await tester.pumpAndSettle();
        await _submit(tester, editing: editing);
        await tester.pumpAndSettle();
        final retry = find.byKey(const Key('access-profile-complete')).evaluate().isNotEmpty
            ? find.byKey(const Key('access-profile-complete'))
            : find.byKey(const Key('access-profile-save'));
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(repository.saves, 1);
        expect(deliveries, 2);
        expect(find.byType(CoeloFormTextField), findsNothing);
        expect(find.byKey(const Key('access-profile-previous')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final replaceRepository in [false, true]) {
    testWidgets(
      'confirmed receipt invalidated by replacement repository=$replaceRepository',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1440, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final first = _Repository('A');
        var oldDeliveries = 0;
        await tester.pumpWidget(
          _app(
            first,
            editing: true,
            onSaved: (_) {
              oldDeliveries++;
              throw StateError('navigation failed');
            },
          ),
        );
        await tester.pumpAndSettle();
        await _submit(tester, editing: true);
        await tester.pumpAndSettle();
        final oldCompletion = tester
            .widget<FilledButton>(find.byKey(const Key('access-profile-complete')))
            .onPressed!;
        final replacement = replaceRepository ? _Repository('B') : first;
        var newDeliveries = 0;
        await tester.pumpWidget(
          _app(replacement, editing: true, profileId: 'B', onSaved: (_) => newDeliveries++),
        );
        await tester.pumpAndSettle();
        oldCompletion();
        await tester.pumpAndSettle();
        expect(oldDeliveries, 1);
        expect(newDeliveries, 0);
        expect(find.byKey(const Key('access-profile-confirmed-save')), findsNothing);
        expect(find.widgetWithText(CoeloFormTextField, 'Nome do perfil'), findsOneWidget);
        await _submit(tester, editing: true);
        await tester.pumpAndSettle();
        expect(newDeliveries, 1);
        expect(first.saves + (replaceRepository ? replacement.saves : 0), 2);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Widget _app(
  _Repository repository, {
  required bool editing,
  String? profileId,
  required ValueChanged<AccessProfile> onSaved,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: AccessProfileFormPage(
    repository: repository,
    domain: AccessProfileDomain.platform,
    profileId: editing ? profileId ?? repository.id : null,
    logout: unavailableSuperadminLogout,
    onCancel: () {},
    onSaved: onSaved,
  ),
);

Future<void> _submit(WidgetTester tester, {required bool editing}) async {
  await tester.enterText(
    find.widgetWithText(CoeloFormTextField, 'Nome do perfil'),
    'Nome revisado',
  );
  for (var step = 0; step < (editing ? 3 : 2); step++) {
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
  _Repository(this.id);
  final String id;
  var reads = 0;
  var saves = 0;
  @override
  Future<AccessProfile> fetchDetail(AccessProfileDomain domain, String profileId) async {
    reads++;
    return _profile(id);
  }

  @override
  Future<AccessProfile> fetchTemplate(AccessProfileDomain domain) async => _profile(id);

  @override
  Future<AccessProfile> save({
    required String requestId,
    required int expectedVersion,
    required String reason,
    required AccessProfile draft,
  }) async {
    saves++;
    return draft;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
