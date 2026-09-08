// Destino previsto no repositorio:
//   apps/superadmin/test/features/activities/presentation/
//     activity_directory_error_hang_test.dart
//
// O arquivo e auto-contido de proposito: nao usa `test/support/...` por
// caminho relativo, entao pode ser colocado em qualquer pasta sob
// `apps/superadmin/test/` sem ajustar imports.
//
// O QUE ESTE ARQUIVO MEDE
//
// Contrato: quando o repositorio do diretorio de Atividades falha, `load()`
// termina e o estado sai de `loading` para `failure`, com retry na tela.
// O teste afirma esse contrato, nao o defeito.
//
// Fatos confirmados lendo o codigo (nao supostos):
// - `ActivityDirectoryViewModel._load` (activity_directory_view_model.dart,
//   137-174) envolve o `Future.wait` num try cujo unico catch generico e
//   `on Exception` (168). Em Dart, `on Exception` NAO captura `Error`.
// - O `notifyListeners()` final (173) esta FORA do try. Se um `Error` escapar,
//   ele nao roda e `_state` permanece `ActivityDirectoryLoadState.loading`.
// - `ActivityDirectoryPage._ActivityDirectoryPageState.initState`
//   (activity_directory_page.dart, 170-176) dispara `_viewModel.load()` dentro
//   de `WidgetsBinding.instance.addPostFrameCallback` e descarta o Future.
//   Logo, um `Error` que escape vira erro assincrono nao tratado e a tela fica
//   no esqueleto de carregamento, sem retry.
// - `_ActivityDirectoryContent.build` (1687-1706) renderiza o esqueleto com
//   `Key('activity-directory-loading')` para `initial`/`loading`, e o painel
//   'Nao foi possivel carregar as atividades' + 'Tentar novamente' para
//   `failure`.
// - `ActivityDirectoryItem.fromJson` usa casts crus (`json['id'] as String`),
//   e `SupabaseActivityDirectoryRepository` trata apenas `PostgrestException`,
//   entao um `TypeError` de decodificacao e produzivel de verdade.
//
// O QUE ESTE ARQUIVO DELIBERADAMENTE NAO AFIRMA
//
// Nada sobre `_capture` (176-184). Ela devolve `Exception` como VALOR e deixa
// `Error` subir de proposito: se `_capture` capturasse `Object`, um `Error`
// viraria valor de retorno e passaria pelo filtro `whereType<Exception>()` da
// linha 148 como se fosse sucesso, quebrando no cast da linha 150. O contrato
// medido aqui e so um: `load()` termina e o estado sai de `loading`.

import 'package:coelo_superadmin/features/activities/domain/activity_directory.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_page.dart';
import 'package:coelo_superadmin/features/activities/presentation/activity_directory_view_model.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Este arquivo mistura `test` e `testWidgets`; garantir o binding antes evita
  // depender da ordem de execucao.
  TestWidgetsFlutterBinding.ensureInitialized();

  // CONTROLE DO HARNESS.
  // Prova que o repositorio falso, o `_runLoad` e as asserções funcionam.
  // Uma `Exception` comum e capturada pelo `on Exception` da linha 168, entao
  // este caso deve passar mesmo hoje. Se ele falhar, o problema esta no teste,
  // nao no codigo de producao.
  test(
    'controle: uma Exception comum no fetchPage leva o diretorio a failure',
    () async {
      final viewModel = ActivityDirectoryViewModel(
        _FailingActivityDirectoryRepository(_FailureMode.exceptionOnPage),
      );
      addTearDown(viewModel.dispose);

      final outcome = await _runLoad(viewModel);

      expect(
        outcome.completed,
        isTrue,
        reason:
            'load() nao completou em 2 segundos com uma Exception comum: '
            'o harness do teste esta quebrado, nao o view model.',
      );
      expect(
        outcome.escaped,
        isNull,
        reason:
            'load() propagou ${outcome.escaped} em vez de tratar a Exception.',
      );
      expect(
        viewModel.state,
        ActivityDirectoryLoadState.failure,
        reason:
            'Com uma Exception comum o diretorio deve ir para failure e '
            'oferecer retry. Estado observado: ${viewModel.state.name}.',
      );
    },
  );

  test(
    'load() termina em failure quando fetchPage lanca um Error de decodificacao',
    () async {
      final viewModel = ActivityDirectoryViewModel(
        _FailingActivityDirectoryRepository(_FailureMode.errorOnPage),
      );
      addTearDown(viewModel.dispose);

      final outcome = await _runLoad(viewModel);

      expect(
        outcome.completed,
        isTrue,
        reason:
            'load() nao completou em 2 segundos. Estado observado: '
            '${viewModel.state.name}. O diretorio ficaria preso no esqueleto.',
      );
      expect(
        viewModel.state,
        isNot(ActivityDirectoryLoadState.loading),
        reason:
            'O estado permaneceu em loading: notifyListeners() da linha 173 '
            'nao rodou e a tela mostraria esqueleto para sempre, sem retry.',
      );
      expect(
        viewModel.state,
        ActivityDirectoryLoadState.failure,
        reason:
            'Uma falha de decodificacao deve virar failure recuperavel. '
            'Estado observado: ${viewModel.state.name}.',
      );
      expect(
        outcome.escaped,
        isNull,
        reason:
            'load() propagou ${outcome.escaped} em vez de trata-lo. A pagina '
            'chama load() por addPostFrameCallback e descarta o Future, entao '
            'um erro que escapa nunca chega a nenhum handler.',
      );
    },
  );

  test(
    'load() termina em failure quando fetchFilterOptions lanca um Error de decodificacao',
    () async {
      final viewModel = ActivityDirectoryViewModel(
        _FailingActivityDirectoryRepository(_FailureMode.errorOnFilterOptions),
      );
      addTearDown(viewModel.dispose);

      final outcome = await _runLoad(viewModel);

      expect(
        outcome.completed,
        isTrue,
        reason:
            'load() nao completou em 2 segundos. Estado observado: '
            '${viewModel.state.name}. O diretorio ficaria preso no esqueleto.',
      );
      expect(
        viewModel.state,
        isNot(ActivityDirectoryLoadState.loading),
        reason:
            'O estado permaneceu em loading apos falha nas opcoes de filtro: '
            'notifyListeners() da linha 173 nao rodou.',
      );
      expect(
        viewModel.state,
        ActivityDirectoryLoadState.failure,
        reason:
            'Uma falha de decodificacao nas opcoes de filtro deve virar failure '
            'recuperavel. Estado observado: ${viewModel.state.name}.',
      );
      expect(
        outcome.escaped,
        isNull,
        reason: 'load() propagou ${outcome.escaped} em vez de trata-lo.',
      );
    },
  );

  testWidgets(
    'a pagina sai do esqueleto e oferece retry quando o repositorio lanca um Error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CoeloTheme.light,
          home: ActivityDirectoryPage(
            repository: _FailingActivityDirectoryRepository(
              _FailureMode.errorOnPage,
            ),
            logout: () async => const LogoutResult.success(),
            onCreate: () {},
            onView: (_) {},
          ),
        ),
      );

      // Nao usar pumpAndSettle: o esqueleto e um CoeloStatePanel com
      // CircularProgressIndicator, que nunca assenta enquanto o estado for
      // loading. Um numero fixo e generoso de frames termina sempre.
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(
        find.byKey(const Key('activity-directory-loading')),
        findsNothing,
        reason:
            'A pagina continua no esqueleto de carregamento apos a falha do '
            'repositorio, sem qualquer caminho de recuperacao.',
      );
      expect(
        find.text('Não foi possível carregar as atividades'),
        findsOneWidget,
        reason:
            'A pagina deve mostrar o painel de falha do diretorio quando o '
            'carregamento falha.',
      );
      expect(
        find.text('Tentar novamente'),
        findsWidgets,
        reason: 'A falha do diretorio deve oferecer retry.',
      );
    },
  );
}

/// Executa `load()` sem deixar o teste travar.
///
/// Retorna se `load()` completou dentro do limite e qual erro, se algum,
/// escapou do view model. Um `Error` que escapa e informacao relevante: a
/// pagina descarta o Future de `load()`, entao esse erro nunca seria tratado.
Future<({bool completed, Object? escaped})> _runLoad(
  ActivityDirectoryViewModel viewModel,
) async {
  Object? escaped;
  var completed = false;

  Future<void> guarded() async {
    try {
      await viewModel.load();
    } catch (error) {
      escaped = error;
    }
    completed = true;
  }

  await guarded().timeout(const Duration(seconds: 2), onTimeout: () {});

  return (completed: completed, escaped: escaped);
}

enum _FailureMode {
  /// `fetchPage` lanca `Error` (falha de decodificacao).
  errorOnPage,

  /// `fetchFilterOptions` lanca `Error` (falha de decodificacao).
  errorOnFilterOptions,

  /// `fetchPage` lanca `Exception` comum: caso de controle do harness.
  exceptionOnPage,
}

/// Reproduz o cast cru de `ActivityDirectoryItem.fromJson`
/// (`json['id'] as String`) sobre uma linha cujo tipo diverge do esperado.
///
/// Lanca um `TypeError` real, que e `Error` e nao `Exception` — exatamente a
/// classe de falha que `SupabaseActivityDirectoryRepository` deixa escapar,
/// porque ele so trata `PostgrestException`.
T _decodeWithRawCast<T>() {
  final row = <String, Object?>{'id': 42};
  final id = row['id']! as String;
  throw StateError('o cast invalido nao ocorreu: "$id"');
}

final class _FailingActivityDirectoryRepository
    implements ActivityDirectoryRepository {
  _FailingActivityDirectoryRepository(this.mode);

  final _FailureMode mode;

  @override
  Future<ActivityDirectoryResult> fetchPage(ActivityDirectoryQuery query) async {
    switch (mode) {
      case _FailureMode.errorOnPage:
        return _decodeWithRawCast<ActivityDirectoryResult>();
      case _FailureMode.exceptionOnPage:
        throw const ActivityDirectoryUnavailableException();
      case _FailureMode.errorOnFilterOptions:
        return ActivityDirectoryResult(
          items: const [],
          totalCount: 0,
          page: query.page,
          pageSize: query.pageSize,
        );
    }
  }

  @override
  Future<ActivityFilterOptions> fetchFilterOptions() async {
    if (mode == _FailureMode.errorOnFilterOptions) {
      return _decodeWithRawCast<ActivityFilterOptions>();
    }
    return const ActivityFilterOptions();
  }

  @override
  Future<ActivityTemplateOptions> fetchTemplateOptions({
    String? institutionId,
  }) async => const ActivityTemplateOptions();

  @override
  Future<ActivityFormOptions> fetchFormOptions({
    required String institutionId,
  }) async => const ActivityFormOptions();

  @override
  Future<List<ActivityFormProfessionalOption>> searchProfessionals({
    required String institutionId,
    required String query,
    int limit = 20,
  }) async => const <ActivityFormProfessionalOption>[];

  @override
  Future<ActivityDetail?> fetchById(String activityId) async => null;
}
