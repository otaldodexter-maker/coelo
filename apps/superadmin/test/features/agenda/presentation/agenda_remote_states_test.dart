import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coelo_superadmin/features/agenda/data/supabase_agenda_repository.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_calendar_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_events_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_requests_page.dart';
import 'package:coelo_superadmin/features/agenda/presentation/agenda_approvals_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  for (final approvals in [false, true]) {
    for (final state in ['loading', 'failure', 'unauthorized']) {
      testWidgets('request collection approvals=$approvals exposes $state', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          final pending = Completer<Response>();
          final repository = await _repository(
            tester,
            (_) => state == 'loading'
                ? pending.future
                : Future.value(_error(state == 'failure' ? 'XX000' : '42501')),
          );
          addTearDown(() {
            if (!pending.isCompleted) pending.complete(_json(<Object?>[]));
          });
          await tester.pumpWidget(
            MaterialApp(
              theme: CoeloTheme.light,
              home: Scaffold(
                body: approvals
                    ? AgendaApprovalsPage(store: repository)
                    : AgendaRequestsPage.production(store: repository),
              ),
            ),
          );
          if (state == 'loading') {
            await tester.pump();
          } else {
            await tester.pumpAndSettle();
          }
          expect(find.byKey(Key('agenda-collection-$state')), findsOneWidget);
          if (state == 'loading') {
            expect(find.bySemanticsLabel('Carregando retornos da Agenda'), findsOneWidget);
          }
          expect(
            find.byKey(Key(approvals ? 'agenda-approvals-table' : 'agenda-requests-table')),
            findsNothing,
          );
          expect(find.text('Tentar novamente'), state == 'failure' ? findsOneWidget : findsNothing);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
    testWidgets('request collection approvals=$approvals retries both readers', (tester) async {
      var calls = 0;
      final repository = await _repository(
        tester,
        (_) async => ++calls <= 2 ? _error('XX000') : _json(<Object?>[]),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: Scaffold(
            body: approvals
                ? AgendaApprovalsPage(store: repository)
                : AgendaRequestsPage.production(store: repository),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 2);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(calls, 4);
      expect(find.byKey(const Key('agenda-collection-failure')), findsNothing);
      expect(find.byKey(const Key('agenda-collection-empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('request collection states stay accessible across viewports and themes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final approvals in [false, true]) {
      for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
        for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
          for (final state in ['loading', 'failure', 'unauthorized']) {
            await tester.pumpWidget(const SizedBox.shrink());
            tester.view.physicalSize = Size(width, 1000);
            final pending = Completer<Response>();
            final repository = await _repository(
              tester,
              (_) => state == 'loading'
                  ? pending.future
                  : Future.value(_error(state == 'failure' ? 'XX000' : '42501')),
            );
            await tester.pumpWidget(
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(width == 375 ? 2 : 1)),
                  child: RepaintBoundary(key: const Key('agenda-http-golden-root'), child: child!),
                ),
                home: Scaffold(
                  body: approvals
                      ? AgendaApprovalsPage(store: repository)
                      : AgendaRequestsPage.production(store: repository),
                ),
              ),
            );
            if (state == 'loading') {
              await tester.pump();
            } else {
              await tester.pumpAndSettle();
            }
            expect(tester.takeException(), isNull);
            if (state == 'failure') {
              final retry = find.widgetWithText(OutlinedButton, 'Tentar novamente');
              await tester.ensureVisible(retry);
              await tester.pumpAndSettle();
              expect(retry.hitTestable(), findsOneWidget);
              if ((width == 375 && theme.brightness == Brightness.dark) ||
                  (width == 1440 && theme.brightness == Brightness.light)) {
                await expectLater(
                  find.byKey(const Key('agenda-http-golden-root')),
                  matchesGoldenFile(
                    'goldens/agenda_http_${approvals ? 'approvals' : 'requests'}_failure_${theme.brightness.name}_${width.toInt()}.png',
                  ),
                );
              }
            }
            await tester.pumpWidget(const SizedBox.shrink());
            if (!pending.isCompleted) pending.complete(_json(<Object?>[]));
            await tester.pumpAndSettle();
          }
        }
      }
    }
  });

  testWidgets('retry do calendário fica integralmente visível após scroll em tela baixa', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = await _repository(tester, (_) async => _error('XX000'));
    await tester.pumpWidget(_calendar(repository, textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();
    final action = find.widgetWithText(OutlinedButton, 'Tentar novamente');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    final viewport = find.ancestor(of: action, matching: find.byType(SingleChildScrollView)).first;
    final actionRect = tester.getRect(action);
    final viewportRect = tester.getRect(viewport);
    expect(actionRect.top, greaterThanOrEqualTo(viewportRect.top));
    expect(actionRect.bottom, lessThanOrEqualTo(viewportRect.bottom));
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goldens dos estados de leitura seguem painel contextual Coelo', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [375.0, 1440.0]) {
      final compact = width == 375;
      final theme = compact ? CoeloTheme.dark : CoeloTheme.light;
      for (final state in ['loading', 'failure', 'unauthorized']) {
        for (final detail in [false, true]) {
          tester.view.physicalSize = Size(width, 1200);
          await tester.pumpWidget(const SizedBox.shrink());
          final pending = Completer<Response>();
          final repository = await _repository(
            tester,
            (_) => state == 'loading'
                ? pending.future
                : Future.value(_error(state == 'failure' ? 'XX000' : '42501')),
          );
          addTearDown(() {
            if (!pending.isCompleted) {
              pending.complete(_json(detail ? _event() : {'items': <Object?>[]}));
            }
          });
          final scaler = TextScaler.linear(compact ? 2 : 1);
          await tester.pumpWidget(
            detail
                ? _detail(repository, theme: theme, textScaler: scaler)
                : _calendar(repository, theme: theme, textScaler: scaler),
          );
          if (state == 'loading') {
            await tester.pump();
          } else {
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('agenda-http-golden-root')),
            matchesGoldenFile(
              'goldens/agenda_http_${detail ? 'detail' : 'calendar'}_${state}_${theme.brightness.name}_${width.toInt()}.png',
            ),
          );
          await tester.pumpWidget(const SizedBox.shrink());
          if (!pending.isCompleted) {
            pending.complete(_json(detail ? _event() : {'items': <Object?>[]}));
          }
          await tester.pumpAndSettle();
        }
      }
    }
  });

  testWidgets('detalhe permite voltar durante leitura pendente', (tester) async {
    final pending = Completer<Response>();
    final repository = await _repository(tester, (_) => pending.future);
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(_json(_event()));
    });
    var returned = false;
    await tester.pumpWidget(_detail(repository, onBack: () => returned = true));
    await tester.pump();
    await tester.tap(find.text('Eventos'));
    expect(returned, isTrue);
  });

  testWidgets('retry do detalhe funciona pelo teclado', (tester) async {
    var calls = 0;
    final repository = await _repository(
      tester,
      (_) async => ++calls == 1 ? _error('XX000') : _json(_event()),
    );
    await tester.pumpWidget(_detail(repository));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Evento sintético'), findsOneWidget);
  });

  testWidgets('erro de solicitações não derruba calendário pronto', (tester) async {
    final repository = await _repository(
      tester,
      (request) async => request.url.path.endsWith('superadmin_agenda_list')
          ? _json({'items': <Object?>[]})
          : _json('invalid'),
    );
    await tester.pumpWidget(_calendar(repository));
    await tester.pumpAndSettle();
    await repository.loadRequests();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
    expect(find.byKey(const Key('agenda-calendar-failure')), findsNothing);
  });

  testWidgets('estados remotos preservam responsividade, semântica e texto 200%', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final semantics = tester.ensureSemantics();
    try {
      for (final width in [375.0, 1440.0]) {
        for (final theme in [CoeloTheme.light, CoeloTheme.dark]) {
          for (final state in ['loading', 'failure', 'unauthorized']) {
            for (final detail in [false, true]) {
              tester.view.physicalSize = Size(width, 1200);
              await tester.pumpWidget(const SizedBox.shrink());
              final pending = Completer<Response>();
              final repository = await _repository(
                tester,
                (_) => state == 'loading'
                    ? pending.future
                    : Future.value(_error(state == 'failure' ? 'XX000' : '42501')),
              );
              addTearDown(() {
                if (!pending.isCompleted) {
                  pending.complete(_json(detail ? _event() : {'items': <Object?>[]}));
                }
              });
              await tester.pumpWidget(
                detail
                    ? _detail(repository, theme: theme, textScaler: const TextScaler.linear(2))
                    : _calendar(repository, theme: theme, textScaler: const TextScaler.linear(2)),
              );
              if (state == 'loading') {
                await tester.pump();
              } else {
                await tester.pumpAndSettle();
              }
              final panel = find.byKey(Key('agenda-${detail ? 'event' : 'calendar'}-$state'));
              expect(panel, findsOneWidget);
              expect(
                tester.takeException(),
                isNull,
                reason: '$width ${theme.brightness} $state detail=$detail',
              );
              if (state == 'loading') {
                expect(tester.getSemantics(panel).label, contains('Carregando'));
                await tester.pumpWidget(const SizedBox.shrink());
                pending.complete(_json(detail ? _event() : {'items': <Object?>[]}));
                await tester.pumpAndSettle();
              } else if (state == 'failure') {
                final action = find.widgetWithText(OutlinedButton, 'Tentar novamente');
                await tester.ensureVisible(action);
                expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
              }
              expect(
                tester.takeException(),
                isNull,
                reason: '$width ${theme.brightness} $state detail=$detail',
              );
            }
          }
        }
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('calendário distingue leitura pendente de mês vazio confirmado', (tester) async {
    final pending = Completer<Response>();
    final repository = await _repository(tester, (_) => pending.future);
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(_json({'items': <Object?>[]}));
    });
    await tester.pumpWidget(_calendar(repository));
    await tester.pump();
    expect(find.byKey(const Key('agenda-calendar-loading')), findsOneWidget);
    expect(find.byKey(const Key('agenda-month-grid')), findsNothing);
    pending.complete(_json({'items': <Object?>[]}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
    expect(find.byKey(const Key('agenda-calendar-loading')), findsNothing);
  });

  testWidgets('calendário mostra falha e retry preserva período solicitado', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final repository = await _repository(tester, (request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return bodies.length == 1 ? _error('XX000') : _json({'items': <Object?>[]});
    });
    await tester.pumpWidget(_calendar(repository));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-calendar-failure')), findsOneWidget);
    expect(find.byKey(const Key('agenda-month-grid')), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(bodies, hasLength(2));
    expect(bodies[1]['p_from'], bodies[0]['p_from']);
    expect(bodies[1]['p_to'], bodies[0]['p_to']);
    expect(find.byKey(const Key('agenda-month-grid')), findsOneWidget);
  });

  testWidgets('negação remove conteúdo anterior da lista do calendário', (tester) async {
    var denied = false;
    final repository = await _repository(
      tester,
      (_) async => denied
          ? _error('42501')
          : _json({
              'items': [_event()],
            }),
    );
    await tester.pumpWidget(_calendar(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('agenda-view-list')));
    await tester.pumpAndSettle();
    expect(find.text('Evento sintético'), findsOneWidget);
    denied = true;
    await repository.loadEvents(from: DateTime(2026, 9), to: DateTime(2026, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-calendar-unauthorized')), findsOneWidget);
    expect(find.text('Evento sintético'), findsNothing);
    expect(find.byKey(const Key('agenda-list-timeline')), findsNothing);
  });

  testWidgets('detalhe pendente não apresenta not-found nem ações', (tester) async {
    final pending = Completer<Response>();
    final repository = await _repository(tester, (_) => pending.future);
    addTearDown(() {
      if (!pending.isCompleted) pending.complete(_json(_event()));
    });
    await tester.pumpWidget(_detail(repository));
    await tester.pump();
    expect(find.byKey(const Key('agenda-event-loading')), findsOneWidget);
    expect(find.text('Item não encontrado'), findsNothing);
    expect(find.text('Editar item'), findsNothing);
    pending.complete(_json(_event()));
    await tester.pumpAndSettle();
    expect(find.text('Evento sintético'), findsOneWidget);
  });

  testWidgets('detalhe com falha oculta snapshot e retry consulta o mesmo ID', (tester) async {
    var fail = false;
    final ids = <Object?>[];
    final repository = await _repository(tester, (request) async {
      ids.add((jsonDecode(request.body) as Map<String, dynamic>)['p_event_id']);
      return fail ? _error('XX000') : _json(_event());
    });
    await tester.pumpWidget(_detail(repository));
    await tester.pumpAndSettle();
    expect(find.text('Evento sintético'), findsOneWidget);
    fail = true;
    await repository.loadItem(_eventId);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agenda-event-failure')), findsOneWidget);
    expect(find.text('Evento sintético'), findsNothing);
    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(ids, [_eventId, _eventId, _eventId]);
    expect(find.text('Evento sintético'), findsOneWidget);
  });

  testWidgets('detalhe indisponível não consulta o repository', (tester) async {
    var calls = 0;
    final repository = await _repository(tester, (_) async {
      calls++;
      return _json(_event());
    });
    await tester.pumpWidget(_detail(repository, unavailable: true));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(find.text('Agenda indisponível'), findsOneWidget);
  });

  for (final code in ['P0002', '42501']) {
    testWidgets('detalhe distingue resposta remota $code', (tester) async {
      final repository = await _repository(tester, (_) async => _error(code));
      await tester.pumpWidget(_detail(repository));
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key(code == 'P0002' ? 'agenda-event-not-found' : 'agenda-event-unauthorized')),
        findsOneWidget,
      );
      if (code == '42501') expect(find.text('Item não encontrado'), findsNothing);
    });
  }
}

Future<SupabaseAgendaRepository> _repository(
  WidgetTester tester,
  Future<Response> Function(Request) handler,
) async {
  // The SDK creates a JSON isolate; initialize and dispose it outside fakeAsync.
  final client = (await tester.runAsync(
    () async => SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((request) async {
        // O detalhe aberto por link direto tambem le os contextos (rev 26 da
        // R04); os testes de item nao contam essa chamada nem a simulam.
        final response = request.url.path.endsWith('superadmin_agenda_contexts')
            ? _json({'contexts': <Object?>[]})
            : await handler(request);
        return Response.bytes(
          response.bodyBytes,
          response.statusCode,
          headers: response.headers,
          request: request,
        );
      }),
    ),
  ))!;
  final repository = SupabaseAgendaRepository(client, clock: () => DateTime(2026, 9, 3));
  addTearDown(() async {
    repository.dispose();
    await tester.runAsync(client.dispose);
  });
  return repository;
}

Widget _calendar(
  SupabaseAgendaRepository repository, {
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  themeAnimationStyle: AnimationStyle.noAnimation,
  theme: theme ?? CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler, disableAnimations: true),
    child: RepaintBoundary(key: const Key('agenda-http-golden-root'), child: child!),
  ),
  home: AgendaCalendarPage(
    store: repository,
    logout: () async => const LogoutResult.success(),
    onAreaSelected: (_) {},
    onCreateItem: () {},
  ),
);
Widget _detail(
  SupabaseAgendaRepository repository, {
  bool unavailable = false,
  ThemeData? theme,
  TextScaler textScaler = TextScaler.noScaling,
  VoidCallback? onBack,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  themeAnimationStyle: AnimationStyle.noAnimation,
  theme: theme ?? CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler, disableAnimations: true),
    child: RepaintBoundary(key: const Key('agenda-http-golden-root'), child: child!),
  ),
  home: Scaffold(
    body: AgendaEventDetailPage(
      store: repository,
      eventId: _eventId,
      onBack: onBack ?? () {},
      onEdit: () {},
      unavailable: unavailable,
    ),
  ),
);
Response _json(Object value) =>
    Response(jsonEncode(value), 200, headers: {'content-type': 'application/json'});
Response _error(String code) => code == 'XX000'
    ? _json('invalid')
    : Response(
        jsonEncode({'code': code, 'message': 'untrusted server text'}),
        code == '42501' ? 403 : 404,
        headers: {'content-type': 'application/json'},
      );
Map<String, Object?> _event() => {
  'id': _eventId,
  'institution_id': '10000000-0000-4000-8000-000000000001',
  'title': 'Evento sintético',
  'item_type': 'event',
  'priority': 'normal',
  'status': 'draft',
  'origin': 'institution',
  'starts_at': '2026-09-03T13:00:00Z',
  'ends_at': '2026-09-03T14:00:00Z',
  'audience': <String, Object?>{},
  'revision': 1,
};
const _eventId = '30000000-0000-4000-8000-000000000001';

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final icons = File(
    '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons)))).load();
}
