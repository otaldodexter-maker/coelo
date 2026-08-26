import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_navigation.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the requested ten sections and the shared form foundations', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in [
      'Identidade',
      'Hierarquia',
      'Localização',
      'Administradores',
      'Pessoas',
      'Convites',
      'Turmas',
      'Atividades',
      'Plano',
      'Revisão',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
  });

  testWidgets('offers granular identity inheritance without the global identity switch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Herdar identidade visual da instituição'), findsNothing);
    for (final context in ['logo', 'cover', 'surface', 'brand', 'text']) {
      expect(find.byKey(Key('unit-inherit-$context')), findsOneWidget);
    }
    expect(
      find.ancestor(
        of: find.byKey(const Key('unit-inherit-brand')),
        matching: find.byType(Container),
      ),
      findsNothing,
    );

    await _tapVisible(tester, find.byKey(const Key('unit-inherit-brand')));
    expect(find.byKey(const Key('unit-color-picker-accentColor')), findsOneWidget);
  });

  testWidgets('restores inherited identity and plan summaries after customization', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final institution = institutions.records.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inheritedIdentity = 'Identidade herdada de ${institution.publicName}';
    expect(find.text(inheritedIdentity), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('unit-inherit-brand')));
    expect(find.byKey(const Key('unit-color-picker-accentColor')), findsOneWidget);
    expect(find.text(inheritedIdentity), findsNothing);
    await _tapVisible(tester, find.byKey(const Key('unit-inherit-brand')));
    expect(find.byKey(const Key('unit-color-picker-accentColor')), findsNothing);
    expect(find.text(inheritedIdentity), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('step-plano')));
    expect(find.text('Plano efetivo herdado de ${institution.publicName}'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('unit-inherit-plan')));
    await _tapVisible(tester, find.byKey(const Key('unit-plan-professional')));
    expect(find.text('Plano específico desta unidade'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('unit-inherit-plan')));
    expect(find.text('Plano efetivo herdado de ${institution.publicName}'), findsOneWidget);
    expect(find.text(institution.plan.label), findsWidgets);
  });
  testWidgets('keeps administrators and people changes local to the unit form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const Key('step-administradores')));
    expect(find.textContaining('Owner'), findsWidgets);
    expect(find.text('Herdados da instituição'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tabela de Administradores da unidade')), findsOneWidget);
    tester.widget<FilledButton>(find.byKey(const Key('unit-add-administrator'))).onPressed!();
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);
    await tester.enterText(find.byKey(const Key('unit-local-name')), 'Marina Oliveira');
    await tester.tap(find.byKey(const Key('unit-local-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Marina Oliveira'), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('step-pessoas')));
    expect(find.byKey(const Key('unit-import-people')), findsOneWidget);
    expect(find.byKey(const Key('unit-export-people')), findsNothing);
    expect(find.byKey(const Key('unit-search-person')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Tabela de Pessoas da unidade')), findsOneWidget);
  });

  testWidgets('masks lookup identifiers and distinguishes existing from new users', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pessoas').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('unit-search-person')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-local-name')), '@ana');
    await tester.tap(find.byKey(const Key('unit-local-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Usuário encontrado'), findsOneWidget);
    expect(find.text('@ana'), findsNothing);

    await tester.tap(find.byKey(const Key('unit-search-person')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-local-name')), '99999999999');
    await tester.tap(find.byKey(const Key('unit-local-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Novo usuário'), findsOneWidget);
    expect(find.text('99999999999'), findsNothing);
  });

  testWidgets('registers a linked family and exposes professional registration modes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('step-pessoas')));
    await tester.tap(find.byKey(const Key('unit-add-person')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('unit-person-registration-type')));
    await tester.pumpAndSettle();
    expect(find.text('Profissional'), findsOneWidget);
    expect(find.text('Profissional e responsável'), findsOneWidget);
    await tester.tap(find.text('Nova família').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('unit-family-guardians')), 'Ana Souza');
    await tester.enterText(find.byKey(const Key('unit-family-children')), 'Lia Souza');
    await tester.tap(find.byKey(const Key('unit-local-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.textContaining('Lia Souza'), findsOneWidget);
    expect(find.textContaining('Responsável ↔ criança'), findsOneWidget);
  });

  testWidgets('opens the existing turma flow when a callback is supplied', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
          onCreateGroup: (_, _) => opened = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('step-turmas')));
    await tester.tap(find.byKey(const Key('unit-add-group')));
    expect(opened, isTrue);
    expect(find.byType(CoeloAdminDialogShell), findsNothing);
  });

  testWidgets('exposes local invite, turma, and activity actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final target in const {
      'step-convites': 'unit-add-invite',
      'step-turmas': 'unit-add-group',
      'step-atividades': 'unit-add-activity',
    }.entries) {
      await _tapVisible(tester, find.byKey(Key(target.key)));
      expect(find.byKey(Key(target.value)), findsOneWidget);
    }
  });

  testWidgets('cannot bypass required hierarchy validation from review', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    UnitFormSaveResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revisão').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-form-save')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Hierarquia'), findsWidgets);
    expect(find.text('Campo obrigatório.'), findsNWidgets(2));
  });

  testWidgets('plan choices keep hover in the Coelo primary palette without gray overlay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('step-plano')));
    expect(find.byType(SwitchListTile), findsNothing);
    final inheritPlan = tester.widget<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField));
    inheritPlan.onChanged!(false);
    await tester.pumpAndSettle();

    final button = tester.widget<OutlinedButton>(find.byKey(const Key('unit-plan-professional')));
    expect(button.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.hovered}),
      CoeloTheme.light.colorScheme.primaryContainer,
    );
  });

  testWidgets('creates a unit with inherited plan and institution branding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    UnitFormSaveResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar unidade'), findsWidgets);
    expect(find.text('Identidade'), findsWidgets);
    expect(find.text('Herdar identidade visual da instituição'), findsNothing);
    expect(find.byKey(const Key('unit-brand-preview')), findsOneWidget);
    expect(find.byKey(const Key('unit-logo-card')), findsOneWidget);
    expect(find.byKey(const Key('unit-cover-card')), findsOneWidget);
    expect(find.textContaining('Identidade herdada de'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unit-form-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-name-field')), 'Unidade Parque');
    await tester.enterText(find.byKey(const Key('unit-slug-field')), 'unidade-parque');

    await _tapVisible(tester, find.byKey(const Key('step-plano')));
    expect(find.text('Herdar plano da instituição'), findsOneWidget);
    expect(find.byKey(const Key('unit-plan-summary')), findsOneWidget);
    await tester.tap(find.byKey(const Key('unit-form-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-review-edit-profile')), findsOneWidget);
    expect(find.byKey(const Key('unit-review-edit-location')), findsOneWidget);
    expect(find.byKey(const Key('unit-review-edit-plan')), findsOneWidget);
    expect(find.byKey(const Key('unit-review-edit-branding')), findsOneWidget);
    await tester.tap(find.byKey(const Key('unit-form-save')));
    await tester.pumpAndSettle();

    expect(result, UnitFormSaveResult.created);
    final saved = repository.records.lastWhere((record) => record.name == 'Unidade Parque');
    expect(saved.planOverride, isNull);
    expect(saved.inheritInstitutionBranding, isTrue);
  });

  testWidgets('uses the canonical advanced color picker for unit branding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const Key('unit-inherit-logo')));
    await _tapVisible(tester, find.byKey(const Key('unit-logo-picker')));
    final removeLogo = tester.widget<TextButton>(find.byKey(const Key('unit-logo-remove')));
    final colors = CoeloTheme.light.colorScheme;
    expect(removeLogo.style?.foregroundColor?.resolve({}), colors.error);
    expect(
      removeLogo.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.errorContainer,
    );
    expect(removeLogo.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);

    await _tapVisible(tester, find.byKey(const Key('unit-inherit-brand')));
    await tester.ensureVisible(find.byKey(const Key('unit-color-picker-accentColor')));
    await tester.pumpAndSettle();
    final colorPicker = tester.widget<IconButton>(
      find.byKey(const Key('unit-color-picker-accentColor')),
    );
    final semanticColors = CoeloTheme.light.colorScheme;
    expect(colorPicker.style?.overlayColor?.resolve({WidgetState.hovered}), Colors.transparent);
    expect(
      colorPicker.style?.backgroundColor?.resolve({WidgetState.hovered}),
      semanticColors.primaryContainer,
    );
    await tester.tap(find.byKey(const Key('unit-color-picker-accentColor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('advanced-color-picker-area')), findsOneWidget);
    expect(find.byKey(const Key('advanced-color-picker-hex')), findsOneWidget);
    expect(find.text('Usar cor'), findsOneWidget);
  });

  testWidgets('locks the institution on edit and confirms discarding dirty changes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: repository,
          unitId: repository.records.first.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () => cancelled = true,
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hierarquia').first);
    await tester.pumpAndSettle();

    final lockedField = find.ancestor(
      of: find.byKey(const Key('unit-institution-field')),
      matching: find.byType(IgnorePointer),
    );
    expect(tester.widget<IgnorePointer>(lockedField.first).ignoring, isTrue);

    await tester.enterText(find.byKey(const Key('unit-name-field')), 'Nome alterado');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Sair sem salvar?'), findsOneWidget);
    expect(find.textContaining('nesta unidade'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);
  });

  testWidgets('uses compact ten-step navigation on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-form-step-summary')), findsOneWidget);
    expect(find.text('Etapa 1 de 10'), findsOneWidget);
    expect(find.text('Identidade'), findsWidgets);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsNothing);
    final formContext = tester.element(find.byKey(const Key('unit-form-scroll')));
    final formTheme = Theme.of(formContext);
    expect(formTheme.scaffoldBackgroundColor, formTheme.colorScheme.surface);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the 248 px rail and footer after it at 768 and 1024', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    for (final width in [768.0, 1024.0]) {
      await tester.binding.setSurfaceSize(Size(width, 900));
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: UnitFormPage(
            key: ValueKey(width),
            repository: FakeUnitDirectoryRepository(institutions),
            logout: () async => const LogoutResult.success(),
            onCancel: () {},
            onSaved: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigation = tester.getRect(find.byType(UnitFormNavigation));
      final form = tester.getRect(find.byKey(const Key('unit-form-scroll')));
      final footer = tester.getRect(find.byKey(const Key('unit-form-footer')));

      expect(navigation.width, 248, reason: 'rail at ${width.toInt()}');
      expect(form.left - navigation.right, closeTo(CoeloSpacing.space6, 1));
      expect(footer.left, greaterThanOrEqualTo(navigation.right + CoeloSpacing.space6));
      expect(find.byKey(const Key('superadmin-form-step-summary')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('keeps edit actions inline on a wide layout', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final units = FakeUnitDirectoryRepository(institutions);

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: units,
          unitId: units.records.first.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancelar'));
    final continueAction = tester.getRect(find.byKey(const Key('unit-form-continue')));
    final save = tester.getRect(find.byKey(const Key('unit-form-save-current')));
    expect(cancel.center.dy, closeTo(continueAction.center.dy, 1));
    expect(continueAction.center.dy, closeTo(save.center.dy, 1));
  });

  testWidgets('supports approved widths, themes, and text at 200 percent', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.physicalSize = Size(width, 900);
        final institutions = FakeInstitutionDirectoryRepository();
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            darkTheme: CoeloTheme.dark,
            themeMode: mode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: UnitFormPage(
              repository: FakeUnitDirectoryRepository(institutions),
              logout: () async => const LogoutResult.success(),
              onCancel: () {},
              onSaved: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'width=$width, theme=$mode');
      }
    }
  });

  testWidgets('does not turn an unknown edit id into creation', (tester) async {
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          unitId: 'missing-unit',
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-form-not-found')), findsOneWidget);
    expect(find.text('Unidade não encontrada'), findsOneWidget);
    expect(find.byKey(const Key('unit-form-save')), findsNothing);
  });

  testWidgets('represents async loading and unauthorized edit states', (tester) async {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final completer = Completer<UnitRecord?>();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: _LoadingUnitRepository(repository, completer.future),
          unitId: repository.records.first.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('unit-form-loading')), findsOneWidget);

    completer.completeError(const UnitDirectoryUnauthorizedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-form-unauthorized')), findsOneWidget);
    expect(find.text('Sem permissão para acessar esta unidade'), findsOneWidget);
  });

  testWidgets('represents load failures without falling back to creation', (tester) async {
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final completer = Completer<UnitRecord?>();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: _LoadingUnitRepository(repository, completer.future),
          unitId: repository.records.first.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('unit-form-loading')), findsOneWidget);

    completer.completeError(StateError('load failed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unit-form-error')), findsOneWidget);
    expect(find.byKey(const Key('unit-form-save')), findsNothing);
  });

  testWidgets('validates an optional contact email when it is filled', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hierarquia').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-name-field')), 'Unidade Parque');
    await tester.enterText(find.byKey(const Key('unit-slug-field')), 'unidade-parque');
    await tester.tap(find.byKey(const Key('unit-form-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-contact-email-field')), 'email-invalido');
    await tester.tap(find.byKey(const Key('unit-form-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Informe um e-mail válido.'), findsOneWidget);
    expect(find.text('Plano'), findsWidgets);
    expect(find.text('Localização'), findsWidgets);
  });

  testWidgets('edit saves from the current step and remains on the form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final edited = repository.records.first;
    UnitFormSaveResult? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: repository,
          unitId: edited.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hierarquia').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-name-field')), 'Unidade Atualizada');
    await tester.tap(find.byKey(const Key('unit-form-save-current')));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Editar unidade'), findsWidgets);
    expect(find.text('Alterações salvas localmente.'), findsOneWidget);
    expect(repository.findById(edited.id)?.name, 'Unidade Atualizada');
  });

  testWidgets('restores edit controls and shows contextual feedback after save failure', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final institutions = FakeInstitutionDirectoryRepository();
    final repository = FakeUnitDirectoryRepository(institutions);
    final edited = repository.records.first;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: UnitFormPage(
          repository: _LoadingUnitRepository(repository, Future.value(edited), failSave: true),
          unitId: edited.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hierarquia').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-name-field')), 'Falha esperada');
    await tester.tap(find.byKey(const Key('unit-form-save-current')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-form-save-error')), findsOneWidget);
    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    final save = tester.widget<FilledButton>(find.byKey(const Key('unit-form-save-current')));
    expect(save.onPressed, isNotNull);
    expect(repository.findById(edited.id)?.name, isNot('Falha esperada'));
  });
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

final class _LoadingUnitRepository implements UnitDirectoryRepository {
  const _LoadingUnitRepository(this.delegate, this.result, {this.failSave = false});

  final UnitDirectoryRepository delegate;
  final Future<UnitRecord?> result;
  final bool failSave;

  @override
  List<UnitRecord> get records => delegate.records;

  @override
  String createId(String institutionId, String slug) => delegate.createId(institutionId, slug);

  @override
  UnitRecord? findById(String id) => delegate.findById(id);

  @override
  Future<UnitDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) => delegate.fetchFilterOptions(states: states, cities: cities);

  @override
  Future<UnitDirectoryPage> fetchPage(UnitDirectoryQuery query) => delegate.fetchPage(query);

  @override
  Future<UnitFormData> loadForm({String? unitId}) async {
    final form = await delegate.loadForm();
    return UnitFormData(institutions: form.institutions, record: await result);
  }

  @override
  Future<void> upsert(UnitRecord record) {
    if (failSave) {
      throw StateError('save failed');
    }
    return delegate.upsert(record);
  }
}
