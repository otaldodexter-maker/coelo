// C07 - Segurança da criança: uma carga que falha com `Error` precisa virar
// estado de erro recuperável, nunca esqueleto eterno.
//
// Destino no repositório:
//   apps/superadmin/test/features/safety/application/child_safety_error_hang_test.dart
//
// Defeito medido: `child_safety_controller.dart:146` fecha o `try` de `_load`
// com `on Exception`. Em Dart, `on Exception` não captura `Error`. O `Error`
// escapa antes do `_notify()` da linha 152, então:
//
// - o estado continua `ChildSafetyLoadState.loading` (linha 128);
// - nenhum ouvinte é avisado da falha, logo a página não reconstrói;
// - `safety_pages.dart:229` continua servindo o `CoeloStatePanel(loading: true)`
//   e o retry, que só existe no ramo `ChildSafetyLoadState.error`
//   (`safety_pages.dart:239`), nunca aparece;
// - `safety_pages.dart:67` (`initState`) dispara `load()` sem `await` e sem
//   `catchError`, então o `Error` ainda vira erro não tratado na árvore.
//
// Consequência de domínio: a tela presa em carregando esconde do operador o
// estado real das autorizações de retirada de uma criança.
//
// O que estes testes afirmam é o contrato, não o bug: carregar nunca propaga
// nem fica pendente; falhar é anunciado; e o retry recupera.
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
  // ---------------------------------------------------------------------------
  // safety.list: carga que falha com Error
  // ---------------------------------------------------------------------------
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

  // Controle: separa "o teste está errado" de "o código está errado". A mesma
  // carga, falhando com uma Exception comum, já termina em erro hoje.
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

  // ---------------------------------------------------------------------------
  // safety.list: a mesma falha na tela
  //
  // Caminho de produção: a página nasce em loading e o próprio `initState`
  // dispara a carga. Se o `Error` escapar, nada reconstrói a tela.
  // ---------------------------------------------------------------------------
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
    // O detalhe técnico do cast nunca chega à tela.
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

// -----------------------------------------------------------------------------
// Ajudantes
// -----------------------------------------------------------------------------

/// Um `Future` que nunca completa e um `Future` que estoura são falhas
/// diferentes do mesmo contrato: carregar tem de virar estado. O `timeout`
/// transforma o travamento em falha legível; o `catchError` transforma o
/// vazamento em asserção, em vez de deixar o `Error` cru derrubar o teste.
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

/// Produz o mesmo `TypeError` que um payload fora do contrato geraria num cast
/// cru como os de `child_safety_response_decoder.dart:84-88`
/// (`internal_id as String?` e vizinhos). `TypeError` é `Error`, não
/// `Exception`, e por isso atravessa o `on Exception` do controller.
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

/// Avança frames com duração fixa: esperar o loading terminar com
/// `pumpAndSettle` tornaria o próprio travamento indistinguível de um timeout.
Future<void> _settleLoad(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// -----------------------------------------------------------------------------
// Fake
// -----------------------------------------------------------------------------

final class _Repository implements ChildSafetyRepository {
  final queries = <ChildSafetyDirectoryQuery>[];

  /// Construído a cada leitura para que cada falha seja um objeto distinto.
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
