import 'dart:async';

import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_form_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dispose in [false, true]) {
    testWidgets('discard confirmation leaves with its form: dispose=$dispose', (tester) async {
      final repository = _Repository('A');
      var canceled = 0;
      await tester.pumpWidget(_app(repository, onCancel: () => canceled++));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('platform-user-first-name')), 'Novo nome');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);
      await tester.pumpWidget(
        dispose
            ? MaterialApp(theme: CoeloTheme.light, home: const SizedBox())
            : _app(repository, capability: PlatformUserCapability.unauthorized),
      );
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsNothing);
      expect(canceled, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('repeated cancel requests open only one discard confirmation', (tester) async {
    final repository = _Repository('A');
    var canceled = 0;
    await tester.pumpWidget(_app(repository, onCancel: () => canceled++));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('platform-user-first-name')), 'Novo nome');
    final cancel = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar'))
        .onPressed!;
    cancel();
    cancel();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?', skipOffstage: false), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(canceled, 1);
  });

  testWidgets('a denied editor never starts remote catalog or detail reads', (tester) async {
    final repository = _Repository('A');
    await tester.pumpWidget(_app(repository, capability: PlatformUserCapability.unauthorized));
    await tester.pumpAndSettle();
    expect(repository.catalogReads, 0);
    expect(repository.detailIds, isEmpty);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byKey(const Key('platform-user-first-name')), findsNothing);
  });

  testWidgets('old catalog completion cannot request detail in a replacement context', (
    tester,
  ) async {
    final catalog = Completer<List<PlatformAccessProfile>>();
    final first = _Repository('A', catalog: catalog.future);
    final second = _Repository('B');
    await tester.pumpWidget(_app(first));
    await tester.pump();
    await tester.pumpWidget(_app(second));
    await tester.pump();
    catalog.complete(first.profiles);
    await tester.pumpAndSettle();
    expect(first.detailIds, isEmpty);
    expect(second.detailIds, [second.record.id]);
    expect(_firstName(tester), 'B');
    expect(tester.takeException(), isNull);
  });

  testWidgets('revoking editor capability discards a pending update callback', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final pending = Completer<PlatformUserRecord>();
    final repository = _Repository('A', saving: pending.future);
    var updates = 0;
    await tester.pumpWidget(_app(repository, onUpdated: (_) => updates++));
    await tester.pumpAndSettle();
    for (var step = 0; step < 3; step++) {
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Salvar alterações'));
    await tester.pump();
    expect(repository.updates, 1);
    await tester.pumpWidget(
      _app(
        repository,
        capability: PlatformUserCapability.unauthorized,
        onUpdated: (_) => updates++,
      ),
    );
    await tester.pump();
    pending.complete(repository.record);
    await tester.pumpAndSettle();
    expect(updates, 0);
    expect(find.text('Acesso não autorizado'), findsOneWidget);
    expect(find.byKey(const Key('platform-user-first-name')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

String _firstName(WidgetTester tester) => tester
    .widget<TextFormField>(find.byKey(const Key('platform-user-first-name')))
    .controller!
    .text;

Widget _app(
  _Repository repository, {
  PlatformUserCapability capability = PlatformUserCapability.owner,
  ValueChanged<PlatformUserRecord>? onUpdated,
  VoidCallback? onCancel,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: PlatformUserFormPage(
    repository: repository,
    capability: capability,
    internalUserId: repository.record.id,
    logout: unavailableSuperadminLogout,
    onUpdated: onUpdated,
    onCancel: onCancel,
  ),
);

final class _Repository implements PlatformUserRepository, PlatformUserRemoteLoader {
  _Repository(String name, {this.catalog, this.saving}) {
    final source = FakePlatformUserRepository().records.first;
    record = source.copyWith(
      identity: source.identity.copyWith(firstName: name, lastName: 'Sintético', displayName: ''),
    );
  }
  late final PlatformUserRecord record;
  final Future<List<PlatformAccessProfile>>? catalog;
  final Future<PlatformUserRecord>? saving;
  var catalogReads = 0;
  var updates = 0;
  final detailIds = <String>[];
  @override
  bool get isDemo => false;
  @override
  List<PlatformAccessProfile> get profiles => [record.profile];
  @override
  List<PlatformUserRecord> get records => [record];
  @override
  PlatformUserRecord? findById(String id) => record;
  @override
  Future<List<PlatformAccessProfile>> fetchProfiles() async {
    catalogReads++;
    return catalog ?? profiles;
  }

  @override
  Future<PlatformUserRecord?> fetchById(String id) async {
    detailIds.add(id);
    return record;
  }

  @override
  Future<PlatformUserRecord> update(String id, PlatformUserDraft draft) async {
    updates++;
    return saving ?? record;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
