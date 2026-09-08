import 'dart:async';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_page.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_query.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_record.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_form_page.dart';
import 'package:coelo_superadmin/features/institutions/presentation/view_models/institution_form_controller.dart';
import 'package:coelo_superadmin/features/institutions/presentation/widgets/institution_form_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saved snapshot replaces original and values while preserving step', (tester) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _beginSave(tester, repository);
    final saved = repository.drafts.single.copyWith(publicName: 'Nome normalizado', version: 9);
    repository.pending.single.complete(saved);
    await tester.pumpAndSettle();
    final controller = _controller(tester);
    expect(controller.currentStep, InstitutionFormStep.profile);
    expect(controller.text(InstitutionFormField.publicName), saved.publicName);
    expect(controller.original, same(saved));
    expect(controller.toRecord(id: 'first').version, 9);
    expect(controller.isDirty, isFalse);
    expect(find.text('Alterações salvas.'), findsOneWidget);
    controller.setText(InstitutionFormField.publicName, 'Segundo envio');
    await tester.pump();
    await tester.tap(find.byKey(const Key('institution-form-save-current')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(repository.expectedVersions.last, 9);
    repository.pending.last.complete(repository.drafts.last.copyWith(version: 10));
    await tester.pumpAndSettle();
    expect(_controller(tester).isDirty, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending save blocks pointer keyboard navigation and duplicate submission', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    final submit = await _beginSave(tester, repository);
    final lock = find.byKey(const Key('institution-form-interaction-lock'));
    expect(tester.widget<AbsorbPointer>(lock).absorbing, isTrue);
    expect(
      tester.widget<ExcludeFocus>(find.byKey(const Key('institution-form-focus-lock'))).excluding,
      isTrue,
    );
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('institution-form-save-current'))).onPressed,
      isNull,
    );
    final field = find.byKey(const Key('institution-field-publicName'));
    final editable = tester.widget<EditableText>(
      find.descendant(of: field, matching: find.byType(EditableText)),
    );
    expect(editable.focusNode.canRequestFocus, isFalse);
    await tester.tap(field, warnIfMissed: false);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.tap(find.byKey(const Key('institution-step-location')), warnIfMissed: false);
    submit();
    await tester.pump();
    expect(_controller(tester).currentStep, InstitutionFormStep.profile);
    expect(_controller(tester).text(InstitutionFormField.publicName), 'Nome enviado');
    expect(tester.testTextInput.hasAnyClients, isFalse);
    expect(repository.pending, hasLength(1));
    repository.pending.single.completeError(const InstitutionDirectoryUnavailableException());
    await tester.pumpAndSettle();
    expect(tester.widget<AbsorbPointer>(lock).absorbing, isFalse);
    expect(_controller(tester).isDirty, isTrue);
    expect(_controller(tester).text(InstitutionFormField.publicName), 'Nome enviado');
  });

  for (final failure in [false, true]) {
    testWidgets('switching institution ignores stale save failure=$failure', (tester) async {
      final repository = _Repository();
      await _mount(tester, repository);
      await _beginSave(tester, repository);
      await tester.pumpWidget(_app(repository, id: 'second'));
      await tester.pumpAndSettle();
      final current = _controller(tester);
      current.setText(InstitutionFormField.publicName, 'Rascunho da segunda');
      if (failure) {
        repository.pending.single.completeError(const InstitutionDirectoryUnavailableException());
      } else {
        repository.pending.single.complete(
          repository.drafts.single.copyWith(publicName: 'Resposta antiga', version: 9),
        );
      }
      await tester.pumpAndSettle();
      expect(_controller(tester), same(current));
      expect(current.original!.id, 'second');
      expect(current.text(InstitutionFormField.publicName), 'Rascunho da segunda');
      expect(current.isDirty, isTrue);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dispose during save ignores completion without notifying disposed state', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await _beginSave(tester, repository);
    await tester.pumpWidget(const SizedBox.shrink());
    repository.pending.single.complete(repository.drafts.single.copyWith(version: 2));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}

InstitutionFormController _controller(WidgetTester tester) =>
    tester.widget<InstitutionFormNavigation>(find.byType(InstitutionFormNavigation)).controller;
Widget _app(_Repository repository, {String id = 'first'}) => MaterialApp(
  theme: CoeloTheme.light,
  home: InstitutionFormPage(
    repository: repository,
    institutionId: id,
    logout: () async => const LogoutResult.success(),
    onCancel: () {},
    onSaved: (_) {},
  ),
);
Future<void> _mount(WidgetTester tester, _Repository repository) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 1000);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(_app(repository));
  await tester.pumpAndSettle();
}

Future<VoidCallback> _beginSave(WidgetTester tester, _Repository repository) async {
  final controller = _controller(tester);
  controller.confirmRepresentativeAdministrators(
    controller.legalRepresentatives.map((item) => item.id).toSet(),
  );
  controller.selectStep(InstitutionFormStep.profile);
  controller.setText(InstitutionFormField.publicName, 'Nome enviado');
  await tester.pumpAndSettle();
  final submit = tester
      .widget<FilledButton>(find.byKey(const Key('institution-form-save-current')))
      .onPressed!;
  await tester.tap(find.byKey(const Key('institution-form-save-current')));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
  expect(repository.pending, hasLength(1));
  return submit;
}

class _Repository implements InstitutionDirectoryRepository {
  final delegate = FakeInstitutionDirectoryRepository();
  final pending = <Completer<InstitutionRecord>>[];
  final drafts = <InstitutionRecord>[];
  final expectedVersions = <int>[];
  @override
  Future<InstitutionRecord> fetchById(String id) async =>
      (await delegate.fetchById('demo-institution-aurora')).copyWith(id: id);
  @override
  Future<InstitutionRecord> update(InstitutionRecord draft, {required int expectedVersion}) {
    drafts.add(draft);
    expectedVersions.add(expectedVersion);
    final completer = Completer<InstitutionRecord>();
    pending.add(completer);
    return completer.future;
  }

  @override
  Future<InstitutionRecord> create(InstitutionRecord draft) => delegate.create(draft);
  @override
  Future<InstitutionDirectoryPage> fetchPage(InstitutionDirectoryQuery query) =>
      delegate.fetchPage(query);
  @override
  Future<InstitutionDirectoryFilterOptions> fetchFilterOptions({
    Set<String> states = const {},
    Set<String> cities = const {},
  }) => delegate.fetchFilterOptions(states: states, cities: cities);
}
