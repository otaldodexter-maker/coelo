import 'package:coelo_domain/profile_about.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coelo_superadmin/features/profile_about/presentation/profile_about_editor.dart';

void main() {
  testWidgets('covers loading, empty, error and unauthorized states', (tester) async {
    final controller = _controller();
    controller.status = ProfileAboutEditorStatus.loading;
    await tester.pumpWidget(_app(controller));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    for (final entry in <(ProfileAboutEditorStatus, String)>[
      (ProfileAboutEditorStatus.empty, 'Nenhum conteúdo no Sobre'),
      (ProfileAboutEditorStatus.failure, 'Não foi possível carregar'),
      (ProfileAboutEditorStatus.unauthorized, 'Sem permissão'),
    ]) {
      controller.status = entry.$1;
      await tester.pumpWidget(_app(controller));
      expect(find.text(entry.$2), findsOneWidget);
    }
  });

  testWidgets('keeps phone, tablet and desktop free from layout exceptions at 200 percent text', (
    tester,
  ) async {
    for (final width in [375.0, 768.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        _app(_controller(withSections: true), textScaler: const TextScaler.linear(2)),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width $width');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('offers touch and semantic alternatives to reorder', (tester) async {
    final controller = _controller(withSections: true);
    await tester.pumpWidget(_app(controller));
    expect(find.byTooltip('Mover para baixo'), findsWidgets);
    await tester.tap(find.byTooltip('Mover para baixo').first);
    await tester.pump();
    expect(controller.page.sections.first.id, 'second');
    expect(find.bySemanticsLabel(RegExp('posição 1 de 2')), findsOneWidget);
  });

  testWidgets('adds an editorial section without a no-op action', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_app(controller));
    final addFlyout = tester.widget<CoeloAdminFlyout<ProfileAboutSectionType>>(
      find.byType(CoeloAdminFlyout<ProfileAboutSectionType>),
    );
    addFlyout.onSelected(ProfileAboutSectionType.text);
    await tester.pumpAndSettle();
    expect(controller.page.sections, hasLength(1));
    expect(find.text('Nova seção'), findsOneWidget);
  });

  testWidgets('keeps creation actions available in the empty state', (tester) async {
    final controller = _controller()..status = ProfileAboutEditorStatus.empty;

    await tester.pumpWidget(_app(controller));

    expect(find.text('Nenhum conteúdo no Sobre'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Adicionar seção'), findsOneWidget);
  });

  test('allocates a new local id after reopening a saved draft section', () {
    final controller = ProfileAboutEditorController(
      page: ProfileAboutPage(
        subject: const ProfileAboutSubjectRef(
          type: ProfileAboutSubjectType.institution,
          institutionId: 'institution',
        ),
        version: 2,
        fields: const [],
        sections: const [
          ProfileAboutSection(
            id: 'draft-section-1',
            type: ProfileAboutSectionType.text,
            title: 'Seção salva',
            body: 'Conteúdo',
            position: 0,
          ),
        ],
      ),
    );

    controller.addSection();

    expect(controller.page.sections.map((section) => section.id).toSet(), hasLength(2));
  });

  testWidgets('reactively blocks draft mutations while saving', (tester) async {
    final controller = _controller();
    await tester.pumpWidget(_app(controller));

    controller.status = ProfileAboutEditorStatus.saving;
    await tester.pump();
    controller.addSection();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(controller.page.sections, isEmpty);
  });

  testWidgets('selects the preview audience without changing field visibility', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _controller(withSections: true);
    await tester.pumpWidget(_app(controller));

    final audienceFlyout = tester.widget<CoeloAdminFlyout<ProfileAboutAudience>>(
      find.byType(CoeloAdminFlyout<ProfileAboutAudience>),
    );
    audienceFlyout.onSelected(ProfileAboutAudience.team);
    await tester.pumpAndSettle();

    expect(controller.previewAudience, ProfileAboutAudience.team);
    expect(find.text('Prévia: Somente equipe'), findsOneWidget);
    expect(controller.page.sections, hasLength(2));
  });

  testWidgets('asks before updating official data and keeps permission separate', (tester) async {
    const changes = {ProfileAboutFieldKey.phone: '11999999999'};
    late Map<ProfileAboutFieldKey, String> result;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await confirmProfileAboutOfficialUpdate(
                context,
                changes: changes,
                canUpdateOfficialData: true,
              );
            },
            child: const Text('Salvar'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Atualizar também no cadastro oficial?'), findsOneWidget);
    await tester.tap(find.text('Sim, atualizar'));
    await tester.pumpAndSettle();
    expect(result, changes);

    final withoutPermission = await confirmProfileAboutOfficialUpdate(
      tester.element(find.text('Salvar')),
      changes: changes,
      canUpdateOfficialData: false,
    );
    expect(withoutPermission, isEmpty);
  });
}

ProfileAboutEditorController _controller({bool withSections = false}) =>
    ProfileAboutEditorController(
      page: ProfileAboutPage(
        subject: const ProfileAboutSubjectRef(
          type: ProfileAboutSubjectType.institution,
          institutionId: 'institution',
        ),
        version: 1,
        fields: const [],
        sections: withSections
            ? const [
                ProfileAboutSection(
                  id: 'first',
                  type: ProfileAboutSectionType.text,
                  title: 'Nossa história',
                  body: 'Texto',
                  position: 0,
                ),
                ProfileAboutSection(
                  id: 'second',
                  type: ProfileAboutSectionType.text,
                  title: 'Nossa proposta',
                  body: 'Texto',
                  position: 1,
                ),
              ]
            : const [],
      ),
    );

Widget _app(ProfileAboutEditorController controller, {TextScaler? textScaler}) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(textScaler: textScaler ?? TextScaler.noScaling),
    child: Scaffold(
      body: SingleChildScrollView(child: ProfileAboutEditor(controller: controller)),
    ),
  ),
);
