import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../user_preferences_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.controller,
    required this.logout,
    this.onDestinationSelected,
    super.key,
  });

  final UserPreferencesController controller;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  @override
  Widget build(BuildContext context) => SuperadminShell(
    logout: logout,
    title: 'Configurações',
    subtitle: 'Personalize a aparência e a acessibilidade do Superadmin.',
    currentDestination: 'settings',
    onDestinationSelected: onDestinationSelected,
    child: ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (!controller.loaded) return const Center(child: CircularProgressIndicator());
        return SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space5),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingsCard(
                    title: 'Aparência',
                    description: 'Escolha como o Coelo deve nascer neste dispositivo.',
                    child: SegmentedButton<ThemeMode>(
                      expandedInsets: EdgeInsets.zero,
                      style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected) ||
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused)) {
                            return Theme.of(context).colorScheme.primaryContainer;
                          }
                          return Theme.of(context).colorScheme.surface;
                        }),
                        foregroundColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected) ||
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused)) {
                            return Theme.of(context).colorScheme.primary;
                          }
                          return Theme.of(context).colorScheme.onSurfaceVariant;
                        }),
                        iconColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected) ||
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused)) {
                            return Theme.of(context).colorScheme.primary;
                          }
                          return Theme.of(context).colorScheme.onSurfaceVariant;
                        }),
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                        minimumSize: const WidgetStatePropertyAll(
                          Size(CoeloSize.touchMin, CoeloSize.touchMin),
                        ),
                        side: WidgetStatePropertyAll(
                          BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.devices_rounded),
                          label: Text('Sistema', key: Key('settings-theme-system')),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined),
                          label: Text('Claro', key: Key('settings-theme-light')),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined),
                          label: Text('Escuro', key: Key('settings-theme-dark')),
                        ),
                      ],
                      selected: {controller.preferences.themeMode},
                      onSelectionChanged: (selection) => controller.setThemeMode(selection.single),
                      showSelectedIcon: false,
                    ),
                  ),
                  const SizedBox(height: CoeloSpacing.space5),
                  _SettingsCard(
                    title: 'Acessibilidade',
                    description: 'Reduza transições e movimentos não essenciais.',
                    child: Semantics(
                      key: const Key('settings-reduce-motion-row'),
                      container: true,
                      label: 'Reduzir animações',
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Reduzir animações',
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  const SizedBox(height: CoeloSpacing.spaceHalf),
                                  Text(
                                    'Também respeitamos a preferência de movimento do sistema.',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: CoeloSpacing.space4),
                            Switch.adaptive(
                              key: const Key('settings-reduce-motion'),
                              value: controller.preferences.reduceMotion,
                              onChanged: controller.setReduceMotion,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.description, required this.child});

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: CoeloSpacing.space5),
          child,
        ],
      ),
    ),
  );
}
