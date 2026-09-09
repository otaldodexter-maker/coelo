import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _failureTitle = 'Não foi possível carregar';
const _failureMessage = 'Nenhum dado anterior foi mantido.';
const _retryLabel = 'Tentar novamente';
const _errorMessage = 'Não foi possível carregar a segurança da criança.';

final _retry = find.widgetWithText(OutlinedButton, _retryLabel);

void main() {
  test('safety.list: carga que lança Error conclui e cai em erro, não em loading', () async {
    final repository = _Repository()..directoryFailure = _realCastError;
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    addTearDown(controller.dispose);

    await _completeWithoutEscaping(controller.load(), 'ChildSafetyController.load()');

    expect(
      controller.state,
      ChildSafetyLoadState.error,
      reason:
          'o estado ficou em ${controller.state}; enquanto for loading a página serve o '
          'esqueleto e nunca oferece "$_retryLabel"',
    );
    expect(controller.records, isEmpty, reason: 'a falha não pode manter dado anterior');
    expect(controller.totalCount, 0);
    expect(controller.canCreate, isFalse);
    expect(
      controller.errorMessage,
      isNotNull,
      reason: 'a falha precisa de mensagem própria, como já acontece com Exception',
    );
  });

  test('safety.list: a falha com Error é anunciada e o retry recupera a listagem', () async {
    final repository = _Repository()..directoryFailure = _realCastError;
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    addTearDown(controller.dispose);
    final announced = <ChildSafetyLoadState>[];
    controller.addListener(() => announced.add(controller.state));

    await _completeWithoutEscaping(controller.load(), 'ChildSafetyController.load()');

    expect(
      announced,
      isNotEmpty,
      reason: 'a carga precisa avisar pelo menos o início e o desfecho',
    );
    expect(
      announced.last,
      ChildSafetyLoadState.error,
      reason:
          'o último aviso aos ouvintes foi ${announced.last}: sem um aviso de erro a '
          'página não reconstrói e o operador continua vendo o esqueleto',
    );

    repository.directoryFailure = null;
    await _completeWithoutEscaping(controller.retry(), 'ChildSafetyController.retry()');

    expect(
      controller.state,
      ChildSafetyLoadState.ready,
      reason: 'falhar deve ser recuperável: o retry precisa devolver o diretório',
    );
    expect(controller.records.single.childName, 'Ana');
    expect(controller.errorMessage, isNull);
    expect(repository.queries, hasLength(2), reason: 'o retry deve reler exatamente uma vez');
  });

  test('safety.list: controle - carga que lança Exception já cai em erro', () async {
    final repository = _Repository()
      ..directoryFailure = () => const ChildSafetyUnavailableException();
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    addTearDown(controller.dispose);

    await _completeWithoutEscaping(controller.load(), 'ChildSafetyController.load()');

    expect(controller.state, ChildSafetyLoadState.error);
    expect(controller.records, isEmpty);
    expect(controller.errorMessage, _errorMessage);
  });

  testWidgets('safety.list: a falha com Error sai do esqueleto e mostra retry', (tester) async {
    await _useSurface(tester, 1440);
    final repository = _Repository()..directoryFailure = _realCastError;
    final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller));
    await _settleLoad(tester);

    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'a página de Segurança da criança ficou presa no esqueleto de carregamento',
    );
    expect(find.text(_failureTitle), findsOneWidget);
    expect(find.text(_failureMessage), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(_retry).enabled,
      isTrue,
      reason: 'sem "$_retryLabel" o operador não tem saída da tela travada',
    );
    expect(find.textContaining('is not a subtype'), findsNothing);
    expect(
      tester.takeException(),
      isNull,
      reason:
          'a carga disparada em initState propagou erro não tratado para a árvore: '
          '`load()` deve converter a falha em estado, não em exceção solta',
    );
  });
}

Future<void> _completeWithoutEscaping(Future<void> future, String action) async {
  Object? escaped;
  await future
      .catchError((Object error) {
        escaped = error;
      })
      .timeout(
        const Duration(seconds: 2),
        onTimeout: () => fail(
          '$action não concluiu em 2 s: a carga ficou pendente e a tela permanece '
          'no esqueleto de carregamento.',
        ),
      );
  expect(
    escaped,
    isNull,
    reason:
        '$action propagou ${escaped?.runtimeType} em vez de virar estado de erro. '
        'O `on Exception` de `_load` não captura `Error`, então o `_notify()` '
        'final não roda e o estado permanece em loading.',
  );
}

Object _boxedInteger() => 42;

Object _realCastError() {
  try {
    final _ = _boxedInteger() as String;
  } on TypeError catch (error) {
    return error;
  }
  return StateError('o cast inesperadamente funcionou');
}

Widget _app(ChildSafetyController controller) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  home: SafetyLandingPage(
    controller: controller,
    logout: () async => const LogoutResult.success(),
    onOpenChild: (_) {},
    onCreate: () {},
    onExport: () {},
  ),
);

Future<void> _useSurface(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _settleLoad(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final class _Repository implements ChildSafetyRepository, ChildSafetyMutationSupport {
  @override
  bool get mutationsEnabled => true;
  final queries = <ChildSafetyDirectoryQuery>[];

  Object Function()? directoryFailure;

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async {
    queries.add(query);
    final failure = directoryFailure;
    if (failure != null) throw failure();
    return const ChildSafetyDirectoryPage(
      records: [
        ChildSafetyRecord(
          childId: 'child-1',
          childName: 'Ana',
          internalId: 'RA 1',
          institutionName: 'Aurora',
          unitName: 'Centro',
          authorizations: [],
        ),
      ],
      totalCount: 1,
      segmentCounts: ChildSafetySegmentCounts(all: 1, withoutAuthorization: 1),
      canCreate: true,
    );
  }

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async => null;
  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async =>
      const [];
  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {}
  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {}
  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) async {}
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {}
}
