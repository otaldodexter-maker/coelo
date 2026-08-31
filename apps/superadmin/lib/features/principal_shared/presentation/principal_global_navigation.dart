import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum PrincipalDestination { home, forYou, moments, search }

final class PrincipalGlobalHeader extends StatelessWidget implements PreferredSizeWidget {
  const PrincipalGlobalHeader({
    required this.onOpenMenu,
    required this.onOpenNotifications,
    required this.onOpenProfile,
    this.onReportProblem,
    this.keyPrefix = 'principal-happens',
    super.key,
  });

  final VoidCallback onOpenMenu;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenProfile;
  final VoidCallback? onReportProblem;
  final String keyPrefix;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: CoeloSpacing.space4, right: CoeloSpacing.space3),
          child: Row(
            children: [
              Semantics(
                image: true,
                label: 'Coelo',
                child: _ClampedTextScale(
                  maxScaleFactor: 1.3,
                  child: Text(
                    'coelo',
                    key: ValueKey('$keyPrefix-logo'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-menu'),
                tooltip: 'Abrir menu',
                onPressed: onOpenMenu,
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('$keyPrefix-report-problem'),
                tooltip: 'Reportar problema',
                onPressed:
                    onReportProblem ??
                    () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('O envio de problemas ainda não está disponível.'),
                      ),
                    ),
                icon: const Icon(Icons.bug_report_outlined, size: 22),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-notifications'),
                tooltip: 'Notificações',
                onPressed: onOpenNotifications,
                icon: const Icon(Icons.notifications_none_rounded, size: 22),
              ),
              IconButton(
                key: ValueKey('$keyPrefix-context-avatar'),
                tooltip: 'Abrir perfil',
                onPressed: onOpenProfile,
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const _ClampedTextScale(maxScaleFactor: 1.3, child: Text('AM')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ClampedTextScale extends StatelessWidget {
  const _ClampedTextScale({required this.maxScaleFactor, required this.child});

  final double maxScaleFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = MediaQuery.textScalerOf(context).scale(1);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(current > maxScaleFactor ? maxScaleFactor : current),
      ),
      child: child,
    );
  }
}

final class PrincipalGlobalNavigation extends StatelessWidget {
  const PrincipalGlobalNavigation({
    required this.selected,
    required this.onHome,
    required this.onForYou,
    required this.onPublishNow,
    required this.onMoments,
    required this.onSearch,
    required this.onMessages,
    super.key,
  });

  final PrincipalDestination selected;
  final VoidCallback onHome;
  final VoidCallback onForYou;
  final VoidCallback onPublishNow;
  final VoidCallback onMoments;
  final VoidCallback onSearch;
  final VoidCallback onMessages;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + CoeloSpacing.space4;
    final scheme = Theme.of(context).colorScheme;
    final expandedText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final dockHeight = expandedText ? 104.0 : 72.0;
    Widget dockAction({
      required String tooltip,
      required IconData icon,
      required bool selected,
      required VoidCallback onPressed,
    }) {
      final action = _DockAction(
        tooltip: tooltip,
        icon: icon,
        selected: selected,
        expandedText: expandedText,
        onPressed: onPressed,
      );
      return expandedText
          ? Expanded(child: action)
          : SizedBox(width: 68, height: dockHeight, child: action);
    }

    return Stack(
      children: [
        Positioned(
          left: CoeloSpacing.space4,
          right: CoeloSpacing.space4,
          bottom: bottom,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: SizedBox(
                height: dockHeight + 27,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(
                      key: const Key('principal-global-dock'),
                      height: dockHeight,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(CoeloRadius.full),
                        border: Border.all(color: scheme.outlineVariant),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: .06),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          dockAction(
                            tooltip: 'Home',
                            icon: Icons.home_outlined,
                            selected: selected == PrincipalDestination.home,
                            onPressed: onHome,
                          ),
                          dockAction(
                            tooltip: 'Para você',
                            icon: Icons.favorite_border_rounded,
                            selected: selected == PrincipalDestination.forYou,
                            onPressed: onForYou,
                          ),
                          const SizedBox(width: 68),
                          dockAction(
                            tooltip: 'Momentos',
                            icon: Icons.smart_display_outlined,
                            selected: selected == PrincipalDestination.moments,
                            onPressed: onMoments,
                          ),
                          dockAction(
                            tooltip: 'Pesquisar',
                            icon: Icons.search_rounded,
                            selected: selected == PrincipalDestination.search,
                            onPressed: onSearch,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: SizedBox(
                        width: 68,
                        child: Column(
                          children: [
                            Semantics(
                              button: true,
                              label: 'Publicar no Agora',
                              child: IconButton.filled(
                                key: const Key('principal-global-publish-now'),
                                tooltip: 'Publicar no Agora',
                                onPressed: onPublishNow,
                                icon: const Icon(Icons.add_rounded, size: 24),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size.square(54),
                                  maximumSize: const Size.square(54),
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                ),
                              ),
                            ),
                            Text(
                              'Agora',
                              key: const Key('principal-global-publish-now-label'),
                              maxLines: 1,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: CoeloSpacing.space4,
          bottom: bottom + dockHeight + CoeloSpacing.space3,
          child: IconButton.filledTonal(
            key: const Key('principal-global-messages'),
            tooltip: 'Mensagens',
            onPressed: onMessages,
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            style: IconButton.styleFrom(minimumSize: const Size.square(CoeloSize.touchMin)),
          ),
        ),
      ],
    );
  }
}

final class _DockAction extends StatelessWidget {
  const _DockAction({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.expandedText,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final bool expandedText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      child: Tooltip(
        message: tooltip,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: color,
            minimumSize: Size.zero,
            maximumSize: const Size(double.infinity, double.infinity),
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                tooltip,
                maxLines: expandedText ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
