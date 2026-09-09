// C07 - Segurança da criança: uma busca que falha precisa dizer que falhou.
// Falhar nunca pode virar "não encontrei ninguém".
//
// Destino no repositório:
//   apps/superadmin/test/features/safety/presentation/child_safety_silent_search_test.dart
//
// -----------------------------------------------------------------------------
// Produtor do defeito
// -----------------------------------------------------------------------------
// `child_safety_response_decoder.dart:84-88`, dentro de
// `decodeChildSafetyOptions`, usa conversões cruas:
//
//   internalId:      child['internal_id']         as String?
//   childContextId:  context['child_context_id']  as String?
//   institutionId:   context['institution_id']    as String?
//   unitId:          context['unit_id']           as String?
//
// O mesmo arquivo define `_string`, `_nullableString`, `_map` e `_list` e os usa
// em todo o resto do decodificador, inclusive nos campos vizinhos
// `institution_name` e `unit_name` das mesmas linhas. Se a consulta devolver um
// desses quatro campos como número, sai `TypeError`, que é `Error` e não
// `Exception`.
//
// -----------------------------------------------------------------------------
// Consumidor do defeito
// -----------------------------------------------------------------------------
// `safety_pages.dart:1125-1137`, `_ChildSafetyWizardPageState._search`:
//
//   setState(() { searching = true; error = null; });
//   try   { final result = await widget.controller.searchChildren(childSearch.text);
//           if (mounted) setState(() => options = result); }
//   on Exception { if (mounted) setState(() => error = 'Não foi possível buscar crianças.'); }
//   finally      { if (mounted) setState(() => searching = false); }
//
// O `Error` atravessa o `on Exception` — mas o `finally` desliga o indicador
// assim mesmo. Não basta ver que existe um `finally`: é preciso ler o que há
// dentro dele. Aqui o `finally` é justamente o que produz o sintoma silencioso.
//
// Efeito observável: o spinner some, a mensagem de erro não aparece e a lista
// fica vazia (ou com o resultado anterior). A busca "termina" fingindo que não
// encontrou ninguém, num formulário que autoriza quem pode retirar uma criança.
// Pior que uma tela presa: presa é visivelmente quebrada; esta parece funcionar
// e devolve uma resposta errada plausível.
//
// Agravante lido na própria tela: o passo 0 do wizard
// (`safety_pages.dart:947-995`) renderiza apenas o campo de busca e o laço sobre
// `options`. Não existe mensagem de "nenhum resultado". Logo o único sinal que
// separa "falhou" de "vazio legítimo" é exatamente a mensagem de erro que o
// defeito suprime.
//
// -----------------------------------------------------------------------------
// O que estes testes afirmam
// -----------------------------------------------------------------------------
// O contrato, não o bug: uma busca que falha anuncia a falha e não é
// apresentada como resultado; um vazio legítimo continua vazio; e um payload
// fora do contrato degrada no decodificador em vez de derrubar a busca.
import 'dart:async';

import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/safety/application/child_safety_controller.dart';
import 'package:coelo_superadmin/features/safety/data/child_safety_response_decoder.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety.dart';
import 'package:coelo_superadmin/features/safety/domain/child_safety_contract.dart';
import 'package:coelo_superadmin/features/safety/presentation/safety_pages.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _searchFailure = 'Não foi possível buscar crianças.';

final _wizard = find.byType(ChildSafetyWizardPage);
final _searchField = find.byType(TextFormField);
final _searchButton = find.byTooltip('Buscar');
final _failureText = find.text(_searchFailure);
final _busyIndicator = find.descendant(
  of: _wizard,
  matching: find.byType(CircularProgressIndicator),
);
final _optionCards = find.byWidgetPredicate(
  (widget) =>
      widget is CoeloAdminInteractiveCard &&
      (widget.semanticLabel?.startsWith('Selecionar ') ?? false),
  description: 'cartão de opção de criança',
);

void main() {
  // ---------------------------------------------------------------------------
  // Consumidor: a busca do wizard de autorização de retirada
  //
  // O wizard nasce no passo 0 (`step = 0`), que já é o passo "Criança". Nenhum
  // avanço de etapa é necessário para chegar ao campo de busca.
  // ---------------------------------------------------------------------------

  // Controle: separa "o teste está errado" de "o código está errado". A mesma
  // busca, falhando com uma Exception comum, já anuncia a falha hoje.
  testWidgets('safety.wizard: controle - busca que lança Exception anuncia a falha', (
    tester,
  ) async {
    final repository = _Repository()
      ..searchFailure = () => const ChildSafetyUnavailableException();
    await _pumpWizard(tester, repository);

    final escaped = await _search(tester, 'Ana');

    expect(escaped, isNull, reason: 'a Exception é capturada pelo `on Exception` de `_search`');
    expect(
      _failureText,
      findsOneWidget,
      reason: 'com Exception a tela já cumpre o contrato hoje (${_observed()})',
    );
    expect(_busyIndicator, findsNothing, reason: 'o indicador precisa desligar (${_observed()})');
    expect(tester.takeException(), isNull);
  });

  // O caso central.
  testWidgets(
    'safety.wizard: busca que lança Error anuncia a falha em vez de fingir "ninguém encontrado"',
    (tester) async {
      final repository = _Repository()..searchFailure = _realCastError;
      await _pumpWizard(tester, repository);

      final escaped = await _search(tester, 'Ana');

      expect(
        _failureText,
        findsOneWidget,
        reason:
            'a busca falhou e a tela não disse que falhou. Estado observado: ${_observed()}. '
            'O `finally` de `_search` desligou o indicador mesmo com o `Error` escapando do '
            '`on Exception`, então o operador vê uma busca concluída sem resultado — num '
            'formulário que autoriza quem pode retirar uma criança.',
      );
      expect(
        _optionCards,
        findsNothing,
        reason:
            'nada pode ser apresentado como resultado de uma busca que falhou (${_observed()})',
      );
      expect(
        _busyIndicator,
        findsNothing,
        reason: 'a falha precisa encerrar o indicador de progresso (${_observed()})',
      );
      expect(
        escaped,
        isNull,
        reason:
            '`_search` deixou ${escaped?.runtimeType} escapar como erro assíncrono não tratado: '
            'a falha da busca deve virar estado da tela, não erro solto na árvore',
      );
      // O detalhe técnico do cast nunca chega à tela.
      expect(find.textContaining('is not a subtype'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // A outra metade do mesmo sintoma: quando já havia resultado, a falha silenciosa
  // deixa o resultado velho na tela como se fosse a resposta da busca nova.
  testWidgets('safety.wizard: busca que lança Error não pode manter resultado velho como atual', (
    tester,
  ) async {
    final repository = _Repository();
    await _pumpWizard(tester, repository);

    expect(await _search(tester, 'Ana'), isNull);
    expect(
      _optionCards,
      findsOneWidget,
      reason: 'a busca bem-sucedida precisa renderizar um cartão de opção (${_observed()})',
    );

    repository.searchFailure = _realCastError;
    final escaped = await _search(tester, 'Bia');

    expect(
      repository.queries,
      ['Ana', 'Bia'],
      reason: 'a segunda busca precisa ter chegado ao repositório para o caso fazer sentido',
    );
    expect(
      _failureText,
      findsOneWidget,
      reason:
          'a segunda busca falhou e a tela seguiu mostrando o resultado da primeira como se '
          'fosse a resposta de "Bia". Estado observado: ${_observed()}.',
    );
    expect(escaped, isNull, reason: 'a falha escapou como erro assíncrono não tratado');
    expect(tester.takeException(), isNull);
  });

  // Distingue o defeito de "vazio some". A tela não tem mensagem própria de
  // "nenhum resultado" (passo 0 renderiza só o campo e o laço sobre `options`),
  // então o vazio legítimo é medido pelo que existe: sem mensagem de falha, sem
  // cartão, sem indicador. É exatamente por isso que a mensagem de erro é o
  // único sinal que separa "falhou" de "vazio" — e o defeito suprime esse sinal.
  testWidgets('safety.wizard: vazio legítimo continua vazio e sem mensagem de falha', (
    tester,
  ) async {
    final repository = _Repository()..searchResults = const [];
    await _pumpWizard(tester, repository);

    final escaped = await _search(tester, 'Ana');

    expect(escaped, isNull);
    expect(
      _failureText,
      findsNothing,
      reason: 'um vazio legítimo não é falha e não pode acusar erro (${_observed()})',
    );
    expect(_optionCards, findsNothing, reason: 'nenhum resultado, nenhum cartão (${_observed()})');
    expect(_busyIndicator, findsNothing, reason: 'a busca concluiu (${_observed()})');
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------
  // Produtor: o decodificador de opções de criança
  //
  // Um payload fora do contrato deve degradar como o resto do arquivo já faz
  // (`_string` / `_nullableString`), não derrubar a busca com `Error`.
  // ---------------------------------------------------------------------------
  test('safety.options: controle - payload dentro do contrato decodifica', () {
    final options = decodeChildSafetyOptions([_optionPayload()]);

    expect(options, hasLength(1));
    expect(options.single.name, 'Ana Criança');
    expect(options.single.internalId, 'RA 1');
    expect(options.single.childContextId, 'context-1');
    expect(options.single.institutionId, 'institution-1');
    expect(options.single.unitId, 'unit-1');
  });

  for (final field in _rawCastFields) {
    test('safety.options: $field numérico degrada em vez de lançar Error', () {
      expect(
        () => decodeChildSafetyOptions([_optionPayload(numericField: field)]),
        returnsNormally,
        reason:
            'o cast cru `$field as String?` (child_safety_response_decoder.dart:84-88) lança '
            '`TypeError` com payload numérico. `TypeError` é `Error`, não `Exception`, então '
            'atravessa o `on Exception` de `_search` e a busca falha em silêncio. Os campos '
            'vizinhos da mesma linha já usam os ajudantes defensivos do próprio arquivo.',
      );
    });
  }
}

// -----------------------------------------------------------------------------
// Ajudantes
// -----------------------------------------------------------------------------

const _rawCastFields = ['internal_id', 'child_context_id', 'institution_id', 'unit_id'];

Map<String, Object?> _optionPayload({String? numericField}) {
  Object? value(String field, Object? inContract) => field == numericField ? 7 : inContract;
  return {
    'id': 'child-1',
    'display_name': 'Ana Criança',
    'internal_id': value('internal_id', 'RA 1'),
    'contexts': [
      {
        'child_context_id': value('child_context_id', 'context-1'),
        'institution_id': value('institution_id', 'institution-1'),
        'institution_name': 'Instituição Aurora',
        'unit_id': value('unit_id', 'unit-1'),
        'unit_name': 'Unidade Centro',
      },
    ],
  };
}

Object _boxedInteger() => 42;

/// Produz o mesmo `TypeError` que um payload fora do contrato geraria nos casts
/// crus de `child_safety_response_decoder.dart:84-88`.
Object _realCastError() {
  try {
    final _ = _boxedInteger() as String;
  } on TypeError catch (error) {
    return error;
  }
  return StateError('o cast inesperadamente funcionou');
}

/// Estado realmente observado na tela, para a mensagem de falha dizer o que
/// aconteceu em vez de só dizer o que não aconteceu.
String _observed() {
  final indicator = _busyIndicator.evaluate().isEmpty ? 'desligado' : 'ligado';
  final message = _failureText.evaluate().isEmpty ? 'ausente' : 'presente';
  return 'indicador $indicator, mensagem de falha $message, '
      '${_optionCards.evaluate().length} opção(ões) na tela';
}

Future<void> _pumpWizard(WidgetTester tester, _Repository repository) async {
  await tester.binding.setSurfaceSize(const Size(1024, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = ChildSafetyController(repository, searchDebounce: Duration.zero);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      home: ChildSafetyWizardPage(
        controller: controller,
        logout: () async => const LogoutResult.success(),
        onCancel: () {},
        onSaved: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Digita e dispara a busca, devolvendo o erro que escapou de `_search`, se
/// houver.
///
/// `onPressed: searching ? null : _search` descarta o `Future<void>` de
/// `_search`, então um `Error` que atravessa o `on Exception` vira erro
/// assíncrono não tratado. Sem este cerco, o `handleUncaughtError` do
/// `flutter_test` (binding.dart:1814) encerraria o teste na hora, com o
/// `TypeError` cru e antes de qualquer asserção — o teste falharia sem medir
/// nada. Bifurcar uma zona apenas em volta do toque mantém o erro observável e
/// preserva as asserções. `TestAsyncUtils` não se incomoda: cada chamada
/// guardada é aguardada, e a zona bifurcada não carrega o marcador de escopo.
Future<Object?> _search(WidgetTester tester, String query) async {
  Object? escaped;
  final zone = Zone.current.fork(
    specification: ZoneSpecification(
      handleUncaughtError: (self, parent, errorZone, error, stackTrace) {
        escaped ??= error;
      },
    ),
  );
  await tester.enterText(_searchField.first, query);
  await zone.run<Future<void>>(() async {
    await tester.tap(_searchButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });
  return escaped;
}

// -----------------------------------------------------------------------------
// Fake
// -----------------------------------------------------------------------------

final class _Repository implements ChildSafetyRepository {
  final queries = <String>[];

  /// Construído a cada busca para que cada falha seja um objeto distinto.
  Object Function()? searchFailure;
  List<ChildSafetyChildOption> searchResults = const [
    ChildSafetyChildOption(
      id: 'child-1',
      name: 'Ana Criança',
      internalId: 'RA 1',
      childContextId: 'context-1',
      institutionId: 'institution-1',
      institutionName: 'Instituição Aurora',
      unitId: 'unit-1',
      unitName: 'Unidade Centro',
    ),
  ];

  @override
  Future<List<ChildSafetyChildOption>> searchChildren(String query, {int limit = 20}) async {
    queries.add(query);
    final failure = searchFailure;
    if (failure != null) throw failure();
    return searchResults;
  }

  @override
  Future<ChildSafetyDirectoryPage> fetchDirectory(ChildSafetyDirectoryQuery query) async =>
      const ChildSafetyDirectoryPage(
        records: [],
        totalCount: 0,
        segmentCounts: ChildSafetySegmentCounts(),
        canCreate: true,
      );

  @override
  Future<ChildSafetyRecord?> fetchChild(String childId) async => null;
  @override
  Future<void> saveAuthorization(SavePickupAuthorizationCommand command) async {}
  @override
  Future<void> transitionAuthorization(TransitionPickupAuthorizationCommand command) async {}
  @override
  Future<void> suspendAuthorization(SuspendPickupAuthorizationCommand command) async {}
  @override
  Future<void> requestExport(ChildSafetyExportCommand command) async {}
}
