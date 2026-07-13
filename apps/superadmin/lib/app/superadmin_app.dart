import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/config/superadmin_app_config.dart';
import '../core/guards/superadmin_session.dart';
import '../features/auth/domain/login_request.dart';
import 'router/superadmin_router.dart';

class SuperadminApp extends StatefulWidget {
  const SuperadminApp({this.session, this.login = unavailableSuperadminLogin, super.key});

  final SuperadminSession? session;
  final LoginAction login;

  @override
  State<SuperadminApp> createState() => _SuperadminAppState();
}

class _SuperadminAppState extends State<SuperadminApp> {
  late final SuperadminSession _session;
  late final GoRouter _router;
  late final bool _ownsSession;

  @override
  void initState() {
    super.initState();
    _ownsSession = widget.session == null;
    _session = widget.session ?? SuperadminSession();
    _router = createSuperadminRouter(session: _session, login: widget.login);
  }

  @override
  void dispose() {
    _router.dispose();
    if (_ownsSession) {
      _session.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: SuperadminAppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
