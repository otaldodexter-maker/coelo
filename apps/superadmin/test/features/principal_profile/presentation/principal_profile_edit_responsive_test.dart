import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_superadmin/features/principal_profile/presentation/principal_profile_edit_page.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/profile_about/domain/profile_about_repository.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Responsive and accessibility proofs for `principal.profile-edit`.
///
/// The editor is a production surface: it must hold up at the canonical widths
/// and at 200% text, and its denied and error states must be readable and
/// reachable.
void main() {
  const context = PrincipalRuntimeContext(
    membershipId: 'membership-1',
    personId: 'person-1',
    institutionId: 'institution-1',
    institutionName: 'Instituição Autorizada',
    roleCode: 'staff',
    scopeKind: 'institution',
  );

  ProfileAboutPage pageWithSections() => ProfileAboutPage(
    subject: const ProfileAboutSubjectRef(
      type: ProfileAboutSubjectType.institution,
      institutionId: 'institution-1',
    ),
    version: 2,
    fields: const [],
    sections: [
      ProfileAboutSection(
        id: 'section-1',
        type: ProfileAboutSectionType.text,
        title: 'Nossa proposta pedagógica para a comunidade escolar',
        body:
            'Um texto autorizado longo o bastante para exercitar o refluxo do '
            'editor em telas estreitas e com escala de texto ampliada.',
        position: 0,
        state: ProfileAboutSectionState.published,
      ),
      ProfileAboutSection(
        id: 'section-2',
        type: ProfileAboutSectionType.iconList,
        title: 'Atendimento',
        body: '',
        position: 1,
        items: const ['Segunda a sexta', 'Das 7h às 19h'],
        state: ProfileAboutSectionState.published,
      ),
    ],
  );

  Future<void> pumpEditor(
    WidgetTester tester, {
    required Size surface,
    double textScale = 1,
    ProfileAboutRepository? repository,
  }) async {
    await tester.binding.setSurfaceSize(surface);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: PrincipalProfileEditPage(
          runtimeContext: context,
          repository: repository ?? _StubAboutRepository(page: pageWithSections()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectNoLayoutError(WidgetTester tester) => expect(tester.takeException(), isNull);

  group('layout', () {
    for (final width in <double>[375, 768, 1024, 1440]) {
      testWidgets('renders the editor without overflow at ${width.toInt()} px', (tester) async {
        await pumpEditor(tester, surface: Size(width, 1000));

        expect(find.byKey(const Key('principal-profile-edit-save')), findsOneWidget);
        expectNoLayoutError(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    for (final width in <double>[375, 1440]) {
      testWidgets('renders without overflow at ${width.toInt()} px and 200% text', (tester) async {
        await pumpEditor(tester, surface: Size(width, 1600), textScale: 2);

        expect(find.byKey(const Key('principal-profile-edit-save')), findsOneWidget);
        expectNoLayoutError(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets('keeps the save and reload actions reachable at 375 px', (tester) async {
      await pumpEditor(tester, surface: const Size(375, 700));

      await tester.ensureVisible(find.byKey(const Key('principal-profile-edit-save')));
      await tester.ensureVisible(find.byKey(const Key('principal-profile-edit-reload')));
      expectNoLayoutError(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('accessibility', () {
    testWidgets('the loaded editor keeps reachable tap targets', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(tester, surface: const Size(1440, 1000));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the denied state announces itself and offers no retry', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(
        tester,
        surface: const Size(375, 800),
        repository: _StubAboutRepository(loadError: ProfileAboutUnauthorizedException()),
      );

      expect(find.bySemanticsLabel('Sem permissão'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the error state stays readable and its retry is reachable', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpEditor(
        tester,
        surface: const Size(375, 800),
        repository: _StubAboutRepository(loadError: ProfileAboutUnavailableException()),
      );

      expect(find.text('Tentar novamente'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

final class _StubAboutRepository implements ProfileAboutRepository {
  _StubAboutRepository({this.page, this.loadError});

  ProfileAboutPage? page;
  Object? loadError;

  @override
  Future<ProfileAboutPage?> load(
    ProfileAboutSubjectRef subject, {
    ProfileAboutAudience? preview,
  }) async {
    final failure = loadError;
    if (failure != null) throw failure;
    return page;
  }

  @override
  Future<ProfileAboutSaveResult> save(
    ProfileAboutPage page, {
    required String requestId,
    Map<ProfileAboutFieldKey, String> officialUpdates = const {},
  }) => Future.error(UnimplementedError());
}
