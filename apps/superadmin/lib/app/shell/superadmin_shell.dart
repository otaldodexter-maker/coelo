import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../core/config/superadmin_app_config.dart';

class SuperadminShell extends StatelessWidget {
  const SuperadminShell({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;

        if (!showRail) {
          return const Scaffold(appBar: _CompactAppBar(), body: _BootstrapContent());
        }

        return const Scaffold(
          body: Row(
            children: [
              _SuperadminNavigationRail(),
              VerticalDivider(width: 1),
              Expanded(child: _BootstrapContent()),
            ],
          ),
        );
      },
    );
  }
}

class _CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompactAppBar();

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Superadmin'), centerTitle: false);
  }
}

class _SuperadminNavigationRail extends StatelessWidget {
  const _SuperadminNavigationRail();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return NavigationRail(
      selectedIndex: 0,
      minWidth: 88,
      backgroundColor: colors.surface,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.space_dashboard_outlined),
          selectedIcon: Icon(Icons.space_dashboard),
          label: Text('Inicio'),
        ),
      ],
    );
  }
}

class _BootstrapContent extends StatelessWidget {
  const _BootstrapContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SuperadminAppConfig.appSubtitle,
                  style: theme.textTheme.labelLarge?.copyWith(color: colors.primary),
                ),
                const SizedBox(height: CoeloSpacing.space2),
                Text(SuperadminAppConfig.appName, style: theme.textTheme.headlineLarge),
                const SizedBox(height: CoeloSpacing.space4),
                Text(
                  'Base inicial pronta',
                  style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: CoeloSpacing.space8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    border: Border.all(color: colors.outlineVariant),
                    borderRadius: BorderRadius.circular(CoeloRadius.md),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(CoeloSpacing.space4),
                    child: Text(
                      'A proxima etapa pode conectar a tela de login a esta base.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
