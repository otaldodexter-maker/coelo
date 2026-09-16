import 'package:coelo_superadmin/features/attendance/attendance.dart';
import 'package:coelo_superadmin/features/attendance/attendance_history_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_attendance_history_repository.dart';

/// Acompanhamento › Assiduidade › Histórico (ADR 0041 B2, spec 052).
///
/// A tela consulta; não edita. O que se prova aqui: estados (carregando,
/// vazio, sem resultados, erro, não autorizado), colunas pedidas pelo Owner,
/// abrir o detalhe, filtros em cascata, paginação por cursor e o rótulo de
/// rotina (snapshot × "rotina atual"). Escopo e negativas são do servidor.
const _options = AttendanceContextOptions(
  institutions: [AttendanceContextOption(id: 'inst-1', name: 'Escola Horizonte')],
  units: [
    AttendanceContextOption(id: 'unit-1', name: 'Unidade Centro', institutionId: 'inst-1'),
    AttendanceContextOption(id: 'unit-2', name: 'Unidade Norte', institutionId: 'inst-1'),
  ],
  groups: [
    AttendanceContextOption(
      id: 'group-1',
      name: 'Turma Sol',
      institutionId: 'inst-1',
      unitId: 'unit-1',
    ),
    AttendanceContextOption(
      id: 'group-2',
      name: 'Turma Lua',
      institutionId: 'inst-1',
      unitId: 'unit-2',
    ),
  ],
  activities: [
    AttendanceContextOption(
      id: 'activity-1',
      name: 'Música',
      institutionId: 'inst-1',
      unitId: 'unit-1',
      groupId: 'group-1',
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  required FakeAttendanceHistoryRepository repository,
  ValueChanged<String>? onOpenCall,
  Size size = const Size(1440, 1024),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: AttendanceHistoryPage(
        repository: repository,
        logout: unavailableSuperadminLogout,
        onOpenCall: onOpenCall,
        today: DateTime(2026, 9, 16),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the calls with the columns the Owner asked for', (tester) async {
    final opened = <String>[];
    await _pump(
      tester,
      repository: FakeAttendanceHistoryRepository(
        options: _options,
        pages: [
          AttendanceHistoryPageResult(
            items: [
              fakeHistoryItem(
                'call-1',
                routine: const AttendanceRoutineRef(
                  source: AttendanceRoutineSource.snapshot,
                  applicationId: 'app-1',
                  revisionNo: 3,
                  name: 'Rotina Berçário',
                ),
              ),
              fakeHistoryItem(
                'call-2',
                activityName: 'Música',
                status: AttendanceCallStatus.inProgress,
                responsible: 'Bia Educadora',
                present: 0,
                absent: 0,
                routine: const AttendanceRoutineRef(
                  source: AttendanceRoutineSource.current,
                  applicationId: 'app-1',
                  revisionNo: 4,
                  name: 'Rotina Berçário',
                ),
              ),
              // Legado: concluída antes do snapshot existir.
              fakeHistoryItem(
                'call-3',
                date: DateTime(2026, 9, 10),
                groupName: 'Turma Lua',
                responsible: 'Cid Educador',
                routine: const AttendanceRoutineRef(
                  source: AttendanceRoutineSource.current,
                  applicationId: 'app-2',
                  revisionNo: 1,
                  name: 'Rotina Lua',
                ),
              ),
            ],
            hasMore: false,
          ),
        ],
      ),
      onOpenCall: opened.add,
    );

    expect(find.text('Histórico de chamadas'), findsOneWidget);
    for (final header in ['Data', 'Turma / atividade', 'Quem lançou', 'Presentes', 'Ausentes', 'Rotina', 'Situação']) {
      expect(find.text(header), findsWidgets, reason: 'coluna $header');
    }
    expect(find.text('15/09/2026'), findsAtLeastNWidgets(2));
    expect(find.text('Turma Sol'), findsOneWidget);
    expect(find.text('Música'), findsOneWidget);
    expect(find.text('Ana Educadora'), findsOneWidget);
    expect(find.text('Bia Educadora'), findsOneWidget);
    expect(find.text('Concluída'), findsNWidgets(2));
    expect(find.text('Em andamento'), findsOneWidget);
    // Rotina: snapshot mostra nome + versão; chamada aberta segue a vigente sem
    // qualificador; legado concluído sem snapshot leva a indicação do Owner.
    expect(find.text('Rotina Berçário · v3'), findsOneWidget);
    expect(find.text('Rotina Berçário · v4'), findsOneWidget);
    expect(find.text('Rotina Lua · v1'), findsOneWidget);
    expect(find.text('rotina atual (não registrada na época)'), findsOneWidget);
    expect(find.text('rotina vigente'), findsNothing, reason: 'na tabela, só o legado leva qualificador');
    // Nenhum controle de presença/edição nesta tela.
    expect(find.text('Presente'), findsNothing);
    expect(find.text('Concluir chamada'), findsNothing);

    // A coluna Ações fica à direita da rolagem horizontal da tabela; a ação
    // é acionada como no painel (attendance_routes_test).
    tester
        .widget<IconButton>(find.byKey(const ValueKey('attendance-history-open-call-2')))
        .onPressed!();
    await tester.pumpAndSettle();
    expect(opened, ['call-2']);
  });

  testWidgets('shows the empty state without filters and no-results with filters', (tester) async {
    final queries = <AttendanceHistoryQuery>[];
    await _pump(
      tester,
      repository: FakeAttendanceHistoryRepository(options: _options, queries: queries),
    );
    expect(find.text('Nenhuma chamada no período'), findsOneWidget);
    expect(find.byKey(const Key('attendance-history-clear-filters')), findsNothing);

    await tester.tap(find.byKey(const Key('attendance-history-filter-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluídas').last);
    await tester.pumpAndSettle();

    expect(queries.last.status, AttendanceHistoryStatusFilter.completed);
    expect(find.text('Nenhuma chamada encontrada'), findsOneWidget);
    expect(find.byKey(const Key('attendance-history-clear-filters')), findsOneWidget);

    await tester.tap(find.byKey(const Key('attendance-history-clear-filters')));
    await tester.pumpAndSettle();
    expect(queries.last.status, isNull);
    expect(find.text('Nenhuma chamada no período'), findsOneWidget);
  });

  testWidgets('institution, unit and group filters cascade and reset the dependents', (
    tester,
  ) async {
    final queries = <AttendanceHistoryQuery>[];
    await _pump(
      tester,
      repository: FakeAttendanceHistoryRepository(options: _options, queries: queries),
    );

    await tester.tap(find.byKey(const Key('attendance-history-filter-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidade Norte').last);
    await tester.pumpAndSettle();
    expect(queries.last.unitId, 'unit-2');

    await tester.tap(find.byKey(const Key('attendance-history-filter-group')));
    await tester.pumpAndSettle();
    expect(find.text('Turma Sol'), findsNothing, reason: 'turma de outra unidade não é oferecida');
    await tester.tap(find.text('Turma Lua').last);
    await tester.pumpAndSettle();
    expect(queries.last.groupId, 'group-2');

    // Trocar a unidade limpa a turma escolhida (servidor nunca recebe par incoerente).
    await tester.tap(find.byKey(const Key('attendance-history-filter-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unidade Centro').last);
    await tester.pumpAndSettle();
    expect(queries.last.unitId, 'unit-1');
    expect(queries.last.groupId, isNull);

    // Atividade só aparece depois de escolher a turma que a possui.
    expect(find.byKey(const Key('attendance-history-filter-activity')), findsNothing);
    await tester.tap(find.byKey(const Key('attendance-history-filter-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Turma Sol').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attendance-history-filter-activity')), findsOneWidget);
  });

  testWidgets('paginates by cursor without repeating the server read for known pages', (
    tester,
  ) async {
    final queries = <AttendanceHistoryQuery>[];
    await _pump(
      tester,
      repository: FakeAttendanceHistoryRepository(
        options: _options,
        queries: queries,
        pages: [
          AttendanceHistoryPageResult(
            items: [fakeHistoryItem('call-1', groupName: 'Turma Um')],
            hasMore: true,
            nextCursor: 'next-1',
          ),
          AttendanceHistoryPageResult(
            items: [fakeHistoryItem('call-2', groupName: 'Turma Dois')],
            hasMore: false,
          ),
        ],
      ),
    );
    expect(find.text('Turma Um'), findsOneWidget);
    expect(find.byKey(const Key('attendance-history-pagination')), findsOneWidget);
    expect(queries.length, 1);

    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();
    expect(find.text('Turma Dois'), findsOneWidget);
    expect(find.text('Turma Um'), findsNothing);
    expect(queries.length, 2);
    expect(queries.last.cursor, 'next-1');

    await tester.tap(find.text('Anterior'));
    await tester.pumpAndSettle();
    expect(find.text('Turma Um'), findsOneWidget);
    expect(queries.length, 2, reason: 'página já conhecida não volta ao servidor');
  });

  testWidgets('unauthorized, unavailable and failure states are distinct', (tester) async {
    await _pump(
      tester,
      repository: const FakeAttendanceHistoryRepository(
        error: AttendanceUnauthorizedException(),
      ),
    );
    expect(find.text('Acesso não autorizado'), findsOneWidget);

    await _pump(
      tester,
      repository: const FakeAttendanceHistoryRepository(
        error: AttendanceUnavailableException(),
      ),
    );
    expect(find.text('Histórico indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);

    await _pump(
      tester,
      repository: FakeAttendanceHistoryRepository(error: StateError('boom')),
    );
    expect(find.text('Histórico indisponível'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('without the routine repository there is no launches segment', (tester) async {
    await _pump(tester, repository: const FakeAttendanceHistoryRepository(options: _options));
    expect(find.byKey(const Key('attendance-history-segments')), findsNothing);
  });

  testWidgets('compact width keeps the table reachable with no horizontal page overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      size: const Size(375, 812),
      repository: FakeAttendanceHistoryRepository(
        options: _options,
        pages: [
          AttendanceHistoryPageResult(items: [fakeHistoryItem('call-1')], hasMore: false),
        ],
      ),
    );
    expect(find.byType(CoeloAdminResizableTable<AttendanceHistoryItem>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
