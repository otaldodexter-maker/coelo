import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_pages.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_action_footer.dart';
import 'package:coelo_superadmin/shared/presentation/widgets/superadmin_form_step_navigation.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new call starts in the context step with canonical form controls', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
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

    expect(find.byType(SuperadminFormStepNavigation), findsOneWidget);
    expect(find.text('Contexto da chamada'), findsOneWidget);
    expect(find.text('Instituição'), findsOneWidget);
    expect(find.text('Unidade'), findsOneWidget);
    expect(find.text('Turma'), findsWidgets);
    expect(find.text('Hoje · 03/08/2026'), findsOneWidget);
    expect(find.byType(SuperadminFormActionFooter), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continuar'), findsOneWidget);
  });

  testWidgets('new call opens Chamada directly from the step navigation', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
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

    await tester.tap(find.text('Chamada'));
    await tester.pump();

    expect(createdCallId, isNotNull);
    expect(repository.callById(createdCallId!), isNotNull);
  });

  testWidgets('new call accepts a prefilled activity context', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceNewCallPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCancel: () {},
          onCreated: (_) {},
          initialInstitutionId: 'institution-2',
          initialUnitId: 'unit-2',
          initialGroupId: 'group-moon',
          initialActivityId: 'activity-music-group-sun',
        ),
      ),
    );

    expect(find.text('Colégio Aurora · meta 90%'), findsOneWidget);
    expect(find.text('Unidade Norte'), findsOneWidget);
    expect(find.text('Turma Lua'), findsOneWidget);
    expect(find.text('Atividade'), findsOneWidget);
    expect(find.text('Música · Chamada exigida'), findsOneWidget);
  });
  testWidgets('new call adapts without overflow at Coelo breakpoints and 200 percent text', (
    tester,
  ) async {
    final repository = InMemoryAttendanceRepository.seeded();
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
          textScaler: size.width == 375 ? const TextScaler.linear(2) : TextScaler.noScaling,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow at ${size.width}px');
    }
  });
  testWidgets('attendance directory replaces the dashboard with a create card', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          permissions: const AttendancePermissions.owner(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );

    expect(find.byType(CoeloAdminCreateAction), findsOneWidget);
    expect(find.text('Nova chamada'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Nova chamada'), findsNothing);
    expect(find.text('Hoje'), findsNothing);
    expect(find.text('Período analítico'), findsNothing);
    expect(find.textContaining('Dados locais'), findsOneWidget);
  });

  testWidgets('read-only administrator has no write action', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      _app(
        AttendanceDashboardPage(
          repository: repository,
          permissions: const AttendancePermissions.readOnly(),
          logout: unavailableSuperadminLogout,
          onCreate: () {},
          onOpenCall: (_) {},
        ),
      ),
    );

    expect(find.text('Nova chamada'), findsNothing);
    expect(find.textContaining('somente leitura'), findsOneWidget);
  });

  testWidgets('call page marks remaining and then completes', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
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
    await tester.ensureVisible(absenceAction);
    await tester.pump();
    await tester.tap(absenceAction);
    await tester.pump();
    expect(
      repository.callById('call-progress')!.participants.first.state,
      AttendancePresenceState.absent,
    );

    final markRemaining = find.text('Marcar restantes como presentes');
    await tester.ensureVisible(markRemaining);
    await tester.pump();
    await tester.tap(markRemaining);
    await tester.pump();

    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Concluir chamada')).onPressed,
      isNotNull,
    );
  });

  testWidgets('call page marks one participant as present', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
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

    final presentAction = find.widgetWithText(OutlinedButton, 'Presente').first;
    await tester.ensureVisible(presentAction);
    await tester.pump();
    await tester.tap(presentAction);
    await tester.pump();

    expect(
      repository.callById('call-progress')!.participants.first.state,
      AttendancePresenceState.present,
    );
  });

  testWidgets('assigned teacher operates the canonical call flow', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
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

    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Presente').first)
          .onPressed,
      isNotNull,
    );
    expect(find.text('Visualizar como professor'), findsNothing);
  });

  testWidgets('participant list preserves Coelo radius and clipping', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
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

    final surface = find.byKey(const Key('attendance-participant-list'));
    final decoration = tester.widget<DecoratedBox>(surface).decoration as BoxDecoration;
    final clip = tester.widget<ClipRRect>(
      find.descendant(of: surface, matching: find.byType(ClipRRect)),
    );
    expect(decoration.borderRadius, BorderRadius.circular(CoeloRadius.lg));
    expect(clip.borderRadius, BorderRadius.circular(CoeloRadius.lg));
  });

  testWidgets('call flow adapts at Coelo breakpoints without overflow', (tester) async {
    final repository = InMemoryAttendanceRepository.seeded();
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
          textScaler: size.width == 375 ? const TextScaler.linear(2) : TextScaler.noScaling,
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'overflow at ${size.width}px');
    }
  });

  testWidgets('call page expands the first pending routine supplied by the UI seam', (
    tester,
  ) async {
    final repository = InMemoryAttendanceRepository.seeded();
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

    expect(find.text('Rotina diária'), findsOneWidget);
    expect(find.text('1 obrigatória pendente'), findsOneWidget);
    expect(find.text('Rotina de Lia Horizonte'), findsOneWidget);
  });
}

Widget _app(Widget child, {TextScaler textScaler = TextScaler.noScaling}) => MaterialApp(
  theme: CoeloTheme.light,
  home: MediaQuery(
    data: MediaQueryData(size: const Size(1440, 900), textScaler: textScaler),
    child: child,
  ),
);
