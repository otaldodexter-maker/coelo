import 'package:coelo_auth/coelo_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/catalog_app.dart';
import 'auth/catalog_access_gateway.dart';
import 'auth/supabase_catalog_access_gateway.dart';

const _supabaseUrl = String.fromEnvironment('COELO_SUPABASE_URL');
const _supabasePublishableKey = String.fromEnvironment('COELO_SUPABASE_PUBLISHABLE_KEY');
const catalogSessionKey = 'coelo.catalog.auth.session';

FlutterAuthClientOptions createCatalogAuthOptions(LocalStorage localStorage) {
  return FlutterAuthClientOptions(localStorage: localStorage, detectSessionInUri: false);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await _createCatalogDependencies();
  runApp(
    CatalogApp(
      accessGateway: dependencies.accessGateway,
      authGateway: dependencies.authGateway,
      publicAccess: true,
    ),
  );
}

Future<_CatalogDependencies> _createCatalogDependencies() async {
  if (_supabaseUrl.isEmpty || _supabasePublishableKey.isEmpty) {
    return const _CatalogDependencies.unavailable();
  }

  try {
    final storage = ConditionalSupabaseLocalStorage(
      delegate: SharedPreferencesLocalStorage(persistSessionKey: catalogSessionKey),
    );
    await Supabase.initialize(
      url: _supabaseUrl,
      publishableKey: _supabasePublishableKey,
      authOptions: createCatalogAuthOptions(storage),
    );
    final client = Supabase.instance.client;
    return _CatalogDependencies(
      accessGateway: SupabaseCatalogAccessGateway(client),
      authGateway: SupabaseCoeloAuthGateway(client, sessionPersistence: storage),
    );
  } on Exception catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'coelo_catalog',
        context: ErrorDescription('while initializing the independent catalog authentication'),
      ),
    );
    return const _CatalogDependencies.unavailable();
  }
}

final class _CatalogDependencies {
  const _CatalogDependencies({required this.accessGateway, required this.authGateway});

  const _CatalogDependencies.unavailable()
    : accessGateway = const _UnavailableCatalogAccessGateway(),
      authGateway = const UnavailableCoeloAuthGateway();

  final CatalogAccessGateway accessGateway;
  final CoeloAuthGateway authGateway;
}

final class _UnavailableCatalogAccessGateway implements CatalogAccessGateway {
  const _UnavailableCatalogAccessGateway();

  @override
  Future<CatalogAccessResult> checkAccess() {
    return Future.value(CatalogAccessResult.unavailable);
  }
}
