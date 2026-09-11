import 'package:coelo_superadmin/features/chat/domain/chat_repository.dart';
import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_create_group_dialog.dart';
import 'package:coelo_superadmin/app/dev_menu/development_person_directory_repository.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('monta o comando com instituicao, titulo e membros escolhidos do diretorio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final people = DevelopmentPersonDirectoryRepository();
    final options = await people.fetchFilterOptions();
    final institution = options.institutions.first;
    final page = await people.fetchPage(
      PersonDirectoryQuery(institutionIds: {institution.id}, pageSize: 50),
    );
    ChatCreateGroupCommand? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await SuperadminChatCreateGroupDialog.show(
                    context,
                    people: people,
                    requestId: 'request-1',
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('superadmin-chat-create-group-dialog')), findsOneWidget);
    final submit = find.byKey(const Key('superadmin-chat-create-group-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull, reason: 'sem titulo nem membros');

    await tester.tap(find.byKey(const Key('superadmin-chat-create-group-institution')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(institution.label).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('superadmin-chat-create-group-title')), 'Coordenação');
    await tester.pumpAndSettle();
    final first = page.items.first;
    await tester.tap(find.byKey(Key('superadmin-chat-create-group-person-${first.id}')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.institutionId, institution.id);
    expect(result!.title, 'Coordenação');
    expect(result!.personIds, [first.id]);
    expect(result!.requestId, 'request-1');
  });
}
