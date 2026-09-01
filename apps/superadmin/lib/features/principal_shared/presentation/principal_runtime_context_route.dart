import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/principal_runtime_context.dart';

typedef PrincipalRuntimeContextBuilder =
    Widget Function(BuildContext context, PrincipalRuntimeContext runtimeContext);

/// Resolves the authenticated actor's server-authorized Principal context.
///
/// Production routes use this boundary instead of accepting scope IDs from the
/// URL or falling back to preview fixtures.
final class PrincipalRuntimeContextRoute extends StatefulWidget {
  const PrincipalRuntimeContextRoute({required this.repository, required this.builder, super.key});

  final PrincipalRuntimeContextRepository repository;
  final PrincipalRuntimeContextBuilder builder;

  @override
  State<PrincipalRuntimeContextRoute> createState() => _PrincipalRuntimeContextRouteState();
}

final class _PrincipalRuntimeContextRouteState extends State<PrincipalRuntimeContextRoute> {
  late Future<List<PrincipalRuntimeContext>> _load;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PrincipalRuntimeContextRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) _reload();
  }

  void _reload() => _load = widget.repository.listAvailableContexts();

  void _retry() => setState(_reload);

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PrincipalRuntimeContext>>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(key: Key('principal-runtime-context-loading')),
          ),
        );
      }
      final error = snapshot.error;
      if (error is PrincipalRuntimeContextUnauthorized) {
        return const Scaffold(
          body: CoeloStatePanel(
            title: 'Contexto indisponível',
            message: 'Seu acesso não possui um vínculo ativo para esta experiência.',
            icon: Icons.lock_outline_rounded,
          ),
        );
      }
      if (error != null) {
        return Scaffold(
          body: CoeloStatePanel(
            title: 'Não foi possível carregar',
            message: 'Não conseguimos validar seu contexto agora.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Tentar novamente',
            onAction: _retry,
          ),
        );
      }
      final contexts = snapshot.data ?? const <PrincipalRuntimeContext>[];
      if (contexts.isEmpty) {
        return const Scaffold(
          body: CoeloStatePanel(
            title: 'Nenhum contexto disponível',
            message: 'Peça à instituição para confirmar seu vínculo ativo.',
            icon: Icons.person_search_outlined,
          ),
        );
      }
      if (contexts.length > 1) {
        return const Scaffold(
          body: CoeloStatePanel(
            title: 'Selecione um contexto',
            message:
                'Você possui mais de um vínculo ativo. A seleção explícita '
                'será necessária antes de continuar.',
            icon: Icons.account_tree_outlined,
          ),
        );
      }
      return widget.builder(context, contexts.first);
    },
  );
}
