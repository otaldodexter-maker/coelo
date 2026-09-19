import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:coelo_superadmin/features/staff_access/data/staff_access_denied_http_client.dart';
import 'package:coelo_superadmin/features/staff_access/domain/staff_access_denied.dart';
import 'package:coelo_superadmin/features/principal_shared/presentation/principal_runtime_context_route.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// ADR 0035: o vínculo bloqueado pelo servidor segue listado, sem dados; ao
/// tentar entrar, popup (uma vez por sessão) ou mensagem genérica e volta ao
/// seletor. O cliente nunca decide: só reflete `access_blocked`.
void main() {
  Widget app(PrincipalRuntimeContextRepository repository) => MaterialApp(
    theme: CoeloTheme.light,
    home: Scaffold(
      body: PrincipalRuntimeContextRoute(
        repository: repository,
        avatarInitials: 'QA',
        builder: (_, selected) => Text('Ativo: ${selected.institutionName}'),
      ),
    ),
  );

  testWidgets('abre no primeiro contexto liberado e marca o bloqueado no seletor', (tester) async {
    resetPrincipalContextSelectionForTests();
    await tester.pumpWidget(app(_Contexts(blockedFirst: true)));
    await tester.pumpAndSettle();
    // "a" está bloqueado: o contexto ativo é "b", sem expor nada de "a".
    expect(find.text('Ativo: QA b'), findsOneWidget);

    await tester.tap(find.byTooltip('Abrir menu do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver como'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('principal-context-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('principal-context-blocked-a')), findsOneWidget);
    expect(find.text('Não disponível agora'), findsOneWidget);

    // Tentar entrar em "a": popup com o horário do servidor e "Trocar contexto".
    await tester.tap(find.byKey(const ValueKey('principal-context-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-context-blocked-dialog')), findsOneWidget);
    expect(find.text('Horário permitido: Seg 08:00–18:00.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('principal-context-blocked-switch')));
    await tester.pumpAndSettle();
    // Continua em "b".
    expect(find.text('Ativo: QA b'), findsOneWidget);

    // Segunda tentativa na mesma sessão: mensagem curta, sem popup.
    await tester.tap(find.byTooltip('Abrir menu do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver como'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('principal-context-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-context-blocked-dialog')), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Ativo: QA b'), findsOneWidget);
  });

  testWidgets('popup desligado mostra a mensagem genérica', (tester) async {
    resetPrincipalContextSelectionForTests();
    await tester.pumpWidget(app(_Contexts(blockedFirst: true, popup: false)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Abrir menu do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver como'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('principal-context-a')));
    await tester.pumpAndSettle();
    expect(find.text('Este contexto não está disponível agora.'), findsOneWidget);
  });

  testWidgets('todos os vínculos bloqueados: painel sem dados do contexto', (tester) async {
    resetPrincipalContextSelectionForTests();
    await tester.pumpWidget(app(_Contexts(blockedFirst: true, blockedAll: true)));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-context-all-blocked')), findsOneWidget);
    expect(find.textContaining('Ativo:'), findsNothing);
  });

  testWidgets('"ver como" múltiplo: o bloqueado não marca e abre o popup', (tester) async {
    resetPrincipalContextSelectionForTests();
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: Scaffold(
          body: PrincipalRuntimeContextRoute(
            repository: _Contexts(blockedFirst: true),
            avatarInitials: 'QA',
            multipleBuilder: (_, selected) => Text('Selected: ${selected.length}'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Abrir menu do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver como'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('principal-context-a')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('principal-context-blocked-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('principal-context-blocked-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(find.text('Selected: 1'), findsOneWidget);
  });

  testWidgets('sessão aberta: PT403 do servidor vira popup do listener, fecha o "ver como" e recarrega', (
    tester,
  ) async {
    resetPrincipalContextSelectionForTests();
    staffAccessDenied.value = null;
    final contexts = _Contexts();
    // Mesma cadeia da produção: resposta 403/STAFF_ACCESS_DENIED de uma RPC do
    // Principal passa pelo cliente HTTP e publica a negação.
    const body =
        '{"code":"PT403","message":"STAFF_ACCESS_DENIED","hint":null,'
        '"details":"{\\"code\\":\\"STAFF_ACCESS_DENIED\\",\\"membership_id\\":\\"a\\",\\"reason\\":\\"schedule\\",'
        '\\"popup\\":{\\"kind\\":\\"schedule\\",\\"windows\\":[{\\"weekday\\":1,\\"start\\":\\"08:00\\",\\"end\\":\\"18:00\\"}]}}"}';
    final client = StaffAccessDeniedHttpClient(MockClient((_) async => http.Response(body, 403)));
    await tester.pumpWidget(app(contexts));
    await tester.pumpAndSettle();
    expect(find.text('Ativo: QA a'), findsOneWidget);

    await tester.tap(find.byTooltip('Abrir menu do perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver como'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('principal-context-a')), findsOneWidget);

    // O horário vira com a sessão aberta: a próxima chamada ao servidor nega.
    contexts.blockedFirst = true;
    await client.post(Uri.parse('https://x/rest/v1/rpc/list_visible_happens_feed'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff-access-denied-dialog')), findsOneWidget);
    expect(find.text('Horário permitido: Seg 08:00–18:00.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('staff-access-denied-switch')));
    await tester.pumpAndSettle();
    // Folha antiga fechada, contextos recarregados: segue em "b".
    expect(find.byKey(const ValueKey('principal-context-a')), findsNothing);
    expect(find.text('Ativo: QA b'), findsOneWidget);
  });
}

class _Contexts implements PrincipalRuntimeContextRepository {
  _Contexts({this.blockedFirst = false, this.blockedAll = false, this.popup = true});
  bool blockedFirst;
  final bool blockedAll;
  final bool popup;

  @override
  Future<List<PrincipalRuntimeContext>> listAvailableContexts() async => [
    for (final id in ['a', 'b'])
      PrincipalRuntimeContext(
        membershipId: id,
        personId: 'qa',
        institutionId: id,
        institutionName: 'QA $id',
        roleCode: 'teacher',
        scopeKind: 'institution',
        accessBlocked: blockedAll || (blockedFirst && id == 'a'),
        accessReason: blockedAll || (blockedFirst && id == 'a') ? 'schedule' : null,
        accessPopup: popup && (blockedAll || (blockedFirst && id == 'a'))
            ? {
                'kind': 'schedule',
                'windows': [
                  {'weekday': 1, 'start': '08:00', 'end': '18:00'},
                ],
              }
            : null,
      ),
  ];
}
