import 'package:coelo_superadmin/features/activities/data/fake_activity_directory_repository.dart';
import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_page.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_form_draft.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_frame.dart';
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
    expect(find.byType(SuperadminFormFrame), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.textContaining(RegExp(r'apenas nesta sess', caseSensitive: false)), findsNothing);
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

  testWidgets('uses the medium form inset at 768 pixels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(768, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    final outerPadding = tester
        .widgetList<Padding>(
          find.ancestor(
            of: find.byKey(const Key('activity-form-scroll')),
            matching: find.byType(Padding),
          ),
        )
        .firstWhere((widget) {
          final padding = widget.padding;
          return padding is EdgeInsets &&
              padding.bottom == CoeloSpacing.space4 &&
              padding.left == padding.top &&
              padding.left == padding.right;
        });
    expect((outerPadding.padding as EdgeInsets).left, CoeloSpacing.space6);
    final navigation = tester.getRect(find.byType(SuperadminFormStepNavigation));
    final scroll = tester.getRect(find.byKey(const Key('activity-form-scroll')));
    final footer = tester.getRect(find.byKey(const Key('activity-form-footer-surface')));
    expect(navigation.width, 248);
    expect(scroll.left - navigation.right, closeTo(CoeloSpacing.space6, 1));
    expect(footer.left, greaterThanOrEqualTo(navigation.right + CoeloSpacing.space6));
  });

  testWidgets('keeps the compact chat launcher above the canonical footer', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    final launcher = find.byKey(const Key('superadmin-chat-launcher-surface'));
    final footer = find.byKey(const Key('activity-form-footer-surface'));
    expect(launcher, findsOneWidget);
    expect(
      tester.getBottomLeft(launcher).dy,
      lessThanOrEqualTo(tester.getTopLeft(footer).dy - CoeloSpacing.space4),
    );
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
        repository: _ProfessionalOptionsRepository(),
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
    expect(find.text('Marina Costa'), findsOneWidget);
    expect(find.text('Rafael Lima'), findsNothing);
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
    expect(submittedDraft?.assignments.single.groupId, 'institution-1-group-1');
    expect(submittedDraft?.assignments.single.professionalId, 'professional-1');
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
    tester.view.physicalSize = const Size(375, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    await tester.ensureVisible(find.byKey(const Key('activity-unit-institution-1-unit-1')));
    await tester.pumpAndSettle();
    await tester.pump();

    final selectorRect = tester.getRect(find.byKey(const Key('activity-form-location')));
    final actionRect = tester.getRect(find.byKey(const Key('activity-create-location')));
    expect(actionRect.top, greaterThan(selectorRect.bottom));
    expect(actionRect.width, closeTo(selectorRect.width, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports 200 percent text at all approved widths', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
      await tester.pumpAndSettle();
      if (width < 768) {
        expect(find.text('Etapa 1 de 4'), findsOneWidget);
      } else {
        expect(find.text('Etapa 1 de 4'), findsNothing);
        expect(tester.getSize(find.byType(SuperadminFormStepNavigation)).width, 248);
      }
      expect(tester.takeException(), isNull, reason: '$width overflow');
    }
  });
}

Widget _app({
  String? activityId,
  ActivityFormDraft? initialDraft,
  ActivityDirectoryRepository? repository,
  Future<void> Function(ActivityFormDraft)? onSaveDraft,
  Future<void> Function(ActivityFormDraft)? onSubmit,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: ActivityFormPage(
    activityId: activityId,
    initialDraft: initialDraft,
    repository: repository ?? FakeActivityDirectoryRepository(),
    logout: () async => const LogoutResult.success(),
    onCancel: () {},
    onSaveDraft: onSaveDraft ?? (_) async {},
    onSubmit: onSubmit ?? (_) async {},
    onCreateLocation: (draft) async =>
        ActivityFormLocationOption(id: 'session-location', unitId: draft.unitId, name: draft.name),
    imagePicker: () async => null,
  ),
);

final class _ProfessionalOptionsRepository implements ActivityDirectoryRepository {
  final FakeActivityDirectoryRepository _delegate = FakeActivityDirectoryRepository();

  @override
  Future<ActivityDetail?> fetchById(String activityId) => _delegate.fetchById(activityId);

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() => _delegate.fetchFilterOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions() async {
    final options = await _delegate.fetchFormOptions();
    return ActivityFormOptions(
      institutions: options.institutions,
      units: options.units,
      locations: options.locations,
      groups: options.groups,
      professionals: const [
        ActivityFormProfessionalOption(
          id: 'professional-1',
          name: 'Marina Costa',
          role: 'Professora',
        ),
      ],
    );
  }

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) =>
      _delegate.fetchPage(query);
}
