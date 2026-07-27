import 'package:coelo_catalog/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('uses an isolated catalog session key', () {
    expect(catalogSessionKey, 'coelo.catalog.auth.session');
  });

  test('does not detect authentication sessions in the browser URL', () {
    final options = createCatalogAuthOptions(
      SharedPreferencesLocalStorage(persistSessionKey: catalogSessionKey),
    );

    expect(options.detectSessionInUri, isFalse);
  });
}
