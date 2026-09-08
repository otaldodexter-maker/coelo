// C07 - Alunos: aceitacao de fluxo da tela de Acompanhamento (sem golden).
//
// Acoes do inventario cobertas aqui: apenas `students.list`.
//
// `students.link`, `students.transfer`, `students.edit` e `students.revoke` nao
// possuem superficie neste app. A unica rota de gerenciamento e
// `/students/:childContextId/manage`, que o router resolve para
// `SuperadminErrorScreen(kind: unavailable)`; isso ja e provado por
// `test/app/router/student_tracking_fail_closed_routes_test.dart`. Nenhum teste
// foi fabricado para elas.
//
// `students.list` tem duas metades no codigo: a tela real
// (`StudentTrackingPage` em `/students`, cujo seletor canonico de aluno consome
// `fetchChildren`) e o pipeline de leitura CHILD (`features/children/`), que
// existe sem UI e ja tem testes proprios. Este arquivo exercita a tela.
//
// Cobre so o que `test/features/student_tracking/` e `test/features/children/`
// ainda nao provam: carga que falha por `Error` (nao `Exception`) saindo do
// esqueleto, retry que le uma vez e nao entra em laco, negado depois de sucesso
// sem residuo do aluno, vazio distinto de sem-resultados e de falha, alcance por
// Tab com alvos de 48 px, as cinco abas em 375 e 1440 sem excecao de layout e a
// navegacao pelos cartoes da visao geral.
//
// O fake local e o proprio exemplo do app (`DevelopmentStudentTrackingRepository`,
// usado por `/dev/students`): 2 alunos, 2 contextos, 2 periodos, 90% de
// assiduidade, 2 itens de agenda e boletim publicado.
import 'package:coelo_superadmin/app/dev_menu/development_student_tracking_repository.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/student_tracking/domain/student_tracking.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_page.dart';
import 'package:coelo_superadmin/features/student_tracking/presentation/student_tracking_view_model.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _failureTitle = 'Não foi possível carregar';
const _deniedTitle = 'Acesso negado';
const _noChildrenTitle = 'Nenhum filho vinculado';
const _noDataTitle = 'Nenhum dado publicado';
const _unavailableTitle = 'Acompanhamento indisponível';
const _retryLabel = 'Tentar novamente';
const _loadingLabel = 'Carregando acompanhamento';
const _firstChild = 'Lia Martins';
const _secondChild = 'Caio Martins';

final _retry = find.widgetWithText(OutlinedButton, _retryLabel);
final _childSelector = find.byKey(const Key('student-child-selector'));
final _contextSelector = find.byKey(const Key('student-context-selector'));
final _periodSelector = find.byKey(const Key('student-period-selector'));
final _tabs = find.byKey(const Key('student-tracking-tabs'));
final _search = find.byKey(const Key('coelo-admin-single-select-search'));

/// Um marcador exclusivo do conteudo de cada aba.
final _tabMarkers = <StudentTrackingTab, Finder>{
  StudentTrackingTab.overview: find.text('Recomendação da professora'),
  StudentTrackingTab.attendance: find.text('Faltas justificadas'),
  StudentTrackingTab.assessments: find.text('Matemática'),
  StudentTrackingTab.competencies: find.byKey(const Key('student-tracking-competency-radar')),
  StudentTrackingTab.reportCards: find.text('Boletim do 3º bimestre'),
};

/// As duas leituras que a carga encadeia: alunos e depois snapshot.
final _errorStages = <_ErrorStage>[
  _ErrorStage(
    'a leitura de alunos',
    (repository) => repository.malformedChildren = true,
    (repository) => repository.malformedChildren = false,
  ),
  _ErrorStage(
    'a leitura do snapshot',
    (repository) => repository.malformedSnapshot = true,
    (repository) => repository.malformedSnapshot = false,
  ),
];

void main() {
  group('students.list - erro e retry', () {
    for (final stage in _errorStages) {
      test(
        'students.list: ${stage.label} que lança Error conclui em falha e o retry recupera',
        () async {
          final repository = _ScriptedStudentTrackingRepository();
          stage.arm(repository);
          final viewModel = StudentTrackingViewModel(repository);
          addTearDown(viewModel.dispose);

          // `StudentTrackingViewModel` captura `on Exception`; um `Error` real
          // (TypeError de cast, como o de um decoder que recebe outro shape)
          // escapa da carga e deixa o estado preso em Loading. O timeout impede
          // que um hang vire um teste que nunca termina.
          await expectLater(
            viewModel.load().timeout(const Duration(seconds: 2)),
            completes,
            reason: 'a carga precisa concluir mesmo quando a leitura lança Error',
          );
          expect(viewModel.state, isA<StudentTrackingFailure>());
          expect(viewModel.children, isEmpty);
          expect(viewModel.snapshot, isNull);
          expect(viewModel.selectedChild, isNull);

          stage.disarm(repository);
          await viewModel.retry().timeout(const Duration(seconds: 2));

          expect(viewModel.state, isA<StudentTrackingReady>());
          expect(viewModel.children.map((child) => child.name), [_firstChild, _secondChild]);
          expect(viewModel.snapshot, isNotNull);
        },
      );
    }

    testWidgets('students.list: a carga que lança Error sai do esqueleto e oferece retry', (
      tester,
    ) async {
      await _useSurface(tester, 1440);
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      final repository = _ScriptedStudentTrackingRepository()..malformedChildren = true;

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      // Enquanto o `Error` escapar do view model, o flutter_test encerra este
      // teste com o erro cru, antes de chegar nas verificações abaixo; corrigida
      // a captura, elas descrevem o que a tela deve mostrar.
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(_loadingLabel), findsNothing);
      expect(find.text(_failureTitle), findsOneWidget);
      expect(_retry, findsOneWidget);
      expect(find.text(_firstChild), findsNothing);
      expect(_tabs, findsNothing);

      repository.malformedChildren = false;
      await tester.tap(_retry);
      await tester.pumpAndSettle();

      expect(repository.childrenCalls, 2);
      expect(find.text(_failureTitle), findsNothing);
      expect(find.text(_firstChild), findsWidgets);
    });

    testWidgets('students.list: o retry relê uma vez, sem laço, e devolve a lista', (tester) async {
      await _useSurface(tester, 1440);
      final repository = _ScriptedStudentTrackingRepository()
        ..childrenError = const FormatException('resposta inválida');

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text(_failureTitle), findsOneWidget);
      expect(_retry, findsOneWidget);
      expect(tester.getSize(_retry).height, greaterThanOrEqualTo(CoeloSize.touchMin));
      expect(tester.getSize(_retry).width, greaterThanOrEqualTo(CoeloSize.touchMin));
      // Falha na primeira leitura não pode disparar a segunda nem vazar aluno.
      expect(repository.childrenCalls, 1);
      expect(repository.snapshotCalls, 0);
      expect(find.text(_firstChild), findsNothing);
      expect(_childSelector, findsNothing);

      repository.childrenError = null;
      await tester.tap(_retry);
      await tester.pumpAndSettle();

      expect(repository.childrenCalls, 2);
      expect(find.text(_failureTitle), findsNothing);
      expect(find.text(_firstChild), findsWidgets);
      expect(_childSelector, findsOneWidget);
      expect(_contextSelector, findsOneWidget);
      expect(_periodSelector, findsOneWidget);
      expect(_tabs, findsOneWidget);

      // Uma tela pronta não fica relendo o repositório sozinha.
      await tester.pump(const Duration(seconds: 3));
      expect(repository.childrenCalls, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('students.list: negado ao trocar o período não deixa dado do aluno na tela', (
      tester,
    ) async {
      await _useSurface(tester, 1440);
      final repository = _ScriptedStudentTrackingRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      expect(find.text(_firstChild), findsWidgets);

      // O contexto autorizado some no meio da sessão: a próxima leitura nega.
      repository.snapshotError = const StudentTrackingDeniedException();
      await tester.tap(_periodSelector);
      await tester.pumpAndSettle();
      await tester.tap(find.text('4º bimestre').last);
      await tester.pumpAndSettle();

      expect(find.text(_deniedTitle), findsOneWidget);
      expect(find.text(_firstChild), findsNothing);
      expect(find.text(_secondChild), findsNothing);
      expect(find.text('Instituto Horizonte'), findsNothing);
      expect(find.text('Matemática'), findsNothing);
      expect(_childSelector, findsNothing);
      expect(_contextSelector, findsNothing);
      expect(_periodSelector, findsNothing);
      expect(_tabs, findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('students.list - vazio e sem resultados', () {
    testWidgets('students.list: sem alunos vinculados é distinto de sem dados e de falha', (
      tester,
    ) async {
      await _useSurface(tester, 1440);
      final repository = _ScriptedStudentTrackingRepository()..emptyChildren = true;

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();

      expect(find.text(_noChildrenTitle), findsOneWidget);
      expect(find.text('Não há crianças disponíveis para este acesso.'), findsOneWidget);
      expect(find.text(_noDataTitle), findsNothing);
      expect(find.text(_failureTitle), findsNothing);
      expect(find.text(_deniedTitle), findsNothing);
      expect(find.text(_unavailableTitle), findsNothing);
      // Vazio honesto não oferece retry nem finge uma lista.
      expect(_retry, findsNothing);
      expect(_childSelector, findsNothing);
      expect(_tabs, findsNothing);
      // Lista vazia não pede snapshot de ninguém e não entra em laço.
      expect(repository.childrenCalls, 1);
      expect(repository.snapshotCalls, 0);
      await tester.pump(const Duration(seconds: 3));
      expect(repository.childrenCalls, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('students.list: a busca sem resultados no seletor não vira lista vazia', (
      tester,
    ) async {
      await _useSurface(tester, 1440);
      final repository = _ScriptedStudentTrackingRepository();

      await tester.pumpWidget(_app(repository));
      await tester.pumpAndSettle();
      await tester.tap(_childSelector);
      await tester.pumpAndSettle();
      expect(_search, findsOneWidget);

      await tester.enterText(_search, 'zzz');
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma opção encontrada.'), findsOneWidget);
      expect(find.text(_secondChild), findsNothing);
      // Sem resultados na busca não é o mesmo que não ter aluno vinculado.
      expect(find.text(_noChildrenTitle), findsNothing);
      expect(find.text(_failureTitle), findsNothing);

      await tester.enterText(_search, 'Caio');
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma opção encontrada.'), findsNothing);
      expect(find.text(_secondChild), findsOneWidget);
      // O filtro é do cliente: nenhuma releitura do repositório.
      expect(repository.childrenCalls, 1);
      expect(tester.takeException(), isNull);
    });
  });

  group('students.list - foco, teclado e largura', () {
    testWidgets('students.list: Tab alcança os seletores e as cinco abas com alvos de 48 px', (
      tester,
    ) async {
      await _useSurface(tester, 1440);
      final repository = _ScriptedStudentTrackingRepository();

      await tester.pumpWidget(_app(repository, disableAnimations: true));
      await tester.pumpAndSettle();

      final targets = <String, Finder>{
        'seletor de aluno': _childSelector,
        'seletor de contexto': _contextSelector,
        'seletor de período': _periodSelector,
        for (final tab in StudentTrackingTab.values) 'aba ${tab.name}': _tabItem(tab),
      };

      for (final entry in targets.entries) {
        expect(entry.value, findsOneWidget, reason: entry.key);
        final size = tester.getSize(entry.value);
        expect(size.height, greaterThanOrEqualTo(CoeloSize.touchMin), reason: entry.key);
        expect(size.width, greaterThanOrEqualTo(CoeloSize.touchMin), reason: entry.key);
      }

      final reached = <String>{};
      for (var step = 0; step < 240 && reached.length < targets.length; step++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        for (final entry in targets.entries) {
          if (_focusTouches(tester, entry.value)) reached.add(entry.key);
        }
      }
      await tester.pumpAndSettle();

      expect(
        reached,
        containsAll(targets.keys),
        reason: 'não alcançado por Tab: ${targets.keys.toSet().difference(reached)}',
      );
      expect(tester.takeException(), isNull);
    });

    for (final width in [375.0, 1440.0]) {
      testWidgets('students.list: as cinco abas renderizam em ${width.toInt()} px sem exceção', (
        tester,
      ) async {
        await _useSurface(tester, width);
        final repository = _ScriptedStudentTrackingRepository();

        await tester.pumpWidget(_app(repository, disableAnimations: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.getRect(_tabs).right, lessThanOrEqualTo(width));

        for (final entry in _tabMarkers.entries) {
          final label = '${entry.key.name} em ${width.toInt()}';
          final item = _tabItem(entry.key);
          await tester.ensureVisible(item);
          await tester.pumpAndSettle();
          await tester.tap(item);
          await tester.pumpAndSettle();

          expect(entry.value, findsWidgets, reason: label);
          expect(
            tester.getSize(item).height,
            greaterThanOrEqualTo(CoeloSize.touchMin),
            reason: label,
          );
          expect(tester.takeException(), isNull, reason: label);
        }
        // Navegar entre abas é local: não relê o repositório.
        expect(repository.childrenCalls, 1);
      });
    }
  });

  group('students.list - navegação', () {
    testWidgets(
      'students.list: o cartão da visão geral leva à aba e ela sobrevive à troca de aluno',
      (tester) async {
        await _useSurface(tester, 1440);
        final repository = _ScriptedStudentTrackingRepository();

        await tester.pumpWidget(_app(repository, disableAnimations: true));
        await tester.pumpAndSettle();

        // O rótulo 'Assiduidade' também é uma aba; só o cartão tem a superfície.
        final attendanceCard = find.ancestor(
          of: find.text('Assiduidade'),
          matching: find.byType(CoeloAdminInteractiveCard),
        );
        expect(attendanceCard, findsOneWidget);
        expect(tester.getSize(attendanceCard).height, greaterThanOrEqualTo(CoeloSize.touchMin));

        await tester.tap(attendanceCard);
        await tester.pumpAndSettle();

        expect(find.text('Faltas justificadas'), findsOneWidget);
        expect(find.text('Recomendação da professora'), findsNothing);
        final snapshotsBefore = repository.snapshotCalls;

        await tester.tap(_childSelector);
        await tester.pumpAndSettle();
        await tester.tap(find.text(_secondChild).last);
        await tester.pumpAndSettle();

        expect(repository.lastChildContextId, 'caio-context');
        expect(repository.snapshotCalls, greaterThan(snapshotsBefore));
        expect(find.text(_secondChild), findsWidgets);
        expect(find.text(_firstChild), findsNothing);
        // A aba escolhida continua valendo depois da troca de aluno.
        expect(find.text('Faltas justificadas'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

Widget _app(StudentTrackingRepository repository, {bool disableAnimations = false}) => MaterialApp(
  theme: CoeloTheme.light,
  home: Builder(
    builder: (context) {
      final page = StudentTrackingPage(repository: repository, logout: unavailableSuperadminLogout);
      if (!disableAnimations) return page;
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: page,
      );
    },
  ),
);

Future<void> _useSurface(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// O item clicável de cada aba do `SuperadminUnderlineTabs`.
Finder _tabItem(StudentTrackingTab tab) => find.byKey(ValueKey('superadmin-underline-tab-$tab'));

/// Se o foco primário está dentro de [target] ou o envolve (o `InkWell` que
/// carrega o `FocusNode` é ancestral do container com a chave).
bool _focusTouches(WidgetTester tester, Finder target) {
  final focusedContext = tester.binding.focusManager.primaryFocus?.context;
  if (focusedContext == null || target.evaluate().isEmpty) return false;
  final focused = find.byElementPredicate((element) => identical(element, focusedContext));
  return find.descendant(of: target, matching: focused, matchRoot: true).evaluate().isNotEmpty ||
      find.descendant(of: focused, matching: target, matchRoot: true).evaluate().isNotEmpty;
}

final class _ErrorStage {
  _ErrorStage(this.label, this.arm, this.disarm);
  final String label;
  final void Function(_ScriptedStudentTrackingRepository repository) arm;
  final void Function(_ScriptedStudentTrackingRepository repository) disarm;
}

/// Envolve o exemplo local do app para contar leituras e falhar com `Error`
/// real (não `Exception`) ou com os sinais mapeados do domínio.
final class _ScriptedStudentTrackingRepository implements StudentTrackingRepository {
  static const _delegate = DevelopmentStudentTrackingRepository();

  int childrenCalls = 0;
  int snapshotCalls = 0;
  String? lastChildContextId;
  String? lastActivityId;
  String? lastPeriodId;

  /// A leitura responde uma página sem nenhum aluno vinculado.
  bool emptyChildren = false;

  /// `fetchChildren` completa com um `TypeError` de cast real.
  bool malformedChildren = false;

  /// `fetchSnapshot` completa com um `TypeError` de cast real.
  bool malformedSnapshot = false;

  Object? childrenError;
  Object? snapshotError;

  @override
  Future<StudentTrackingChildPage> fetchChildren({
    String? query,
    StudentTrackingCursor? after,
    int limit = 20,
  }) async {
    childrenCalls += 1;
    if (childrenError case final error?) throw error;
    if (malformedChildren) return _cast<StudentTrackingChildPage>('página inválida');
    if (emptyChildren) return StudentTrackingChildPage(items: const []);
    return _delegate.fetchChildren(query: query, after: after, limit: limit);
  }

  @override
  Future<StudentTrackingSnapshot> fetchSnapshot({
    required String childContextId,
    String? activityId,
    String? periodId,
    StudentTrackingAgendaCursor? agendaAfter,
    int agendaLimit = 20,
  }) async {
    snapshotCalls += 1;
    lastChildContextId = childContextId;
    lastActivityId = activityId;
    lastPeriodId = periodId;
    if (snapshotError case final error?) throw error;
    if (malformedSnapshot) return _cast<StudentTrackingSnapshot>('snapshot inválido');
    return _delegate.fetchSnapshot(
      childContextId: childContextId,
      activityId: activityId,
      periodId: periodId,
      agendaAfter: agendaAfter,
      agendaLimit: agendaLimit,
    );
  }
}

/// Produz um `Error` real, como o de um decoder que recebe outro shape.
T _cast<T>(Object value) => value as T;
