import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ultima visao (cards/tabela) do diretorio de Suporte, por dispositivo
/// (P49 = A, Owner 11/09/2026). Persistencia local por desenho, como o tema.
abstract interface class SupportDisplayStore {
  Future<CoeloAdminDirectoryDisplay?> load();
  Future<void> save(CoeloAdminDirectoryDisplay display);
}

final class InMemorySupportDisplayStore implements SupportDisplayStore {
  CoeloAdminDirectoryDisplay? _display;

  @override
  Future<CoeloAdminDirectoryDisplay?> load() async => _display;

  @override
  Future<void> save(CoeloAdminDirectoryDisplay display) async => _display = display;
}

final class SharedPreferencesSupportDisplayStore implements SupportDisplayStore {
  SharedPreferencesSupportDisplayStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences;

  static const _key = 'coelo.superadmin.support.display';
  SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _store => _preferences ??= SharedPreferencesAsync();

  @override
  Future<CoeloAdminDirectoryDisplay?> load() async {
    final name = await _store.getString(_key);
    return CoeloAdminDirectoryDisplay.values.where((d) => d.name == name).firstOrNull;
  }

  @override
  Future<void> save(CoeloAdminDirectoryDisplay display) => _store.setString(_key, display.name);
}
