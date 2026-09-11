import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../../../app/shell/superadmin_shell.dart';
import '../../../auth/domain/logout_action.dart';
import '../../data/account_sessions_repository.dart';
import '../user_preferences_controller.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.controller,
    required this.logout,
    this.onDestinationSelected,
    this.sessions,
    super.key,
  });

  final UserPreferencesController controller;
  final LogoutAction logout;
  final ValueChanged<String>? onDestinationSelected;

  /// Sessoes do proprio usuario (account.sessions). Sem repositorio a secao
  /// nao aparece: a composicao de desenvolvimento nao tem sessao real.
  final AccountSessionsRepository? sessions;

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
        if (controller.loadFailed) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(CoeloSpacing.space5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Não foi possível carregar as preferências deste dispositivo.'),
                  const SizedBox(height: CoeloSpacing.space4),
                  FilledButton(
                    onPressed: () => _consumeReportedFailure(controller.load()),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          );
        }
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
                  if (controller.saveFailed) ...[
                    Semantics(
                      liveRegion: true,
                      child: MaterialBanner(
                        forceActionsBelow: true,
                        content: const Text(
                          'Não foi possível salvar as preferências neste dispositivo.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => _consumeReportedFailure(controller.retrySave()),
                            child: const Text('Tentar salvar novamente'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: CoeloSpacing.space5),
                  ],
                  _SettingsCard(
                    title: 'Aparência',
                    description: 'Escolha como o Coelo deve nascer neste dispositivo.',
                    child: SegmentedButton<ThemeMode>(
                      expandedInsets: EdgeInsets.zero,
                      style: ButtonStyle(
                        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
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
                          label: _SettingsThemeLabel(
                            icon: Icons.devices_rounded,
                            label: 'Sistema',
                            labelKey: Key('settings-theme-system'),
                          ),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: _SettingsThemeLabel(
                            icon: Icons.light_mode_outlined,
                            label: 'Claro',
                            labelKey: Key('settings-theme-light'),
                          ),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: _SettingsThemeLabel(
                            icon: Icons.dark_mode_outlined,
                            label: 'Escuro',
                            labelKey: Key('settings-theme-dark'),
                          ),
                        ),
                      ],
                      selected: {controller.preferences.themeMode},
                      onSelectionChanged: (selection) =>
                          _consumeReportedFailure(controller.setThemeMode(selection.single)),
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
                              onChanged: (value) =>
                                  _consumeReportedFailure(controller.setReduceMotion(value)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (sessions != null) ...[
                    const SizedBox(height: CoeloSpacing.space5),
                    _SettingsCard(
                      title: 'Sessões',
                      description:
                          'Dispositivos e navegadores conectados com a sua conta. Encerre as outras sessões se não reconhecer alguma.',
                      child: SettingsSessionsSection(repository: sessions!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

// Keep the approved icon/label composition without the SDK icon slot's fixed
// asymmetric padding, which wraps "Sistema" at the 375 px breakpoint.
class _SettingsThemeLabel extends StatelessWidget {
  const _SettingsThemeLabel({required this.icon, required this.label, required this.labelKey});

  final IconData icon;
  final String label;
  final Key labelKey;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon),
      const SizedBox(width: CoeloSpacing.space2),
      Flexible(child: Text(label, key: labelKey)),
    ],
  );
}

Future<void> _consumeReportedFailure(Future<void> operation) async {
  try {
    await operation;
  } on Object {
    // The controller exposes a sanitized failure state for this screen.
  }
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

/// Lista minima de sessoes (P43 = B): sessao atual em destaque, demais com
/// navegador, IP e ultima atividade, e um unico comando "Encerrar as outras
/// sessoes". ponytail: sem revogacao individual; o GoTrue so expoe scope=others.
class SettingsSessionsSection extends StatefulWidget {
  const SettingsSessionsSection({required this.repository, super.key});

  final AccountSessionsRepository repository;

  @override
  State<SettingsSessionsSection> createState() => _SettingsSessionsSectionState();
}

class _SettingsSessionsSectionState extends State<SettingsSessionsSection> {
  List<AccountSession>? _sessions;
  String? _failure;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final sessions = await widget.repository.list();
      if (!mounted) return;
      setState(() => _sessions = sessions);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _failure = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revokeOthers() async {
    setState(() {
      _busy = true;
      _failure = null;
      _notice = null;
    });
    try {
      await widget.repository.revokeOthers();
      if (!mounted) return;
      _notice = 'As outras sessões foram encerradas.';
      await _load();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _failure = '$error';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = _sessions;
    final others = sessions?.where((s) => !s.isCurrent).length ?? 0;
    return Column(
      key: const Key('settings-sessions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_failure != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              _failure!,
              key: const Key('settings-sessions-failure'),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        if (_notice != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(_notice!, key: const Key('settings-sessions-notice')),
          ),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        if (sessions == null && _busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: CoeloSpacing.space4),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (sessions != null)
          for (final session in sessions) _SessionRow(session: session),
        const SizedBox(height: CoeloSpacing.space3),
        Wrap(
          spacing: CoeloSpacing.space3,
          runSpacing: CoeloSpacing.space2,
          children: [
            OutlinedButton.icon(
              key: const Key('settings-sessions-reload'),
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Atualizar'),
            ),
            FilledButton.tonalIcon(
              key: const Key('settings-sessions-revoke-others'),
              onPressed: _busy || others == 0 ? null : _revokeOthers,
              icon: const Icon(Icons.logout_rounded),
              label: Text(others == 0 ? 'Nenhuma outra sessão' : 'Encerrar as outras sessões ($others)'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session});

  final AccountSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final agent = session.userAgent.isEmpty ? 'Navegador não identificado' : session.userAgent;
    final details = [
      if (session.ip.isNotEmpty) 'IP ${session.ip}',
      if (session.refreshedAt != null) 'ativa em ${_format(session.refreshedAt!.toLocal())}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            session.isCurrent ? Icons.verified_user_outlined : Icons.devices_other_outlined,
            color: session.isCurrent ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.isCurrent ? '$agent (esta sessão)' : agent,
                  style: theme.textTheme.bodyLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _format(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
  }
}
