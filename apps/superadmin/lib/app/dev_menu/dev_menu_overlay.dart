import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../router/superadmin_routes.dart';

class DevMenuOverlay extends StatelessWidget {
  const DevMenuOverlay({required this.child, required this.onNavigate, super.key});

  final Widget child;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
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
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  CoeloSpacing.space4,
                  CoeloSpacing.space3,
                  CoeloSpacing.space4,
                  CoeloSpacing.space2,
                ),
                child: Text('Pré-visualizações'),
              ),
              _PreviewMenuItem(
                icon: Icons.login,
                label: 'Login',
                route: SuperadminRoutes.devLogin,
                onNavigate: onNavigate,
              ),
              _PreviewMenuItem(
                icon: Icons.lock_reset_outlined,
                label: 'Recuperar senha',
                route: SuperadminRoutes.devForgotPassword,
                onNavigate: onNavigate,
              ),
              _PreviewMenuItem(
                icon: Icons.password_outlined,
                label: 'Redefinir senha',
                route: SuperadminRoutes.devResetPassword,
                onNavigate: onNavigate,
              ),
              _PreviewMenuItem(
                icon: Icons.home_outlined,
                label: 'Home',
                route: SuperadminRoutes.devHome,
                onNavigate: onNavigate,
              ),
              _PreviewMenuItem(
                icon: Icons.apartment_outlined,
                label: 'Instituições',
                route: SuperadminRoutes.devInstitutions,
                onNavigate: onNavigate,
              ),
              _PreviewMenuItem(
                icon: Icons.forum_outlined,
                label: 'Conversas',
                route: SuperadminRoutes.devConversations,
                onNavigate: onNavigate,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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
