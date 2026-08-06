import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../router/superadmin_routes.dart';

class DevMenuOverlay extends StatelessWidget {
  const DevMenuOverlay({
    required this.child,
    required this.onNavigate,
    this.showTrigger = true,
    super.key,
  });

  final Widget child;
  final ValueChanged<String> onNavigate;
  final bool showTrigger;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final menuMaxHeight = math
        .max(
          CoeloSize.touchMin * 3,
          mediaQuery.size.height - mediaQuery.padding.vertical - CoeloSpacing.space20,
        )
        .toDouble();
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showTrigger)
          Positioned(
            left: CoeloSpacing.space4,
            bottom: CoeloSpacing.space4,
            child: MenuAnchor(
              builder: (context, controller, child) {
                return FloatingActionButton.small(
                  tooltip: 'Abrir menu de desenvolvimento',
                  onPressed: controller.isOpen ? controller.close : controller.open,
                  child: Image.asset('assets/brand/logo-coelo-orange.png', width: 24, height: 24),
                );
              },
              menuChildren: [
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: menuMaxHeight),
                  child: SingleChildScrollView(
                    key: const Key('superadmin-dev-preview-scroll'),
                    primary: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(
                            CoeloSpacing.space4,
                            CoeloSpacing.space3,
                            CoeloSpacing.space4,
                            CoeloSpacing.space2,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text('Pré-visualizações'),
                          ),
                        ),
                        for (final destination in _previewDestinations)
                          _PreviewMenuItem(
                            icon: destination.icon,
                            label: destination.label,
                            route: destination.route,
                            onNavigate: onNavigate,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PreviewDestinationData {
  const _PreviewDestinationData(this.label, this.route, this.icon);

  final String label;
  final String route;
  final IconData icon;
}

const _previewDestinations = <_PreviewDestinationData>[
  _PreviewDestinationData('Login', SuperadminRoutes.devLogin, Icons.login),
  _PreviewDestinationData(
    'Recuperar senha',
    SuperadminRoutes.devForgotPassword,
    Icons.lock_reset_outlined,
  ),
  _PreviewDestinationData(
    'Redefinir senha',
    SuperadminRoutes.devResetPassword,
    Icons.password_outlined,
  ),
  _PreviewDestinationData('Home', SuperadminRoutes.devHome, Icons.home_outlined),
  _PreviewDestinationData(
    'Instituições',
    SuperadminRoutes.devInstitutions,
    Icons.account_balance_outlined,
  ),
  _PreviewDestinationData('Unidades', SuperadminRoutes.devUnits, Icons.apartment_outlined),
  _PreviewDestinationData('Turmas', SuperadminRoutes.devGroups, Icons.groups_outlined),
  _PreviewDestinationData(
    'Atividades',
    SuperadminRoutes.devActivities,
    Icons.local_activity_outlined,
  ),
  _PreviewDestinationData('Assiduidade', SuperadminRoutes.devAttendance, Icons.fact_check_outlined),
  _PreviewDestinationData(
    'Rotina diária',
    SuperadminRoutes.devDailyRoutine,
    Icons.view_agenda_outlined,
  ),
  _PreviewDestinationData(
    'Perfis de cuidado',
    SuperadminRoutes.devHealthCareProfiles,
    Icons.child_care_outlined,
  ),
  _PreviewDestinationData(
    'Planos de medicação',
    SuperadminRoutes.devHealthMedicationPlans,
    Icons.medication_outlined,
  ),
  _PreviewDestinationData('Pessoas', SuperadminRoutes.devPeople, Icons.people_outline),
  _PreviewDestinationData(
    'Usuários internos',
    SuperadminRoutes.devInternalUsers,
    Icons.badge_outlined,
  ),
  _PreviewDestinationData(
    'Perfis e permissões',
    SuperadminRoutes.devProfiles,
    Icons.admin_panel_settings_outlined,
  ),
  _PreviewDestinationData('Planos', SuperadminRoutes.devPlans, Icons.loyalty_outlined),
  _PreviewDestinationData('Agenda', SuperadminRoutes.devAgenda, Icons.calendar_month_outlined),
  _PreviewDestinationData('Importações', SuperadminRoutes.devImports, Icons.upload_file_outlined),
  _PreviewDestinationData('Convites', SuperadminRoutes.devInvites, Icons.mail_outline),
  _PreviewDestinationData('Avisos', SuperadminRoutes.devNotices, Icons.campaign_outlined),
  _PreviewDestinationData(
    'Conversas',
    SuperadminRoutes.devConversations,
    Icons.chat_bubble_outline,
  ),
  _PreviewDestinationData('Auditoria', SuperadminRoutes.devAudit, Icons.security_outlined),
  _PreviewDestinationData('Catálogo', SuperadminRoutes.devCatalog, Icons.widgets_outlined),
  _PreviewDestinationData(
    'Suporte e implantação',
    SuperadminRoutes.devSupport,
    Icons.support_agent_outlined,
  ),
  _PreviewDestinationData('Perfil', SuperadminRoutes.devProfile, Icons.person_outline),
  _PreviewDestinationData('Configurações', SuperadminRoutes.devSettings, Icons.settings_outlined),
];

class _PreviewMenuItem extends StatelessWidget {
  const _PreviewMenuItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.onNavigate,
  });

  final IconData icon;
  final String label;
  final String route;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      leadingIcon: Icon(icon),
      onPressed: () => onNavigate(route),
      child: Text(label),
    );
  }
}
