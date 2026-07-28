import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_form_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
          institutions: institutions,
          repository: repository,
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (value) => result = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criar unidade'), findsWidgets);
    expect(find.text('Identidade visual'), findsWidgets);
    expect(find.text('Herdar identidade visual da instituição'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unit-form-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-name-field')), 'Unidade Parque');
    await tester.enterText(find.byKey(const Key('unit-slug-field')), 'unidade-parque');

    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byKey(const Key('unit-form-continue')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Herdar plano da instituição'), findsOneWidget);
    await tester.tap(find.byKey(const Key('unit-form-continue')));
    await tester.pumpAndSettle();
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
          institutions: institutions,
          repository: FakeUnitDirectoryRepository(institutions),
          logout: () async => const LogoutResult.success(),
          onCancel: () {},
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit-color-picker-accentColor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('unit-color-area')), findsOneWidget);
    expect(find.byKey(const Key('unit-color-hex')), findsOneWidget);
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
          institutions: institutions,
          repository: repository,
          unitId: repository.records.first.id,
          logout: () async => const LogoutResult.success(),
          onCancel: () => cancelled = true,
          onSaved: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil da unidade').first);
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
}
