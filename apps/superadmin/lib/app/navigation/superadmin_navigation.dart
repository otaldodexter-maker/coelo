import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:go_router/go_router.dart';

enum CoeloNavigationEnvironment { production, development }

typedef CoeloNavigationAvailability = bool Function(CoeloNavigationEnvironment environment);
typedef CoeloNavigationCapabilityCheck = bool Function(String capability);

class CoeloNavigationNode {
  const CoeloNavigationNode({
    required this.id,
    required this.label,
    required this.icon,
    this.routeName,
    this.keywords = const <String>[],
    this.children = const <CoeloNavigationNode>[],
    this.availability = _alwaysAvailable,
    this.capability,
  });

  final String id;
  final String label;
  final IconData icon;
  final String? routeName;
  final List<String> keywords;
  final List<CoeloNavigationNode> children;
  final CoeloNavigationAvailability availability;
  final String? capability;

  bool isAvailable(
    CoeloNavigationEnvironment environment, {
    CoeloNavigationCapabilityCheck? canAccess,
  }) =>
      availability(environment) && (capability == null || (canAccess?.call(capability!) ?? false));

  Iterable<CoeloNavigationNode> get descendants sync* {
    for (final child in children) {
      yield child;
      yield* child.descendants;
    }
  }

  String get searchText => <String>[label, ...keywords].join(' ');
}

bool _alwaysAvailable(CoeloNavigationEnvironment _) => true;
bool _developmentOnly(CoeloNavigationEnvironment environment) =>
    environment == CoeloNavigationEnvironment.development;

const _structuralNavigationIds = <String>{
  'structure',
  'monitoring',
  'access',
  'health-care',
  'operations',
  'communication',
  'governance',
  'principal',
};

CoeloNavigationNode _leaf(
  String id,
  String label,
  IconData icon, {
  String? routeName,
  List<String> keywords = const <String>[],
  CoeloNavigationAvailability availability = _alwaysAvailable,
  String? capability,
}) => CoeloNavigationNode(
  id: id,
  label: label,
  icon: icon,
  routeName: routeName ?? id,
  keywords: keywords,
  availability: availability,
  capability:
      capability ?? ((id.endsWith('-create') || id.endsWith('-publish')) ? '$id.access' : null),
);

CoeloNavigationNode _screen(
  String id,
  String label,
  IconData icon,
  List<CoeloNavigationNode> children, {
  String? routeName,
  List<String> keywords = const <String>[],
  CoeloNavigationAvailability availability = _alwaysAvailable,
}) => CoeloNavigationNode(
  id: id,
  label: label,
  icon: icon,
  routeName: routeName ?? (_structuralNavigationIds.contains(id) ? null : id),
  keywords: keywords,
  children: children,
  availability: availability,
);

final coeloSuperadminNavigation = <CoeloNavigationNode>[
  _leaf('home', 'Home', Icons.home_outlined, routeName: 'home'),
  _screen('structure', 'Estrutura', Icons.account_balance_outlined, [
    _screen('institutions', 'Instituições', Icons.account_balance_outlined, const []),
    _screen('units', 'Unidades', Icons.apartment_outlined, const []),
    _screen('groups', 'Turmas', Icons.groups_outlined, const []),
    _screen('activities', 'Atividades', Icons.local_activity_outlined, [
      _leaf('assessment-entry', 'Lançar avaliações', Icons.edit_note_outlined),
      _leaf('assessment-closing', 'Fechamento de avaliações', Icons.lock_clock_outlined),
    ]),
  ]),
  _screen('monitoring', 'Acompanhamento', Icons.monitor_heart_outlined, [
    _screen('attendance', 'Assiduidade', Icons.fact_check_outlined, [
      _leaf(
        'attendance-create',
        'Nova chamada',
        Icons.add_task_outlined,
        capability: 'attendance.create',
      ),
    ]),
    _screen('daily-routine', 'Rotina diária', Icons.view_agenda_outlined, const []),
    _leaf('students', 'Acompanhamento de alunos', Icons.school_outlined),
  ]),
  _screen('access', 'Acessos', Icons.manage_accounts_outlined, [
    _screen('people', 'Pessoas', Icons.people_outline, const []),
    _screen('safety', 'Segurança da criança', Icons.shield_outlined, const []),
    _screen(
      'internal-users',
      'Usuários internos',
      Icons.badge_outlined,
      const [],
      availability: _developmentOnly,
    ),
    _screen('profiles', 'Perfis e permissões', Icons.admin_panel_settings_outlined, const []),
  ]),
  _screen('health-care', 'Saúde e Cuidado', Icons.health_and_safety_outlined, [
    _screen('health-care-profiles', 'Perfis de cuidado', Icons.child_care_outlined, const []),
    _screen('health-medication-plans', 'Planos de medicação', Icons.medication_outlined, const []),
  ]),
  _screen('operations', 'Operação', Icons.tune_outlined, [
    _screen('plans', 'Planos', Icons.loyalty_outlined, const [], availability: _developmentOnly),
    _screen(
      'meal-plans',
      'Cardápios',
      Icons.restaurant_menu_outlined,
      const [],
      availability: _developmentOnly,
    ),
    _screen('forms', 'Formulários', Icons.dynamic_form_outlined, const []),
    _screen('import', 'Importações', Icons.upload_file_outlined, const []),
    _screen('agenda', 'Agenda', Icons.calendar_month_outlined, [
      _leaf('agenda-create', 'Criar evento', Icons.add_circle_outline_rounded),
      _leaf('agenda-requests', 'Solicitações', Icons.inbox_outlined),
      _leaf('agenda-approvals', 'Aprovações', Icons.approval_outlined),
    ]),
  ]),
  _screen('communication', 'Comunicação', Icons.forum_outlined, [
    _leaf('conversations', 'Conversas', Icons.chat_bubble_outline),
    _screen('invites', 'Convites', Icons.mail_outline, const []),
    _screen('notices', 'Comunicações', Icons.campaign_outlined, const []),
    _screen('circulars', 'Circulares', Icons.description_outlined, [
      _leaf('circular-create', 'Publicar Circular', Icons.note_add_outlined),
    ]),
  ]),
  _screen('governance', 'Governança', Icons.verified_user_outlined, [
    _leaf('support', 'Suporte e implantação', Icons.support_agent_outlined),
    _leaf('audit', 'Auditoria', Icons.security_outlined),
    _leaf('catalog', 'Catálogo', Icons.widgets_outlined),
  ]),
  _screen('principal', 'Coelo (Principal)', Icons.apps_outlined, [
    _screen('principal-happens', 'Acontece', Icons.dynamic_feed_outlined, [
      _leaf('principal-happens-publish', 'Publicar no Acontece', Icons.publish_outlined),
    ]),
    _leaf('principal-for-you', 'Para você', Icons.favorite_border_rounded),
    _screen('principal-moments', 'Momentos', Icons.play_circle_outline_rounded, [
      _leaf('principal-moments-publish', 'Publicar em Momentos', Icons.add_to_photos_outlined),
    ]),
    _screen('principal-now', 'Agora', Icons.auto_awesome_motion_outlined, [
      _leaf('principal-now-publish', 'Publicar no Agora', Icons.add_circle_outline_rounded),
    ]),
    _leaf('principal-chat', 'Chat', Icons.chat_bubble_outline),
    _leaf('principal-profile', 'Perfil', Icons.account_circle_outlined),
  ], availability: _developmentOnly),
];

String normalizeCoeloNavigationText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[áàãâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[íìîï]'), 'i')
    .replaceAll(RegExp('[óòõôö]'), 'o')
    .replaceAll(RegExp('[úùûü]'), 'u')
    .replaceAll('ç', 'c');

List<({CoeloNavigationNode node, List<String> breadcrumb})> searchCoeloNavigation(
  String query, {
  CoeloNavigationEnvironment environment = CoeloNavigationEnvironment.development,
  CoeloNavigationCapabilityCheck? canAccess,
}) {
  final normalized = normalizeCoeloNavigationText(query.trim());
  if (normalized.isEmpty) return const [];
  final results = <({CoeloNavigationNode node, List<String> breadcrumb})>[];
  void visit(CoeloNavigationNode node, List<String> path) {
    if (!node.isAvailable(environment, canAccess: canAccess)) return;
    final next = [...path, node.label];
    if (node.routeName != null &&
        normalizeCoeloNavigationText(node.searchText).contains(normalized)) {
      results.add((node: node, breadcrumb: next));
    }
    for (final child in node.children) {
      visit(child, next);
    }
  }

  for (final node in coeloSuperadminNavigation) {
    visit(node, const []);
  }
  return results;
}

Set<String> coeloNavigationAncestors(String id) {
  final result = <String>{};
  bool visit(CoeloNavigationNode node, List<String> ancestors) {
    if (node.id == id) {
      result.addAll(ancestors);
      return true;
    }
    for (final child in node.children) {
      if (visit(child, [...ancestors, node.id])) {
        return true;
      }
    }
    return false;
  }

  for (final node in coeloSuperadminNavigation) {
    if (visit(node, const [])) {
      break;
    }
  }
  return result;
}

CoeloNavigationNode? coeloNavigationNodeById(String id) {
  CoeloNavigationNode? visit(CoeloNavigationNode node) {
    if (node.id == id) return node;
    for (final child in node.children) {
      final result = visit(child);
      if (result != null) return result;
    }
    return null;
  }

  for (final node in coeloSuperadminNavigation) {
    final result = visit(node);
    if (result != null) return result;
  }
  return null;
}

class CoeloNavigationContent extends StatefulWidget {
  const CoeloNavigationContent({
    required this.collapsed,
    required this.currentDestination,
    required this.onDestinationSelected,
    this.canAccessCapability,
    super.key,
  });

  final bool collapsed;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;
  final CoeloNavigationCapabilityCheck? canAccessCapability;

  @override
  State<CoeloNavigationContent> createState() => _CoeloNavigationContentState();
}

class _CoeloNavigationContentState extends State<CoeloNavigationContent> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Set<String> _expanded = <String>{};
  Set<String> _beforeSearch = <String>{};
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _expanded = coeloNavigationAncestors(widget.currentDestination);
  }

  @override
  void didUpdateWidget(covariant CoeloNavigationContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDestination != widget.currentDestination) {
      _expanded = {..._expanded, ...coeloNavigationAncestors(widget.currentDestination)};
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  CoeloNavigationEnvironment get _environment {
    try {
      return GoRouterState.of(context).uri.path.startsWith('/dev/')
          ? CoeloNavigationEnvironment.development
          : CoeloNavigationEnvironment.production;
    } on GoError {
      return CoeloNavigationEnvironment.production;
    }
  }

  void _onSearchChanged(String value) {
    final hasQuery = value.trim().isNotEmpty;
    setState(() {
      if (hasQuery && !_searchActive) {
        _beforeSearch = {..._expanded};
      }
      if (hasQuery) {
        _expanded = {
          for (final result in searchCoeloNavigation(
            value,
            environment: _environment,
            canAccess: widget.canAccessCapability,
          ))
            ...coeloNavigationAncestors(result.node.id),
        };
      } else {
        _expanded = {..._beforeSearch};
      }
      _searchActive = hasQuery;
    });
  }

  void _activate(CoeloNavigationNode node) {
    if (node.children.isNotEmpty) {
      setState(() {
        if (node.routeName == null && !_expanded.add(node.id)) {
          _expanded.remove(node.id);
        } else {
          _expanded.add(node.id);
        }
      });
      if (node.routeName == null) return;
    }
    widget.onDestinationSelected?.call(node.id);
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) Navigator.of(context).pop();
  }

  void _openCollapsedSearch() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final results = searchCoeloNavigation(
            _searchController.text,
            environment: _environment,
            canAccess: widget.canAccessCapability,
          );
          void onChanged(String value) {
            _onSearchChanged(value);
            setDialogState(() {});
          }

          return CoeloAdminDialogShell(
            dialogKey: const Key('superadmin-navigation-search-dialog'),
            title: 'Buscar na navegação',
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CoeloSearchField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: onChanged,
                  semanticLabel: 'Buscar áreas, telas e ações',
                  hintText: 'Buscar áreas, telas e ações',
                ),
                const SizedBox(height: CoeloSpacing.space3),
                if (_searchController.text.trim().isEmpty)
                  const Text('Pesquise seções, telas e ações da navegação.')
                else if (results.isEmpty)
                  const Text('Nenhum item de navegação encontrado.')
                else
                  for (final result in results)
                    _NavigationTreeItem(
                      node: result.node,
                      level: result.breadcrumb.length - 1,
                      active: result.node.id == widget.currentDestination,
                      breadcrumb: result.breadcrumb.join(' › '),
                      onTap: () {
                        _activate(result.node);
                        Navigator.of(dialogContext).pop();
                      },
                    ),
              ],
            ),
            primaryAction: FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Concluir busca'),
            ),
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.collapsed) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
            child: IconButton(
              key: const Key('superadmin-navigation-search-collapsed'),
              tooltip: 'Buscar na navegação',
              onPressed: _openCollapsedSearch,
              icon: const Icon(Icons.search),
            ),
          ),
          Expanded(
            child: _CollapsedCoeloNavigation(
              currentDestination: widget.currentDestination,
              environment: _environment,
              onDestinationSelected: widget.onDestinationSelected,
              canAccessCapability: widget.canAccessCapability,
            ),
          ),
        ],
      );
    }
    final query = _searchController.text;
    final results = searchCoeloNavigation(
      query,
      environment: _environment,
      canAccess: widget.canAccessCapability,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space1,
          ),
          child: CoeloSearchField(
            key: const Key('superadmin-navigation-search'),
            controller: _searchController,
            focusNode: _searchFocusNode,
            onChanged: _onSearchChanged,
            semanticLabel: 'Buscar na navegação',
            hintText: 'Buscar na navegação',
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('superadmin-navigation-scroll'),
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space2,
              vertical: CoeloSpacing.space2,
            ),
            children: [
              if (query.isNotEmpty)
                if (results.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(CoeloSpacing.space3),
                    child: Text('Nenhum item de navegação encontrado.'),
                  )
                else
                  for (final result in results)
                    _NavigationTreeItem(
                      node: result.node,
                      level: result.breadcrumb.length - 1,
                      active: result.node.id == widget.currentDestination,
                      breadcrumb: result.breadcrumb.join(' › '),
                      onTap: () => _activate(result.node),
                    )
              else ...[
                _NavigationTreeItem(
                  node: coeloSuperadminNavigation.first,
                  level: 0,
                  active: widget.currentDestination == 'home',
                  onTap: () => _activate(coeloSuperadminNavigation.first),
                ),
                for (final node in coeloSuperadminNavigation.skip(1))
                  if (node.isAvailable(_environment, canAccess: widget.canAccessCapability))
                    _buildNode(node, 0),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNode(CoeloNavigationNode node, int level) {
    final open = _expanded.contains(node.id);
    return Column(
      children: [
        _NavigationTreeItem(
          node: node,
          level: level,
          active:
              node.id == widget.currentDestination ||
              coeloNavigationAncestors(widget.currentDestination).contains(node.id),
          expanded: open,
          onTap: () => _activate(node),
        ),
        if (open)
          for (final child in node.children)
            if (child.isAvailable(_environment, canAccess: widget.canAccessCapability))
              _buildNode(child, level + 1),
      ],
    );
  }
}

class _CollapsedCoeloNavigation extends StatelessWidget {
  const _CollapsedCoeloNavigation({
    required this.currentDestination,
    required this.environment,
    required this.onDestinationSelected,
    this.canAccessCapability,
  });

  final String currentDestination;
  final CoeloNavigationEnvironment environment;
  final ValueChanged<String>? onDestinationSelected;
  final CoeloNavigationCapabilityCheck? canAccessCapability;

  @override
  Widget build(BuildContext context) {
    final visible = coeloSuperadminNavigation
        .where((node) => node.isAvailable(environment, canAccess: canAccessCapability))
        .toList(growable: false);
    return ListView(
      key: const Key('superadmin-navigation-scroll'),
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
      children: [
        for (final node in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
            child: node.children.isEmpty
                ? _CollapsedNavigationButton(
                    buttonKey: Key('superadmin-navigation-${node.id}'),
                    node: node,
                    selected: node.id == currentDestination,
                    onPressed: () => onDestinationSelected?.call(node.id),
                  )
                : CoeloAdminFlyout<String>(
                    alignmentOffset: const Offset(
                      CoeloSpacing.space24 - CoeloSpacing.space1,
                      -CoeloSize.touchMin,
                    ),
                    items: [
                      for (final destination in node.descendants.where(
                        (candidate) =>
                            candidate.isAvailable(environment, canAccess: canAccessCapability),
                      ))
                        CoeloAdminFlyoutItem<String>(
                          value: destination.id,
                          label: destination.label,
                          icon: destination.icon,
                          selected: destination.id == currentDestination,
                        ),
                    ],
                    onSelected: (value) => onDestinationSelected?.call(value),
                    builder: (context, controller) => _CollapsedNavigationButton(
                      buttonKey: Key('superadmin-navigation-section-${node.id}'),
                      node: node,
                      selected:
                          node.id == currentDestination ||
                          coeloNavigationAncestors(currentDestination).contains(node.id),
                      onPressed: controller.isOpen ? controller.close : controller.open,
                    ),
                  ),
          ),
      ],
    );
  }
}

class _CollapsedNavigationButton extends StatelessWidget {
  const _CollapsedNavigationButton({
    required this.buttonKey,
    required this.node,
    required this.selected,
    required this.onPressed,
  });

  final CoeloNavigationNode node;
  final bool selected;
  final VoidCallback? onPressed;
  final Key buttonKey;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      key: buttonKey,
      tooltip: node.label,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(CoeloSize.touchMin),
        foregroundColor: selected ? colors.primary : colors.onSurfaceVariant,
        backgroundColor: selected ? colors.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
      ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
      icon: Icon(node.icon),
    );
  }
}

class _NavigationTreeItem extends StatefulWidget {
  const _NavigationTreeItem({
    required this.node,
    required this.level,
    required this.active,
    required this.onTap,
    this.expanded = false,
    this.breadcrumb,
  });

  final CoeloNavigationNode node;
  final int level;
  final bool active;
  final bool expanded;
  final String? breadcrumb;
  final VoidCallback onTap;

  @override
  State<_NavigationTreeItem> createState() => _NavigationTreeItemState();
}

class _NavigationTreeItemState extends State<_NavigationTreeItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selectedSection = widget.level == 0 && widget.active;
    final interactive = _hovered || _focused;
    final foreground = selectedSection
        ? colors.onPrimary
        : widget.active
        ? colors.primary
        : interactive
        ? colors.primary
        : colors.onSurfaceVariant;
    final background = selectedSection
        ? colors.primary
        : widget.active
        ? (widget.level >= 2
              ? colors.primaryContainer.withValues(alpha: 0.72)
              : colors.primaryContainer)
        : interactive
        ? colors.primaryContainer
        : colors.primaryContainer.withValues(alpha: 0);
    final itemKey = Key(
      widget.level == 0 && widget.node.children.isNotEmpty
          ? 'superadmin-navigation-section-${widget.node.id}'
          : 'superadmin-navigation-${widget.node.id}',
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: CoeloSpacing.space2 + (widget.level * CoeloSpacing.space3),
        bottom: CoeloSpacing.space1,
      ),
      child: Semantics(
        label: widget.breadcrumb ?? widget.node.label,
        button: true,
        selected: widget.active,
        expanded: widget.node.children.isEmpty ? null : widget.expanded,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): const ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): const ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              onTap: widget.onTap,
              behavior: HitTestBehavior.opaque,
              child: Container(
                key: itemKey,
                constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoeloSpacing.space2,
                    vertical: CoeloSpacing.space2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        widget.node.icon,
                        color: foreground,
                        size: widget.level == 0 ? CoeloSize.iconMd : CoeloSize.iconSm,
                      ),
                      const SizedBox(width: CoeloSpacing.space2),
                      Expanded(
                        child: Text(
                          widget.node.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: foreground,
                            fontWeight: widget.active || widget.level == 0
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (widget.node.children.isNotEmpty)
                        Icon(
                          widget.expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: foreground,
                          size: CoeloSize.iconSm,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
