import 'dart:async';

import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/app/shell/superadmin_shell.dart';
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
  for (final configuration in [
    (375.0, 2.0, false),
    (768.0, 1.0, true),
    (1024.0, 1.0, false),
    (1440.0, 1.0, true),
  ]) {
    testWidgets('dashboard exports are informative only at ${configuration.$1}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(configuration.$1, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = FakeAttendanceRepository.seeded();
      addTearDown(repository.dispose);
      final dashboard = _DashboardRepository(canCreate: configuration.$3);
      await tester.pumpWidget(
        _app(
          AttendanceDashboardPage(
            repository: repository,
            dashboardRepository: dashboard,
            permissions: const AttendancePermissions.owner(),
            logout: unavailableSuperadminLogout,
            onCreate: configuration.$3 ? () {} : null,
            onOpenCall: (_) {},
          ),
          textScaler: TextScaler.linear(configuration.$2),
          brightness: configuration.$3 ? Brightness.dark : Brightness.light,
        ),
      );
      await tester.pumpAndSettle();
      final trigger = find.byKey(const Key('coelo-admin-files-action'));
      expect(trigger, findsOneWidget);
      expect(tester.getSize(trigger).height, greaterThanOrEqualTo(CoeloSize.touchMin));
      for (final label in ['Exportar CSV', 'Exportar XLSX']) {
        await tester.ensureVisible(trigger);
        await tester.pumpAndSettle();
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(find.text('Disponível depois do MVP'), findsWidgets);
        expect(dashboard.exportRequests, 0);
        expect(dashboard.exportPolls, 0);
        expect(find.text('Solicitar exportação'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });
  }

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
    final selectedDay = find.byKey(selectedKey);
    await tester.ensureVisible(selectedDay);
    await tester.pump();
    await tester.tap(selectedDay);
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

  testWidgets('new call prevents duplicate submission and ignores completion after dispose', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository.seeded()..createGate = Completer<void>();
    addTearDown(repository.dispose);
    var created = false;

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) => created = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chamada'));
    await tester.tap(find.text('Chamada'));
    await tester.pump();

    expect(repository.createCallCount, 1);
    await tester.pumpWidget(const SizedBox());
    repository.createGate!.complete();
    await tester.pumpAndSettle();
    expect(created, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new call locks its context while submission is in flight', (tester) async {
    final repository = FakeAttendanceRepository.seeded()..createGate = Completer<void>();
    addTearDown(repository.dispose);
    var cancelled = false;

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () => cancelled = true,
          onCreated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chamada'));
    await tester.pump();

    expect(repository.createCallCount, 1);
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('attendance-date-picker'))).onPressed,
      isNull,
    );
    expect(
      tester
          .widgetList<CoeloAdminSingleSelectField<String>>(
            find.byType(CoeloAdminSingleSelectField<String>),
          )
          .every((field) => !field.enabled),
      isTrue,
    );
    expect(
      tester.widget<TextButton>(find.byKey(const Key('attendance-context-cancel'))).onPressed,
      isNull,
    );
    expect(cancelled, isFalse);

    repository.createGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('new call ignores completion from repository A after a swap to B', (tester) async {
    final repositoryA = FakeAttendanceRepository.seeded()..createGate = Completer<void>();
    final repositoryB = FakeAttendanceRepository.seeded();
    addTearDown(repositoryA.dispose);
    addTearDown(repositoryB.dispose);
    var created = 0;

    Widget page(AttendanceRepository repository) => _app(
      AttendanceNewCallPage(
        repository: repository,
        permissions: const AttendancePermissions.owner(),
        logout: unavailableSuperadminLogout,
        onCancel: () {},
        onCreated: (_) => created += 1,
      ),
    );

    await tester.pumpWidget(page(repositoryA));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chamada'));
    await tester.pump();
    expect(repositoryA.createCallCount, 1);

    await tester.pumpWidget(page(repositoryB));
    await tester.pumpAndSettle();
    repositoryA.createGate!.complete();
    await tester.pumpAndSettle();

    expect(created, 0);
    expect(repositoryB.createCallCount, 0);
    expect(find.text('Contexto da chamada'), findsOneWidget);
  });

  testWidgets('new call keeps the form and exposes retryable command failure', (tester) async {
    final repository = FakeAttendanceRepository.seeded()
      ..createCallError = const AttendanceUnavailableException();
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
    await tester.tap(find.text('Chamada'));
    await tester.pumpAndSettle();

    expect(find.text('Contexto da chamada'), findsOneWidget);
    expect(find.text('Não foi possível criar a chamada.'), findsOneWidget);
    expect(find.byType(SuperadminShell), findsOneWidget);
  });

  testWidgets('new call rejects a created call outside the submitted context', (tester) async {
    final repository = _MismatchedCreatedCallRepository();
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
    await tester.pumpAndSettle();

    expect(createdCallId, isNull);
    expect(find.text('Não foi possível criar a chamada.'), findsOneWidget);
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

  testWidgets('new call ignores context options returned for an older date', (tester) async {
    final repository = _DelayedAttendanceOptionsRepository();
    final firstDate = DateTime(2026, 8, 3);
    final secondDate = DateTime(2026, 8, 4);

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) {},
          today: firstDate,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) {},
          today: secondDate,
        ),
      ),
    );
    await tester.pump();

    repository.complete(secondDate, _contextOptions('B'));
    await tester.pumpAndSettle();
    expect(find.text('Instituição B'), findsOneWidget);

    repository.complete(firstDate, _contextOptions('A'));
    await tester.pumpAndSettle();
    expect(find.text('Instituição B'), findsOneWidget);
    expect(find.text('Instituição A'), findsNothing);
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

  testWidgets('dashboard uses the supplied civil date for its period and picker limit', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: true);
    final today = DateTime(2026, 9, 9);

    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          dashboardRepository: dashboard,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
          today: today,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(dashboard.lastQuery!.periodStart, DateTime(2026, 9));
    expect(dashboard.lastQuery!.periodEnd, today);
    final picker = tester.widget<CoeloDateRangeField>(find.byType(CoeloDateRangeField));
    expect(picker.lastDate, today);
    expect(picker.currentDate, today);
  });

  testWidgets('dashboard replaces its repository without retaining the previous context', (
    tester,
  ) async {
    final gateA = Completer<void>();
    final gateB = Completer<void>();
    final repository = FakeAttendanceRepository.seeded();
    final dashboardA = _DashboardRepository(
      canCreate: true,
      label: 'Instituição A',
      dashboardDelay: gateA.future,
    );
    final dashboardB = _DashboardRepository(
      canCreate: true,
      label: 'Instituição B',
      dashboardDelay: gateB.future,
    );
    addTearDown(repository.dispose);

    Widget page(AttendanceDashboardRepository dashboard) => _app(
      AttendanceDashboardPage(
        repository: repository,
        dashboardRepository: dashboard,
        permissions: const AttendancePermissions.owner(),
        logout: unavailableSuperadminLogout,
        onCreate: null,
        onOpenCall: null,
      ),
    );

    await tester.pumpWidget(page(dashboardA));
    await tester.pump();
    await tester.pumpWidget(page(dashboardB));
    await tester.pump();

    gateB.complete();
    await tester.pumpAndSettle();
    expect(find.text('Instituição B'), findsWidgets);
    expect(find.text('Instituição A'), findsNothing);

    gateA.complete();
    await tester.pumpAndSettle();
    expect(find.text('Instituição B'), findsWidgets);
    expect(find.text('Instituição A'), findsNothing);
  });

  testWidgets('repository swap clears the search text from the previous context', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    final dashboardA = _DashboardRepository(canCreate: true, label: 'Instituição A');
    final dashboardB = _DashboardRepository(canCreate: true, label: 'Instituição B');
    addTearDown(repository.dispose);

    Widget page(AttendanceDashboardRepository dashboard) => _app(
      AttendanceDashboardPage(
        repository: repository,
        dashboardRepository: dashboard,
        permissions: const AttendancePermissions.owner(),
        logout: unavailableSuperadminLogout,
        onCreate: null,
        onOpenCall: null,
      ),
    );

    await tester.pumpWidget(page(dashboardA));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CoeloSearchField), 'Instituição A');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CoeloSearchField>(find.byType(CoeloSearchField)).controller.text,
      'Instituição A',
    );

    await tester.pumpWidget(page(dashboardB));
    await tester.pumpAndSettle();
    expect(tester.widget<CoeloSearchField>(find.byType(CoeloSearchField)).controller.text, isEmpty);
    expect(find.text('Instituição B'), findsWidgets);
    expect(find.text('Instituição A'), findsNothing);
  });

  testWidgets('read-only administrator has no write action', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: true);

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
    final firstSave = find.byKey(const Key('attendance-participant-save-participant-1'));
    await tester.ensureVisible(firstSave);
    await tester.pump();
    await tester.tap(firstSave);
    await tester.pumpAndSettle();
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
    final clearMarked = find.text('Desfazer último lote');
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

  testWidgets('call loading failure and not found remain inside the shell with retry', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository.seeded()
      ..fetchCallError = const AttendanceUnavailableException();
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
    expect(find.byType(SuperadminShell), findsOneWidget);
    expect(find.text('Não foi possível carregar a chamada.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    repository.fetchCallError = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Alunos de Turma Sol'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          key: const ValueKey('missing-call'),
          repository: repository,
          callId: 'missing',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SuperadminShell), findsOneWidget);
    expect(find.text('Chamada não encontrada.'), findsOneWidget);
  });

  testWidgets('call page rejects detail bound to another call id', (tester) async {
    final repository = _MismatchedAttendanceReadRepository();
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

    expect(find.text('Não foi possível carregar a chamada.'), findsOneWidget);
    expect(find.textContaining('Turma Lua'), findsNothing);
  });

  testWidgets('call route reloads when the call id changes in place', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    Widget page(String callId) => _app(
      AttendanceCallPage(
        repository: repository,
        callId: callId,
        permissions: const AttendancePermissions.owner(),
        logout: unavailableSuperadminLogout,
        onBack: () {},
      ),
    );

    await tester.pumpWidget(page('call-progress'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Turma Sol'), findsWidgets);

    await tester.pumpWidget(page('call-completed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Turma Lua'), findsWidgets);
    expect(find.textContaining('Turma Sol'), findsNothing);
  });

  testWidgets('completed empty call does not expose participant correction', (tester) async {
    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: _EmptyAttendanceRepository(),
          callId: 'empty-call',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nenhum participante encontrado para este contexto.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Corrigir chamada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('command failure preserves the call snapshot and reloads safely', (tester) async {
    final repository = FakeAttendanceRepository.seeded()
      ..commandError = const AttendanceVersionConflictException();
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
    final action = find.widgetWithText(OutlinedButton, 'Presente').first;
    await tester.ensureVisible(action);
    await tester.tap(action);
    final save = find.byKey(const Key('attendance-participant-save-participant-1'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Alunos de Turma Sol'), findsOneWidget);
    expect(find.text('A chamada foi atualizada em outro acesso.'), findsOneWidget);
    expect(find.byKey(const Key('attendance-participant-pending-participant-1')), findsOneWidget);
    repository.commandError = null;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Recarregar chamada'));
    await tester.pumpAndSettle();
    expect(find.text('A chamada foi atualizada em outro acesso.'), findsNothing);
  });

  testWidgets('one in-flight command disables every mutation and prevents duplicate bulk', (
    tester,
  ) async {
    final repository = FakeAttendanceRepository.seeded()..commandGate = Completer<void>();
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
    final bulk = find.widgetWithText(OutlinedButton, 'Marcar todos restantes como presentes');
    await tester.ensureVisible(bulk);
    await tester.tap(bulk);
    await tester.tap(bulk);
    await tester.pump();

    expect(repository.markRemainingCount, 1);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Presente').first)
          .onPressed,
      isNull,
    );
    repository.commandGate!.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('completion stays disabled while its command is in flight', (tester) async {
    final delegate = FakeAttendanceRepository.seeded();
    final initialCall = (await delegate.fetchCall('call-progress'))!;
    await delegate.markRemainingPresent('call-progress', expectedVersion: initialCall.version);
    final repository = _DelayedCompletionRepository(delegate);
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
    final complete = find.byKey(const Key('attendance-call-complete'));

    await tester.tap(complete);
    await tester.pump();

    expect(repository.completeCalls, 1);
    expect(tester.widget<FilledButton>(complete).onPressed, isNull);

    repository.complete();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Corrigir chamada'), findsOneWidget);
  });

  testWidgets('bulk failure keeps snapshot and reload never clears manual marks', (tester) async {
    final repository = FakeAttendanceRepository.seeded()
      ..commandError = const AttendanceUnavailableException();
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
    final bulk = find.widgetWithText(OutlinedButton, 'Marcar todos restantes como presentes');
    await tester.ensureVisible(bulk);
    await tester.tap(bulk);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar a alteração.'), findsOneWidget);
    expect(find.text('Alunos de Turma Sol'), findsOneWidget);

    repository.commandError = null;
    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          key: const ValueKey('completed-call-after-reload'),
          repository: repository,
          callId: 'call-completed',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    final undo = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Desfazer último lote'),
    );
    expect(undo.onPressed, isNull);
    expect(repository.clearPresenceMarksCount, 0);
  });

  testWidgets('dashboard uses one KPI column at 200 percent and describes both series', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(375, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    final dashboard = _DashboardRepository(canCreate: true, includePreviousSeries: true);

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

    final first = tester.getRect(find.byKey(const Key('attendance-kpi-presence')));
    final second = tester.getRect(find.byKey(const Key('attendance-kpi-pending')));
    expect(first.bottom, lessThanOrEqualTo(second.top));
    expect(find.text('Período atual'), findsOneWidget);
    expect(find.text('Período anterior'), findsOneWidget);
    final semantics = tester.getSemantics(find.byKey(const Key('attendance-series-chart')));
    expect(semantics.label, contains('Período atual'));
    expect(semantics.label, contains('Período anterior'));
    expect(semantics.label, contains('linha tracejada'));
    expect(semantics.label, contains('marcadores quadrados'));
    final customPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const Key('attendance-series-chart')),
        matching: find.byType(CustomPaint),
      ),
    );
    final topology = (customPaint.painter as dynamic).debugSeriesTopology(
      const Size(200, 100),
      const <double?>[80, null, 60],
    );
    expect(topology.markerCount, 2);
    expect(topology.segmentCount, 0);
  });

  testWidgets('call page saves each participant explicitly and keeps feelings local', (
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
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sentimento'), findsWidgets);
    expect(find.text('Ainda não está disponível nesta versão.'), findsWidgets);
    final feeling = find.byKey(const Key('attendance-feeling-participant-1-animated'));
    await tester.ensureVisible(feeling);
    await tester.pump();
    await tester.tap(feeling);
    await tester.pump();
    expect(tester.widget<Semantics>(feeling).properties.selected, isTrue);

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

      expect(
        (await repository.fetchCall('call-progress'))!.participants.first.state,
        isNot(entry.$2),
      );
      await tester.tap(find.byKey(const Key('attendance-participant-save-participant-1')));
      await tester.pumpAndSettle();
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

  testWidgets('call page ignores an older call response after an A to B swap', (tester) async {
    final seed = FakeAttendanceRepository.seeded();
    addTearDown(seed.dispose);
    final repositoryA = _DelayedAttendanceCallRepository();
    final repositoryB = _DelayedAttendanceCallRepository();

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repositoryA,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repositoryB,
          callId: 'call-completed',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();

    repositoryB.complete('call-completed', await seed.fetchCall('call-completed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Turma Lua'), findsWidgets);

    repositoryA.complete('call-progress', await seed.fetchCall('call-progress'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Turma Lua'), findsWidgets);
    expect(find.text('Música · Turma Sol'), findsNothing);
  });

  testWidgets('call page ignores an older command response after an A to B swap', (tester) async {
    final repositoryA = FakeAttendanceRepository.seeded()..commandGate = Completer<void>();
    final repositoryB = FakeAttendanceRepository.seeded();
    addTearDown(repositoryA.dispose);
    addTearDown(repositoryB.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repositoryA,
          callId: 'call-progress',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.widgetWithText(OutlinedButton, 'Presente').first;
    await tester.ensureVisible(action);
    await tester.tap(action);
    final save = find.byKey(const Key('attendance-participant-save-participant-1'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pump();

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repositoryB,
          callId: 'call-completed',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('Turma Lua'), findsWidgets);

    repositoryA.commandGate!.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('Turma Lua'), findsWidgets);
    expect(find.text('Música · Turma Sol'), findsNothing);
  });

  testWidgets('call page rejects a command response bound to another call', (tester) async {
    final repository = _MismatchedAttendanceCommandRepository();
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

    final action = find.widgetWithText(OutlinedButton, 'Presente').first;
    await tester.ensureVisible(action);
    await tester.tap(action);
    final save = find.byKey(const Key('attendance-participant-save-participant-1'));
    await tester.ensureVisible(save);
    await tester.pump();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível salvar a alteração.'), findsOneWidget);
    expect(find.textContaining('Turma Sol'), findsWidgets);
    expect(find.textContaining('Turma Lua'), findsNothing);
  });

  testWidgets('correction dialog does not write through a replacement repository', (tester) async {
    final repositoryA = FakeAttendanceRepository.seeded();
    final repositoryB = FakeAttendanceRepository.seeded();
    addTearDown(repositoryA.dispose);
    addTearDown(repositoryB.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repositoryA,
          callId: 'call-completed',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Corrigir chamada'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ajuste conferido');

    await tester.pumpWidget(
      _app(
        AttendanceCallPage(
          repository: repositoryB,
          callId: 'call-completed',
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pumpAndSettle();

    final callA = await repositoryA.fetchCall('call-completed');
    final callB = await repositoryB.fetchCall('call-completed');
    expect(callA!.revisions, isEmpty);
    expect(callB!.revisions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('correction dialog does not use a removed call page context', (tester) async {
    final repository = FakeAttendanceRepository.seeded();
    addTearDown(repository.dispose);
    late StateSetter replacePage;
    var showPage = true;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: StatefulBuilder(
          builder: (context, setState) {
            replacePage = setState;
            return showPage
                ? AttendanceCallPage(
                    repository: repository,
                    callId: 'call-completed',
                    permissions: const AttendancePermissions.owner(),
                    logout: unavailableSuperadminLogout,
                    onBack: () {},
                  )
                : const SizedBox.shrink();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Corrigir chamada'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Página removida');

    replacePage(() => showPage = false);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pumpAndSettle();

    expect((await repository.fetchCall('call-completed'))!.revisions, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed correction keeps its draft open and retries successfully', (tester) async {
    final repository = _FailOnceCorrectionRepository();
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Corrigir chamada'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Motivo preservado');

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pumpAndSettle();

    expect(find.text('Corrigir chamada'), findsAtLeastNWidgets(2));
    expect(find.text('Motivo preservado'), findsOneWidget);
    expect(repository.attempts, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pumpAndSettle();

    expect(find.text('Corrigir chamada'), findsOneWidget);
    expect(repository.attempts, 2);
    final call = await repository.fetchCall('call-completed');
    expect(call!.revisions.single.reason, 'Motivo preservado');
    expect(tester.takeException(), isNull);
  });

  testWidgets('correction requires a reason and preserves the draft', (tester) async {
    final semantics = tester.ensureSemantics();
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Corrigir chamada'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('attendance-correction-reason')), '   ');

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pumpAndSettle();

    expect(find.text('Motivo obrigatório'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Motivo obrigatório')).getSemanticsData().label,
      contains('Motivo obrigatório'),
    );
    expect(find.text('Corrigir chamada'), findsAtLeastNWidgets(2));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('attendance-correction-reason')))
          .controller
          ?.text,
      '   ',
    );
    expect((await repository.fetchCall('call-completed'))!.revisions, isEmpty);

    await tester.enterText(
      find.byKey(const Key('attendance-correction-reason')),
      'Conferido com a família',
    );
    await tester.pump();
    expect(find.text('Motivo obrigatório'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pumpAndSettle();

    final call = await repository.fetchCall('call-completed');
    expect(call!.revisions.single.participantId, 'participant-1');
    expect(call.revisions.single.reason, 'Conferido com a família');
    semantics.dispose();
  });

  testWidgets('correction applies to the participant selected in the dialog', (tester) async {
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Corrigir chamada'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('attendance-correction-participant')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tom Vale').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('attendance-correction-state')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saída antecipada').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('attendance-correction-reason')),
      'Saída conferida',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pumpAndSettle();

    final call = await repository.fetchCall('call-completed');
    expect(call!.revisions.single.participantId, 'participant-2');
    expect(call.revisions.single.reason, 'Saída conferida');
    expect(call.participants[0].state, AttendancePresenceState.present);
    expect(call.participants[1].state, AttendancePresenceState.earlyDeparture);
  });

  testWidgets('correction fields stay locked while the command is in flight', (tester) async {
    final repository = _DelayedCorrectionRepository();
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
    await tester.tap(find.widgetWithText(OutlinedButton, 'Corrigir chamada'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('attendance-correction-reason')),
      'Motivo em envio',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Registrar correção'));
    await tester.pump();

    expect(
      tester
          .widget<CoeloAdminSingleSelectField<AttendanceParticipant>>(
            find.byKey(const Key('attendance-correction-participant')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<CoeloAdminSingleSelectField<AttendancePresenceState>>(
            find.byKey(const Key('attendance-correction-state')),
          )
          .enabled,
      isFalse,
    );
    expect(
      tester.widget<TextFormField>(find.byKey(const Key('attendance-correction-reason'))).enabled,
      isFalse,
    );
    expect(
      tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancelar')).onPressed,
      isNull,
    );

    repository.complete();
    await tester.pumpAndSettle();
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
        expect(
          find.byKey(const Key('attendance-participant-identity-participant-1')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('attendance-participant-actions-participant-1')),
          findsOneWidget,
        );
      }
    }
  });

  for (final brightness in Brightness.values) {
    testWidgets('compact call footer remains reachable at text 200 $brightness', (tester) async {
      final repository = FakeAttendanceRepository.seeded();
      addTearDown(repository.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(375, 900));
      var returned = false;
      await tester.pumpWidget(
        _app(
          AttendanceCallPage(
            repository: repository,
            callId: 'call-progress',
            permissions: const AttendancePermissions.owner(),
            logout: unavailableSuperadminLogout,
            onBack: () => returned = true,
          ),
          brightness: brightness,
          textScaler: const TextScaler.linear(2),
        ),
      );
      await tester.pumpAndSettle();
      final action = find.widgetWithText(TextButton, 'Voltar para Assiduidade');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byKey(const Key('attendance-call-scroll')));
      final button = tester.getRect(action);
      expect(button.height, greaterThan(0));
      expect(viewport.height, greaterThan(0));
      await tester.ensureVisible(action);
      expect(action.hitTestable(), findsOneWidget);
      await tester.tap(action);
      expect(returned, isTrue);
      await tester.ensureVisible(
        find.byKey(const Key('attendance-participant-identity-participant-1')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

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

Widget _app(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: brightness == Brightness.dark ? CoeloTheme.dark : CoeloTheme.light,
  builder: (context, appChild) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: appChild!,
  ),
  home: child,
);

final class _FailOnceCorrectionRepository implements AttendanceRepository {
  final FakeAttendanceRepository _delegate = FakeAttendanceRepository.seeded();
  var attempts = 0;

  void dispose() => _delegate.dispose();

  @override
  Future<AttendanceCall?> fetchCall(String callId) => _delegate.fetchCall(callId);

  @override
  Future<AttendanceCall> correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
    required int expectedVersion,
  }) {
    attempts++;
    if (attempts == 1) {
      return Future.error(const AttendanceVersionConflictException());
    }
    return _delegate.correctParticipant(
      callId: callId,
      participantId: participantId,
      state: state,
      reason: reason,
      expectedVersion: expectedVersion,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedCorrectionRepository implements AttendanceRepository {
  final FakeAttendanceRepository _delegate = FakeAttendanceRepository.seeded();
  final Completer<void> _gate = Completer<void>();

  void dispose() => _delegate.dispose();
  void complete() => _gate.complete();

  @override
  Future<AttendanceCall?> fetchCall(String callId) => _delegate.fetchCall(callId);

  @override
  Future<AttendanceCall> correctParticipant({
    required String callId,
    required String participantId,
    required AttendancePresenceState state,
    required String reason,
    required int expectedVersion,
  }) async {
    await _gate.future;
    return _delegate.correctParticipant(
      callId: callId,
      participantId: participantId,
      state: state,
      reason: reason,
      expectedVersion: expectedVersion,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MismatchedAttendanceCommandRepository implements AttendanceRepository {
  final FakeAttendanceRepository _delegate = FakeAttendanceRepository.seeded();

  void dispose() => _delegate.dispose();

  @override
  Future<AttendanceCall?> fetchCall(String callId) => _delegate.fetchCall(callId);

  @override
  Future<AttendanceCall> setParticipantState(
    String callId,
    String participantId,
    AttendancePresenceState state, {
    required int expectedVersion,
  }) async => (await _delegate.fetchCall('call-completed'))!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MismatchedCreatedCallRepository implements AttendanceRepository {
  final FakeAttendanceRepository _delegate = FakeAttendanceRepository.seeded();

  void dispose() => _delegate.dispose();

  @override
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date}) =>
      _delegate.fetchContextOptions(date: date);

  @override
  Future<AttendanceCall> createCall(AttendanceCallDraft draft) async =>
      (await _delegate.fetchCall('call-completed'))!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _MismatchedAttendanceReadRepository implements AttendanceRepository {
  final FakeAttendanceRepository _delegate = FakeAttendanceRepository.seeded();

  void dispose() => _delegate.dispose();

  @override
  Future<AttendanceCall?> fetchCall(String callId) => _delegate.fetchCall('call-completed');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _EmptyAttendanceRepository implements AttendanceRepository {
  @override
  Future<AttendanceCall?> fetchCall(String callId) async => AttendanceCall(
    id: callId,
    institutionId: 'institution-1',
    institutionName: 'Instituto Horizonte',
    unitId: 'unit-1',
    unitName: 'Unidade Centro',
    groupId: 'group-empty',
    groupName: 'Turma sem participantes',
    date: DateTime(2026, 8, 3),
    status: AttendanceCallStatus.completed,
    canManage: true,
    participants: const [],
    responsible: 'Equipe pedagógica',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedAttendanceOptionsRepository implements AttendanceRepository {
  final Map<DateTime, Completer<AttendanceContextOptions>> _requests = {};

  void complete(DateTime date, AttendanceContextOptions options) {
    _requests[date]!.complete(options);
  }

  @override
  Future<AttendanceContextOptions> fetchContextOptions({required DateTime date}) =>
      (_requests[date] ??= Completer<AttendanceContextOptions>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedAttendanceCallRepository implements AttendanceRepository {
  final Map<String, Completer<AttendanceCall?>> _requests = {};

  void complete(String callId, AttendanceCall? call) {
    _requests[callId]!.complete(call);
  }

  @override
  Future<AttendanceCall?> fetchCall(String callId) =>
      (_requests[callId] ??= Completer<AttendanceCall?>()).future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedCompletionRepository implements AttendanceRepository {
  _DelayedCompletionRepository(this._delegate);

  final FakeAttendanceRepository _delegate;
  final _gate = Completer<void>();
  int completeCalls = 0;

  void complete() => _gate.complete();
  void dispose() => _delegate.dispose();

  @override
  Future<AttendanceCall?> fetchCall(String callId) => _delegate.fetchCall(callId);

  @override
  Future<AttendanceCall> completeCall(String callId, {required int expectedVersion}) async {
    completeCalls++;
    await _gate.future;
    return _delegate.completeCall(callId, expectedVersion: expectedVersion);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AttendanceContextOptions _contextOptions(String suffix) => AttendanceContextOptions(
  institutions: [AttendanceContextOption(id: 'institution-$suffix', name: 'Instituição $suffix')],
  units: [
    AttendanceContextOption(
      id: 'unit-$suffix',
      name: 'Unidade $suffix',
      institutionId: 'institution-$suffix',
    ),
  ],
  groups: [
    AttendanceContextOption(
      id: 'group-$suffix',
      name: 'Turma $suffix',
      institutionId: 'institution-$suffix',
      unitId: 'unit-$suffix',
    ),
  ],
  activities: const [],
  canManage: true,
);

final class _DashboardRepository implements AttendanceDashboardRepository {
  _DashboardRepository({
    required this.canCreate,
    this.includePreviousSeries = false,
    this.label = 'Instituto Horizonte',
    this.dashboardDelay,
  });
  final bool canCreate;
  final bool includePreviousSeries;
  final String label;
  final Future<void>? dashboardDelay;
  bool failNext = false;
  int exportRequests = 0;
  int exportPolls = 0;
  AttendanceDashboardQuery? lastQuery;

  AttendanceDashboardAccess get _access => AttendanceDashboardAccess(
    scope: AttendanceDashboardScope.platform,
    canRead: true,
    canCreateCall: canCreate,
  );

  @override
  Future<AttendanceDashboardAccess> fetchAccess() async => _access;

  @override
  Future<AttendanceDashboardSnapshot> fetchDashboard(AttendanceDashboardQuery query) async {
    lastQuery = query;
    await dashboardDelay;
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
      items: [AttendanceRankingItem(id: 'institution-1', label: label, rate: rate)],
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
          previous: includePreviousSeries
              ? AttendanceRate.fromCounts(
                  present: 17,
                  late: 1,
                  earlyDeparture: 0,
                  lateAndEarly: 0,
                  absent: 2,
                )
              : null,
          absences: 1,
          late: 1,
        ),
        AttendanceSeriesPoint(
          start: query.periodEnd,
          label: 'Fim',
          current: rate,
          previous: includePreviousSeries
              ? AttendanceRate.fromCounts(
                  present: 16,
                  late: 1,
                  earlyDeparture: 0,
                  lateAndEarly: 0,
                  absent: 3,
                )
              : null,
          absences: 0,
          late: 0,
        ),
      ],
      calls: AttendanceDashboardCallPage(
        items: [
          AttendanceDashboardCallRow(
            id: 'call-1',
            context: '$label · Unidade Centro · Turma Sol',
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
      contextLabel: label,
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
  }) {
    exportRequests += 1;
    throw UnimplementedError();
  }

  @override
  Future<AttendanceDashboardExportJob> fetchExportJob(String id) {
    exportPolls += 1;
    throw UnimplementedError();
  }
}
