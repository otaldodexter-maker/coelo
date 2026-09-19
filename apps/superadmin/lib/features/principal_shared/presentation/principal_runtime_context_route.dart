import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/shell/superadmin_shell.dart';
import '../../staff_access/domain/staff_access_denied.dart';
import '../../staff_access/domain/staff_access_popup_text.dart';
import '../../staff_access/presentation/staff_access_denied_listener.dart';
import '../domain/principal_runtime_context.dart';
import 'principal_global_navigation.dart';

typedef PrincipalRuntimeContextBuilder =
    Widget Function(BuildContext context, PrincipalRuntimeContext runtimeContext);

/// Resolves the authenticated actor's server-authorized Principal context.
///
/// Production routes use this boundary instead of accepting scope IDs from the
/// URL or falling back to preview fixtures. With more than one context the
/// route keeps the first as the active "perfil" and shows the selector of P28
/// (Owner, 11/09/2026): até 5 perfis inline, "Ver todos" em popup e, para o
/// usuário híbrido, ver como Responsável, Funcionário ou ambos.
final class PrincipalRuntimeContextRoute extends StatefulWidget {
  const PrincipalRuntimeContextRoute({
    required this.repository,
    this.builder,
    this.multipleBuilder,
    this.avatarInitials = '?',
    this.avatarImage,
    this.avatarBackgroundColor,
    this.avatarForegroundColor,
    this.onOpenProfile,
    this.onOpenHome,
    this.notificationAction,
    this.onReportProblem,
    super.key,
  });

  final PrincipalRuntimeContextRepository repository;
  final PrincipalRuntimeContextBuilder? builder;
  final Widget Function(BuildContext, List<PrincipalRuntimeContext>)? multipleBuilder;
  final String avatarInitials;
  final ImageProvider? avatarImage;
  final Color? avatarBackgroundColor;
  final Color? avatarForegroundColor;
  final ValueChanged<BuildContext>? onOpenProfile;
  final ValueChanged<BuildContext>? onOpenHome;
  final Widget? notificationAction;
  final ValueChanged<BuildContext>? onReportProblem;

  @override
  State<PrincipalRuntimeContextRoute> createState() => _PrincipalRuntimeContextRouteState();
}

/// A escolha de perfil sobrevive à navegação entre as telas do Principal
/// dentro da mesma sessão; não é autorização, só preferência de filtro.
String? _selectedMembershipId;
Set<String> _selectedMembershipIds = {};

/// ADR 0035 (decisão 5): o popup do contexto bloqueado aparece uma vez por
/// sessão por contexto; depois vale a mensagem curta no seletor.
final Set<String> _blockedPopupShown = {};

/// Limpa a preferência de "ver como" da sessão (só para testes de widget).
@visibleForTesting
void resetPrincipalContextSelectionForTests() {
  _selectedMembershipId = null;
  _selectedMembershipIds = {};
  _blockedPopupShown.clear();
}

/// Popup do contexto bloqueado: texto fixo do servidor (horário, vigência ou
/// afastamento quando o administrador ligou o popup; senão a mensagem
/// genérica), sem dados do contexto, com "Trocar contexto". Nunca decide
/// localmente: só reflete `access_blocked` do servidor.
Future<void> showPrincipalBlockedContextDialog(
  BuildContext context,
  PrincipalRuntimeContext blocked,
) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    key: const Key('principal-context-blocked-dialog'),
    surfaceTintColor: Colors.transparent,
    title: Text(blocked.label),
    content: Text(
      staffAccessBlockedMessage(blocked.accessPopup),
      key: const Key('principal-context-blocked-message'),
    ),
    actions: [
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: const Key('principal-context-blocked-switch'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Trocar contexto'),
        ),
      ),
    ],
  ),
);

final class _PrincipalRuntimeContextRouteState extends State<PrincipalRuntimeContextRoute> {
  late Future<List<PrincipalRuntimeContext>> _load;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant PrincipalRuntimeContextRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) _reload();
  }

  void _reload() => _load = widget.repository.listAvailableContexts();

  bool _sheetOpen = false;

  void _retry() => setState(_reload);

  /// Sessão que já estava dentro quando o horário virou: o servidor negou com
  /// motivo (PT403/STAFF_ACCESS_DENIED); o popup já foi mostrado pelo
  /// listener — aqui só voltamos ao seletor com os contextos recarregados.
  void _onDenied(StaffAccessDenial denial) {
    if (!mounted) return;
    // A folha "Ver como" aberta ainda lista os contextos antigos: fecha.
    if (_sheetOpen) Navigator.of(context).pop();
    setState(() {
      _selectedMembershipId = null;
      _selectedMembershipIds = {};
      if (denial.membershipId != null) _blockedPopupShown.add(denial.membershipId!);
      _reload();
    });
  }

  void _select(PrincipalRuntimeContext selected) =>
      setState(() => _selectedMembershipId = selected.membershipId);

  /// Contexto bloqueado pelo servidor: mostra o popup (uma vez por sessão por
  /// contexto) ou a mensagem curta e volta ao seletor, sem selecionar.
  Future<void> _choose(BuildContext context, PrincipalRuntimeContext chosen) async {
    if (!chosen.accessBlocked) {
      _select(chosen);
      return;
    }
    if (_blockedPopupShown.add(chosen.membershipId)) {
      await showPrincipalBlockedContextDialog(context, chosen);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(staffAccessBlockedMessage(chosen.accessPopup))),
      );
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PrincipalRuntimeContext>>(
    future: _load,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(key: Key('principal-runtime-context-loading')),
          ),
        );
      }
      final error = snapshot.error;
      if (error is PrincipalRuntimeContextUnauthorized) {
        return const Scaffold(
          body: CoeloStatePanel(
            title: 'Contexto indisponível',
            message: 'Seu acesso não possui um vínculo ativo para esta experiência.',
            icon: Icons.lock_outline_rounded,
          ),
        );
      }
      if (error != null) {
        return Scaffold(
          body: CoeloStatePanel(
            title: 'Não foi possível carregar',
            message: 'Não conseguimos validar seu contexto agora.',
            icon: Icons.cloud_off_outlined,
            actionLabel: 'Tentar novamente',
            onAction: _retry,
          ),
        );
      }
      final contexts = snapshot.data ?? const <PrincipalRuntimeContext>[];
      if (contexts.isEmpty) {
        return const Scaffold(
          body: CoeloStatePanel(
            title: 'Nenhum contexto disponível',
            message: 'Peça à instituição para confirmar seu vínculo ativo.',
            icon: Icons.person_search_outlined,
          ),
        );
      }

      final available = contexts.where((item) => !item.accessBlocked).toList();
      if (available.isEmpty) {
        // Todos os vínculos bloqueados agora: nada do contexto é mostrado.
        final first = contexts.first;
        return Scaffold(
          body: CoeloStatePanel(
            key: const Key('principal-context-all-blocked'),
            title: 'Este contexto não está disponível agora',
            message: staffAccessBlockedMessage(first.accessPopup),
            icon: Icons.lock_clock_outlined,
            actionLabel: 'Tentar novamente',
            onAction: _retry,
          ),
        );
      }
      final selected = available.firstWhere(
        (item) => item.membershipId == _selectedMembershipId,
        orElse: () => available.first,
      );
      final chosenContexts = available
          .where((item) => _selectedMembershipIds.contains(item.membershipId))
          .toList();
      final selectedContexts = chosenContexts.isEmpty ? [selected] : chosenContexts;
      // ADR 0041 B9: "ver como" só troca avatar/nome no cabeçalho, sem faixa
      // fixa. Sem escolha explícita o cabeçalho segue a conta autenticada.
      final viewingAs = _selectedMembershipId != null || _selectedMembershipIds.isNotEmpty;
      final scheme = Theme.of(context).colorScheme;
      final viewAsLabel = !viewingAs
          ? null
          : selectedContexts.length > 1
          ? '${selectedContexts.length} perfis'
          : selected.label;
      return StaffAccessDeniedListener(
        onDismissed: _onDenied,
        child: Column(
        children: [
          PrincipalGlobalHeader(
            notificationAction: widget.notificationAction,
            onReportProblem: () => widget.onReportProblem?.call(context),
            keyPrefix: 'principal-context-header',
            avatarInitials: viewingAs ? _initials(selected.label) : widget.avatarInitials,
            avatarImage: viewingAs ? null : widget.avatarImage,
            avatarBackgroundColor: viewingAs
                ? scheme.primaryContainer
                : widget.avatarBackgroundColor,
            avatarForegroundColor: viewingAs
                ? scheme.onPrimaryContainer
                : widget.avatarForegroundColor,
            contextLabel: viewAsLabel,
            onOpenMenu: () {
              final host = Scaffold.maybeOf(context);
              if (host?.hasDrawer ?? false) {
                host!.openDrawer();
              } else {
                widget.onOpenHome?.call(context);
              }
            },
            onOpenNotifications: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Consulte as notificações pelo sino do Superadmin.')),
            ),
            onOpenProfile: () => widget.onOpenProfile?.call(context),
            onChooseContexts: () async {
              final restoreLauncher = SuperadminShell.suppressChatLauncher(context);
              _sheetOpen = true;
              try {
                if (widget.multipleBuilder != null) {
                  final chosen = await showModalBottomSheet<List<PrincipalRuntimeContext>>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Theme.of(context).brightness == Brightness.light
                        ? CoeloPalette.neutral0
                        : Theme.of(context).colorScheme.surface,
                    elevation: 0,
                    builder: (_) => _neutralContextInteraction(
                      context,
                      _MultipleContextSheet(contexts: contexts, selected: selectedContexts),
                    ),
                  );
                  if (chosen != null && chosen.isNotEmpty && mounted) {
                    final allowed = chosen.where((c) => !c.accessBlocked).toList();
                    if (allowed.isEmpty) return;
                    setState(() {
                      _selectedMembershipIds = allowed.map((c) => c.membershipId).toSet();
                      _selectedMembershipId = allowed.first.membershipId;
                    });
                  }
                  return;
                }
                final chosen = await showModalBottomSheet<PrincipalRuntimeContext>(
                  context: context,
                  backgroundColor: Theme.of(context).brightness == Brightness.light
                      ? CoeloPalette.neutral0
                      : Theme.of(context).colorScheme.surface,
                  elevation: 0,
                  showDragHandle: true,
                  builder: (_) => _neutralContextInteraction(
                    context,
                    _ContextSheet(
                      contexts: contexts,
                      selected: selected,
                      hybrid:
                          contexts.any((c) => c.isGuardianRole) &&
                          contexts.any((c) => !c.isGuardianRole),
                    ),
                  ),
                );
                if (chosen != null && context.mounted) await _choose(context, chosen);
              } finally {
                _sheetOpen = false;
                restoreLauncher?.call();
              }
            },
          ),
          Expanded(
            child:
                widget.multipleBuilder?.call(context, selectedContexts) ??
                widget.builder!(context, selected),
          ),
        ],
        ),
      );
    },
  );
}

enum _ViewAs { guardian, staff, both }

/// Barra "Vendo como" com o seletor de perfil (P28). Vive dentro do contêiner
/// do Principal, então funciona hospedada no Superadmin e no app.
final class PrincipalContextSelectorBar extends StatelessWidget {
  const PrincipalContextSelectorBar({
    required this.contexts,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<PrincipalRuntimeContext> contexts;
  final PrincipalRuntimeContext selected;
  final ValueChanged<PrincipalRuntimeContext> onSelect;

  static const inlineLimit = 5;

  bool get _hybrid =>
      contexts.any((item) => item.isGuardianRole) && contexts.any((item) => !item.isGuardianRole);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CoeloSpacing.space4,
          CoeloSpacing.space2,
          CoeloSpacing.space4,
          CoeloSpacing.space1,
        ),
        child: Row(
          children: [
            Icon(Icons.filter_alt_outlined, size: CoeloSize.iconSm, color: scheme.onSurfaceVariant),
            const SizedBox(width: CoeloSpacing.space2),
            Text('Vendo como', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(width: CoeloSpacing.space2),
            Flexible(
              child: ActionChip(
                key: const Key('principal-context-selector'),
                avatar: const Icon(Icons.expand_more_rounded, size: CoeloSize.iconSm),
                label: Text(
                  '${selected.label}${selected.handle == null ? '' : ' · @${selected.handle}'}',
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: () => _openMenu(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMenu(BuildContext context) async {
    final chosen = await showModalBottomSheet<PrincipalRuntimeContext>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.light
          ? CoeloPalette.neutral0
          : Theme.of(context).colorScheme.surface,
      elevation: 0,
      builder: (sheetContext) =>
          _ContextSheet(contexts: contexts, selected: selected, hybrid: _hybrid),
    );
    if (chosen == null || !context.mounted) return;
    if (chosen.accessBlocked) {
      await showPrincipalBlockedContextDialog(context, chosen);
      return;
    }
    onSelect(chosen);
  }
}

final class _ContextSheet extends StatefulWidget {
  const _ContextSheet({required this.contexts, required this.selected, required this.hybrid});

  final List<PrincipalRuntimeContext> contexts;
  final PrincipalRuntimeContext selected;
  final bool hybrid;

  @override
  State<_ContextSheet> createState() => _ContextSheetState();
}

final class _ContextSheetState extends State<_ContextSheet> {
  var _viewAs = _ViewAs.both;

  List<PrincipalRuntimeContext> get _visible => switch (_viewAs) {
    _ViewAs.guardian => widget.contexts.where((item) => item.isGuardianRole).toList(),
    _ViewAs.staff => widget.contexts.where((item) => !item.isGuardianRole).toList(),
    _ViewAs.both => widget.contexts,
  };

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final inline = visible.take(PrincipalContextSelectorBar.inlineLimit).toList();
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            child: Text('Ver como', style: Theme.of(context).textTheme.titleMedium),
          ),
          if (widget.hybrid)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                CoeloSpacing.space4,
                CoeloSpacing.space2,
                CoeloSpacing.space4,
                0,
              ),
              child: SegmentedButton<_ViewAs>(
                key: const Key('principal-context-view-as'),
                segments: const [
                  ButtonSegment(value: _ViewAs.guardian, label: Text('Responsável')),
                  ButtonSegment(value: _ViewAs.staff, label: Text('Funcionário')),
                  ButtonSegment(value: _ViewAs.both, label: Text('Ambos')),
                ],
                selected: {_viewAs},
                onSelectionChanged: (value) => setState(() => _viewAs = value.first),
              ),
            ),
          for (final item in inline) _ContextTile(item: item, selected: widget.selected),
          if (visible.length > inline.length)
            ListTile(
              key: const Key('principal-context-see-all'),
              leading: const Icon(Icons.list_rounded),
              title: Text('Ver todos (${visible.length})'),
              onTap: () async {
                final chosen = await showDialog<PrincipalRuntimeContext>(
                  context: context,
                  builder: (dialogContext) => SimpleDialog(
                    title: const Text('Todos os perfis'),
                    children: [
                      for (final item in visible)
                        _ContextTile(item: item, selected: widget.selected),
                    ],
                  ),
                );
                if (chosen != null && context.mounted) Navigator.of(context).pop(chosen);
              },
            ),
          const SizedBox(height: CoeloSpacing.space2),
        ],
      ),
    );
  }
}

final class _ContextTile extends StatelessWidget {
  const _ContextTile({required this.item, required this.selected});

  final PrincipalRuntimeContext item;
  final PrincipalRuntimeContext selected;

  @override
  Widget build(BuildContext context) {
    final isSelected = item.membershipId == selected.membershipId;
    final scope = [
      if (item.groupName != null) item.unitName,
      if (item.groupName != null || item.unitName != null) item.institutionName,
    ].whereType<String>().join(' · ');
    final blocked = item.accessBlocked;
    return ListTile(
      key: ValueKey('principal-context-${item.membershipId}'),
      selected: false,
      hoverColor: Colors.transparent,
      focusColor: Theme.of(context).colorScheme.primaryContainer,
      leading: CircleAvatar(child: Text(_initials(item.label))),
      title: Text(item.label),
      subtitle: Text(
        blocked
            ? 'Não disponível agora'
            : [if (item.handle != null) '@${item.handle}', if (scope.isNotEmpty) scope].join(' · '),
      ),
      trailing: blocked
          ? Icon(
              Icons.lock_outline_rounded,
              key: ValueKey('principal-context-blocked-${item.membershipId}'),
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            )
          : isSelected
          ? const Icon(Icons.check_rounded)
          : null,
      onTap: () => Navigator.of(context).pop(item),
    );
  }
}

String _initials(String value) {
  final parts = value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

class _MultipleContextSheet extends StatefulWidget {
  const _MultipleContextSheet({required this.contexts, required this.selected});
  final List<PrincipalRuntimeContext> contexts;
  final List<PrincipalRuntimeContext> selected;
  @override
  State<_MultipleContextSheet> createState() => _MultipleContextSheetState();
}

class _MultipleContextSheetState extends State<_MultipleContextSheet> {
  late final Set<String> selected = widget.selected.map((c) => c.membershipId).toSet();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .65,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Text('Ver como', style: Theme.of(context).textTheme.titleLarge),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final item in widget.contexts)
                  CheckboxListTile(
                    key: ValueKey('principal-context-${item.membershipId}'),
                    title: Text(item.label),
                    subtitle: Text(item.handle == null ? item.institutionName : '@${item.handle}'),
                    value: selected.contains(item.membershipId),
                    hoverColor: Colors.transparent,
                    controlAffinity: ListTileControlAffinity.leading,
                    secondary: item.accessBlocked ? const Icon(Icons.lock_outline_rounded) : null,
                    // Bloqueado: nao marca; explica (popup do servidor) e fica no seletor.
                    onChanged: item.accessBlocked
                        ? (_) => showPrincipalBlockedContextDialog(context, item)
                        : (value) => setState(() {
                            if (value == true) {
                              selected.add(item.membershipId);
                            } else {
                              selected.remove(item.membershipId);
                            }
                          }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                const SizedBox(width: CoeloSpacing.space3),
                FilledButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.pop(
                          context,
                          widget.contexts
                              .where((item) => selected.contains(item.membershipId))
                              .toList(),
                        ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _neutralContextInteraction(BuildContext context, Widget child) => Theme(
  data: Theme.of(context).copyWith(
    hoverColor: Colors.transparent,
    highlightColor: Colors.transparent,
    splashColor: Colors.transparent,
    splashFactory: NoSplash.splashFactory,
  ),
  child: child,
);
