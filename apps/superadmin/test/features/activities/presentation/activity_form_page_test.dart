import 'package:coelo_superadmin/features/activities/data/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_page.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_draft.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses the four-step institution baseline and chained categories', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('step-identidade'))).right,
      lessThan(tester.getRect(find.byKey(const Key('activity-form-name'))).left),
    );
    for (final label in [
      'Identidade',
      'Estrutura e locais',
      'Vínculos',
      'Profissionais e revisão',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byKey(const Key('activity-form-name')), findsOneWidget);
    expect(find.byKey(const Key('activity-form-category')), findsOneWidget);
    expect(find.text('Simples/Opcional'), findsOneWidget);

    final category = tester.widget<CoeloAdminSingleSelectField<ActivityCategory?>>(
      find.byKey(const Key('activity-form-category')),
    );
    category.onChanged(ActivityCategory.languages);
    await tester.pump();
    final suggestion = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('activity-form-suggestion')),
    );
    expect(suggestion.options, ['', 'Português', 'Inglês', 'Outro']);
    suggestion.onChanged('Outro');
    await tester.pump();
    expect(find.byKey(const Key('activity-form-other')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saves a minimum draft then completes links and professional permissions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ActivityFormDraft? savedDraft;
    ActivityFormDraft? submittedDraft;

    await tester.pumpWidget(
      _app(
        onSaveDraft: (draft) async => savedDraft = draft,
        onSubmit: (draft) async => submittedDraft = draft,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();

    final institution = tester.widget<CoeloAdminSingleSelectField<String>>(
      find.byKey(const Key('activity-form-institution')),
    );
    institution.onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('activity-form-save-draft')));
    await tester.pumpAndSettle();
    expect(savedDraft?.unitIds, {'institution-1-unit-1'});

    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-group-institution-1-group-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('activity-invite-institution-1-group-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-professional-professional-1')));
    await tester.pump();
    await tester.tap(find.text('Concluir convite'));
    await tester.pumpAndSettle();

    final toggles = tester
        .widgetList<CoeloAdminToggleField>(find.byType(CoeloAdminToggleField))
        .toList();
    expect(toggles, hasLength(4));

    await tester.tap(find.byKey(const Key('activity-form-submit')));
    await tester.pumpAndSettle();
    expect(submittedDraft?.groupIds, {'institution-1-group-1'});
    expect(submittedDraft?.assignments.single.permissions.happens, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a unit-scoped local and keeps edit institution fixed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Música');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-form-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-create-location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('activity-create-location-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('activity-location-name')), 'Sala maker');
    await tester.tap(find.byKey(const Key('activity-location-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Sala maker'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app(activityId: 'activity-3'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('step-identidade')));
    await tester.pump();
    final governance = tester.widget<CoeloAdminSingleSelectField<ActivityGovernance>>(
      find.byKey(const Key('activity-form-governance')),
    );
    expect(governance.enabled, isFalse);
    expect(governance.value, ActivityGovernance.fixed);
  });

  testWidgets('preserves a complete initial draft through the edit page contract', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ActivityFormDraft? savedDraft;
    const initialDraft = ActivityFormDraft(
      name: 'Ingl\u00EAs avan\u00E7ado',
      description: 'Conversa\u00E7\u00E3o para a Turma 1.',
      category: ActivityCategory.languages,
      activityLabel: 'Ingl\u00EAs',
      governance: ActivityGovernance.optional,
      institutionId: 'institution-1',
      unitIds: {'institution-1-unit-1'},
      locationId: 'institution-1-unit-1-location-1',
      groupIds: {'institution-1-group-1'},
      assignments: [
        ActivityProfessionalAssignment(
          groupId: 'institution-1-group-1',
          professionalId: 'professional-1',
          permissions: ActivityProfessionalPermissions(
            happens: true,
            now: false,
            moments: true,
            chat: false,
          ),
        ),
      ],
      imageName: 'atividade.png',
    );

    await tester.pumpWidget(
      _app(
        activityId: 'activity-1',
        initialDraft: initialDraft,
        onSaveDraft: (draft) async => savedDraft = draft,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(find.byKey(const Key('activity-form-name'))).controller?.text,
      'Ingl\u00EAs avan\u00E7ado',
    );
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<ActivityCategory?>>(
            find.byKey(const Key('activity-form-category')),
          )
          .value,
      ActivityCategory.languages,
    );

    await tester.tap(find.byKey(const Key('activity-form-save-draft')));
    await tester.pumpAndSettle();

    expect(savedDraft?.activityLabel, 'Ingl\u00EAs');
    expect(savedDraft?.institutionId, 'institution-1');
    expect(savedDraft?.unitIds, {'institution-1-unit-1'});
    expect(savedDraft?.locationId, 'institution-1-unit-1-location-1');
    expect(savedDraft?.groupIds, {'institution-1-group-1'});
    expect(savedDraft?.assignments.single.professionalId, 'professional-1');
    expect(savedDraft?.assignments.single.permissions.now, isFalse);
    expect(savedDraft?.assignments.single.permissions.chat, isFalse);
    expect(savedDraft?.imageName, 'atividade.png');
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks local selector and create action at full width on compact screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('activity-form-name')), 'Robótica');
    await tester.tap(find.byKey(const Key('activity-form-continue')));
    await tester.pumpAndSettle();
    tester
        .widget<CoeloAdminSingleSelectField<String>>(
          find.byKey(const Key('activity-form-institution')),
        )
        .onChanged('institution-1');
    await tester.pump();
    await tester.tap(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pump();

    final selectorRect = tester.getRect(find.byKey(const Key('activity-form-location')));
    final actionRect = tester.getRect(find.byKey(const Key('activity-create-location')));
    expect(actionRect.top, greaterThan(selectorRect.bottom));
    expect(actionRect.width, closeTo(selectorRect.width, 1));
    expect(tester.takeException(), isNull);
  });
}

Widget _app({
  String? activityId,
  ActivityFormDraft? initialDraft,
  Future<void> Function(ActivityFormDraft)? onSaveDraft,
  Future<void> Function(ActivityFormDraft)? onSubmit,
}) => MaterialApp(
  theme: CoeloTheme.light,
  home: ActivityFormPage(
    activityId: activityId,
    initialDraft: initialDraft,
    repository: FakeActivityDirectoryRepository(),
    logout: () async => const LogoutResult.success(),
    onCancel: () {},
    onSaveDraft: onSaveDraft ?? (_) async {},
    onSubmit: onSubmit ?? (_) async {},
    onCreateLocation: (draft) async =>
        ActivityFormLocationOption(id: 'session-location', unitId: draft.unitId, name: draft.name),
    imagePicker: () async => null,
  ),
);
