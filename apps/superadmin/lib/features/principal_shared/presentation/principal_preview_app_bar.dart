import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

/// App bar compartilhada somente pelos previews do app Principal no Superadmin.
///
/// Mantém o contrato visual aprovado: wordmark à esquerda e ações
/// bug → notificações → contexto à direita.
final class PrincipalPreviewAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PrincipalPreviewAppBar({
    required this.keyPrefix,
    required this.onReportBug,
    required this.onOpenNotifications,
    required this.onOpenContext,
    this.unreadNotifications = 1,
    super.key,
  });

  final String keyPrefix;
  final VoidCallback onReportBug;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenContext;
  final int unreadNotifications;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: preferredSize.height,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      titleSpacing: CoeloSpacing.space4,
      title: Semantics(
        image: true,
        label: 'Coelo',
        child: Text(
          'coelo',
          key: ValueKey('$keyPrefix-logo'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: scheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
      ),
      actions: [
        _PrincipalHeaderAction(
          actionKey: ValueKey('$keyPrefix-bug'),
          icon: Icons.bug_report_outlined,
          tooltip: 'Reportar bug',
          onPressed: onReportBug,
        ),
        _PrincipalHeaderAction(
          actionKey: ValueKey('$keyPrefix-notifications'),
          icon: Icons.notifications_none_rounded,
          tooltip: unreadNotifications == 1
              ? 'Notificações, 1 não lida'
              : 'Notificações, $unreadNotifications não lidas',
          badgeLabel: unreadNotifications > 0 ? '$unreadNotifications' : null,
          onPressed: onOpenNotifications,
        ),
        Padding(
          padding: const EdgeInsets.only(right: CoeloSpacing.space3),
          child: IconButton(
            key: ValueKey('$keyPrefix-context-avatar'),
            tooltip: 'Trocar contexto',
            onPressed: onOpenContext,
            style: _headerActionStyle(scheme),
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: const Text('AC'),
            ),
          ),
        ),
      ],
    );
  }
}

final class _PrincipalHeaderAction extends StatelessWidget {
  const _PrincipalHeaderAction({
    required this.actionKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badgeLabel,
  });

  final Key actionKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: actionKey,
          tooltip: tooltip,
          onPressed: onPressed,
          style: _headerActionStyle(scheme),
          icon: Icon(icon),
        ),
        if (badgeLabel case final label?)
          Positioned(
            right: 5,
            top: 4,
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

ButtonStyle _headerActionStyle(ColorScheme scheme) =>
    IconButton.styleFrom(
      minimumSize: const Size.square(CoeloSize.touchMin),
      foregroundColor: scheme.onSurface,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused) ||
            states.contains(WidgetState.pressed)) {
          return scheme.primaryContainer.withValues(alpha: .48);
        }
        return Colors.transparent;
      }),
    );
