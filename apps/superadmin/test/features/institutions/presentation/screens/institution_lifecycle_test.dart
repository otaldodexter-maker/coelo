import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/institutions/data/fake_institution_directory_repository.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_directory_item.dart';
import 'package:coelo_superadmin/features/institutions/domain/institution_lifecycle.dart';
import 'package:coelo_superadmin/features/institutions/presentation/screens/institution_directory_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// spec 066: ⋯ do card oferece Inativar/Ativar/Excluir; transição restritiva
// exige motivo e o comando recebe id, versão e motivo; sem comandos, sem menu.
void main() {
  testWidgets('directory shows no lifecycle menu without commands', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('institution-lifecycle-demo-institution-aurora')), findsNothing);
  });

  testWidgets('inactivate asks for a reason and sends the command', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifecycle = _RecordingLifecycle();
    await tester.pumpWidget(_app(lifecycle: lifecycle));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-lifecycle-demo-institution-aurora')));
    await tester.pumpAndSettle();
    expect(find.text('Inativar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    await tester.tap(find.text('Inativar'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('institution-lifecycle-reason-dialog')), findsOneWidget);
    final confirm = find.byKey(const Key('institution-lifecycle-confirm'));
    expect(tester.widget<FilledButton>(confirm).enabled, isFalse);
    await tester.enterText(
      find.byKey(const Key('institution-lifecycle-reason')),
      'Encerramento do contrato',
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(lifecycle.calls, hasLength(1));
    expect(lifecycle.calls.single.$1, 'demo-institution-aurora');
    expect(lifecycle.calls.single.$2, InstitutionStatus.inactive);
    expect(lifecycle.calls.single.$3, 'Encerramento do contrato');
    expect(find.textContaining('inativada.'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('delete without dependents reports a real deletion', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lifecycle = _RecordingLifecycle(hardDelete: true);
    await tester.pumpWidget(_app(lifecycle: lifecycle));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('institution-lifecycle-demo-institution-aurora')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('institution-lifecycle-reason')), 'Duplicada');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('institution-lifecycle-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(lifecycle.deletes, ['demo-institution-aurora']);
    expect(find.textContaining('excluída.'), findsOneWidget);
    await tester.pumpAndSettle();
  });
}

Widget _app({InstitutionLifecycleCommands? lifecycle}) => MaterialApp(
  theme: CoeloTheme.light,
  home: InstitutionDirectoryPage(
    repository: FakeInstitutionDirectoryRepository(),
    lifecycle: lifecycle,
    logout: () async => const LogoutResult.success(),
    onCreate: () {},
    onEdit: (_) {},
  ),
);

final class _RecordingLifecycle implements InstitutionLifecycleCommands {
  _RecordingLifecycle({this.hardDelete = false});

  final bool hardDelete;
  final calls = <(String, InstitutionStatus, String?)>[];
  final deletes = <String>[];

  @override
  Future<InstitutionLifecycleResult> changeStatus(
    String institutionId, {
    required int expectedVersion,
    required InstitutionStatus status,
    required String requestId,
    String? reason,
  }) async {
    calls.add((institutionId, status, reason));
    return InstitutionLifecycleResult(
      institutionId: institutionId,
      status: status.databaseValue,
      hardDeleted: false,
      managementVersion: expectedVersion + 1,
    );
  }

  @override
  Future<InstitutionLifecycleResult> delete(
    String institutionId, {
    required int expectedVersion,
    required String requestId,
    required String reason,
  }) async {
    deletes.add(institutionId);
    return InstitutionLifecycleResult(
      institutionId: institutionId,
      status: hardDelete ? 'deleted' : 'archived',
      hardDeleted: hardDelete,
    );
  }
}
