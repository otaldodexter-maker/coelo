import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../features/support/domain/support_ticket.dart';
import '../../activity/superadmin_activity.dart';
import '../../navigation/superadmin_navigation.dart';
import '../superadmin_activity_center.dart';
import '../superadmin_bug_report_dialog.dart';
import '../superadmin_notice.dart';
import '../superadmin_shell.dart';
import 'shell_account_destinations.dart';

class ShellHeaderUtilityActions extends StatefulWidget {
  const ShellHeaderUtilityActions({
    super.key,
    required this.activityController,
    required this.currentScreen,
    this.onBugReportSubmitted,
  });

  final SuperadminActivityController activityController;
  final String currentScreen;
  final SuperadminBugReportSubmit? onBugReportSubmitted;

  @override
  State<ShellHeaderUtilityActions> createState() => ShellHeaderUtilityActionsState();
}

class ShellHeaderUtilityActionsState extends State<ShellHeaderUtilityActions> {
  DialogRoute<SupportReportDraft>? _reportRoute;
  var _reportGeneration = 0;

  void _invalidateReport() {
    _reportGeneration++;
    final route = _reportRoute;
    _reportRoute = null;
    if (route != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (route.isActive) route.navigator?.removeRoute(route);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ShellHeaderUtilityActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentScreen != widget.currentScreen ||
        oldWidget.onBugReportSubmitted != widget.onBugReportSubmitted) {
      _invalidateReport();
    }
  }

  @override
  void dispose() {
    _invalidateReport();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hoverColor = theme.extension<CoeloActionColors>()?.primaryHover ?? colors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // MENU/MENU-M (decisão do Owner de 10/09/2026): o botão de Bug nunca é
        // omitido. Sem canal de envio, o relato não é descartado em silêncio:
        // a tela avisa que o envio ainda não está conectado.
        CoeloTourAnchor(
          id: 'report-bug',
          child: IconButton(
            key: const Key('superadmin-report-bug'),
            tooltip: 'Reportar bug',
            onPressed: () async {
              if (!mounted || _reportRoute != null) return;
              final generation = _reportGeneration;
              final submit = widget.onBugReportSubmitted;
              bool isCurrent() => mounted && generation == _reportGeneration;
              DialogRoute<SupportReportDraft>? openedRoute;
              final draft = await showSuperadminBugReportDialog(
                context,
                currentScreen: widget.currentScreen,
                isContextCurrent: isCurrent,
                onRouteCreated: (route) {
                  openedRoute = route;
                  _reportRoute = route;
                },
                sections: {
                  for (final section in coeloSuperadminNavigation.where(
                    (node) => node.children.isNotEmpty,
                  ))
                    section.label: [...section.children.map((node) => node.label), 'Outro'],
                  'Conta': [
                    ...shellAccountDestinations.map((destination) => destination.label),
                    'Outros',
                  ],
                  'Outros': const [],
                },
              );
              if (identical(_reportRoute, openedRoute)) _reportRoute = null;
              if (draft == null || !isCurrent()) {
                return;
              }
              if (submit == null) {
                if (!context.mounted) return;
                showSuperadminNotice(
                  context,
                  'O envio de relatos ainda não está conectado nesta tela.',
                  icon: Icons.info_outline_rounded,
                );
                return;
              }
              try {
                await submit(draft);
              } on Object {
                if (!context.mounted || !isCurrent()) return;
                showSuperadminNotice(
                  context,
                  'Não foi possível enviar o relato. Tente novamente.',
                  icon: Icons.error_outline_rounded,
                );
                return;
              }
              if (!context.mounted || !isCurrent()) return;
              showSuperadminNotice(
                context,
                'Relato enviado com sucesso.',
                icon: Icons.check_circle_outline_rounded,
              );
            },
            style: _headerUtilityButtonStyle(colors, hoverColor),
            icon: const Icon(Icons.bug_report_outlined),
          ),
        ),
        CoeloTourAnchor(
          id: 'notifications',
          child: SuperadminActivityCenter(
            controller: widget.activityController,
            buttonStyle: _headerUtilityButtonStyle(colors, hoverColor),
          ),
        ),
      ],
    );
  }
}

ButtonStyle _headerUtilityButtonStyle(ColorScheme colors, Color hoverColor) {
  return IconButton.styleFrom(
    foregroundColor: colors.onSurfaceVariant,
    shape: const CircleBorder(),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed)) {
        return hoverColor;
      }
      return colors.onSurfaceVariant;
    }),
    overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
  );
}
