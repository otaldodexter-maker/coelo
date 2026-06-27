import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../core/config/superadmin_app_config.dart';
import 'router/superadmin_routes.dart';
import 'shell/superadmin_shell.dart';

class SuperadminApp extends StatelessWidget {
  const SuperadminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: SuperadminAppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: ThemeMode.system,
      initialRoute: SuperadminRoutes.home,
      routes: <String, WidgetBuilder>{SuperadminRoutes.home: (_) => const SuperadminShell()},
    );
  }
}
