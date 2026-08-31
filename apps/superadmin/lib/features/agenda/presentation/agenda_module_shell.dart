import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../auth/domain/logout_action.dart';

enum AgendaModuleArea { calendar, events, requests, approvals, permissions }

extension AgendaModuleAreaLabel on AgendaModuleArea {
  String get label => switch (this) {
    AgendaModuleArea.calendar => 'Calendário',
    AgendaModuleArea.events => 'Eventos',
    AgendaModuleArea.requests => 'Solicitações',
    AgendaModuleArea.approvals => 'Aprovações',
    AgendaModuleArea.permissions => 'Permissões',
  };
}

/// App-local composition that keeps every Agenda surface inside the canonical
/// Superadmin shell. Navigation between Agenda routes lives in the app router;
/// this widget deliberately does not add a second tab hierarchy.
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
    title: 'Agenda institucional',
    subtitle: 'Acompanhe o calendário, eventos e respostas por contexto.',
    logout: logout,
    currentDestination: 'agenda',
    actions: actions,
    compactActions: compactActions,
    onDestinationSelected: onDestinationSelected,
    child: child,
  );
}
