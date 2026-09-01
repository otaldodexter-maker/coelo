import 'dart:async';

import 'package:coelo_auth/coelo_auth.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../auth/catalog_access_gateway.dart';
import '../catalog/catalog_foundations.dart';
import '../catalog/catalog_registry.dart';
import '../presentation/catalog_home_page.dart';

final class CatalogApp extends StatelessWidget {
  const CatalogApp({
    required this.accessGateway,
    required this.authGateway,
    this.publicAccess = false,
    super.key,
  });

  final CatalogAccessGateway accessGateway;
  final CoeloAuthGateway authGateway;
  final bool publicAccess;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catálogo Coelo',
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      home: publicAccess
          ? const _CatalogAuthorizedPage()
          : _CatalogAccessGate(accessGateway: accessGateway, authGateway: authGateway),
    );
  }
}

final class _CatalogAccessGate extends StatefulWidget {
  const _CatalogAccessGate({required this.accessGateway, required this.authGateway});

  final CatalogAccessGateway accessGateway;
  final CoeloAuthGateway authGateway;

  @override
  State<_CatalogAccessGate> createState() => _CatalogAccessGateState();
}

final class _CatalogAccessGateState extends State<_CatalogAccessGate> with WidgetsBindingObserver {
  static const _accessRevalidationInterval = Duration(minutes: 5);

  StreamSubscription<bool>? _authSubscription;
  Timer? _revalidationTimer;
  CatalogAccessResult? _result;
  var _requestVersion = 0;
  var _authStreamVersion = 0;
  var _signOutFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeToAuth();
    unawaited(_checkAccess());
  }

  @override
  void didUpdateWidget(covariant _CatalogAccessGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authGateway != widget.authGateway) {
      unawaited(_authSubscription?.cancel());
      _subscribeToAuth();
    }
    if (oldWidget.accessGateway != widget.accessGateway ||
        oldWidget.authGateway != widget.authGateway) {
      unawaited(_checkAccess());
    }
  }

  @override
  void dispose() {
    _requestVersion++;
    _authStreamVersion++;
    _revalidationTimer?.cancel();
    unawaited(_authSubscription?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkAccess());
    }
  }

  void _subscribeToAuth() {
    final streamVersion = ++_authStreamVersion;
    _authSubscription = widget.authGateway.authStateChanges.listen(
      (_) {
        if (streamVersion == _authStreamVersion) {
          unawaited(_checkAccess());
        }
      },
      onError: (Object _, StackTrace _) {
        if (streamVersion == _authStreamVersion) {
          _failClosed();
        }
      },
    );
  }

  void _failClosed() {
    _requestVersion++;
    _revalidationTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _signOutFailed = false;
      _result = CatalogAccessResult.unavailable;
    });
  }

  Future<void> _checkAccess({bool verifyFailedSignOut = false}) async {
    final version = ++_requestVersion;
    _revalidationTimer?.cancel();
    if (mounted) {
      setState(() {
        _signOutFailed = false;
        _result = null;
      });
    }

    CatalogAccessResult result;
    if (!widget.authGateway.isAuthenticated) {
      result = CatalogAccessResult.unauthenticated;
    } else {
      try {
        result = await widget.accessGateway.checkAccess();
      } on Exception {
        result = CatalogAccessResult.unavailable;
      }
      if (!widget.authGateway.isAuthenticated) {
        result = CatalogAccessResult.unauthenticated;
      }
    }

    if (!mounted || version != _requestVersion) {
      return;
    }
    setState(() {
      if (verifyFailedSignOut && result != CatalogAccessResult.unauthenticated) {
        _signOutFailed = true;
        _result = CatalogAccessResult.unavailable;
      } else {
        _result = result;
      }
    });
    if (_result == CatalogAccessResult.allowed) {
      _revalidationTimer = Timer(_accessRevalidationInterval, () => unawaited(_checkAccess()));
    }
  }

  Future<void> _signOut() async {
    _requestVersion++;
    _revalidationTimer?.cancel();
    if (mounted) {
      setState(() {
        _signOutFailed = false;
        _result = null;
      });
    }
    try {
      await widget.authGateway.signOut();
    } on Exception {
      if (!mounted) {
        return;
      }
      await _checkAccess(verifyFailedSignOut: true);
      return;
    }
    await _checkAccess();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_result) {
      null => const _CatalogLoadingPage(),
      CatalogAccessResult.allowed => _CatalogAuthorizedPage(onSignOut: _signOut),
      CatalogAccessResult.unauthenticated => _CatalogLoginPage(
        authGateway: widget.authGateway,
        onAuthenticated: _checkAccess,
      ),
      CatalogAccessResult.denied => _CatalogMessagePage(
        icon: Icons.lock_outline,
        title: 'Acesso não autorizado',
        message:
            'Sua conta está autenticada, mas não possui a permissão '
            'platform.read.',
        action: OutlinedButton(onPressed: _signOut, child: const Text('Sair')),
      ),
      CatalogAccessResult.unavailable => _CatalogMessagePage(
        icon: Icons.cloud_off_outlined,
        title: _signOutFailed ? 'Não foi possível sair' : 'Não foi possível verificar o acesso',
        message: _signOutFailed
            ? 'A sessão continua ativa, mas o catálogo permanece bloqueado.'
            : 'O catálogo permanece bloqueado até a autorização ser '
                  'confirmada.',
        action: OutlinedButton(
          onPressed: _signOutFailed ? _signOut : _checkAccess,
          child: Text(_signOutFailed ? 'Tentar sair novamente' : 'Tentar novamente'),
        ),
      ),
    };
  }
}

final class _CatalogLoadingPage extends StatelessWidget {
  const _CatalogLoadingPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'Verificando acesso ao catálogo',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

final class _CatalogLoginPage extends StatefulWidget {
  const _CatalogLoginPage({required this.authGateway, required this.onAuthenticated});

  final CoeloAuthGateway authGateway;
  final Future<void> Function() onAuthenticated;

  @override
  State<_CatalogLoginPage> createState() => _CatalogLoginPageState();
}

final class _CatalogLoginPageState extends State<_CatalogLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    CoeloAuthSignInResult result;
    try {
      result = await widget.authGateway.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        persistSession: true,
      );
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = CoeloAuthSignInResult.genericFailureMessage;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    if (!result.isSuccess) {
      setState(() {
        _isSubmitting = false;
        _error = result.message ?? CoeloAuthSignInResult.genericFailureMessage;
      });
      return;
    }
    await widget.onAuthenticated();
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _CatalogCenteredPage(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: CoeloSize.iconLg,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Text(
              'Entre no catálogo',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              'Use sua conta interna Coelo. A autorização é verificada no '
              'servidor.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: CoeloSpacing.space6),
            TextFormField(
              key: const Key('catalog-login-email'),
              controller: _emailController,
              autofillHints: const [AutofillHints.email],
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'E-mail'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Informe o e-mail.' : null,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            TextFormField(
              key: const Key('catalog-login-password'),
              controller: _passwordController,
              autofillHints: const [AutofillHints.password],
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => unawaited(_submit()),
              decoration: const InputDecoration(labelText: 'Senha'),
              validator: (value) => value == null || value.isEmpty ? 'Informe a senha.' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: CoeloSpacing.space3),
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: CoeloSpacing.space4),
            FilledButton(
              key: const Key('catalog-login-submit'),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox.square(
                      dimension: CoeloSize.iconSm,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _CatalogAuthorizedPage extends StatelessWidget {
  const _CatalogAuthorizedPage({this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return CatalogHomePage.fromIndexAsset(
      registry: buildCatalogRegistry(),
      foundations: buildCatalogFoundationRegistry(),
      onSignOut: onSignOut,
    );
  }
}

final class _CatalogMessagePage extends StatelessWidget {
  const _CatalogMessagePage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return _CatalogCenteredPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: CoeloSize.iconLg, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: CoeloSpacing.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: CoeloSpacing.space4),
          action,
        ],
      ),
    );
  }
}

final class _CatalogCenteredPage extends StatelessWidget {
  const _CatalogCenteredPage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(padding: const EdgeInsets.all(CoeloSpacing.space6), child: child),
            ),
          ),
        ),
      ),
    );
  }
}
