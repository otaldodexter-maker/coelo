import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/health_care/domain/health_care.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_form_pages.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _profileChildren = [
  HealthCareProfileChildOption(id: 'child-demo-a', label: 'Criança Demo A'),
  HealthCareProfileChildOption(id: 'child-demo-b', label: 'Criança Demo B'),
];

void main() {
  testWidgets('profile form is unavailable without injected data and save command', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(logout: unavailableSuperadminLogout, onCancel: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-care-profile-form-unavailable')), findsOneWidget);
    expect(find.textContaining('Demo'), findsNothing);
    expect(find.byType(SuperadminFormActionFooter), findsNothing);
  });

  testWidgets('profile create is a responsive full page with canonical fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          onCancel: () {},
          onSaved: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alergias e restrições'), findsOneWidget);
    expect(find.text('Orientações de cuidado'), findsOneWidget);
    await tester.tap(find.text('Orientações de cuidado'));
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminMultiSelectField<String>), findsOneWidget);
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('superadmin-chat-launcher-surface')), findsOneWidget);
    expect(find.byType(RadioListTile), findsNothing);
    expect(find.text('Criança'), findsWidgets);
  });

  testWidgets('profile edit locks the child identity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          childId: 'child-demo-a',
          onCancel: () {},
          loadDraft: (childId) async => HealthCareProfileDraft(childId: childId),
          onSaved: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criança Demo A'), findsWidgets);
    expect(find.byType(CoeloAdminSingleSelectField<String>), findsNothing);
    await tester.tap(find.text('Alergias e restrições'));
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString().startsWith('CoeloAdminSingleSelectField<'),
      ),
      findsNWidgets(3),
    );
  });

  testWidgets('profile edit loads every draft field and saves the complete draft', (tester) async {
    HealthCareProfileDraft? saved;
    final initial = HealthCareProfileDraft(
      childId: 'child-demo-a',
      allergyType: HealthCareAllergyType.medication,
      allergyStatus: HealthCareAllergyStatus.monitoring,
      lastEpisode: '15/07/2026',
      severity: HealthCareEpisodeSeverity.severe,
      observedReaction: 'Edema',
      allergyGuidance: 'Acionar protocolo',
      allergyNotes: 'Nota clínica',
      careItemIds: const {'autism'},
      importantSigns: 'Mudança de comportamento',
      adaptations: 'Antecipar rotina',
      justification: 'Revisão anual',
    );
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          childId: initial.childId,
          loadDraft: (_) async => initial,
          onCancel: () {},
          onSaved: (draft) async => saved = draft,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alergias e restrições').last);
    await tester.pumpAndSettle();
    expect(find.text('Edema'), findsOneWidget);
    expect(find.text('Acionar protocolo'), findsOneWidget);
    expect(find.text('Nota clínica'), findsOneWidget);

    await tester.tap(find.text('Orientações de cuidado').last);
    await tester.pumpAndSettle();
    expect(find.text('Mudança de comportamento'), findsOneWidget);
    expect(find.text('Antecipar rotina'), findsOneWidget);
    expect(find.text('Revisão anual'), findsOneWidget);

    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();

    expect(saved?.childId, initial.childId);
    expect(saved?.allergyType, initial.allergyType);
    expect(saved?.allergyStatus, initial.allergyStatus);
    expect(saved?.lastEpisode, initial.lastEpisode);
    expect(saved?.severity, initial.severity);
    expect(saved?.observedReaction, initial.observedReaction);
    expect(saved?.allergyGuidance, initial.allergyGuidance);
    expect(saved?.allergyNotes, initial.allergyNotes);
    expect(saved?.careItemIds, initial.careItemIds);
    expect(saved?.importantSigns, initial.importantSigns);
    expect(saved?.adaptations, initial.adaptations);
    expect(saved?.justification, initial.justification);
  });

  testWidgets('profile edit ignores stale child response after A to B route swap', (tester) async {
    final a = Completer<HealthCareProfileDraft?>();
    final b = Completer<HealthCareProfileDraft?>();
    Future<HealthCareProfileDraft?> load(String childId) =>
        childId == 'child-demo-a' ? a.future : b.future;
    Widget page(String childId) => MaterialApp(
      theme: CoeloTheme.light,
      home: HealthCareProfileFormPage(
        logout: unavailableSuperadminLogout,
        childOptions: _profileChildren,
        childId: childId,
        loadDraft: load,
        onCancel: () {},
        onSaved: (_) async {},
      ),
    );

    await tester.pumpWidget(page('child-demo-a'));
    await tester.pump();
    await tester.pumpWidget(page('child-demo-b'));
    b.complete(HealthCareProfileDraft(childId: 'child-demo-b', justification: 'Perfil B'));
    await tester.pumpAndSettle();
    a.complete(HealthCareProfileDraft(childId: 'child-demo-a', justification: 'Perfil A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orientações de cuidado').last);
    await tester.pumpAndSettle();

    expect(find.text('Perfil B'), findsOneWidget);
    expect(find.text('Perfil A'), findsNothing);
  });

  testWidgets('profile edit rejects a draft returned for another child', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          childId: 'child-demo-a',
          loadDraft: (_) async => HealthCareProfileDraft(
            childId: 'child-demo-b',
            justification: 'Dados de outra criança',
          ),
          onCancel: () {},
          onSaved: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('O perfil retornado não corresponde à criança solicitada.'), findsOneWidget);
    expect(find.text('Dados de outra criança'), findsNothing);
  });

  testWidgets('switching from edit to create clears the previous child draft', (tester) async {
    Widget page({required String? childId}) => MaterialApp(
      theme: CoeloTheme.light,
      home: HealthCareProfileFormPage(
        logout: unavailableSuperadminLogout,
        childOptions: _profileChildren,
        childId: childId,
        loadDraft: (_) async => HealthCareProfileDraft(
          childId: 'child-demo-a',
          justification: 'Dado sensível anterior',
          importantSigns: 'Sinal anterior',
          careItemIds: const {'allergy'},
        ),
        onCancel: () {},
        onSaved: (_) async {},
      ),
    );

    await tester.pumpWidget(page(childId: 'child-demo-a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orientações de cuidado').last);
    await tester.pumpAndSettle();
    expect(find.text('Dado sensível anterior'), findsOneWidget);

    await tester.pumpWidget(page(childId: null));
    await tester.pumpAndSettle();
    expect(find.text('Dado sensível anterior'), findsNothing);
    expect(find.text('Sinal anterior'), findsNothing);
    expect(find.text('Selecione a criança que receberá o perfil.'), findsOneWidget);
  });

  testWidgets('pending save cannot complete the route that replaced it', (tester) async {
    final pending = Completer<void>();
    var successA = 0;
    var successB = 0;
    var savesB = 0;
    Widget page({
      required String childId,
      required HealthCareProfileFormSave save,
      required VoidCallback onSuccess,
    }) => MaterialApp(
      theme: CoeloTheme.light,
      home: HealthCareProfileFormPage(
        logout: unavailableSuperadminLogout,
        childOptions: _profileChildren,
        childId: childId,
        loadDraft: (id) async => HealthCareProfileDraft(
          childId: id,
          justification: id == 'child-demo-a' ? 'Perfil A' : 'Perfil B',
        ),
        onCancel: () {},
        onSaved: save,
        onSaveSucceeded: onSuccess,
      ),
    );

    await tester.pumpWidget(
      page(childId: 'child-demo-a', save: (_) => pending.future, onSuccess: () => successA++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pump();

    await tester.pumpWidget(
      page(childId: 'child-demo-b', save: (_) async => savesB++, onSuccess: () => successB++),
    );
    await tester.pumpAndSettle();
    pending.complete();
    await tester.pumpAndSettle();
    expect(successA, 0);
    expect(find.text('Perfil B'), findsNothing);

    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();
    expect(savesB, 1);
    expect(successB, 1);
  });

  testWidgets('same child callback swap releases saving without stale success', (tester) async {
    final pending = Completer<void>();
    var oldSuccess = 0;
    var newSuccess = 0;
    var newSaves = 0;
    Future<HealthCareProfileDraft?> load(String id) async =>
        HealthCareProfileDraft(childId: id, justification: 'Perfil atual');
    Widget page({required HealthCareProfileFormSave save, required VoidCallback onSuccess}) =>
        MaterialApp(
          theme: CoeloTheme.light,
          home: HealthCareProfileFormPage(
            logout: unavailableSuperadminLogout,
            childOptions: _profileChildren,
            childId: 'child-demo-a',
            loadDraft: load,
            onCancel: () {},
            onSaved: save,
            onSaveSucceeded: onSuccess,
          ),
        );

    await tester.pumpWidget(page(save: (_) => pending.future, onSuccess: () => oldSuccess++));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pump();

    await tester.pumpWidget(page(save: (_) async => newSaves++, onSuccess: () => newSuccess++));
    await tester.pump();
    pending.complete();
    await tester.pumpAndSettle();
    expect(oldSuccess, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();
    expect(newSaves, 1);
    expect(newSuccess, 1);
  });

  testWidgets('profile load failure offers retry and recovers', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          childId: 'child-demo-a',
          loadDraft: (_) async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
            return HealthCareProfileDraft(childId: 'child-demo-a', justification: 'Recuperado');
          },
          onCancel: () {},
          onSaved: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byKey(const Key('health-care-profile-form-unavailable')), findsNothing);
  });

  testWidgets('profile save failure preserves the draft and retries once', (tester) async {
    var attempts = 0;
    final initial = HealthCareProfileDraft(
      childId: 'child-demo-a',
      allergyType: HealthCareAllergyType.food,
      allergyStatus: HealthCareAllergyStatus.active,
      lastEpisode: '20/08/2026',
      severity: HealthCareEpisodeSeverity.moderate,
      observedReaction: 'Urticária',
      allergyGuidance: 'Observar',
      allergyNotes: 'Sem medicação',
      careItemIds: const {'allergy'},
      importantSigns: 'Coceira',
      adaptations: 'Evitar alimento',
      justification: 'Atualização familiar',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          childId: initial.childId,
          loadDraft: (_) async => initial,
          onCancel: () {},
          onSaved: (_) async {
            attempts++;
            if (attempts == 1) throw StateError('offline');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revisão').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(
      find.text('Não foi possível salvar. Revise os dados e tente novamente.'),
      findsOneWidget,
    );
    expect(find.text('Atualização familiar'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets('dirty profile asks before cancelling and preserves editing on dismiss', (
    tester,
  ) async {
    var cancels = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          onCancel: () => cancels++,
          onSaved: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alergias e restrições').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Reação observada'), 'Urticária');
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('health-care-profile-confirm-exit-dialog')), findsOneWidget);
    expect(cancels, 0);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Continuar editando'));
    await tester.pumpAndSettle();
    expect(cancels, 0);

    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sair sem salvar'));
    await tester.pumpAndSettle();
    expect(cancels, 1);
  });

  testWidgets('medication plan separates medicine, period, schedules and document', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.dark,
        home: HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Criança e medicamento'), findsWidgets);
    expect(find.text('Vigência'), findsOneWidget);
    expect(find.text('Horários e responsáveis'), findsOneWidget);
    await tester.tap(find.text('Horários e responsáveis'));
    await tester.pumpAndSettle();
    expect(find.text('Responsável'), findsOneWidget);
    await tester.tap(find.text('Documento'));
    await tester.pumpAndSettle();
    expect(find.text('Prescrição'), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
  });

  for (final textScale in [1.0, 2.0]) {
    testWidgets('mobile launchers clear both form footers at ${textScale}x text', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final page in <Widget>[
        HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          onCancel: () {},
          onSaved: (_) async {},
        ),
        HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();

        final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
        final footer = find.byType(SuperadminFormActionFooter);
        final primaryAction = find.widgetWithText(FilledButton, 'Continuar');
        final reason = '${page.runtimeType} at ${textScale}x';
        expect(launcher, findsOneWidget, reason: reason);
        expect(footer, findsOneWidget, reason: reason);
        expect(primaryAction, findsOneWidget, reason: reason);
        expect(tester.getRect(launcher).overlaps(tester.getRect(footer)), isFalse, reason: reason);
        expect(
          tester.getRect(launcher).overlaps(tester.getRect(primaryAction)),
          isFalse,
          reason: reason,
        );
      }
    });
  }

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('both forms have no overflow at $width with 200% text', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final page in <Widget>[
        HealthCareProfileFormPage(
          logout: unavailableSuperadminLogout,
          childOptions: _profileChildren,
          onCancel: () {},
          onSaved: (_) async {},
        ),
        HealthMedicationPlanFormPage(
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onSaved: () async {},
        ),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: CoeloTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: page,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
