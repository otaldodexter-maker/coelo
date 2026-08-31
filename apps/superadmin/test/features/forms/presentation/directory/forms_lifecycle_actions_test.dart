import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/presentation/directory/forms_lifecycle_actions.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hides lifecycle actions without forms.manage', (tester) async {
    await _pump(tester, api: _LifecycleApi(), canManage: false);

    expect(find.byTooltip('Ações do formulário Pesquisa das famílias'), findsNothing);
  });

  testWidgets('exposes schedules without granting lifecycle mutations', (tester) async {
    var schedules = 0;
    await _pump(tester, api: null, canManage: false, onManageSchedules: () => schedules++);

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa das famílias'));
    await tester.pumpAndSettle();

    expect(find.text('Agendamentos'), findsOneWidget);
    expect(find.text('Duplicar'), findsNothing);
    expect(find.text('Arquivar'), findsNothing);
    await tester.tap(find.text('Agendamentos'));
    await tester.pumpAndSettle();
    expect(schedules, 1);
  });

  testWidgets('uses the approved inset zero-halo flyout variant', (tester) async {
    await _pump(tester, api: _LifecycleApi());

    final flyout =
        tester.widget(find.byWidgetPredicate((widget) => widget is CoeloAdminFlyout))
            as CoeloAdminFlyout;
    expect(flyout.viewportGap, CoeloSpacing.space3);
    expect(flyout.elevation, CoeloElevation.level0);
    expect(flyout.alignPanelToViewportEnd, isTrue);
    expect(flyout.crossAxisUnconstrained, isTrue);
    expect(flyout.outlineOpacity, 0.38);
  });

  testWidgets('offers edit and scheduling through explicit navigation callbacks', (tester) async {
    final api = _LifecycleApi();
    var edits = 0;
    var schedules = 0;
    await _pump(tester, api: api, onEdit: () => edits++, onManageSchedules: () => schedules++);

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa das famílias'));
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Agendamentos'), findsOneWidget);

    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(edits, 1);

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa das famílias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendamentos'));
    await tester.pumpAndSettle();
    expect(schedules, 1);
  });

  testWidgets('duplicates only after explicit confirmation and reports success', (tester) async {
    final api = _LifecycleApi();
    var completions = 0;
    await _pump(tester, api: api, onCompleted: () => completions++);

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa das famílias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicar'));
    await tester.pumpAndSettle();

    expect(find.text('Duplicar formulário?'), findsOneWidget);
    expect(api.duplicateCommands, isEmpty);

    await tester.tap(find.widgetWithText(FilledButton, 'Duplicar'));
    await tester.pumpAndSettle();

    expect(api.duplicateCommands.single.expectedVersion, 7);
    expect(api.duplicateCommands.single.payload.formId, 'form-1');
    expect(completions, 1);
    expect(find.text('Formulário duplicado.'), findsOneWidget);
  });

  testWidgets('requires a valid target institution before copying or moving', (tester) async {
    final api = _LifecycleApi();
    await _pump(tester, api: api, canTransferCrossInstitution: true);

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa das famílias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copiar para instituição'));
    await tester.pumpAndSettle();

    final confirm = find.widgetWithText(FilledButton, 'Copiar');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('form-lifecycle-target-institution')),
      '22222222-2222-4222-8222-222222222222',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    final command = api.copyOrMoveCommands.single;
    expect(command.expectedVersion, 7);
    expect(command.payload.targetInstitutionId, '22222222-2222-4222-8222-222222222222');
    expect(command.payload.mode, FormCopyOrMoveMode.copy);
  });

  testWidgets('surfaces a version conflict and does not report completion', (tester) async {
    final api = _LifecycleApi(failure: FormApiFailureKind.conflict);
    var completions = 0;
    await _pump(tester, api: api, onCompleted: () => completions++);

    await tester.tap(find.byTooltip('Ações do formulário Pesquisa das famílias'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arquivar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Arquivar'));
    await tester.pumpAndSettle();

    expect(api.archiveCommands.single.payload.action, FormArchiveOrDeleteAction.archive);
    expect(completions, 0);
    expect(
      find.text('O formulário foi alterado em outra sessão. Recarregue e tente novamente.'),
      findsOneWidget,
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required FormsApi? api,
  bool canManage = true,
  bool canTransferCrossInstitution = false,
  VoidCallback? onCompleted,
  VoidCallback? onEdit,
  VoidCallback? onManageSchedules,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: Center(
          child: FormsLifecycleActions(
            api: api,
            formId: 'form-1',
            formTitle: 'Pesquisa das famílias',
            managementVersion: 7,
            canManage: canManage,
            canTransferCrossInstitution: canTransferCrossInstitution,
            requestIdFactory: () => '11111111-1111-4111-8111-111111111111',
            onCompleted: onCompleted,
            onEdit: onEdit,
            onManageSchedules: onManageSchedules,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _LifecycleApi implements FormsApi {
  _LifecycleApi({this.failure});

  final FormApiFailureKind? failure;
  final duplicateCommands = <FormCommand<FormIdPayload>>[];
  final copyOrMoveCommands = <FormCommand<FormCopyOrMovePayload>>[];
  final archiveCommands = <FormCommand<FormArchiveOrDeletePayload>>[];

  @override
  Future<FormDefinition> duplicate(FormCommand<FormIdPayload> command) async {
    duplicateCommands.add(command);
    _failIfNeeded();
    return _definition;
  }

  @override
  Future<FormDefinition> copyOrMove(FormCommand<FormCopyOrMovePayload> command) async {
    copyOrMoveCommands.add(command);
    _failIfNeeded();
    return _definition;
  }

  @override
  Future<void> archiveOrDelete(FormCommand<FormArchiveOrDeletePayload> command) async {
    archiveCommands.add(command);
    _failIfNeeded();
  }

  void _failIfNeeded() {
    final value = failure;
    if (value != null) throw FormApiException(value, 'backend failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _definition = FormDefinition(
  id: 'form-2',
  institutionId: 'institution-1',
  kind: FormKind.form,
  identityMode: FormIdentityMode.identified,
  responseUnit: FormResponseUnit.person,
  title: 'Cópia de Pesquisa das famílias',
  managementVersion: 1,
  sections: const [],
);
