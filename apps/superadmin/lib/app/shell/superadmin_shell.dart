import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../features/auth/domain/logout_action.dart';
import '../theme/superadmin_theme_mode_scope.dart';

const _headerHeight = CoeloSpacing.space20 + CoeloSpacing.space2;
const _expandedSidebarWidth = 260.0;
const _collapsedSidebarWidth = CoeloSpacing.space20 + CoeloSpacing.space2;
const _shellGutter = CoeloSpacing.space3;

class SuperadminShell extends StatefulWidget {
  const SuperadminShell({
    required this.logout,
    this.child,
    this.title = 'Instituições',
    this.subtitle = 'Gerencie as instituições da plataforma.',
    this.actions = const [],
    super.key,
  });

  final LogoutAction logout;
  final Widget? child;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  State<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends State<SuperadminShell> {
  bool _sidebarCollapsed = false;

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
            appBar: _CompactAppBar(onLogout: _handleLogout),
            drawer: Drawer(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.horizontal(right: Radius.circular(CoeloRadius.xl)),
              ),
              child: SafeArea(child: _NavigationContent(collapsed: false)),
            ),
            body: Column(
              children: [
                _PageHeader(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  actions: widget.actions,
                  onLogout: _handleLogout,
                  compact: true,
                ),
                const _InsetDivider(key: Key('superadmin-page-divider')),
                Expanded(child: pageBody),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
          body: Padding(
            padding: const EdgeInsets.all(_shellGutter),
            child: Row(
              children: [
                AnimatedContainer(
                  key: const Key('superadmin-sidebar'),
                  width: _sidebarCollapsed ? _collapsedSidebarWidth : _expandedSidebarWidth,
                  duration: CoeloMotion.short,
                  curve: Curves.easeOut,
                  child: _FloatingSurface(
                    key: const Key('superadmin-floating-sidebar'),
                    child: _Sidebar(
                      collapsed: _sidebarCollapsed,
                      onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                    ),
                  ),
                ),
                const SizedBox(width: _shellGutter),
                Expanded(
                  child: _FloatingSurface(
                    key: const Key('superadmin-floating-content'),
                    clip: true,
                    child: Column(
                      children: [
                        _PageHeader(
                          title: widget.title,
                          subtitle: widget.subtitle,
                          actions: widget.actions,
                          onLogout: _handleLogout,
                        ),
                        const _InsetDivider(key: Key('superadmin-page-divider')),
                        Expanded(child: pageBody),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.collapsed, required this.onToggle});

  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            _BrandHeader(collapsed: collapsed),
            const _InsetDivider(key: Key('superadmin-brand-divider')),
            Expanded(child: _NavigationContent(collapsed: collapsed)),
          ],
        ),
        Positioned(
          right: -CoeloSpacing.space2,
          top: CoeloSpacing.space8,
          child: _SidebarToggle(collapsed: collapsed, onPressed: onToggle),
        ),
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
    final colors = theme.colorScheme;
    return SizedBox(
      height: _headerHeight,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: collapsed ? CoeloSpacing.space5 : CoeloSpacing.space4,
        ),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Container(
              key: const Key('superadmin-brand-mark'),
              width: CoeloSize.touchMin,
              height: CoeloSize.touchMin,
              padding: const EdgeInsets.all(CoeloSpacing.space2),
              decoration: BoxDecoration(
                color: colors.onSurface,
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
              ),
              child: _OfficialCoeloMark(
                key: const Key('superadmin-brand-symbol'),
                foregroundColor: colors.surface,
                detailColor: colors.primary,
              ),
            ),
            if (!collapsed) ...[
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(child: Text('Superadmin', style: theme.textTheme.titleMedium)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfficialCoeloMark extends StatelessWidget {
  const _OfficialCoeloMark({required this.foregroundColor, required this.detailColor, super.key});

  final Color foregroundColor;
  final Color detailColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _OfficialCoeloMarkPainter(
        foregroundColor: foregroundColor,
        detailColor: detailColor,
      ),
    );
  }
}

class _OfficialCoeloMarkPainter extends CustomPainter {
  const _OfficialCoeloMarkPainter({required this.foregroundColor, required this.detailColor});

  final Color foregroundColor;
  final Color detailColor;

  @override
  void paint(Canvas canvas, Size size) {
    const sourceWidth = 360.15;
    const sourceHeight = 349.32;
    final scale = math.min(size.width / sourceWidth, size.height / sourceHeight);
    final dx = (size.width - sourceWidth * scale) / 2;
    final dy = (size.height - sourceHeight * scale) / 2;
    canvas
      ..save()
      ..translate(dx, dy)
      ..scale(scale);

    final silhouette = Path()
      ..moveTo(253.55, 186.36)
      ..relativeCubicTo(13.42, -8.18, 27.51, -18.49, 41.37, -30.58)
      ..cubicTo(343.75, 113.15, 371.09, 64.58, 356, 47.29)
      ..relativeCubicTo(-15.09, -17.29, -66.91, 3.26, -115.74, 45.88)
      ..relativeCubicTo(-15.02, 13.11, -28, 26.79, -38.35, 39.94)
      ..relativeCubicTo(-5.54, -15.79, -13.41, -32.93, -23.39, -50.19)
      ..cubicTo(146.08, 26.82, 103.68, -9.36, 83.81, 2.13)
      ..relativeCubicTo(-19.87, 11.49, -9.67, 66.29, 22.77, 122.4)
      ..relativeCubicTo(5.18, 8.96, 10.61, 17.41, 16.17, 25.24)
      ..relativeCubicTo(-62.34, -0.08, -112.36, 24.83, -121.34, 65.13)
      ..relativeCubicTo(-11.51, 51.66, 48.78, 109.05, 134.67, 128.19)
      ..relativeCubicTo(85.88, 19.13, 164.84, -7.23, 176.35, -58.89)
      ..relativeCubicTo(7.66, -34.4, -16.51, -71.33, -58.87, -97.82)
      ..close();
    canvas.drawPath(silhouette, Paint()..color = foregroundColor);

    final details = Paint()..color = detailColor;
    canvas
      ..drawCircle(const Offset(91.62, 236.52), 17.96, details)
      ..drawCircle(const Offset(221.39, 262.97), 14.29, details);
    final nose = Path()
      ..moveTo(154.92, 284.67)
      ..relativeCubicTo(5.7, -6.21, 2.54, -16.26, -5.69, -18.1)
      ..relativeCubicTo(-8.23, -1.83, -15.36, 5.93, -12.83, 13.97)
      ..relativeCubicTo(2.53, 8.04, 12.81, 10.33, 18.52, 4.13)
      ..close();
    canvas
      ..drawPath(nose, details)
      ..restore();
  }

  @override
  bool shouldRepaint(covariant _OfficialCoeloMarkPainter oldDelegate) {
    return oldDelegate.foregroundColor != foregroundColor || oldDelegate.detailColor != detailColor;
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.collapsed, required this.onPressed});

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
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
      child: IconButton(
        key: const Key('superadmin-sidebar-collapse'),
        tooltip: collapsed ? 'Expandir menu' : 'Recolher menu',
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(CoeloSpacing.space6),
          maximumSize: const Size.square(CoeloSpacing.space6),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        iconSize: CoeloSpacing.space4,
        icon: Icon(collapsed ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
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
            duration: CoeloMotion.short,
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
        : Colors.transparent;
    final foreground = active
        ? colors.onPrimary
        : _highlighted
        ? colors.primary
        : colors.onSurfaceVariant;
    final content = AnimatedContainer(
      key: Key('superadmin-navigation-section-${widget.section.id}'),
      duration: CoeloMotion.short,
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space3,
        vertical: CoeloSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        children: [
          Icon(widget.section.icon, color: foreground, size: CoeloSize.iconMd),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Text(
              widget.section.label,
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space1),
      child: MenuAnchor(
        alignmentOffset: const Offset(CoeloSpacing.space2, 0),
        style: MenuStyle(
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
                    style: _navigationMenuItemStyle(colors),
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
              style: IconButton.styleFrom(
                minimumSize: const Size.square(CoeloSize.touchMin),
                foregroundColor: active ? colors.onPrimary : colors.onSurfaceVariant,
                backgroundColor: active ? colors.primary : Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
              ).copyWith(overlayColor: WidgetStatePropertyAll(colors.primaryContainer)),
              icon: Icon(section.icon),
            ),
          );
        },
      ),
    );
  }
}

ButtonStyle _navigationMenuItemStyle(ColorScheme colors) {
  return MenuItemButton.styleFrom(
    foregroundColor: colors.onSurfaceVariant,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
  ).copyWith(
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primary
          : colors.onSurfaceVariant;
    }),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
          ? colors.primaryContainer
          : Colors.transparent;
    }),
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
    final size = collapsed ? const Size(40, 80) : const Size(160, 40);

    void toggle() => scope?.onChanged(isDark ? ThemeMode.light : ThemeMode.dark);

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
            borderRadius: BorderRadius.circular(CoeloRadius.full),
            overlayColor: WidgetStatePropertyAll(colors.primaryContainer),
            child: AnimatedContainer(
              duration: CoeloMotion.standard,
              width: size.width,
              height: size.height,
              padding: const EdgeInsets.all(CoeloSpacing.space1),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(CoeloRadius.full),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Stack(
                children: [
                  if (collapsed) ...[
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
                  ] else ...[
                    const Positioned(
                      left: CoeloSpacing.space2,
                      top: 0,
                      bottom: 0,
                      child: Icon(Icons.light_mode_outlined, size: CoeloSize.iconSm),
                    ),
                    const Positioned(
                      right: CoeloSpacing.space2,
                      top: 0,
                      bottom: 0,
                      child: Icon(Icons.dark_mode_outlined, size: CoeloSize.iconSm),
                    ),
                  ],
                  AnimatedAlign(
                    duration: CoeloMotion.standard,
                    curve: Curves.easeOutCubic,
                    alignment: collapsed
                        ? (isDark ? Alignment.bottomCenter : Alignment.topCenter)
                        : (isDark ? Alignment.centerRight : Alignment.centerLeft),
                    child: Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(CoeloSpacing.space1),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.12),
                            blurRadius: CoeloSpacing.space1,
                          ),
                        ],
                      ),
                      child: _OfficialCoeloMark(
                        foregroundColor: colors.onPrimary,
                        detailColor: colors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
    final background = widget.isActive
        ? Colors.transparent
        : _highlighted
        ? colors.primaryContainer
        : Colors.transparent;
    final foreground = widget.isActive
        ? colors.primary
        : _highlighted
        ? colors.primary
        : colors.onSurfaceVariant;
    final content = AnimatedContainer(
      key: Key('superadmin-navigation-${widget.id}'),
      duration: CoeloMotion.short,
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: CoeloSpacing.spaceHalf),
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? CoeloSpacing.space2 : CoeloSpacing.space3,
        vertical: CoeloSpacing.space3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
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
  const _CompactAppBar({required this.onLogout});

  final VoidCallback onLogout;

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
      actions: [
        const _HeaderUtilityActions(),
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
    required this.onLogout,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final showHeaderActions =
            !compact || constraints.maxWidth >= CoeloBreakpoints.medium.minWidth;
        final compactProfile = constraints.maxWidth < 900;
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
                if (showHeaderActions && actions.isNotEmpty) ...[
                  const SizedBox(width: CoeloSpacing.space4),
                  ...actions.expand(
                    (action) => [action, const SizedBox(width: CoeloSpacing.space2)],
                  ),
                ],
                if (!compact) ...[
                  const _HeaderUtilityActions(),
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
          foregroundColor: colors.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                ? colors.primaryContainer
                : Colors.transparent;
          }),
        );
    final logoutStyle =
        MenuItemButton.styleFrom(
          foregroundColor: colors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.md)),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                ? colors.errorContainer
                : Colors.transparent;
          }),
        );
    return MenuAnchor(
      alignmentOffset: const Offset(0, CoeloSpacing.space2),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        elevation: const WidgetStatePropertyAll(4),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(CoeloSpacing.space2)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          key: const Key('superadmin-profile-action'),
          style: standardItemStyle,
          leadingIcon: const Icon(Icons.person_outline),
          onPressed: () => _showMessage(context, 'O perfil será implementado em breve.'),
          child: const Text('Perfil'),
        ),
        MenuItemButton(
          key: const Key('superadmin-settings-action'),
          style: standardItemStyle,
          leadingIcon: const Icon(Icons.settings_outlined),
          onPressed: () => _showMessage(context, 'Configurações será implementado em breve.'),
          child: const Text('Configurações'),
        ),
        const _InsetDivider(),
        MenuItemButton(
          key: const Key('superadmin-logout-action'),
          style: logoutStyle,
          leadingIcon: const Icon(Icons.logout),
          onPressed: onLogout,
          child: const Text('Sair'),
        ),
      ],
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
  const _HeaderUtilityActions();

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
          onPressed: () => _showMessage(context, 'O reporte de bugs será implementado em breve.'),
          style: _headerUtilityButtonStyle(colors, hoverColor),
          icon: const Icon(Icons.bug_report_outlined),
        ),
        IconButton(
          key: const Key('superadmin-notifications'),
          tooltip: 'Notificações',
          onPressed: () => _showMessage(context, 'As notificações serão implementadas em breve.'),
          style: _headerUtilityButtonStyle(colors, hoverColor),
          icon: const Icon(Icons.notifications_none_rounded),
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
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
