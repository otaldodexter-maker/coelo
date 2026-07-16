import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../core/config/superadmin_app_config.dart';
import '../../features/auth/domain/logout_action.dart';

class SuperadminShell extends StatelessWidget {
  const SuperadminShell({required this.logout, super.key});

  final LogoutAction logout;

  Future<void> _handleLogout(BuildContext context) async {
    final result = await logout();
    if (!context.mounted || result.isSuccess) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message ?? LogoutResult.genericFailureMessage)));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showRail = constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;

        if (!showRail) {
          return Scaffold(
            appBar: _CompactAppBar(onLogout: () => _handleLogout(context)),
            body: const _BootstrapContent(),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              _SuperadminNavigationRail(onLogout: () => _handleLogout(context)),
              const VerticalDivider(width: 1),
              const Expanded(child: _BootstrapContent()),
            ],
          ),
        );
      },
    );
  }
}

class _CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompactAppBar({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Superadmin'),
      centerTitle: false,
      actions: [_LogoutButton(onPressed: onLogout)],
    );
  }
}

class _SuperadminNavigationRail extends StatelessWidget {
  const _SuperadminNavigationRail({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return NavigationRail(
      selectedIndex: 0,
      minWidth: 88,
      backgroundColor: colors.surface,
      trailing: _LogoutButton(onPressed: onLogout),
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(tooltip: 'Sair', onPressed: onPressed, icon: const Icon(Icons.logout));
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
