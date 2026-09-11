import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/students/domain/student_link.dart';
import 'package:coelo_superadmin/features/students/presentation/student_manage_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tela mostra onde a criança está antes de oferecer as ações que mudam
/// isso, e nunca autoriza nada por conta própria.
final class _FakeStudentLinkRepository implements StudentLinkRepository {
  _FakeStudentLinkRepository({this.canManage = true, this.status = 'active', this.failure});

  final bool canManage;
  final String status;
  final StudentLinkException? failure;
  var loads = 0;
  final revokes = <Map<String, String>>[];

  @override
  Future<StudentLinks> fetchLinks(String childContextId) async {
    loads++;
    final error = failure;
    if (error != null) throw error;
    return StudentLinks(
      childContextId: childContextId,
      childPersonId: 'person-1',
      displayName: 'Criança Demo',
      institutionId: 'institution-1',
      canManage: canManage,
      unitLinks: [
        StudentUnitLink(
          unitLinkId: 'unit-link-1',
          unitId: 'unit-1',
          unitName: 'Unidade Centro',
          status: status,
          groupLinks: const [
            StudentGroupLink(
              groupLinkId: 'group-link-1',
              groupId: 'group-1',
              groupName: 'Berçário A',
              status: 'active',
            ),
            StudentGroupLink(
              groupLinkId: 'group-link-2',
              groupId: 'group-2',
              groupName: 'Berçário B',
              status: 'inactive',
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<StudentLinkResult> revoke({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String reason,
  }) async {
    revokes.add({'unitId': unitId, 'reason': reason, 'requestId': requestId});
    return const StudentLinkResult(
      childContextId: 'context-1',
      unitLinkId: 'unit-link-1',
      status: 'revoked',
    );
  }

  Never _unused() => throw UnimplementedError();
  @override
  Future<StudentLinkResult> link({
    required String requestId,
    required String childContextId,
    required String unitId,
    String? groupId,
    DateTime? startsAt,
  }) async => _unused();
  @override
  Future<StudentLinkResult> transfer({
    required String requestId,
    required String childContextId,
    required String fromUnitId,
    required String toUnitId,
    required String reason,
    String? toGroupId,
  }) async => _unused();
  @override
  Future<StudentLinkResult> edit({
    required String requestId,
    required String childContextId,
    required String unitId,
    required String groupId,
    DateTime? startsAt,
    DateTime? endsAt,
    bool clearEndsAt = false,
  }) async => _unused();
}

Future<void> _pump(WidgetTester tester, _FakeStudentLinkRepository repository) async {
  await tester.binding.setSurfaceSize(const Size(1440, 1024));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: StudentManagePage(
        repository: repository,
        childContextId: 'context-1',
        logout: unavailableSuperadminLogout,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra a unidade e as turmas antes de qualquer ação', (tester) async {
    await _pump(tester, _FakeStudentLinkRepository());

    expect(find.text('Unidade Centro'), findsOneWidget);
    expect(find.text('Vínculo ativo'), findsOneWidget);
    expect(find.text('Berçário A'), findsOneWidget);
    expect(
      find.text('Berçário B — encerrada'),
      findsOneWidget,
      reason: 'turma encerrada continua visível e dita por texto, não só por cor',
    );
  });

  testWidgets('revogar exige motivo e confirmação', (tester) async {
    final repository = _FakeStudentLinkRepository();
    await _pump(tester, repository);

    await tester.tap(find.byKey(const Key('student-revoke-unit-link-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-revoke-dialog')), findsOneWidget);

    final confirm = tester.widget<FilledButton>(find.byKey(const Key('student-reason-confirm')));
    expect(
      confirm.onPressed,
      isNull,
      reason: 'sem motivo o comando nem sai, porque o servidor recusaria',
    );

    await tester.enterText(find.byKey(const Key('student-reason-field')), 'Saída definitiva.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-reason-confirm')));
    await tester.pumpAndSettle();

    expect(repository.revokes, hasLength(1));
    expect(repository.revokes.single['reason'], 'Saída definitiva.');
    expect(repository.revokes.single['unitId'], 'unit-1');
  });

  testWidgets('depois de revogar, relê do servidor', (tester) async {
    final repository = _FakeStudentLinkRepository();
    await _pump(tester, repository);
    final loadsBefore = repository.loads;

    await tester.tap(find.byKey(const Key('student-revoke-unit-link-1')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('student-reason-field')), 'Saída.');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('student-reason-confirm')));
    await tester.pumpAndSettle();

    expect(
      repository.loads,
      greaterThan(loadsBefore),
      reason: 'a tela mostra o que o servidor confirma, não o que ela supôs',
    );
  });

  testWidgets('quem não pode gerenciar vê o estado e nenhuma ação', (tester) async {
    await _pump(tester, _FakeStudentLinkRepository(canManage: false));

    expect(find.text('Unidade Centro'), findsOneWidget);
    expect(find.byKey(const Key('student-revoke-unit-link-1')), findsNothing);
  });

  testWidgets('vínculo já revogado não oferece revogar de novo', (tester) async {
    await _pump(tester, _FakeStudentLinkRepository(status: 'revoked'));

    expect(find.text('Vínculo revogado'), findsOneWidget);
    expect(find.byKey(const Key('student-revoke-unit-link-1')), findsNothing);
  });

  testWidgets('negativa do servidor falha fechada e oferece nova tentativa', (tester) async {
    await _pump(
      tester,
      _FakeStudentLinkRepository(
        failure: const StudentLinkException(
          StudentLinkFailureKind.notFound,
          'Vínculo indisponível.',
        ),
      ),
    );

    expect(find.byKey(const Key('student-manage-unavailable')), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
