import 'package:shared_preferences/shared_preferences.dart';

/// Guarda, só neste dispositivo, se o usuário já viu o tour do menu
/// (concluído ou pulado) e em que tela parou o tour completo. Sem coluna nem
/// RPC: é preferência local, por usuário, para o primeiro acesso mostrar o
/// tour uma única vez e para o tour completo retomar após um reload.
abstract interface class SuperadminTourStore {
  /// True quando o tour do menu já foi concluído ou pulado por este usuário;
  /// false quando ainda não; null quando ainda não dá para saber (usuário não
  /// identificado neste instante — o shell pergunta de novo depois).
  Future<bool?> hasSeenMenuTour();

  /// Registra que o tour do menu terminou (`done` ou `skipped`).
  Future<void> markMenuTour(String outcome);

  /// Índice da tela em que o tour completo parou (para retomar após reload),
  /// ou null quando não há tour completo em andamento.
  Future<int?> completeTourProgress();

  /// Grava o índice da tela em andamento no tour completo.
  Future<void> saveCompleteTourProgress(int screenIndex);

  /// Registra que o tour completo terminou (`done` ou `skipped`): o progresso
  /// deixa de existir.
  Future<void> markCompleteTour(String outcome);
}

final class InMemorySuperadminTourStore implements SuperadminTourStore {
  InMemorySuperadminTourStore({bool seen = false, int? completeProgress})
    : _seen = seen,
      _completeProgress = completeProgress;

  bool _seen;
  String? lastOutcome;
  int? _completeProgress;
  String? lastCompleteOutcome;

  int? get completeProgress => _completeProgress;

  @override
  Future<bool?> hasSeenMenuTour() async => _seen;

  @override
  Future<void> markMenuTour(String outcome) async {
    _seen = true;
    lastOutcome = outcome;
  }

  @override
  Future<int?> completeTourProgress() async => _completeProgress;

  @override
  Future<void> saveCompleteTourProgress(int screenIndex) async {
    _completeProgress = screenIndex;
  }

  @override
  Future<void> markCompleteTour(String outcome) async {
    _completeProgress = null;
    lastCompleteOutcome = outcome;
  }
}

/// Chaves `coelo.superadmin.tour.menu.<userId>` (done|skipped) e
/// `coelo.superadmin.tour.complete.<userId>` (índice da tela em andamento;
/// `done`/`skipped` ao terminar). Sem usuário identificado a resposta é null
/// (o shell tenta de novo) e nada é gravado.
final class SharedPreferencesSuperadminTourStore implements SuperadminTourStore {
  SharedPreferencesSuperadminTourStore({
    required String? Function() currentUserId,
    SharedPreferencesAsync? preferences,
  }) : _currentUserId = currentUserId,
       _preferences = preferences;

  static const keyPrefix = 'coelo.superadmin.tour.menu.';
  static const completeKeyPrefix = 'coelo.superadmin.tour.complete.';
  final String? Function() _currentUserId;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store => _preferences ??= SharedPreferencesAsync();

  String? _keyFor(String prefix) {
    final userId = _currentUserId();
    return userId == null || userId.isEmpty ? null : '$prefix$userId';
  }

  String? get _key => _keyFor(keyPrefix);
  String? get _completeKey => _keyFor(completeKeyPrefix);

  @override
  Future<bool?> hasSeenMenuTour() async {
    final key = _key;
    if (key == null) return null;
    return (await _store.getString(key)) != null;
  }

  @override
  Future<void> markMenuTour(String outcome) async {
    final key = _key;
    if (key == null) return;
    await _store.setString(key, outcome);
  }

  @override
  Future<int?> completeTourProgress() async {
    final key = _completeKey;
    if (key == null) return null;
    return int.tryParse(await _store.getString(key) ?? '');
  }

  @override
  Future<void> saveCompleteTourProgress(int screenIndex) async {
    final key = _completeKey;
    if (key == null) return;
    await _store.setString(key, '$screenIndex');
  }

  @override
  Future<void> markCompleteTour(String outcome) async {
    final key = _completeKey;
    if (key == null) return;
    await _store.setString(key, outcome);
  }
}
