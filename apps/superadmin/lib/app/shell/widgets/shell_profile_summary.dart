import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../superadmin_shell.dart';
import 'shell_account_destinations.dart';
import 'superadmin_tour_scope.dart';

class ShellProfileSummary extends StatelessWidget {
  const ShellProfileSummary({
    super.key,
    required this.onLogout,
    required this.onDestinationSelected,
    required this.compact,
    this.headerProfile,
  });

  final VoidCallback onLogout;
  final ValueChanged<String>? onDestinationSelected;
  final bool compact;
  final SuperadminHeaderProfile? headerProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = headerProfile;
    final items = <CoeloAdminFlyoutItem<String>>[
      for (final destination in shellAccountDestinations)
        CoeloAdminFlyoutItem<String>(
          value: destination.id,
          label: destination.label,
          icon: destination.icon,
          tourAnchorId: 'account-${destination.id}',
        ),
      const CoeloAdminFlyoutItem<String>(
        value: 'logout',
        label: 'Sair',
        icon: Icons.logout,
        startsGroup: true,
        tone: CoeloAdminFlyoutTone.negative,
        tourAnchorId: 'account-logout',
      ),
    ];
    return CoeloAdminFlyout<String>(
      items: items,
      alignPanelToViewportEnd: compact,
      onSelected: (selection) {
        if (selection == 'logout') {
          onLogout();
          return;
        }
        onDestinationSelected?.call(selection);
        final router = GoRouter.maybeOf(context);
        final isDevelopmentPreview =
            router?.routeInformationProvider.value.uri.path.startsWith('/dev/') ?? false;
        final prefix = isDevelopmentPreview ? '/dev' : '';
        router?.go('$prefix/$selection');
      },
      alignmentOffset: const Offset(0, CoeloSpacing.space2),
      builder: (context, controller) {
        SuperadminTourScope.maybeOf(context)?.menus.account = controller;
        return CoeloTourAnchor(
          id: 'account',
          child: Tooltip(
            message: 'Abrir menu do usuário',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('superadmin-profile-menu'),
                onTap: () => controller.isOpen ? controller.close() : controller.open(),
                borderRadius: BorderRadius.circular(CoeloRadius.full),
                overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: CoeloSpacing.space2,
                      vertical: CoeloSpacing.space1,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: profile?.avatarBackgroundColor,
                          foregroundColor: profile == null
                              ? null
                              : (profile.avatarBackgroundColor.computeLuminance() > 0.179
                                    ? Colors.black
                                    : Colors.white),
                          backgroundImage: profile?.avatarImage,
                          child: profile?.avatarImage == null
                              ? Text(profile?.initials.isNotEmpty == true ? profile!.initials : '–')
                              : null,
                        ),
                        if (!compact) ...[
                          const SizedBox(width: CoeloSpacing.space2),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(profile?.name ?? 'Conta', style: theme.textTheme.labelLarge),
                              Text(profile?.role ?? 'Superadmin', style: theme.textTheme.bodySmall),
                            ],
                          ),
                          const SizedBox(width: CoeloSpacing.space1),
                          const Icon(Icons.arrow_drop_down_rounded),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
