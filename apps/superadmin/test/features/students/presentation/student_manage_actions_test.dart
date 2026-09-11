import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/students/domain/student_link.dart';
import 'package:coelo_superadmin/features/students/presentation/student_manage_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P36: aluno sempre em turma de unidade de instituição. Vincular e
/// transferir escolhem a turma (a unidade vem junto); editar ajusta a vigência.
final class _FakeRepository implements StudentLinkRepository {
  _FakeRepository({this.withUnit = true});

  final bool withUnit;
  final calls = <String>[];

  @override
  Future<StudentLinks> fetchLinks(String childContextId) async => StudentLinks(
    childContextId: childContextId,
    childPersonId: 'person-1',
    displayName: 'Criança Demo',
    institutionId: 'institution-1',
    canManage: true,
    unitLinks: withUnit
        ? [
            StudentUnitLink(
              unitLinkId: 'unit-link-1',
              unitId: 'unit-1',
              unitName: 'Unidade Centro',
              status: 'active',
              groupLinks: [
                StudentGroupLink(
                  groupLinkId: 'group-link-1',
                  groupId: 'group-1',
                  groupName: 'Berçário A',
                  status: 'active',
                  startsAt: DateTime(2026, 2, 1),
                ),
              ],
            ),
          ]
        : const [],
  );

  StudentLinkResult get _ok => const StudentLinkResult(
    childContextId: 'context-1',
    unitLinkId: 'unit-link-1',
    status: 'active',
  );

  @override
  Future<StudentLinkResult> link({
    required String requestId,
    required String childContextId,
    required String unitId,
    String? groupId,
    DateTime? startsAt,
  }) async {
    calls.add('link:$unitId:$groupId');
    return _ok;
  }

  @override
  Future<StudentLinkResult> transfer({
    required String requestId,
    required String childContextId,
    required String fromUnitId,
    required String toUnitId,
    required String reason,
    String? toGroupId,
  }) async {
    calls.add('transfer:$fromUnitId>$toUnitId:$toGroupId:$reason');
    return _ok;
  }

  @override
  Future<StudentLinkResult> edit({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String groupId,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
  }) async {
    calls.add('edit:$groupId:${startsAt?.day}:${endsAt?.day}:$clearEndsAt');
    return _ok;
  }

  @override
  Future<StudentLinkResult> revoke({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String reason,
  }) async => _ok;
}

const _options = [
  StudentGroupOption(
    groupId: 'group-1',
    groupName: 'Berçário A',
    unitId: 'unit-1',
    unitName: 'Unidade Centro',
  ),
  StudentGroupOption(
    groupId: 'group-9',
    groupName: 'Maternal',
    unitId: 'unit-2',
    unitName: 'Unidade Norte',
  ),
];

Future<void> _pump(
  WidgetTester tester,
  _FakeRepository repository, {
  bool withLoader = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1024));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: StudentManagePage(
        repository: repository,
        childContextId: 'context-1',
        logout: unavailableSuperadminLogout,
        loadGroupOptions: withLoader ? (_) async => _options : null,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sem loader de turmas só revogar e editar aparecem', (tester) async {
    await _pump(tester, _FakeRepository(), withLoader: false);
    expect(find.byKey(const Key('student-link-button')), findsNothing);
    expect(find.byKey(const Key('student-transfer-unit-link-1')), findsNothing);
    expect(find.byKey(const Key('student-revoke-unit-link-1')), findsOneWidget);
    expect(find.byKey(const Key('student-edit-group-link-1')), findsOneWidget);
  });

  testWidgets('vincular escolhe a turma e manda a unidade dela', (tester) async {
    final repository = _FakeRepository(withUnit: false);
    await _pump(tester, repository);
    await tester.tap(find.text('Vincular a uma turma'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-link-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('student-group-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maternal — Unidade Norte').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-group-confirm')));
    await tester.pumpAndSettle();
    expect(repository.calls, ['link:unit-2:group-9']);
  });

  testWidgets('transferir exclui a unidade atual, exige motivo e manda origem/destino', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('student-transfer-unit-link-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-group-select')));
    await tester.pumpAndSettle();
    expect(
      find.text('Berçário A — Unidade Centro'),
      findsNothing,
      reason: 'unidade atual não é destino',
    );
    await tester.tap(find.text('Maternal — Unidade Norte').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('student-group-confirm'))).onPressed,
      isNull,
      reason: 'sem motivo não transfere',
    );
    await tester.enterText(find.byKey(const Key('student-reason-field')), 'mudança de bairro');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-group-confirm')));
    await tester.pumpAndSettle();
    expect(repository.calls, ['transfer:unit-1>unit-2:group-9:mudança de bairro']);
  });

  testWidgets('editar vigência valida dd/mm/aaaa e envia início e fim', (tester) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);
    await tester.tap(find.byKey(const Key('student-edit-group-link-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-edit-dialog')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('student-edit-ends')), '31/02/2026');
    await tester.pumpAndSettle();
    expect(find.text('Use dd/mm/aaaa.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('student-edit-ends')), '15/12/2026');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-edit-confirm')));
    await tester.pumpAndSettle();
    expect(repository.calls, ['edit:group-1:1:15:false']);
  });
}
