import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_attendance_repository.dart';

void main() {
  testWidgets('new call uses the canonical single-date picker and restores keyboard focus', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) {},
        ),
        textScaler: const TextScaler.linear(2),
      ),
    );
    await tester.pumpAndSettle();

    final trigger = tester.widget<OutlinedButton>(find.byKey(const Key('attendance-date-picker')));
    trigger.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(CoeloDateRangePicker), findsOneWidget);
    expect(find.text('Esta semana'), findsNothing);
    expect(tester.takeException(), isNull);

    final today = DateUtils.dateOnly(DateTime.now());
    final selected = today.subtract(const Duration(days: 1));
    if (today.day == 1) {
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
    }
    final selectedKey = ValueKey(
      'coelo-date-${selected.year.toString().padLeft(4, '0')}-'
      '${selected.month.toString().padLeft(2, '0')}-'
      '${selected.day.toString().padLeft(2, '0')}',
    );
    await tester.tap(find.byKey(selectedKey));
    await tester.ensureVisible(find.byKey(const ValueKey('coelo-date-range-apply')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('coelo-date-range-apply')));
    await tester.pumpAndSettle();

    expect(find.text('Data da chamada · ${_testDate(selected)}'), findsOneWidget);
    expect(trigger.focusNode!.hasFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CoeloDateRangePicker), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CoeloDateRangePicker), findsNothing);
    expect(trigger.focusNode!.hasFocus, isTrue);
  });

  testWidgets('new call starts in the context step with canonical form controls', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.text('Contexto da chamada'), findsOneWidget);
    expect(find.text('Rotina diária'), findsOneWidget);
    expect(find.text('Chamada'), findsOneWidget);
    expect(find.text('Instituição'), findsOneWidget);
    expect(find.text('Unidade'), findsOneWidget);
    expect(find.text('Turma'), findsWidgets);
    expect(find.byKey(const Key('attendance-date-picker')), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continuar'), findsOneWidget);
  });

  testWidgets('new call opens Chamada directly from the step navigation', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    String? createdCallId;

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (id) => createdCallId = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chamada'));
    await tester.pump();

    expect(createdCallId, isNotNull);
    expect(await repository.fetchCall(createdCallId!), isNotNull);
  });

  testWidgets('new call accepts a prefilled activity context', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) {},
          initialInstitutionId: 'institution-1',
          initialUnitId: 'unit-1',
          initialGroupId: 'group-sun',
          initialActivityId: 'activity-music-group-sun',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Instituto Horizonte'), findsOneWidget);
    expect(find.text('Unidade Centro'), findsOneWidget);
    expect(find.text('Turma Sol'), findsWidgets);
    expect(find.text('Atividade'), findsOneWidget);
    expect(find.text('M\u00fasica'), findsOneWidget);
  });
  testWidgets('new call adapts without overflow at Coelo breakpoints and 200 percent text', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(375, 900), Size(768, 900), Size(1024, 900), Size(1440, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _app(
          AttendanceNewCallPage(
            repository: repository,
            permissions: const AttendancePermissions.owner(),
            logout: unavailableSuperadminLogout,
            onCancel: () {},
            onCreated: (_) {},
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow at ${size.width}px');
    }
  });
  testWidgets('attendance landing renders the authorized analytical dashboard', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: true);

    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          dashboardRepository: dashboard,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visão geral da assiduidade'), findsOneWidget);
    expect(find.text('Nova chamada'), findsOneWidget);
    expect(find.text('Presença geral'), findsOneWidget);
    expect(find.text('Atenção necessária'), findsOneWidget);
    expect(find.text('Desempenho por contexto'), findsOneWidget);
    expect(find.text('Presença no período'), findsOneWidget);
    expect(find.text('Últimas chamadas'), findsOneWidget);
    expect(find.byType(CoeloAdminResizableTable<AttendanceDashboardCallRow>), findsOneWidget);
  });

  testWidgets('read-only administrator has no write action', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: false);

    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          dashboardRepository: dashboard,
          permissions: const AttendancePermissions.readOnly(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nova chamada'), findsNothing);
    expect(find.text('Presença geral'), findsOneWidget);
  });

  testWidgets('dashboard has no overflow at the four required widths', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: true);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(375, 900), Size(768, 900), Size(1024, 900), Size(1440, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _app(
          AttendanceDashboardPage(
            repository: repository,
            dashboardRepository: dashboard,
            permissions: const AttendancePermissions.owner(),
            logout: unavailableSuperadminLogout,
            onCreate: () {},
            onOpenCall: (_) {},
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at ${size.width}px');
    }
  });

  testWidgets('ranking overlay uses the Coelo shell and restores keyboard focus on Esc', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: true);
    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          dashboardRepository: dashboard,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final trigger = find.widgetWithText(TextButton, 'Ver todos');
    await tester.ensureVisible(trigger);
    final triggerElement = tester.element(trigger);
    bool focusIsInsideTrigger() {
      final focusContext = FocusManager.instance.primaryFocus?.context;
      if (focusContext == null) return false;
      var found = focusContext == triggerElement;
      focusContext.visitAncestorElements((ancestor) {
        found = found || ancestor == triggerElement;
        return !found;
      });
      return found;
    }

    for (var index = 0; index < 30 && !focusIsInsideTrigger(); index++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focusIsInsideTrigger(), isTrue);
    final triggerFocus = FocusManager.instance.primaryFocus!;
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminDialogShell), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(CoeloAdminDialogShell), findsNothing);
    expect(triggerFocus.hasFocus, isTrue);
  });

  testWidgets('only authorized calls expose an accessible open action', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    String? opened;
    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          dashboardRepository: _DashboardRepository(canCreate: true),
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (id) => opened = id,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('attendance-open-call-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-open-call-blocked')), findsNothing);
    final action = tester.widget<IconButton>(find.byKey(const ValueKey('attendance-open-call-1')));
    expect(action.onPressed, isNotNull);
    action.onPressed!();
    expect(opened, 'call-1');
  });

  testWidgets('failed refresh keeps snapshot with a live retry banner', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: true);
    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          dashboardRepository: dashboard,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    dashboard.failNext = true;
    await tester.enterText(find.byType(CoeloSearchField), 'turma');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível atualizar. Exibindo os últimos dados.'), findsOneWidget);
    expect(find.text('Presença geral'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível atualizar. Exibindo os últimos dados.'), findsNothing);
  });

  testWidgets('call page marks remaining and then completes', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Concluir chamada'), findsOneWidget);
    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.byKey(const Key('attendance-participant-list')), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Presente'), findsNWidgets(3));
    expect(find.widgetWithText(OutlinedButton, 'Falta'), findsNWidgets(3));
    expect(find.widgetWithText(OutlinedButton, 'Atraso'), findsNWidgets(3));
    expect(find.widgetWithText(OutlinedButton, 'Saída antecipada'), findsNWidgets(3));
    expect(find.text('Visualizar como professor'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Concluir chamada')).onPressed,
      isNull,
    );

    final absenceAction = find.widgetWithText(OutlinedButton, 'Falta').first;
    final absenceButton = tester.widget<OutlinedButton>(absenceAction);
    final colors = Theme.of(tester.element(absenceAction)).colorScheme;
    expect(absenceButton.style?.foregroundColor?.resolve({}), colors.error);
    expect(
      absenceButton.style?.backgroundColor?.resolve({WidgetState.hovered}),
      colors.errorContainer,
    );
    await tester.ensureVisible(absenceAction);
    await tester.pump();
    await tester.tap(absenceAction);
    await tester.pump();
    expect(
      (await repository.fetchCall('call-progress'))!.participants.first.state,
      AttendancePresenceState.absent,
    );

    final markRemaining = find.text('Marcar todos restantes como presentes');
    await tester.ensureVisible(markRemaining);
    await tester.pump();
    await tester.tap(markRemaining);
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Concluir chamada')).onPressed,
      isNotNull,
    );
    final clearMarked = find.text('Desmarcar todos');
    expect(clearMarked, findsOneWidget);
    await tester.tap(clearMarked);
    await tester.pumpAndSettle();

    final call = (await repository.fetchCall('call-progress'))!;
    expect(call.participants.first.state, AttendancePresenceState.absent);
    expect(call.participants.last.state, AttendancePresenceState.unmarked);
    expect(find.text('Marcar todos restantes como presentes'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Concluir chamada')).onPressed,
      isNull,
    );
  });

  testWidgets('call page marks one participant across every individual state', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final entry in const <(String, AttendancePresenceState)>[
      ('Presente', AttendancePresenceState.present),
      ('Falta', AttendancePresenceState.absent),
      ('Atraso', AttendancePresenceState.late),
      ('Saída antecipada', AttendancePresenceState.earlyDeparture),
      ('Atraso + sa\u00edda', AttendancePresenceState.lateAndEarly),
    ]) {
      final action = find.widgetWithText(OutlinedButton, entry.$1).first;
      await tester.ensureVisible(action);
      await tester.pump();
      await tester.tap(action);
      await tester.pump();

      expect((await repository.fetchCall('call-progress'))!.participants.first.state, entry.$2);
      final participantCard = find
          .ancestor(
            of: find.byKey(const Key('attendance-participant-identity-participant-1')),
            matching: find.byType(ColoredBox),
          )
          .first;
      expect(
        find.descendant(
          of: participantCard,
          matching: find.byKey(Key('attendance-status-${entry.$2.name}')),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('Falta and Atraso status labels use their semantic color families', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-completed',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final colors = Theme.of(tester.element(find.byType(AttendanceCallPage))).colorScheme;
    final statusColors = Theme.of(
      tester.element(find.byType(AttendanceCallPage)),
    ).extension<CoeloStatusColors>()!;
    final absenceFinder = find.byKey(const Key('attendance-status-absent'));
    final lateFinder = find.byKey(const Key('attendance-status-late'));
    expect(absenceFinder, findsOneWidget);
    expect(lateFinder, findsOneWidget);
    final absence = tester.widget<DecoratedBox>(absenceFinder);
    final late = tester.widget<DecoratedBox>(lateFinder);

    expect((absence.decoration as BoxDecoration).color, colors.errorContainer);
    expect((late.decoration as BoxDecoration).color, statusColors.warningContainer);
  });

  testWidgets('Atraso action uses warning colors at rest hover and focus', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.widgetWithText(OutlinedButton, 'Atraso').first;
    final button = tester.widget<OutlinedButton>(action);
    final statusColors = Theme.of(tester.element(action)).extension<CoeloStatusColors>()!;
    expect(button.style?.foregroundColor?.resolve({}), statusColors.warning);
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.hovered}),
      statusColors.warningContainer,
    );
    expect(
      button.style?.backgroundColor?.resolve({WidgetState.focused}),
      statusColors.warningContainer,
    );
    expect(button.style?.overlayColor?.resolve({WidgetState.pressed}), Colors.transparent);
  });

  testWidgets('assigned teacher operates the canonical call flow', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.teacher(assignedGroupIds: {'group-sun'}),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Presente').first)
          .onPressed,
      isNotNull,
    );
    expect(find.text('Visualizar como professor'), findsNothing);
  });

  testWidgets('participant list preserves Coelo radius and clipping', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = find.byKey(const Key('attendance-participant-list'));
    final decoration = tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
    final clip = tester.widget<ClipRRect>(
      find.descendant(of: surface, matching: find.byType(ClipRRect)),
    );
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.lg));
    expect(clip.borderRadius, BorderRadius.circular(CoeloRadius.lg));
  });

  testWidgets('call flow adapts at Coelo breakpoints without overflow', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(375, 900), Size(768, 900), Size(1024, 900), Size(1440, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _app(
          AttendanceCallPage(
            repository: repository,
            callId: 'call-progress',
            permissions: const AttendancePermissions.owner(),
            logout: unavailableSuperadminLogout,
            onBack: () {},
          ),
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow at ${size.width}px');
      if (size.width <= 1024) {
        final identity = tester.getRect(
          find.byKey(const Key('attendance-participant-identity-participant-1')),
        );
        final status = tester.getRect(find.byKey(const Key('attendance-status-unmarked')).first);
        final actions = tester.getRect(
          find.byKey(const Key('attendance-participant-actions-participant-1')),
        );
        expect(identity.bottom, lessThanOrEqualTo(status.top));
        expect(status.bottom, lessThanOrEqualTo(actions.top));
      }
    }
  });

  testWidgets('call page expands the first pending routine supplied by the UI seam', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repository,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
          routinePendingParticipantIds: const {'participant-1'},
          participantRoutineBuilder: (context, participant) =>
              Text('Rotina de ${participant.name}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rotina diária'), findsWidgets);
    expect(find.text('1 obrigatória pendente'), findsOneWidget);
    expect(find.text('Rotina de Lia Horizonte'), findsOneWidget);
  });
}

String _testDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

Widget _app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: CoeloTheme.light,
  builder: (context, appChild) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: appChild!,
  ),
  home: child,
);

final class _DashboardRepository implements AttendanceDashboardRepository {
  _DashboardRepository({required this.canCreate});
  final bool canCreate;
  bool failNext = false;

  AttendanceDashboardAccess get _access => AttendanceDashboardAccess(
    scope: AttendanceDashboardScope.platform,
    canRead: true,
    canCreateCall: canCreate,
  );

  @override
  Future<AttendanceDashboardAccess> fetchAccess() async => _access;

  @override
  Future<AttendanceDashboardSnapshot> fetchDashboard(AttendanceDashboardQuery query) async {
    if (failNext) {
      failNext = false;
      throw StateError('offline');
    }
    final rate = AttendanceRate.fromCounts(
      present: 18,
      late: 1,
      earlyDeparture: 0,
      lateAndEarly: 0,
      absent: 1,
    );
    final ranking = AttendanceRanking(
      kind: AttendanceRankingKind.institutions,
      total: 4,
      direction: query.rankingDirection,
      items: [AttendanceRankingItem(id: 'institution-1', label: 'Instituto Horizonte', rate: rate)],
    );
    return AttendanceDashboardSnapshot(
      access: _access,
      query: query,
      kpis: AttendanceDashboardKpis(presence: rate, pendingCalls: 2, absences: 1, inReview: 1),
      attention: const [
        AttendanceAttentionItem(
          id: 'pending',
          label: 'chamadas pendentes',
          detail: 'Aguardando conclusão',
          count: 2,
        ),
      ],
      rankings: [ranking],
      series: [
        AttendanceSeriesPoint(
          start: query.periodStart,
          label: 'Início',
          current: rate,
          absences: 1,
          late: 1,
        ),
        AttendanceSeriesPoint(
          start: query.periodEnd,
          label: 'Fim',
          current: rate,
          absences: 0,
          late: 0,
        ),
      ],
      calls: AttendanceDashboardCallPage(
        items: [
          AttendanceDashboardCallRow(
            id: 'call-1',
            context: 'Instituto Horizonte · Unidade Centro · Turma Sol',
            date: query.periodEnd,
            responsible: 'Equipe pedagógica',
            present: 19,
            absent: 1,
            late: 1,
            presence: rate,
            status: AttendanceDashboardCallStatus.completed,
            canOpen: true,
          ),
          AttendanceDashboardCallRow(
            id: 'call-blocked',
            context: 'Contexto restrito',
            date: query.periodEnd,
            responsible: 'Equipe pedagógica',
            present: 0,
            absent: 0,
            late: 0,
            presence: AttendanceRate.fromCounts(
              present: 0,
              late: 0,
              earlyDeparture: 0,
              lateAndEarly: 0,
              absent: 0,
            ),
            status: AttendanceDashboardCallStatus.pending,
            canOpen: false,
          ),
        ],
        page: query.page,
        pageSize: query.pageSize,
        totalItems: 2,
      ),
      contextLabel: 'Todas as instituições',
    );
  }

  @override
  Future<AttendanceRanking> fetchRanking({
    required AttendanceDashboardQuery query,
    required AttendanceRankingKind kind,
    required int page,
    required int pageSize,
  }) async {
    final rate = AttendanceRate.fromCounts(
      present: 9,
      late: 0,
      earlyDeparture: 0,
      lateAndEarly: 0,
      absent: 1,
    );
    return AttendanceRanking(
      kind: kind,
      total: 4,
      direction: query.rankingDirection,
      items: List.generate(
        4,
        (index) => AttendanceRankingItem(
          id: 'institution-${index + 1}',
          label: 'Instituição ${index + 1}',
          rate: rate,
        ),
      ),
    );
  }

  @override
  Future<AttendanceDashboardExportJob> requestExport({
    required AttendanceDashboardQuery query,
    required AttendanceDashboardExportKind kind,
    required AttendanceDashboardExportFormat format,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<AttendanceDashboardExportJob> fetchExportJob(String id) => throw UnimplementedError();
}
