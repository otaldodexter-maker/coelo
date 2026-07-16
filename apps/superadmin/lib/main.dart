import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/superadmin_app.dart';
import 'core/config/superadmin_auth_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final authScope = await createSuperadminAuthScope();
  runApp(
    SuperadminApp(session: authScope.session, login: authScope.login, logout: authScope.logout),
  );
}
