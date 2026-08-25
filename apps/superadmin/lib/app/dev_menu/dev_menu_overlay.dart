import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../navigation/superadmin_navigation.dart';

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
    final destinations = _previewDestinations();
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showTrigger)
          Positioned(
            left: CoeloSpacing.space4,
            bottom: CoeloSpacing.space4,
            child: CoeloAdminFlyout<String>(
              items: [
                for (final destination in destinations)
                  CoeloAdminFlyoutItem<String>(
                    value: destination.route,
                    label: destination.label,
                    icon: destination.icon,
                  ),
              ],
              onSelected: onNavigate,
              builder: (context, controller) {
                return FloatingActionButton.small(
                  tooltip: 'Abrir menu de desenvolvimento',
                  onPressed: controller.isOpen ? controller.close : controller.open,
                  child: Image.asset('assets/brand/logo-coelo-orange.png', width: 24, height: 24),
                );
              },
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

List<_PreviewDestinationData> _previewDestinations() {
  final nodes = <CoeloNavigationNode>[];
  void collect(CoeloNavigationNode node) {
    if (node.id != 'home' &&
        node.routeName != null &&
        node.isAvailable(CoeloNavigationEnvironment.development)) {
      nodes.add(node);
    }
    for (final child in node.children) {
      collect(child);
    }
  }

  for (final node in coeloSuperadminNavigation) {
    collect(node);
  }
  return [for (final node in nodes) _PreviewDestinationData(node.label, node.id, node.icon)];
}
