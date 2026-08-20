import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../../shared/presentation/widgets/superadmin_underline_tabs.dart';
import '../../auth/domain/logout_action.dart';

enum AgendaModuleArea { calendar, events, requests, permissions }

extension AgendaModuleAreaLabel on AgendaModuleArea {
  String get label => switch (this) {
    AgendaModuleArea.calendar => 'Calendário',
    AgendaModuleArea.events => 'Eventos',
    AgendaModuleArea.requests => 'Solicitações',
    AgendaModuleArea.permissions => 'Permissões',
  };
}

/// App-local shell for the development-only Agenda prototype.
final class AgendaModuleShell extends StatelessWidget {
  const AgendaModuleShell({
    required this.logout,
    required this.selectedArea,
    required this.onAreaSelected,
    required this.child,
    this.actions = const [],
    this.compactActions = const [],
    this.onDestinationSelected,
    super.key,
  });

  final LogoutAction logout;
  final AgendaModuleArea selectedArea;
  final ValueChanged<AgendaModuleArea> onAreaSelected;
  final Widget child;
  final List<Widget> actions;
  final List<Widget> compactActions;
  final ValueChanged<String>? onDestinationSelected;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    title: 'Agenda',
    subtitle: 'Acompanhe calendários, eventos, solicitações e permissões.',
    logout: logout,
    currentDestination: 'agenda',
    actions: actions,
    compactActions: compactActions,
    onDestinationSelected: onDestinationSelected,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space4,
            0,
            CoeloSpacing.space4,
            CoeloSpacing.space3,
          ),
          child: SuperadminUnderlineTabs<AgendaModuleArea>(
            tabs: [
              for (final area in AgendaModuleArea.values)
                SuperadminUnderlineTab(value: area, label: area.label),
            ],
            selected: selectedArea,
            onSelected: onAreaSelected,
          ),
        ),
        Expanded(child: child),
      ],
    ),
  );
}
