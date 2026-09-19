import 'package:shared_preferences/shared_preferences.dart';

/// Guarda, só neste dispositivo, se o usuário já viu o tour do menu
/// (concluído ou pulado). Sem coluna nem RPC: é preferência local, por
/// usuário, para o primeiro acesso mostrar o tour uma única vez.
abstract interface class SuperadminTourStore {
  /// True quando o tour do menu já foi concluído ou pulado por este usuário;
  /// false quando ainda não; null quando ainda não dá para saber (usuário não
  /// identificado neste instante — o shell pergunta de novo depois).
  Future<bool?> hasSeenMenuTour();

  /// Registra que o tour do menu terminou (`done` ou `skipped`).
  Future<void> markMenuTour(String outcome);
}

final class InMemorySuperadminTourStore implements SuperadminTourStore {
  InMemorySuperadminTourStore({bool seen = false}) : _seen = seen;

  bool _seen;
  String? lastOutcome;

  @override
  Future<bool?> hasSeenMenuTour() async => _seen;

  @override
  Future<void> markMenuTour(String outcome) async {
    _seen = true;
    lastOutcome = outcome;
  }
}

/// Chave `coelo.superadmin.tour.menu.<userId>`. Sem usuário identificado a
/// resposta é null (o shell tenta de novo) e nada é gravado.
final class SharedPreferencesSuperadminTourStore implements SuperadminTourStore {
  SharedPreferencesSuperadminTourStore({
    required String? Function() currentUserId,
    SharedPreferencesAsync? preferences,
  }) : _currentUserId = currentUserId,
       _preferences = preferences;

  static const keyPrefix = 'coelo.superadmin.tour.menu.';
  final String? Function() _currentUserId;
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store => _preferences ??= SharedPreferencesAsync();

  String? get _key {
    final userId = _currentUserId();
    return userId == null || userId.isEmpty ? null : '$keyPrefix$userId';
  }

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
}
