import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/units/data/fake_unit_directory_repository.dart';
import 'package:coelo_superadmin/features/units/domain/unit_directory.dart';
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
    expect(find.byKey(const Key('unit-brand-preview')), findsOneWidget);
    expect(find.byKey(const Key('unit-logo-card')), findsOneWidget);
    expect(find.byKey(const Key('unit-cover-card')), findsOneWidget);
    expect(find.textContaining('Identidade herdada de'), findsOneWidget);

    await tester.tap(find.byKey(const Key('unit-form-continue')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('unit-name-field')), 'Unidade Parque');
    await tester.enterText(find.byKey(const Key('unit-slug-field')), 'unidade-parque');

    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byKey(const Key('unit-form-continue')));
      await tester.pumpAndSettle();
    }
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

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('unit-color-picker-accentColor')));
    await tester.pumpAndSettle();
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

  testWidgets('uses compact five-step navigation on mobile', (tester) async {
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

    expect(find.text('Etapa 1 de 5'), findsOneWidget);
    expect(find.byTooltip('Selecionar etapa'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.byKey(const Key('unit-step-profile')));
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
    expect(find.text('Localização e contato'), findsWidgets);
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
    await tester.tap(find.byKey(const Key('unit-step-profile')));
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
    await tester.tap(find.byKey(const Key('unit-step-profile')));
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
