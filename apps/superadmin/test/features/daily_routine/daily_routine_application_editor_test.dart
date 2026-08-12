import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine.dart';
import 'package:coelo_superadmin/features/daily_routine/daily_routine_form_sections.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('does not surface application creation without an authorized context', (
    tester,
  ) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-application-editor')), findsNothing);
    expect(
      find.text('Crie uma rotina aplicada a partir de um contexto autorizado.'),
      findsOneWidget,
    );
  });

  testWidgets('reverts a customized application through the repository', (tester) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryId: 'application-id',
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('daily-routine-inheritance-reset')));
    await tester.pumpAndSettle();

    expect(repository.revertedApplicationId, 'application-id');
  });

  testWidgets('renders scheduled fields and never exposes raw scope identifiers', (tester) async {
    final repository = _RoutineRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: DailyRoutineWizardPage(
          repository: repository,
          logout: unavailableSuperadminLogout,
          entryId: 'application-id',
          entryKind: RoutineEntryKind.application,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('daily-routine-application-starts-at')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-application-ends-at')), findsOneWidget);
    expect(find.byKey(const Key('daily-routine-application-model-version')), findsNothing);
    expect(find.textContaining('00000000-0000'), findsNothing);
  });
}

final class _RoutineRepository implements RoutineRepository {
  RoutineApplication? savedApplication;
  String? revertedApplicationId;

  @override
  Future<RoutineApplication> fetchApplication(String id) async => const RoutineApplication(
    id: 'application-id',
    modelVersionId: 'model-version',
    institutionId: 'institution',
    status: RoutineApplicationStatus.active,
    inheritanceMode: RoutineInheritanceMode.customized,
    effectiveVersion: 3,
    expectedVersion: 2,
    startsAt: '08:00',
    endsAt: '12:00',
    assignees: [
      RoutineApplicationAssignee(
        membershipId: '00000000-0000-4000-8000-000000000015',
        responsibility: RoutineApplicationResponsibility.publish,
      ),
    ],
    canManage: true,
  );

  @override
  Future<String> saveApplication(
    RoutineApplication application, {
    required String requestId,
  }) async {
    savedApplication = application;
    return application.id.isEmpty ? 'created-application' : application.id;
  }

  @override
  Future<String> revertApplicationCustomization({
    required String applicationId,
    required int expectedVersion,
    required String requestId,
  }) async {
    revertedApplicationId = applicationId;
    return applicationId;
  }

  @override
  Future<RoutineDirectoryPage> fetchPage(RoutineDirectoryQuery query) async =>
      throw UnimplementedError();
  @override
  Future<RoutineModel> fetchModel(String id) async => throw UnimplementedError();
  @override
  Future<RoutineLaunch> fetchLaunch(String id) async => throw UnimplementedError();
  @override
  Future<String> saveModel(RoutineModel model, {required String requestId}) async =>
      throw UnimplementedError();
  @override
  Future<String> saveLaunchDraft(RoutineLaunch launch, {required String requestId}) async =>
      throw UnimplementedError();
  @override
  Future<void> publishLaunch({
    required String launchId,
    required int expectedVersion,
    required String requestId,
  }) async => throw UnimplementedError();
  @override
  Future<void> correctLaunch({
    required String launchId,
    required int expectedVersion,
    required String reason,
    required String requestId,
    required List<RoutineAnswerCorrection> corrections,
  }) async => throw UnimplementedError();
}
