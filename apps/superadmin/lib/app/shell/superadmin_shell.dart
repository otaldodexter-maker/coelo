import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/widget_previews.dart';

import '../activity/superadmin_activity.dart';
import '../../features/auth/domain/logout_action.dart';
import '../theme/superadmin_theme_mode_scope.dart';
import 'superadmin_activity_center.dart';
import 'superadmin_bug_report_dialog.dart';
import 'superadmin_notice.dart';

const _sidebarMotionDuration = CoeloMotion.emphasized;
const _sidebarMotionCurve = Cubic(0.4, 0, 0.2, 1);

const _headerHeight = CoeloSpacing.space20 + CoeloSpacing.space2;
const _expandedSidebarWidth = 260.0;
const _collapsedSidebarWidth = CoeloSpacing.space20 + CoeloSpacing.space2;
const _shellGutter = CoeloSpacing.space3;
const _compactProfileMenuWidth = 176.0;
const _compactProfileTriggerWidth = 52.0;
const _coeloMotionCurve = Curves.easeInOut;

class SuperadminShell extends StatefulWidget {
  const SuperadminShell({
    required this.logout,
    this.child,
    this.title = 'Instituições',
    this.subtitle = 'Gerencie as instituições da plataforma.',
    this.actions = const [],
    this.compactActions = const [],
    this.activityController,
    super.key,
  });

  final LogoutAction logout;
  final Widget? child;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> compactActions;
  final SuperadminActivityController? activityController;

  @override
  State<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends State<SuperadminShell> with SingleTickerProviderStateMixin {
  bool _sidebarCollapsed = false;
  late final AnimationController _sidebarController;
  late final SuperadminActivityController _activityController;
  late final bool _ownsActivityController;

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(vsync: this, duration: _sidebarMotionDuration);
    _ownsActivityController = widget.activityController == null;
    _activityController = widget.activityController ?? SuperadminActivityController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion && _sidebarController.isAnimating) {
      _sidebarController.value = _sidebarCollapsed ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    if (_ownsActivityController) {
      _activityController.dispose();
    }
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _toggleSidebar() {
    final collapsed = !_sidebarCollapsed;
    setState(() => _sidebarCollapsed = collapsed);
    final target = collapsed ? 1.0 : 0.0;
    if (_reduceMotion) {
      _sidebarController.value = target;
      return;
    }
    unawaited(_sidebarController.animateTo(target, curve: _sidebarMotionCurve));
  }

  Future<void> _handleLogout() async {
    final result = await widget.logout();
    if (!mounted || result.isSuccess) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message ?? LogoutResult.genericFailureMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final pageBody = widget.child ?? const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
        if (!isDesktop) {
          return Scaffold(
            appBar: _CompactAppBar(
              onLogout: _handleLogout,
              activityController: _activityController,
              currentScreen: widget.title,
            ),
            drawer: Drawer(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(right: Radius.circular(CoeloRadius.xl)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const _BrandHeader(collapsed: false),
                    const _InsetDivider(key: Key('superadmin-brand-divider')),
                    const Expanded(child: _NavigationContent(collapsed: false)),
                  ],
                ),
              ),
            ),
            body: SuperadminNoticeHost(
              child: Column(
                children: [
                  _PageHeader(
                    title: widget.title,
                    subtitle: widget.subtitle,
                    actions: widget.actions,
                    compactActions: widget.compactActions,
                    onLogout: _handleLogout,
                    activityController: _activityController,
                    compact: true,
                  ),
                  const _InsetDivider(key: Key('superadmin-page-divider')),
                  Expanded(child: pageBody),
                ],
              ),
            ),
          );
        }

        final contentSurface = Expanded(
          child: _FloatingSurface(
            key: const Key('superadmin-floating-content'),
            clip: true,
            child: Column(
              children: [
                _PageHeader(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  actions: widget.actions,
                  compactActions: widget.compactActions,
                  onLogout: _handleLogout,
                  activityController: _activityController,
                ),
                const _InsetDivider(key: Key('superadmin-page-divider')),
                Expanded(child: pageBody),
              ],
            ),
          ),
        );
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          body: SuperadminNoticeHost(
            child: Padding(
              padding: const EdgeInsets.all(_shellGutter),
              child: AnimatedBuilder(
                animation: _sidebarController,
                child: contentSurface,
                builder: (context, content) {
                  final sidebarWidth =
                      _expandedSidebarWidth -
                      (_expandedSidebarWidth - _collapsedSidebarWidth) * _sidebarController.value;
                  return Row(
                    children: [
                      SizedBox(
                        width: sidebarWidth + _shellGutter,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SizedBox(
                              key: const Key('superadmin-sidebar'),
                              width: sidebarWidth,
                              child: _FloatingSurface(
                                key: const Key('superadmin-floating-sidebar'),
                                child: _SidebarTransition(
                                  collapsed: _sidebarCollapsed,
                                  reduceMotion: _reduceMotion,
                                ),
                              ),
                            ),
                            Positioned(
                              left: sidebarWidth - CoeloSpacing.space10,
                              top: CoeloSpacing.space5,
                              child: _SidebarToggle(
                                collapsed: _sidebarCollapsed,
                                onPressed: _toggleSidebar,
                              ),
                            ),
                          ],
                        ),
                      ),
                      content!,
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarTransition extends StatelessWidget {
  const _SidebarTransition({required this.collapsed, required this.reduceMotion});

  final bool collapsed;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSwitcher(
        duration: reduceMotion ? Duration.zero : _sidebarMotionDuration,
        switchInCurve: _sidebarMotionCurve,
        switchOutCurve: _sidebarMotionCurve,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.topStart,
          fit: StackFit.expand,
          children: [...previousChildren, ?currentChild],
        ),
        child: SizedBox.expand(
          key: ValueKey(collapsed),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: collapsed ? _collapsedSidebarWidth : null,
              height: double.infinity,
              child: _Sidebar(collapsed: collapsed),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BrandHeader(collapsed: collapsed),
        const _InsetDivider(key: Key('superadmin-brand-divider')),
        Expanded(child: _NavigationContent(collapsed: collapsed)),
      ],
    );
  }
}

class _FloatingSurface extends StatelessWidget {
  const _FloatingSurface({required this.child, this.clip = false, super.key});

  final Widget child;
  final bool clip;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final decoration = BoxDecoration(
      color: colors.surface,
      borderRadius: BorderRadius.circular(CoeloRadius.xl),
      border: Border.all(color: colors.outlineVariant),
      boxShadow: [
        BoxShadow(
          color: colors.shadow.withValues(alpha: 0.06),
          blurRadius: CoeloSpacing.space3,
          offset: const Offset(0, CoeloSpacing.space1),
        ),
      ],
    );
    return DecoratedBox(
      decoration: decoration,
      child: clip
          ? ClipRRect(borderRadius: BorderRadius.circular(CoeloRadius.xl), child: child)
          : child,
    );
  }
}

class _InsetDivider extends StatelessWidget {
  const _InsetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
      child: Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = theme.extension<CoeloVisualColors>()!;
    return SizedBox(
      height: _headerHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? CoeloSpacing.space5 : CoeloSpacing.space4,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showDetails = !collapsed && constraints.maxWidth >= 60;
            return Row(
              mainAxisAlignment: showDetails ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  key: const Key('superadmin-brand-mark'),
                  width: CoeloSize.touchMin,
                  height: CoeloSize.touchMin,
                  padding: const EdgeInsets.all(CoeloSpacing.space2),
                  decoration: BoxDecoration(
                    color: visual.brandMarkBackground,
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    'assets/brand/logo-coelo-white.svg',
                    key: const Key('superadmin-brand-logo'),
                    colorFilter: ColorFilter.mode(visual.brandMarkForeground, BlendMode.srcIn),
                    semanticsLabel: 'Coelo',
                  ),
                ),
                if (showDetails) ...[
                  const SizedBox(width: CoeloSpacing.space3),
                  Expanded(child: Text('Superadmin', style: theme.textTheme.titleMedium)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.collapsed, required this.onPressed});

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IconButton(
      key: const Key('superadmin-sidebar-collapse'),
      tooltip: collapsed ? 'Expandir menu' : 'Recolher menu',
      onPressed: onPressed,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(CoeloSize.touchMin),
        maximumSize: const Size.square(CoeloSize.touchMin),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: CoeloSpacing.space1,
              offset: const Offset(0, CoeloSpacing.spaceHalf),
            ),
          ],
        ),
        child: SizedBox.square(
          dimension: CoeloSpacing.space6,
          child: Icon(
            collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            size: CoeloSpacing.space4,
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationData {
  const _NavigationDestinationData(this.id, this.label, this.icon, {this.active = false});

  final String id;
  final String label;
  final IconData icon;
  final bool active;
}

class _NavigationSectionData {
  const _NavigationSectionData(this.id, this.label, this.icon, this.destinations);

  final String id;
  final String label;
  final IconData icon;
  final List<_NavigationDestinationData> destinations;

  bool get hasActiveDestination => destinations.any((destination) => destination.active);
}

const _navigationSections = <_NavigationSectionData>[
  _NavigationSectionData('structure', 'Estrutura', Icons.account_balance_outlined, [
    _NavigationDestinationData(
      'institutions',
      'Instituições',
      Icons.account_balance_outlined,
      active: true,
    ),
    _NavigationDestinationData('units', 'Unidades', Icons.apartment_outlined),
    _NavigationDestinationData('groups', 'Grupos', Icons.groups_outlined),
  ]),
  _NavigationSectionData('access', 'Acessos', Icons.manage_accounts_outlined, [
    _NavigationDestinationData('people', 'Pessoas', Icons.people_outline),
    _NavigationDestinationData('internal-users', 'Usuários internos', Icons.badge_outlined),
    _NavigationDestinationData(
      'profiles',
      'Perfis e permissões',
      Icons.admin_panel_settings_outlined,
    ),
  ]),
  _NavigationSectionData('operations', 'Operação', Icons.tune_outlined, [
    _NavigationDestinationData('plans', 'Planos', Icons.loyalty_outlined),
    _NavigationDestinationData('import', 'Importações', Icons.upload_file_outlined),
  ]),
  _NavigationSectionData('communication', 'Comunicação', Icons.forum_outlined, [
    _NavigationDestinationData('invites', 'Convites', Icons.mail_outline),
    _NavigationDestinationData('notices', 'Avisos', Icons.campaign_outlined),
  ]),
  _NavigationSectionData('governance', 'Governança', Icons.verified_user_outlined, [
    _NavigationDestinationData('support', 'Suporte', Icons.support_agent_outlined),
    _NavigationDestinationData('audit', 'Auditoria', Icons.security_outlined),
  ]),
];

const _accountDestinations = <_NavigationDestinationData>[
  _NavigationDestinationData('profile', 'Perfil', Icons.person_outline),
  _NavigationDestinationData('settings', 'Configurações', Icons.settings_outlined),
];

class _NavigationContent extends StatefulWidget {
  const _NavigationContent({required this.collapsed});

  final bool collapsed;

  @override
  State<_NavigationContent> createState() => _NavigationContentState();
}

class _NavigationContentState extends State<_NavigationContent> {
  final Set<String> _expandedSections = {'structure'};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space2,
              vertical: CoeloSpacing.space3,
            ),
            children: [
              for (final section in _navigationSections)
                if (widget.collapsed)
                  _CollapsedNavigationSection(section: section)
                else
                  _ExpandedNavigationSection(
                    section: section,
                    expanded: _expandedSections.contains(section.id),
                    onToggle: () => setState(() {
                      if (!_expandedSections.add(section.id)) {
                        _expandedSections.remove(section.id);
                      }
                    }),
                  ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: CoeloSpacing.space2,
            vertical: CoeloSpacing.space2,
          ),
          child: _OnboardingTourButton(collapsed: widget.collapsed),
        ),
        const _InsetDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space3,
          ),
          child: _ThemeModeControl(collapsed: widget.collapsed),
        ),
      ],
    );
  }
}

class _ExpandedNavigationSection extends StatelessWidget {
  const _ExpandedNavigationSection({
    required this.section,
    required this.expanded,
    required this.onToggle,
  });

  final _NavigationSectionData section;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
      child: Column(
        children: [
          _NavigationSectionHeader(section: section, expanded: expanded, onTap: onToggle),
          AnimatedSize(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: CoeloSpacing.space3,
                      top: CoeloSpacing.space1,
                    ),
                    child: Column(
                      children: [
                        for (final destination in section.destinations)
                          _NavigationItem(
                            id: destination.id,
                            icon: destination.icon,
                            label: destination.label,
                            isActive: destination.active,
                            collapsed: false,
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _NavigationSectionHeader extends StatefulWidget {
  const _NavigationSectionHeader({
    required this.section,
    required this.expanded,
    required this.onTap,
  });

  final _NavigationSectionData section;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_NavigationSectionHeader> createState() => _NavigationSectionHeaderState();
}

class _NavigationSectionHeaderState extends State<_NavigationSectionHeader> {
  bool _highlighted = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final active = widget.section.hasActiveDestination;
    final background = active
        ? colors.primary
        : _highlighted
        ? colors.primaryContainer
        : colors.primaryContainer.withValues(alpha: 0);
    final foreground = active
        ? colors.onPrimary
        : _highlighted
        ? colors.primary
        : colors.onSurfaceVariant;
    final content = Container(
      key: Key('superadmin-navigation-section-${widget.section.id}'),
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space3,
        vertical: CoeloSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showDetails = constraints.maxWidth >= 120;
          return Row(
            children: [
              Icon(widget.section.icon, color: foreground, size: CoeloSize.iconMd),
              if (showDetails) ...[
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Text(
                    widget.section.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  widget.expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: foreground,
                  size: CoeloSize.iconSm,
                ),
              ],
            ],
          );
        },
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _highlighted = true),
      onExit: (_) => setState(() => _highlighted = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _highlighted = value),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _CollapsedNavigationSection extends StatelessWidget {
  const _CollapsedNavigationSection({required this.section});

  final _NavigationSectionData section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hoverColor = theme.extension<CoeloActionColors>()?.primaryHover ?? colors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
      child: MenuAnchor(
        alignmentOffset: const Offset(CoeloSpacing.space2, 0),
        style: MenuStyle(
          alignment: AlignmentDirectional.topEnd,
          backgroundColor: WidgetStatePropertyAll(colors.surface),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoeloRadius.lg),
              side: BorderSide(color: colors.outlineVariant),
            ),
          ),
        ),
        menuChildren: [
          SizedBox(
            key: Key('superadmin-navigation-flyout-${section.id}'),
            width: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CoeloSpacing.space4,
                    CoeloSpacing.space3,
                    CoeloSpacing.space4,
                    CoeloSpacing.space2,
                  ),
                  child: Text(section.label, style: Theme.of(context).textTheme.labelLarge),
                ),
                for (final destination in section.destinations)
                  MenuItemButton(
                    key: Key('superadmin-navigation-${destination.id}'),
                    style: _navigationMenuItemStyle(theme, active: destination.active),
                    leadingIcon: Icon(destination.icon),
                    onPressed: () => _handleDestinationTap(context, destination),
                    child: Text(destination.label),
                  ),
              ],
            ),
          ),
        ],
        builder: (context, controller, child) {
          final active = section.hasActiveDestination;
          return Tooltip(
            message: section.label,
            child: IconButton(
              key: Key('superadmin-navigation-section-${section.id}'),
              onPressed: () => controller.isOpen ? controller.close() : controller.open(),
              style:
                  IconButton.styleFrom(
                    minimumSize: const Size.square(CoeloSize.touchMin),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(CoeloRadius.md),
                    ),
                  ).copyWith(
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      final highlighted =
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused);
                      if (active) {
                        return colors.onPrimary;
                      }
                      return highlighted ? colors.primary : colors.onSurfaceVariant;
                    }),
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      final highlighted =
                          states.contains(WidgetState.hovered) ||
                          states.contains(WidgetState.focused);
                      if (active) {
                        return highlighted ? hoverColor : colors.primary;
                      }
                      return highlighted
                          ? colors.primaryContainer
                          : colors.primaryContainer.withValues(alpha: 0);
                    }),
                    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  ),
              icon: Icon(section.icon),
            ),
          );
        },
      ),
    );
  }
}

ButtonStyle _navigationMenuItemStyle(ThemeData theme, {required bool active}) {
  final colors = theme.colorScheme;
  final visual = theme.extension<CoeloVisualColors>()!;
  return MenuItemButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return active || highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      return active || highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
      if (active) {
        return highlighted ? visual.navigationActiveHover : visual.navigationActive;
      }
      return highlighted ? colors.primaryContainer : colors.primaryContainer.withValues(alpha: 0);
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

void _handleDestinationTap(BuildContext context, _NavigationDestinationData destination) {
  if (!destination.active) {
    _showMessage(context, '${destination.label} será implementado em breve.');
  }
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold?.isDrawerOpen ?? false) {
    Navigator.of(context).pop();
  }
}

class _OnboardingTourButton extends StatefulWidget {
  const _OnboardingTourButton({required this.collapsed});

  final bool collapsed;

  @override
  State<_OnboardingTourButton> createState() => _OnboardingTourButtonState();
}

class _OnboardingTourButtonState extends State<_OnboardingTourButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _rotation;
  late final Animation<double> _glow;
  Timer? _restTimer;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 835),
    );
    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 7.3 * math.pi / 180), weight: 20),
      TweenSequenceItem(
        tween: Tween(begin: 7.3 * math.pi / 180, end: -7.3 * math.pi / 180),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -7.3 * math.pi / 180, end: 3.65 * math.pi / 180),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 3.65 * math.pi / 180, end: -3.65 * math.pi / 180),
        weight: 20,
      ),
      TweenSequenceItem(tween: Tween(begin: -3.65 * math.pi / 180, end: 0), weight: 15),
    ]).animate(_animationController);
    _glow = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1, end: 0), weight: 1),
    ]).animate(_animationController);
    _animationController.addStatusListener(_handleAnimationStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion == reduceMotion) {
      return;
    }
    _reduceMotion = reduceMotion;
    _cancelTimer();
    _animationController.stop();
    _animationController.reset();
    if (!reduceMotion) {
      _scheduleNextCycle();
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _scheduleNextCycle();
    }
  }

  void _scheduleNextCycle() {
    _cancelTimer();
    if (_reduceMotion == true) {
      return;
    }
    _restTimer = Timer(const Duration(milliseconds: 3500), () {
      _restTimer = null;
      if (mounted && _reduceMotion != true) {
        _animationController.forward(from: 0);
      }
    });
  }

  void _cancelTimer() {
    _restTimer?.cancel();
    _restTimer = null;
  }

  @override
  void dispose() {
    _cancelTimer();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = theme.extension<CoeloVisualColors>()!;
    final itemStyle = _tourMenuItemStyle(colors);
    return MenuAnchor(
      alignmentOffset: Offset(
        widget.collapsed ? CoeloSize.touchMin + CoeloSpacing.space2 : 252,
        -CoeloSize.touchMin,
      ),
      style: _tourMenuStyle(colors),
      menuChildren: _tourMenuItems(
        itemStyle: itemStyle,
        onScreenSelected: () =>
            _showMessage(context, 'O tour desta tela será implementado na etapa final.'),
        onMenuSelected: () =>
            _showMessage(context, 'O tour do menu será implementado na etapa final.'),
        onCompleteSelected: () =>
            _showMessage(context, 'O tour completo será implementado na etapa final.'),
      ),
      builder: (context, controller, child) {
        final content = Material(
          color: Colors.transparent,
          child: InkWell(
            key: const Key('superadmin-onboarding-tour'),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            borderRadius: BorderRadius.circular(CoeloRadius.md),
            overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
            child: SizedBox(
              width: widget.collapsed ? CoeloSize.touchMin : double.infinity,
              height: CoeloSize.touchMin,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final useCompactLayout = widget.collapsed || constraints.maxWidth < 180;
                  return Row(
                    mainAxisAlignment: useCompactLayout
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      if (!useCompactLayout) const SizedBox(width: CoeloSpacing.space3),
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.rotate(
                            key: const Key('superadmin-onboarding-egg-motion'),
                            angle: _rotation.value,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: CoeloPalette.orange300.withValues(
                                      alpha: 0.38 * _glow.value,
                                    ),
                                    blurRadius: CoeloSpacing.space5 * _glow.value,
                                    spreadRadius: CoeloSpacing.space2 * _glow.value,
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: SizedBox.square(
                          dimension: CoeloSize.iconMd,
                          child: CustomPaint(
                            key: const Key('superadmin-onboarding-egg'),
                            painter: _FlatEggPainter(
                              baseColor: visual.eggBase,
                              ornamentColor: visual.eggOrnament,
                            ),
                          ),
                        ),
                      ),
                      if (!useCompactLayout) ...[
                        const SizedBox(width: CoeloSpacing.space3),
                        Expanded(child: Text('Fazer tour', style: theme.textTheme.labelLarge)),
                        Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
                        const SizedBox(width: CoeloSpacing.space2),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        );
        return Tooltip(message: 'Iniciar onboarding', child: content);
      },
    );
  }
}

MenuStyle _tourMenuStyle(ColorScheme colors) {
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(colors.surface),
    elevation: const WidgetStatePropertyAll(4),
    padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
  );
}

ButtonStyle _tourMenuItemStyle(ColorScheme colors) {
  return MenuItemButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed);
      return highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    iconColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed);
      return highlighted ? colors.primary : colors.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      final highlighted =
          states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused) ||
          states.contains(WidgetState.pressed);
      return highlighted ? colors.primaryContainer : Colors.transparent;
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

List<Widget> _tourMenuItems({
  required ButtonStyle itemStyle,
  required VoidCallback onScreenSelected,
  required VoidCallback onMenuSelected,
  required VoidCallback onCompleteSelected,
}) {
  return [
    _TourMenuItem(
      menuItemKey: const Key('superadmin-tour-screen'),
      style: itemStyle,
      leadingIcon: const Icon(Icons.web_asset_outlined),
      onSelected: onScreenSelected,
      label: 'Tour desta tela',
    ),
    _TourMenuItem(
      menuItemKey: const Key('superadmin-tour-menu'),
      style: itemStyle,
      leadingIcon: const Icon(Icons.menu_open_rounded),
      onSelected: onMenuSelected,
      label: 'Tour do menu',
    ),
    _TourMenuItem(
      menuItemKey: const Key('superadmin-tour-complete'),
      style: itemStyle,
      leadingIcon: const Icon(Icons.play_circle_outline_rounded),
      onSelected: onCompleteSelected,
      label: 'Tour completo',
    ),
  ];
}

class _TourMenuItem extends StatelessWidget {
  const _TourMenuItem({
    required this.menuItemKey,
    required this.style,
    required this.leadingIcon,
    required this.onSelected,
    required this.label,
  });

  final Key menuItemKey;
  final ButtonStyle style;
  final Widget leadingIcon;
  final VoidCallback onSelected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return MenuItemButton(
      key: menuItemKey,
      style: style,
      leadingIcon: leadingIcon,
      onPressed: onSelected,
      child: Text(label),
    );
  }
}

class _FlatEggPainter extends CustomPainter {
  const _FlatEggPainter({required this.baseColor, required this.ornamentColor});

  final Color baseColor;
  final Color ornamentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final egg = Path()
      ..moveTo(size.width * 0.5, 0)
      ..cubicTo(
        size.width * 0.78,
        size.height * 0.08,
        size.width,
        size.height * 0.5,
        size.width * 0.84,
        size.height * 0.82,
      )
      ..cubicTo(
        size.width * 0.7,
        size.height,
        size.width * 0.3,
        size.height,
        size.width * 0.16,
        size.height * 0.82,
      )
      ..cubicTo(0, size.height * 0.5, size.width * 0.22, size.height * 0.08, size.width * 0.5, 0)
      ..close();
    canvas.drawPath(egg, Paint()..color = baseColor);
    canvas
      ..save()
      ..clipPath(egg);
    final wave = Path()
      ..moveTo(-size.width * 0.08, size.height * 0.62)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.45,
        size.width * 0.34,
        size.height * 0.8,
        size.width * 0.58,
        size.height * 0.6,
      )
      ..cubicTo(
        size.width * 0.76,
        size.height * 0.44,
        size.width * 0.9,
        size.height * 0.7,
        size.width * 1.08,
        size.height * 0.54,
      );
    canvas
      ..drawPath(
        wave,
        Paint()
          ..color = ornamentColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, size.height * 0.1)
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
    final dots = Paint()..color = ornamentColor;
    for (final center in [
      Offset(size.width * 0.3, size.height * 0.28),
      Offset(size.width * 0.5, size.height * 0.24),
      Offset(size.width * 0.7, size.height * 0.28),
    ]) {
      canvas.drawCircle(center, size.width * 0.06, dots);
    }
  }

  @override
  bool shouldRepaint(covariant _FlatEggPainter oldDelegate) {
    return baseColor != oldDelegate.baseColor || ornamentColor != oldDelegate.ornamentColor;
  }
}

class _ThemeModeControl extends StatelessWidget {
  const _ThemeModeControl({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final scope = SuperadminThemeModeScope.maybeOf(context);
    final mode = scope?.mode ?? ThemeMode.system;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark =
        mode == ThemeMode.dark || (mode == ThemeMode.system && theme.brightness == Brightness.dark);
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final duration = reduceMotion ? Duration.zero : const Duration(milliseconds: 420);

    void toggle() => scope?.onChanged(isDark ? ThemeMode.light : ThemeMode.dark);

    return SizedBox(
      width: collapsed ? CoeloSize.touchMin : double.infinity,
      height: collapsed ? 80 : CoeloSize.touchMin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useCompactLayout = collapsed || constraints.maxWidth < 180;
          return Tooltip(
            message: isDark ? 'Ativar tema claro' : 'Ativar tema escuro',
            child: Semantics(
              button: true,
              toggled: isDark,
              label: isDark ? 'Tema escuro ativo' : 'Tema claro ativo',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('superadmin-theme-mode-control'),
                  onTap: toggle,
                  borderRadius: BorderRadius.circular(
                    useCompactLayout ? CoeloRadius.full : CoeloRadius.lg,
                  ),
                  overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
                  child: Container(
                    key: const Key('superadmin-theme-mode-surface'),
                    padding: EdgeInsets.symmetric(
                      horizontal: useCompactLayout ? CoeloSpacing.space1 : CoeloSpacing.space3,
                      vertical: CoeloSpacing.space1,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(
                        useCompactLayout ? CoeloRadius.full : CoeloRadius.lg,
                      ),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: useCompactLayout
                        ? _CollapsedCarrotSwitch(isDark: isDark, duration: duration, colors: colors)
                        : Row(
                            children: [
                              Expanded(child: Text('Aparência', style: theme.textTheme.labelLarge)),
                              AnimatedSwitcher(
                                duration: duration,
                                switchInCurve: _coeloMotionCurve,
                                switchOutCurve: _coeloMotionCurve,
                                child: Row(
                                  key: ValueKey(isDark),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                                      size: CoeloSize.iconSm,
                                      color: colors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: CoeloSpacing.space1),
                                    Text(
                                      isDark ? 'Escuro' : 'Claro',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: CoeloSpacing.space2),
                              _HorizontalCarrotSwitch(
                                isDark: isDark,
                                duration: duration,
                                colors: colors,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CollapsedCarrotSwitch extends StatelessWidget {
  const _CollapsedCarrotSwitch({
    required this.isDark,
    required this.duration,
    required this.colors,
  });

  final bool isDark;
  final Duration duration;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: CoeloSpacing.space2,
          left: 0,
          right: 0,
          child: Icon(Icons.light_mode_outlined, size: CoeloSize.iconSm),
        ),
        const Positioned(
          bottom: CoeloSpacing.space2,
          left: 0,
          right: 0,
          child: Icon(Icons.dark_mode_outlined, size: CoeloSize.iconSm),
        ),
        AnimatedAlign(
          duration: duration,
          curve: _coeloMotionCurve,
          alignment: isDark ? Alignment.bottomCenter : Alignment.topCenter,
          child: _CarrotThumb(colors: colors),
        ),
      ],
    );
  }
}

class _HorizontalCarrotSwitch extends StatelessWidget {
  const _HorizontalCarrotSwitch({
    required this.isDark,
    required this.duration,
    required this.colors,
  });

  final bool isDark;
  final Duration duration;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: CoeloSpacing.space16,
      height: CoeloSpacing.space8,
      padding: const EdgeInsets.all(CoeloSpacing.space1),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.full),
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: _coeloMotionCurve,
        alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
        child: _CarrotThumb(colors: colors, size: CoeloSpacing.space6),
      ),
    );
  }
}

class _CarrotThumb extends StatelessWidget {
  const _CarrotThumb({required this.colors, this.size = CoeloSpacing.space8});

  final ColorScheme colors;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visual = theme.extension<CoeloVisualColors>()!;
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(CoeloSpacing.space1),
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: colors.primary.withValues(alpha: 0.12), blurRadius: CoeloSpacing.space1),
        ],
      ),
      child: CustomPaint(
        key: const Key('superadmin-theme-carrot'),
        painter: _FlatCarrotPainter(
          bodyColor: colors.primary,
          markColor: colors.onPrimary,
          leafColor: visual.carrotLeaf,
          leafAccentColor: visual.carrotLeafAccent,
        ),
      ),
    );
  }
}

class _FlatCarrotPainter extends CustomPainter {
  const _FlatCarrotPainter({
    required this.bodyColor,
    required this.markColor,
    required this.leafColor,
    required this.leafAccentColor,
  });

  final Color bodyColor;
  final Color markColor;
  final Color leafColor;
  final Color leafAccentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final carrot = Path()
      ..moveTo(size.width * 0.28, size.height * 0.31)
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.24,
        size.width * 0.68,
        size.height * 0.27,
        size.width * 0.73,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.6,
        size.width * 0.48,
        size.height * 0.85,
        size.width * 0.35,
        size.height * 0.97,
      )
      ..cubicTo(
        size.width * 0.27,
        size.height * 0.72,
        size.width * 0.16,
        size.height * 0.43,
        size.width * 0.28,
        size.height * 0.31,
      )
      ..close();
    canvas.drawPath(carrot, Paint()..color = bodyColor);
    final leftLeaf = Path()
      ..moveTo(size.width * 0.39, size.height * 0.31)
      ..cubicTo(
        size.width * 0.3,
        size.height * 0.2,
        size.width * 0.1,
        size.height * 0.2,
        size.width * 0.12,
        size.height * 0.03,
      )
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.06,
        size.width * 0.43,
        size.height * 0.19,
        size.width * 0.39,
        size.height * 0.31,
      )
      ..close();
    final middleLeaf = Path()
      ..moveTo(size.width * 0.41, size.height * 0.3)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.16,
        size.width * 0.35,
        size.height * 0.05,
        size.width * 0.49,
        0,
      )
      ..cubicTo(
        size.width * 0.57,
        size.height * 0.14,
        size.width * 0.53,
        size.height * 0.25,
        size.width * 0.41,
        size.height * 0.3,
      )
      ..close();
    final rightLeaf = Path()
      ..moveTo(size.width * 0.43, size.height * 0.31)
      ..cubicTo(
        size.width * 0.5,
        size.height * 0.18,
        size.width * 0.64,
        size.height * 0.08,
        size.width * 0.79,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.29,
        size.width * 0.57,
        size.height * 0.36,
        size.width * 0.43,
        size.height * 0.31,
      )
      ..close();
    canvas
      ..drawPath(leftLeaf, Paint()..color = leafColor)
      ..drawPath(middleLeaf, Paint()..color = leafAccentColor)
      ..drawPath(rightLeaf, Paint()..color = leafColor);
    final marks = Paint()
      ..color = markColor
      ..strokeWidth = math.max(1, size.width * 0.055)
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(
        Offset(size.width * 0.38, size.height * 0.44),
        Offset(size.width * 0.58, size.height * 0.41),
        marks,
      )
      ..drawLine(
        Offset(size.width * 0.34, size.height * 0.58),
        Offset(size.width * 0.5, size.height * 0.55),
        marks,
      )
      ..drawLine(
        Offset(size.width * 0.34, size.height * 0.72),
        Offset(size.width * 0.43, size.height * 0.7),
        marks,
      );
  }

  @override
  bool shouldRepaint(covariant _FlatCarrotPainter oldDelegate) {
    return bodyColor != oldDelegate.bodyColor ||
        markColor != oldDelegate.markColor ||
        leafColor != oldDelegate.leafColor ||
        leafAccentColor != oldDelegate.leafAccentColor;
  }
}

class _NavigationItem extends StatefulWidget {
  const _NavigationItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.collapsed,
    this.isActive = false,
  });

  final String id;
  final IconData icon;
  final String label;
  final bool collapsed;
  final bool isActive;

  @override
  State<_NavigationItem> createState() => _NavigationItemState();
}

class _NavigationItemState extends State<_NavigationItem> {
  bool _highlighted = false;

  void _handleTap() {
    final scaffold = Scaffold.maybeOf(context);
    if (!widget.isActive) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${widget.label} será implementado em breve.')));
    }
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visual = theme.extension<CoeloVisualColors>()!;
    final background = widget.isActive
        ? _highlighted
              ? visual.navigationActiveHover
              : visual.navigationActive
        : _highlighted
        ? colors.primaryContainer
        : colors.primaryContainer.withValues(alpha: 0);
    final foreground = widget.isActive
        ? colors.primary
        : _highlighted
        ? colors.primary
        : colors.onSurfaceVariant;
    final content = Container(
      key: Key('superadmin-navigation-${widget.id}'),
      margin: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: widget.collapsed ? CoeloSpacing.space2 : CoeloSpacing.space3,
          vertical: CoeloSpacing.space3,
        ),
        child: Row(
          mainAxisAlignment: widget.collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(widget.icon, color: foreground, size: CoeloSize.iconMd),
            if (!widget.collapsed) ...[
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: foreground,
                    fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _highlighted = true),
      onExit: (_) => setState(() => _highlighted = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (value) => setState(() => _highlighted = value),
        child: Semantics(
          button: true,
          selected: widget.isActive,
          label: widget.label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _handleTap,
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: widget.collapsed ? Tooltip(message: widget.label, child: content) : content,
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompactAppBar({
    required this.onLogout,
    required this.activityController,
    required this.currentScreen,
  });

  final VoidCallback onLogout;
  final SuperadminActivityController activityController;
  final String currentScreen;

  @override
  Size get preferredSize => const Size.fromHeight(CoeloSize.touchMin);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: Builder(
        builder: (context) => IconButton(
          key: const Key('superadmin-mobile-menu'),
          tooltip: 'Abrir menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu),
        ),
      ),
      actionsPadding: const EdgeInsetsDirectional.only(
        top: CoeloSpacing.space1,
        end: CoeloSpacing.space5,
      ),
      actions: [
        _HeaderUtilityActions(activityController: activityController, currentScreen: currentScreen),
        _ProfileSummary(onLogout: onLogout, compact: true),
        const SizedBox(width: CoeloSpacing.space2),
      ],
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    required this.actions,
    required this.compactActions,
    required this.onLogout,
    required this.activityController,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> compactActions;
  final VoidCallback onLogout;
  final SuperadminActivityController activityController;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactProfile = constraints.maxWidth < 900;
        final visibleActions = compact && compactActions.isNotEmpty ? compactActions : actions;
        return SizedBox(
          height: _headerHeight,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space5),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: CoeloSpacing.space1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (visibleActions.isNotEmpty) ...[
                  const SizedBox(width: CoeloSpacing.space4),
                  ...visibleActions.expand(
                    (action) => [action, const SizedBox(width: CoeloSpacing.space2)],
                  ),
                ],
                if (!compact) ...[
                  _HeaderUtilityActions(
                    activityController: activityController,
                    currentScreen: title,
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  _ProfileSummary(onLogout: onLogout, compact: compactProfile),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.onLogout, required this.compact});

  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final standardItemStyle =
        MenuItemButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
        ).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            final highlighted =
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed);
            return highlighted ? colors.primary : colors.onSurfaceVariant;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            final highlighted =
                states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused) ||
                states.contains(WidgetState.pressed);
            return highlighted ? colors.primary : colors.onSurfaceVariant;
          }),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)
                ? colors.primaryContainer
                : Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        );
    final logoutStyle =
        MenuItemButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
        ).copyWith(
          foregroundColor: WidgetStatePropertyAll(colors.error),
          iconColor: WidgetStatePropertyAll(colors.error),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused) ||
                    states.contains(WidgetState.pressed)
                ? colors.errorContainer
                : Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        );
    final menuItems = <Widget>[
      for (final destination in _accountDestinations)
        MenuItemButton(
          key: Key('superadmin-${destination.id}-action'),
          style: standardItemStyle,
          leadingIcon: Icon(destination.icon),
          onPressed: () => _showMessage(
            context,
            destination.id == 'profile'
                ? 'O perfil será implementado em breve.'
                : 'Configurações será implementado em breve.',
          ),
          child: Text(destination.label),
        ),
      const Padding(
        key: Key('superadmin-profile-divider-spacing'),
        padding: EdgeInsets.symmetric(vertical: CoeloSpacing.space1),
        child: _InsetDivider(key: Key('superadmin-profile-divider')),
      ),
      MenuItemButton(
        key: const Key('superadmin-logout-action'),
        style: logoutStyle,
        leadingIcon: const Icon(Icons.logout),
        onPressed: onLogout,
        child: const Text('Sair'),
      ),
    ];
    return MenuAnchor(
      crossAxisUnconstrained: !compact,
      alignmentOffset: Offset(
        compact ? _compactProfileTriggerWidth - _compactProfileMenuWidth : 0,
        CoeloSpacing.space2,
      ),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        elevation: const WidgetStatePropertyAll(4),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
        alignment: compact ? AlignmentDirectional.bottomStart : null,
        minimumSize: compact
            ? const WidgetStatePropertyAll(Size(_compactProfileMenuWidth, 0))
            : null,
        maximumSize: compact
            ? const WidgetStatePropertyAll(Size(_compactProfileMenuWidth, double.infinity))
            : null,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: menuItems,
      builder: (context, controller, child) {
        return Tooltip(
          message: 'Abrir menu do usuário',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('superadmin-profile-menu'),
              onTap: () => controller.isOpen ? controller.close() : controller.open(),
              borderRadius: BorderRadius.circular(CoeloRadius.full),
              overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoeloSpacing.space2,
                  vertical: CoeloSpacing.space1,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircleAvatar(radius: 18, child: Text('OC')),
                    if (!compact) ...[
                      const SizedBox(width: CoeloSpacing.space2),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Owner Coelo', style: theme.textTheme.labelLarge),
                          Text('Superadmin', style: theme.textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(width: CoeloSpacing.space1),
                      const Icon(Icons.arrow_drop_down_rounded),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderUtilityActions extends StatelessWidget {
  const _HeaderUtilityActions({required this.activityController, required this.currentScreen});

  final SuperadminActivityController activityController;
  final String currentScreen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hoverColor = theme.extension<CoeloActionColors>()?.primaryHover ?? colors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          key: const Key('superadmin-report-bug'),
          tooltip: 'Reportar bug',
          onPressed: () => showSuperadminBugReportDialog(
            context,
            currentScreen: currentScreen,
            sections: {
              for (final section in _navigationSections)
                section.label: [
                  ...section.destinations.map((destination) => destination.label),
                  'Outro',
                ],
              'Conta': [..._accountDestinations.map((destination) => destination.label), 'Outros'],
              'Outros': const [],
            },
          ),
          style: _headerUtilityButtonStyle(colors, hoverColor),
          icon: const Icon(Icons.bug_report_outlined),
        ),
        SuperadminActivityCenter(
          controller: activityController,
          buttonStyle: _headerUtilityButtonStyle(colors, hoverColor),
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

void _showMessage(BuildContext context, String message) {
  showSuperadminNotice(context, message);
}

@Preview(name: 'Rodapé da navegação · expandido · light', size: Size(260, 180))
Widget superadminExpandedFooterLightPreview() {
  return _shellFooterPreview(collapsed: false, themeMode: ThemeMode.light);
}

@Preview(name: 'Rodapé da navegação · expandido · dark', size: Size(260, 180))
Widget superadminExpandedFooterDarkPreview() {
  return _shellFooterPreview(collapsed: false, themeMode: ThemeMode.dark);
}

@Preview(name: 'Rodapé da navegação · recolhido · light', size: Size(88, 220))
Widget superadminCollapsedFooterLightPreview() {
  return _shellFooterPreview(collapsed: true, themeMode: ThemeMode.light);
}

@Preview(name: 'Rodapé da navegação · recolhido · dark', size: Size(88, 220))
Widget superadminCollapsedFooterDarkPreview() {
  return _shellFooterPreview(collapsed: true, themeMode: ThemeMode.dark);
}

@Preview(name: 'Tours · submenu · light', size: Size(260, 260))
Widget superadminTourSubmenuLightPreview() {
  return _tourSubmenuPreview(ThemeMode.light);
}

@Preview(name: 'Tours · submenu · dark', size: Size(260, 260))
Widget superadminTourSubmenuDarkPreview() {
  return _tourSubmenuPreview(ThemeMode.dark);
}

Widget _shellFooterPreview({required bool collapsed, required ThemeMode themeMode}) {
  return MaterialApp(
    key: ValueKey((collapsed, themeMode)),
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: themeMode,
    themeAnimationStyle: AnimationStyle.noAnimation,
    builder: (context, child) =>
        MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
    home: SuperadminThemeModeScope(
      mode: themeMode,
      onChanged: _ignoreThemeMode,
      child: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            key: const Key('superadmin-footer-preview'),
            width: collapsed ? _collapsedSidebarWidth : _expandedSidebarWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space2),
                  child: _OnboardingTourButton(collapsed: collapsed),
                ),
                const _InsetDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CoeloSpacing.space2,
                    CoeloSpacing.space2,
                    CoeloSpacing.space2,
                    CoeloSpacing.space3,
                  ),
                  child: _ThemeModeControl(collapsed: collapsed),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _tourSubmenuPreview(ThemeMode themeMode) {
  return MaterialApp(
    key: ValueKey(themeMode),
    debugShowCheckedModeBanner: false,
    theme: CoeloTheme.light,
    darkTheme: CoeloTheme.dark,
    themeMode: themeMode,
    home: const Scaffold(body: Center(child: _TourSubmenuPreviewAnchor())),
  );
}

class _TourSubmenuPreviewAnchor extends StatefulWidget {
  const _TourSubmenuPreviewAnchor();

  @override
  State<_TourSubmenuPreviewAnchor> createState() => _TourSubmenuPreviewAnchorState();
}

class _TourSubmenuPreviewAnchorState extends State<_TourSubmenuPreviewAnchor> {
  final _controller = MenuController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.open();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MenuAnchor(
      controller: _controller,
      style: _tourMenuStyle(colors),
      menuChildren: _tourMenuItems(
        itemStyle: _tourMenuItemStyle(colors),
        onScreenSelected: _ignoreTourSelection,
        onMenuSelected: _ignoreTourSelection,
        onCompleteSelected: _ignoreTourSelection,
      ),
      builder: (context, controller, child) => const SizedBox.square(dimension: CoeloSize.touchMin),
    );
  }
}

void _ignoreThemeMode(ThemeMode mode) {}

void _ignoreTourSelection() {}
