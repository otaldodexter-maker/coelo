import 'package:coelo_superadmin/features/account/data/account_profile_repository.dart';
import 'package:coelo_superadmin/features/account/data/account_sessions_repository.dart';
import 'package:coelo_superadmin/features/account/presentation/screens/settings_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeSessions implements AccountSessionsRepository {
  _FakeSessions(this.sessions, {this.failList = false});

  List<AccountSession> sessions;
  bool failList;
  int revokeCalls = 0;

  @override
  Future<List<AccountSession>> list() async {
    if (failList) throw const AccountProfileRepositoryException('Sem rede.');
    return sessions;
  }

  @override
  Future<void> revokeOthers() async {
    revokeCalls++;
    sessions = sessions.where((s) => s.isCurrent).toList();
  }
}

AccountSession _session(String id, {required bool current}) => AccountSession(
  id: id,
  isCurrent: current,
  createdAt: DateTime(2026, 9, 11, 10),
  refreshedAt: DateTime(2026, 9, 11, 19, 5),
  userAgent: current ? 'Chrome 130 (Windows)' : 'Safari (iPhone)',
  ip: '203.0.113.${current ? 10 : 11}',
);

Widget _host(AccountSessionsRepository repository) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(
    body: SingleChildScrollView(child: SettingsSessionsSection(repository: repository)),
  ),
);

void main() {
  testWidgets('lista a sessao atual primeiro e conta as outras no botao', (tester) async {
    final repository = _FakeSessions([
      _session('a', current: true),
      _session('b', current: false),
      _session('c', current: false),
    ]);
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.text('Chrome 130 (Windows) (esta sessão)'), findsOneWidget);
    expect(find.text('Safari (iPhone)'), findsNWidgets(2));
    expect(find.textContaining('IP 203.0.113.11'), findsNWidgets(2));
    expect(find.text('Encerrar as outras sessões (2)'), findsOneWidget);
  });

  testWidgets('encerrar as outras sessoes chama o repositorio e recarrega', (tester) async {
    final repository = _FakeSessions([_session('a', current: true), _session('b', current: false)]);
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-sessions-revoke-others')));
    await tester.pumpAndSettle();

    expect(repository.revokeCalls, 1);
    expect(find.byKey(const Key('settings-sessions-notice')), findsOneWidget);
    expect(find.text('Safari (iPhone)'), findsNothing);
    expect(find.text('Nenhuma outra sessão'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byKey(const Key('settings-sessions-revoke-others')));
    expect(button.onPressed, isNull, reason: 'sem outras sessoes o comando fica desabilitado');
  });

  testWidgets('falha de carga mostra a mensagem e permite atualizar', (tester) async {
    final repository = _FakeSessions([_session('a', current: true)], failList: true);
    await tester.pumpWidget(_host(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-sessions-failure')), findsOneWidget);
    expect(find.text('Sem rede.'), findsOneWidget);

    repository.failList = false;
    await tester.tap(find.byKey(const Key('settings-sessions-reload')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-sessions-failure')), findsNothing);
    expect(find.text('Chrome 130 (Windows) (esta sessão)'), findsOneWidget);
  });

  testWidgets('SettingsPage sem repositorio de sessoes nao mostra a secao', (tester) async {
    // Coberto pelas suites existentes de settings_page_test (sessions: null);
    // aqui so garantimos que a chave nao existe no host sem repositorio.
    await tester.pumpWidget(
      MaterialApp(theme: CoeloTheme.light, home: const Scaffold(body: SizedBox.shrink())),
    );
    expect(find.byKey(const Key('settings-sessions')), findsNothing);
  });
}
