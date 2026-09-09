// ERRATA MINHA, 2026-09-08T22:47, conferida por mim antes de escrever.
//
// Eu registrei que "os paineis de Locais nao tem consumidor de producao", sem o
// qualificador de escopo. A afirmacao e verdadeira NESTA ARVORE e em origin/dev,
// e FALSA na arvore da C04: la o router referencia LocationsPage nas linhas 1337
// e 1366 e UnitLocationsGate nas 1395 e 1419, com as duas rotas registradas.
// Conferi as tres pontas.
//
// A leitura correta: o fio EXISTE e falta INTEGRAR (o commit 567b3993 nao e
// ancestral de origin/dev). Logo `locations.*` nao e certificavel como FE na
// base integrada por PENDENCIA DE INTEGRACAO, e nao por ausencia de
// implementacao. A diferenca importa: a primeira leitura custa uma integracao,
// a segunda custaria escrever a tela.
//
// Registro contra mim porque e o mesmo formato de erro que venho apontando nos
// outros: verificar uma propriedade num escopo e enuncia-la como geral. O que
// este arquivo mede continua valido, porque mede os paineis diretamente.

// C07 - Locais: aceitacao do fluxo real do catalogo (sem golden).
//
// O que existe no baseline, e so isso e exercitado aqui: dois paineis de
// leitura, `LocationDirectoryPanel` e `LocationDetailPanel`, com o contrato
// `LocationCatalogReader`. Nao ha rota, item de menu nem pagina que os monte -
// `apps/superadmin/lib/app/router/superadmin_router.dart` nao referencia Locais
// e o proprio `location_detail_panel.dart` declara "Isolated content; normal
// routing and authorization composition are not wired". Nao ha criar, editar,
// mudar status, duplicar nem agendar: `features/locations/` tem apenas
// `data/`, `domain/` e os quatro arquivos de `presentation/` de leitura. Por
// isso este arquivo nao inventa nenhum teste de escrita; ele afirma a ausencia
// de afordancia de escrita e mede o que de fato esta ligado.
//
// A composicao diretorio -> detalhe -> voltar e reproduzida aqui por um host
// local, porque e exatamente a composicao que os dois paineis declaram
// (`onOpen` e `onBack`) e a unica navegacao real disponivel.
//
// Cobre o que `test/features/locations/` ainda nao prova: a composicao entre os
// dois paineis, `Error` real (nao `Exception`) sincrono e assincrono, a
// distincao entre falha, vazio legitimo e busca sem resultado, a releitura que
// preserva busca/pagina/tamanho de pagina, o alcance por Tab e os alvos de
// toque da barra e da paginacao, a ativacao do card no primeiro ponto de foco,
// a ausencia de escrita e a indisponibilidade honesta de Importar/Exportar.
// Nao repete: mapeamento do reader Supabase, epocas/revisoes do controller,
// `LocationSelectionSource`, responsividade com texto 200%, alinhamento de
// linha da tabela nem os goldens.
import 'package:coelo_domain/locations.dart';
import 'package:coelo_superadmin/features/locations/domain/location_catalog_reader.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_detail_panel.dart';
import 'package:coelo_superadmin/features/locations/presentation/location_directory_panel.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _institution = '20000000-0000-4000-8000-000000000001';
const _scope = LocationScope.institution(institutionId: _institution);

const _failureTitle = 'Não foi possível carregar os locais';
const _emptyTitle = 'Nenhum local encontrado';
const _noResultsTitle = 'Nenhum resultado para a busca';
const _deniedTitle = 'Acesso não autorizado';
const _unavailableNotice = 'Disponível depois do MVP';

/// Alvo minimo de toque adotado pelo tema (`CoeloSize.touchMin`).
const _minimumTouchTarget = 48.0;

void main() {
  // ---------------------------------------------------------------------------
  // locations.list - o fluxo real disponivel
  // ---------------------------------------------------------------------------
  group('locations.list', () {
    testWidgets('o card abre o detalhe do mesmo local e Voltar retorna relendo o diretório', (
      tester,
    ) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(_app(_LocationsHost(reader: reader)));
      await tester.pumpAndSettle();

      expect(reader.directoryRequests, hasLength(1));
      expect(find.text('13 locais'), findsOneWidget);
      expect(find.byKey(Key('location-card-${_id(1)}')), findsOneWidget);
      // Onze por página em cards: o décimo segundo não está nesta página.
      expect(find.byKey(Key('location-card-${_id(12)}')), findsNothing);

      await tester.tap(find.byKey(Key('location-card-${_id(3)}')));
      await tester.pumpAndSettle();

      expect(reader.detailRequests, [_id(3)]);
      expect(find.byKey(const Key('location-detail-content')), findsOneWidget);
      expect(find.byKey(const Key('location-directory-content')), findsNothing);
      expect(find.text('Sala 03'), findsOneWidget);
      expect(find.text('Catálogo da instituição'), findsOneWidget);

      await tester.tap(find.byKey(const Key('location-detail-back')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location-directory-content')), findsOneWidget);
      expect(
        reader.directoryRequests,
        hasLength(2),
        reason: 'voltar ao diretório precisa reler o catálogo, não exibir uma cópia antiga',
      );
      expect(find.text('Sala 03'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Tab alcança busca, visões, arquivos e paginação', (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(_app(_directory(reader)));
      await tester.pumpAndSettle();

      final targets = <String, Finder>{
        'busca': find.byKey(const Key('location-search')),
        'visão em cards': find.byKey(const Key('location-view-cards')),
        'visão em tabela': find.byKey(const Key('location-view-table')),
        'arquivos': find.byKey(const Key('coelo-admin-files-action')),
        'itens por página': find.byKey(const Key('coelo-admin-pagination-page-size')),
        'próxima página': _outlinedButtonLabelled('Próxima'),
      };
      final reached = <String>{};

      for (var step = 0; step < 220 && reached.length < targets.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final entry in targets.entries) {
          if (_focusTouches(tester, entry.value)) reached.add(entry.key);
        }
        // Nenhum flyout deve abrir sozinho aqui, mas se abrir o Escape devolve
        // o foco e a travessia continua em vez de travar.
        if (find.byType(MenuItemButton).evaluate().isNotEmpty) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();
        }
      }

      expect(
        reached,
        containsAll(targets.keys),
        reason: 'não alcançado por Tab: ${targets.keys.toSet().difference(reached)}',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('os controles do diretório medem ao menos 48 px', (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(_app(_directory(reader)));
      await tester.pumpAndSettle();

      _expectTouchTarget(tester, find.byKey(const Key('coelo-admin-files-action')), 'Arquivos');
      _expectTouchTarget(tester, _segmentOf('location-view-cards'), 'segmento Cards');
      _expectTouchTarget(tester, _segmentOf('location-view-table'), 'segmento Tabela');
      _expectTouchTarget(tester, _outlinedButtonLabelled('Anterior'), 'Anterior');
      _expectTouchTarget(tester, _outlinedButtonLabelled('Próxima'), 'Próxima');
      _expectTouchTarget(
        tester,
        find.byKey(const Key('coelo-admin-pagination-page-size')),
        'itens por página',
      );
      _expectTouchTarget(
        tester,
        find.byKey(const Key('coelo-admin-pagination-page-2')),
        'página 2',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('o card do diretório abre o detalhe no primeiro ponto de foco', (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader(total: 2);
      final opened = <String>[];

      await tester.pumpWidget(
        _app(
          LocationDirectoryPanel(
            scope: _scope,
            reader: reader,
            sessionAvailable: true,
            onOpen: (item) => opened.add(item.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(Key('location-card-${_id(1)}'));
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(opened, [_id(1)], reason: 'o toque no card precisa abrir o detalhe');

      // Teclado: percorre os pontos de foco dentro do card e registra em qual
      // deles Enter abre o detalhe. O contrato é que o primeiro ponto de foco -
      // o que realça o card - já ative, como qualquer botão.
      expect(
        await _tabUntil(tester, card),
        isTrue,
        reason: 'Tab não alcançou o card do local',
      );
      var stopsInsideCard = 0;
      int? activatedAtStop;
      while (_focusWithin(card) && stopsInsideCard < 5) {
        stopsInsideCard += 1;
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        if (opened.length > 1) {
          activatedAtStop = stopsInsideCard;
          break;
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }

      expect(
        opened.skip(1).toList(),
        [_id(1)],
        reason: 'Enter dentro do card não abriu o detalhe (pontos de foco: $stopsInsideCard)',
      );
      expect(
        activatedAtStop,
        1,
        reason:
            'Enter só abriu o detalhe no ponto de foco $activatedAtStop do card; o card expõe '
            'ao menos $stopsInsideCard pontos de foco por Tab e o primeiro apenas realça.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // locations.error - falha honesta, vazio e releitura
  // ---------------------------------------------------------------------------
  group('locations.error', () {
    for (final scenario in _errorScenarios) {
      testWidgets('${scenario.label} termina em falha honesta, sem indicador de carregamento', (
        tester,
      ) async {
        await _useSurface(tester, const Size(1440, 900));
        final reader = _ScriptedLocationReader()
          ..failure = scenario.failure
          ..failSynchronously = scenario.synchronous;

        await tester.pumpWidget(_app(_directory(reader)));
        await tester.pumpAndSettle();

        // O estado final é afirmado diretamente: um timeout sozinho não separa
        // "carga concluiu em erro" de "carga travou".
        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byKey(const Key('location-directory-loading')), findsNothing);
        expect(find.byKey(const Key('location-directory-unavailable')), findsOneWidget);
        expect(find.text(_failureTitle), findsOneWidget);
        expect(
          find.textContaining(scenario.leakedDetail),
          findsNothing,
          reason: 'a falha não pode vazar o detalhe interno "${scenario.leakedDetail}"',
        );

        final retry = find.byKey(const Key('location-directory-reload'));
        expect(retry, findsOneWidget);
        expect(tester.widget<OutlinedButton>(retry).enabled, isTrue);
        expect(reader.directoryRequests, hasLength(1), reason: 'sem laço de releitura automática');

        reader.failure = null;
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pumpAndSettle();

        expect(reader.directoryRequests, hasLength(2));
        expect(find.text(_failureTitle), findsNothing);
        expect(find.byKey(Key('location-card-${_id(1)}')), findsOneWidget);
      });
    }

    testWidgets('falha, vazio legítimo e busca sem resultado são três estados distintos', (
      tester,
    ) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader(total: 0)
        ..failure = () => StateError('detalhe interno da falha');

      await tester.pumpWidget(_app(_directory(reader)));
      await tester.pumpAndSettle();

      // 1. Falha: não pode se disfarçar de catálogo vazio nem publicar contagem.
      expect(find.byKey(const Key('location-directory-unavailable')), findsOneWidget);
      expect(find.text(_failureTitle), findsOneWidget);
      expect(find.byKey(const Key('location-directory-empty')), findsNothing);
      expect(find.byKey(const Key('location-directory-noResults')), findsNothing);
      expect(find.text(_emptyTitle), findsNothing);
      expect(
        find.text('0 locais'),
        findsNothing,
        reason: 'a falha não leu nada e não pode anunciar uma contagem',
      );

      // 2. Vazio legítimo: contagem honesta, sem retry, porque não houve falha.
      reader.failure = null;
      final retry = find.byKey(const Key('location-directory-reload'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location-directory-empty')), findsOneWidget);
      expect(find.text(_emptyTitle), findsOneWidget);
      expect(find.text('0 locais'), findsOneWidget);
      expect(find.byKey(const Key('location-directory-unavailable')), findsNothing);
      expect(
        find.byKey(const Key('location-directory-reload')),
        findsNothing,
        reason: 'catálogo vazio não é falha e não deve oferecer recarregar',
      );

      // 3. Busca sem resultado: mensagem própria, distinta do vazio.
      await tester.enterText(_searchField(), 'inexistente');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location-directory-noResults')), findsOneWidget);
      expect(find.text(_noResultsTitle), findsOneWidget);
      expect(find.byKey(const Key('location-directory-empty')), findsNothing);
      expect(find.text(_emptyTitle), findsNothing);
      expect(reader.lastDirectoryRequest.search, 'inexistente');
      expect(tester.takeException(), isNull);
    });

    testWidgets('Recarregar relê preservando busca, página e tamanho de página', (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(_app(_directory(reader)));
      await tester.pumpAndSettle();
      expect(reader.lastDirectoryRequest.limit, 11);

      // Visão em tabela: oito por página.
      await tester.tap(find.byKey(const Key('location-view-table')));
      await tester.pumpAndSettle();
      expect(reader.lastDirectoryRequest.limit, 8);
      expect(find.byKey(const Key('location-table')), findsOneWidget);

      await tester.enterText(_searchField(), 'sala');
      await tester.pumpAndSettle();
      expect(reader.lastDirectoryRequest.search, 'sala');
      expect(reader.lastDirectoryRequest.offset, 0);

      // A leitura da segunda página falha: o contexto tem de sobreviver a ela.
      reader.failure = () => StateError('detalhe interno da falha');
      await tester.tap(_outlinedButtonLabelled('Próxima'));
      await tester.pumpAndSettle();

      expect(reader.lastDirectoryRequest.offset, 8);
      expect(find.byKey(const Key('location-directory-unavailable')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      reader.failure = null;
      final readsBefore = reader.directoryRequests.length;
      final retry = find.byKey(const Key('location-directory-reload'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();

      expect(reader.directoryRequests, hasLength(readsBefore + 1));
      final retried = reader.lastDirectoryRequest;
      expect(retried.search, 'sala', reason: 'a releitura perdeu o termo buscado');
      expect(retried.offset, 8, reason: 'a releitura voltou sozinha para a primeira página');
      expect(retried.limit, 8, reason: 'a releitura perdeu o tamanho de página da visão tabela');
      expect(find.text('Página 2 de 2'), findsOneWidget);
      expect(find.byKey(const Key('location-table')), findsOneWidget);
      expect(find.text(_failureTitle), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // locations.access-denied
  // ---------------------------------------------------------------------------
  group('locations.access-denied', () {
    testWidgets('sem sessão o diretório não lê, não mostra dado e não oferece recarregar', (
      tester,
    ) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(_app(_directory(reader, sessionAvailable: false)));
      await tester.pumpAndSettle();

      expect(
        reader.directoryRequests,
        isEmpty,
        reason: 'negado não pode chegar ao leitor nem uma vez',
      );
      expect(find.byKey(const Key('location-directory-denied')), findsOneWidget);
      expect(find.text(_deniedTitle), findsOneWidget);
      expect(find.byKey(Key('location-card-${_id(1)}')), findsNothing);
      expect(
        find.byKey(const Key('location-directory-reload')),
        findsNothing,
        reason: 'negado não é falha recuperável e não deve oferecer retry',
      );

      // Sem laço de tentativa contra um backend que já disse não.
      await tester.pump(const Duration(seconds: 3));
      expect(reader.directoryRequests, isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('o detalhe negado não deve oferecer um Recarregar ativo', (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(
        _app(
          LocationDetailPanel(
            id: _id(1),
            scope: _scope,
            reader: reader,
            sessionAvailable: false,
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location-detail-denied')), findsOneWidget);
      expect(reader.detailRequests, isEmpty);

      // Mede antes de afirmar: o botão existe, seu estado, e o que acioná-lo faz.
      final reload = find.byKey(const Key('location-detail-reload'));
      final present = reload.evaluate().isNotEmpty;
      final active = present && tester.widget<OutlinedButton>(reload).enabled;
      if (active) {
        await tester.tap(reload);
        await tester.pumpAndSettle();
      }
      final readsAfterTap = reader.detailRequests.length;
      final stillDenied = find.byKey(const Key('location-detail-denied')).evaluate().isNotEmpty;

      // Contrato: o diretório da mesma feature só oferece Recarregar em falha e
      // o esconde quando nega. Um retry habilitado que nunca relê promete uma
      // recuperação que o cliente sequer tentará.
      expect(
        active,
        isFalse,
        reason:
            'O detalhe negado mantém "Recarregar" habilitado (presente: $present). Depois de '
            'acioná-lo o leitor recebeu $readsAfterTap chamadas e a tela continua negada '
            '(painel negado visível: $stillDenied). O diretório de Locais, no mesmo baseline, '
            'só desenha o retry no estado de falha.',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // locations.capabilities - so o que existe
  // ---------------------------------------------------------------------------
  group('locations.capabilities', () {
    testWidgets('o catálogo é somente leitura e não desenha nenhuma escrita', (tester) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(_app(_LocationsHost(reader: reader)));
      await tester.pumpAndSettle();

      for (final label in _writeLabels) {
        expect(find.text(label), findsNothing, reason: 'o diretório desenhou a escrita "$label"');
      }
      expect(find.byType(FloatingActionButton), findsNothing);

      await tester.tap(find.byKey(Key('location-card-${_id(1)}')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('location-detail-content')), findsOneWidget);
      for (final label in _writeLabels) {
        expect(find.text(label), findsNothing, reason: 'o detalhe desenhou a escrita "$label"');
      }
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(reader.detailRequests, [_id(1)]);
    });

    testWidgets('Importar e Exportar seguem visíveis e respondem indisponibilidade honesta', (
      tester,
    ) async {
      await _useSurface(tester, const Size(1440, 900));
      final reader = _ScriptedLocationReader();

      await tester.pumpWidget(_app(_directory(reader)));
      await tester.pumpAndSettle();
      final readsBefore = reader.directoryRequests.length;

      await tester.tap(find.byKey(const Key('coelo-admin-files-action')));
      await tester.pumpAndSettle();
      for (final label in ['Importar', 'Exportar CSV', 'Exportar XLSX']) {
        expect(find.widgetWithText(MenuItemButton, label), findsOneWidget, reason: label);
      }

      await tester.tap(find.widgetWithText(MenuItemButton, 'Importar'));
      await tester.pumpAndSettle();

      expect(find.text(_unavailableNotice), findsOneWidget);
      expect(
        reader.directoryRequests,
        hasLength(readsBefore),
        reason: 'ação indisponível não pode disparar leitura, job ou persistência',
      );
      expect(find.byKey(Key('location-card-${_id(1)}')), findsOneWidget);
      expect(find.text('13 locais'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

// -----------------------------------------------------------------------------
// Cenarios de erro
// -----------------------------------------------------------------------------

typedef _ErrorScenario = ({
  String label,
  Object Function() failure,
  bool synchronous,
  String leakedDetail,
});

final _errorScenarios = <_ErrorScenario>[
  (
    label: 'um TypeError real de cast na leitura da página',
    failure: _realCastError,
    synchronous: false,
    leakedDetail: 'is not a subtype',
  ),
  (
    label: 'um StateError síncrono, antes de qualquer Future',
    failure: () => StateError('detalhe interno da falha'),
    synchronous: true,
    leakedDetail: 'detalhe interno da falha',
  ),
];

Object _boxedInteger() => 42;

/// Produz o mesmo `TypeError` que um payload malformado geraria num cast.
Object _realCastError() {
  try {
    final _ = _boxedInteger() as String;
  } on TypeError catch (error) {
    return error;
  }
  return StateError('o cast inesperadamente teve sucesso');
}

const _writeLabels = [
  'Criar local',
  'Novo local',
  'Adicionar local',
  'Editar',
  'Excluir',
  'Salvar',
  'Duplicar',
  'Copiar',
  'Agendar',
  'Ativar',
  'Inativar',
  'Arquivar',
  'Reservar',
];

// -----------------------------------------------------------------------------
// Fixtures, host e finders
// -----------------------------------------------------------------------------

String _id(int index) => '10000000-0000-4000-8000-${index.toString().padLeft(12, '0')}';

LocationCatalogEntry _entry(int index) => LocationCatalogEntry(
  id: _id(index),
  scope: _scope,
  kind: LocationKind.internal,
  name: 'Sala ${index.toString().padLeft(2, '0')}',
  description: 'Espaço de apoio ${index.toString().padLeft(2, '0')}.',
  floor: 'Térreo',
  address: null,
  visibility: LocationVisibility.team,
  status: LocationCatalogStatus.active,
  managementVersion: 1,
  createdAt: DateTime.utc(2026, 9, 7),
  updatedAt: DateTime.utc(2026, 9, 7, 12),
);

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  darkTheme: CoeloTheme.dark,
  home: Scaffold(body: child),
);

Widget _directory(LocationCatalogReader reader, {bool sessionAvailable = true}) =>
    LocationDirectoryPanel(
      scope: _scope,
      reader: reader,
      sessionAvailable: sessionAvailable,
      onOpen: (_) {},
    );

/// A única navegação real: o diretório entrega o item por `onOpen` e o detalhe
/// devolve o controle por `onBack`. Nenhuma rota do app monta estes painéis.
final class _LocationsHost extends StatefulWidget {
  const _LocationsHost({required this.reader});

  final LocationCatalogReader reader;

  @override
  State<_LocationsHost> createState() => _LocationsHostState();
}

final class _LocationsHostState extends State<_LocationsHost> {
  LocationCatalogEntry? _opened;

  @override
  Widget build(BuildContext context) {
    final opened = _opened;
    if (opened == null) {
      return LocationDirectoryPanel(
        scope: _scope,
        reader: widget.reader,
        sessionAvailable: true,
        onOpen: (item) => setState(() => _opened = item),
      );
    }
    return LocationDetailPanel(
      id: opened.id,
      scope: opened.scope,
      reader: widget.reader,
      sessionAvailable: true,
      onBack: () => setState(() => _opened = null),
    );
  }
}

Finder _searchField() => find.descendant(
  of: find.byKey(const Key('location-search')),
  matching: find.byType(TextField),
);

/// `OutlinedButton.icon` constrói uma subclasse privada, invisível a `byType`.
Finder _outlinedButtonLabelled(String label) => find
    .ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is OutlinedButton))
    .first;

/// A chave do segmento fica no ícone; quem recebe o toque é o botão do segmento.
Finder _segmentOf(String iconKey) =>
    find.ancestor(of: find.byKey(Key(iconKey)), matching: find.byType(TextButton)).first;

Future<void> _useSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void _expectTouchTarget(WidgetTester tester, Finder finder, String label) {
  expect(finder, findsOneWidget, reason: 'controle "$label" não encontrado');
  final size = tester.getSize(finder);
  expect(
    size.shortestSide,
    greaterThanOrEqualTo(_minimumTouchTarget),
    reason: 'o alvo de toque de "$label" mede ${size.width}x${size.height}',
  );
}

/// Verdadeiro quando o foco primário está em [finder], num descendente ou num
/// ancestral dele (segmentos focam o botão que contém o ícone com a chave).
bool _focusTouches(WidgetTester tester, Finder target) {
  final focusedContext = tester.binding.focusManager.primaryFocus?.context;
  if (focusedContext == null || target.evaluate().isEmpty) return false;
  final focused = find.byElementPredicate((element) => identical(element, focusedContext));
  return find.descendant(of: target, matching: focused, matchRoot: true).evaluate().isNotEmpty ||
      find.descendant(of: focused, matching: target, matchRoot: true).evaluate().isNotEmpty;
}

/// Verdadeiro quando o foco primário está em [finder] ou num descendente dele.
bool _focusWithin(Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element) return false;
  final targets = finder.evaluate().toSet();
  if (targets.contains(focused)) return true;
  var found = false;
  focused.visitAncestorElements((ancestor) {
    if (targets.contains(ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Pressiona Tab até o foco entrar em [finder]; falso após [maxSteps].
Future<bool> _tabUntil(WidgetTester tester, Finder finder, {int maxSteps = 80}) async {
  for (var step = 0; step < maxSteps; step++) {
    if (_focusWithin(finder)) return true;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (find.byType(MenuItemButton).evaluate().isNotEmpty) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
    }
  }
  return _focusWithin(finder);
}

/// Fake local do contrato de leitura: registra cada pedido e pode falhar com
/// `Error` real, síncrono ou assíncrono. Nada além das leituras muda.
final class _ScriptedLocationReader implements LocationCatalogReader {
  _ScriptedLocationReader({int total = 13})
    : entries = [for (var index = 1; index <= total; index++) _entry(index)];

  final List<LocationCatalogEntry> entries;
  final directoryRequests = <LocationDirectoryRequest>[];
  final detailRequests = <String>[];

  /// Construída a cada leitura, para que cada falha seja um objeto distinto.
  Object Function()? failure;
  bool failSynchronously = false;

  LocationDirectoryRequest get lastDirectoryRequest => directoryRequests.last;

  @override
  Future<LocationDirectoryResult> fetchDirectory(LocationDirectoryRequest request) {
    directoryRequests.add(request);
    final current = failure;
    if (current != null && failSynchronously) throw current();
    return _readDirectory(request, current);
  }

  Future<LocationDirectoryResult> _readDirectory(
    LocationDirectoryRequest request,
    Object Function()? current,
  ) async {
    if (current != null) throw current();
    final search = request.search?.toLowerCase();
    final matches = [
      for (final entry in entries)
        if (search == null || entry.name.toLowerCase().contains(search)) entry,
    ];
    final start = request.offset.clamp(0, matches.length);
    final end = (start + request.limit).clamp(start, matches.length);
    return LocationDirectoryResult(
      items: matches.sublist(start, end),
      totalCount: matches.length,
    );
  }

  @override
  Future<LocationCatalogEntry> fetchDetail(String id) async {
    detailRequests.add(id);
    final current = failure;
    if (current != null) throw current();
    return entries.firstWhere((entry) => entry.id == id);
  }
}
