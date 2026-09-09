// CANDIDATE evidence only: no approved golden or production route certification.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/presentation/person_form_page.dart';
import 'package:coelo_superadmin/features/platform_users/data/fake_platform_user_repository.dart';
import 'package:coelo_superadmin/features/platform_users/domain/platform_user.dart';
import 'package:coelo_superadmin/features/platform_users/presentation/platform_user_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../../../../../apps/superadmin/test/support/people/fake_person_directory_repository.dart';

void main() {
  setUpAll(() async {
    await (FontLoader(
          'Nunito Sans',
        )..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf')))
        .load();
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final bytes = File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  for (final people in [true, false]) {
    for (final mobile in [true, false]) {
      final surface = people ? 'people' : 'internal-users';
      final viewport = mobile ? 'light-375' : 'dark-1440';
      testWidgets('$surface confirmed $viewport candidate', (tester) async {
        final size = mobile ? const Size(375, 900) : const Size(1440, 900);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final rootKey = GlobalKey();
        final peopleRepository = _PeopleRepository();
        final userRepository = _UserRepository();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => people
                  ? PersonFormPage(
                      repository: peopleRepository,
                      original: peopleRepository.record,
                      logout: unavailableSuperadminLogout,
                      onCancel: () {},
                      onSaved: (_) {},
                    )
                  : PlatformUserFormPage(
                      repository: userRepository,
                      internalUserId: userRepository.record.id,
                      capability: PlatformUserCapability.owner,
                      institutions: const {},
                      logout: unavailableSuperadminLogout,
                      onUpdated: (_) {},
                    ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          RepaintBoundary(
            key: rootKey,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: mobile ? CoeloTheme.light : CoeloTheme.dark,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var step = 0; step < (people ? 2 : 3); step++) {
          final next = people
              ? find.byKey(const Key('person-form-continue'))
              : find.text('Continuar');
          await tester.ensureVisible(next);
          await tester.tap(next);
          await tester.pumpAndSettle();
        }
        final save = people
            ? find.byKey(const Key('person-form-save'))
            : find.text('Salvar alterações');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        final message = find.text(
          people
              ? 'O cadastro foi confirmado. Continue para concluir.'
              : 'As alterações foram salvas. Continue para concluir.',
        );
        await tester.ensureVisible(message);
        await tester.pumpAndSettle();
        final footer = find.byKey(
          Key(
            people
                ? 'person-form-footer-surface'
                : 'platform-user-form-footer-surface',
          ),
        );
        final continueButton = people
            ? find.byKey(const Key('person-form-complete'))
            : find.widgetWithText(FilledButton, 'Continuar');
        await tester.ensureVisible(continueButton);
        await tester.pumpAndSettle();
        expect(message, findsOneWidget);
        expect(continueButton.hitTestable(), findsOneWidget);
        expect(
          find.widgetWithText(people ? TextButton : OutlinedButton, 'Voltar'),
          findsOneWidget,
        );
        expect(
          tester.getRect(message).bottom,
          lessThanOrEqualTo(tester.getRect(footer).top),
        );
        expect(tester.getRect(message).top, greaterThanOrEqualTo(0));
        expect(tester.getRect(footer).bottom, lessThanOrEqualTo(size.height));
        expect(tester.takeException(), isNull);
        final boundary =
            rootKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final shot = await boundary.toImage(pixelRatio: 1);
          final png = await shot.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../../docs/reviews/etapa-2-operacao/next-round/R02-20260909/evidence/D04/$surface-confirmed-$viewport-candidate.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          shot.dispose();
        });
      });
    }
  }
}

class _PeopleRepository implements PersonDirectoryRepository {
  final record = FakePersonDirectoryRepository.samplePeople.first;
  @override
  Future<PersonDirectoryFilterOptions> fetchFilterOptions() async =>
      const PersonDirectoryFilterOptions();
  @override
  Future<PersonDirectoryItem> updatePerson(PersonUpdate update) async => record;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UserRepository implements PlatformUserRepository {
  _UserRepository() {
    final source = FakePlatformUserRepository().records.first;
    record = source.copyWith(
      identity: source.identity.copyWith(
        postalCode: '',
        street: '',
        number: '',
        complement: '',
        neighborhood: '',
        city: '',
        state: '',
      ),
    );
  }
  late final PlatformUserRecord record;
  @override
  bool get isDemo => false;
  @override
  List<PlatformAccessProfile> get profiles => [
    record.profile,
    PlatformAccessProfiles.byId('operations'),
  ];
  @override
  List<PlatformUserRecord> get records => [record];
  @override
  PlatformUserRecord? findById(String id) => record;
  @override
  Future<PlatformUserRecord> update(String id, PlatformUserDraft draft) async =>
      record;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
