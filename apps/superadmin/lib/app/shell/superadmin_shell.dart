import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../../features/auth/domain/logout_action.dart';
import '../theme/superadmin_theme_mode_scope.dart';

const _headerHeight = CoeloSpacing.space20 + CoeloSpacing.space2;
const _expandedSidebarWidth = 260.0;
const _collapsedSidebarWidth = CoeloSpacing.space20 + CoeloSpacing.space2;

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
            drawer: const Drawer(child: SafeArea(child: _NavigationContent(collapsed: false))),
            body: Column(
              children: [
                _PageHeader(
                  title: widget.title,
                  subtitle: widget.subtitle,
                  actions: widget.actions,
                  onLogout: _handleLogout,
                  compact: true,
                ),
                const Divider(key: Key('superadmin-page-divider'), height: 1),
                Expanded(child: pageBody),
              ],
            ),
          );
        }

        return Scaffold(
          body: Row(
            children: [
              AnimatedContainer(
                key: const Key('superadmin-sidebar'),
                width: _sidebarCollapsed ? _collapsedSidebarWidth : _expandedSidebarWidth,
                duration: CoeloMotion.short,
                curve: Curves.easeOut,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
                child: _Sidebar(
                  collapsed: _sidebarCollapsed,
                  onToggle: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  children: [
                    _PageHeader(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      actions: widget.actions,
                      onLogout: _handleLogout,
                    ),
                    const Divider(key: Key('superadmin-page-divider'), height: 1),
                    Expanded(child: pageBody),
                  ],
                ),
              ),
            ],
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
            const Divider(key: Key('superadmin-brand-divider'), height: 1),
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

class _NavigationContent extends StatelessWidget {
  const _NavigationContent({required this.collapsed});

  final bool collapsed;

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
              _NavigationItem(
                id: 'institutions',
                icon: Icons.account_balance_outlined,
                selectedIcon: Icons.account_balance,
                label: 'Instituições',
                isActive: true,
                collapsed: collapsed,
              ),
              _NavigationItem(
                id: 'plans',
                icon: Icons.loyalty_outlined,
                label: 'Planos',
                collapsed: collapsed,
              ),
              _NavigationItem(
                id: 'internal-users',
                icon: Icons.badge_outlined,
                label: 'Usuários internos',
                collapsed: collapsed,
              ),
              _NavigationItem(
                id: 'notices',
                icon: Icons.campaign_outlined,
                label: 'Avisos',
                collapsed: collapsed,
              ),
              _NavigationItem(
                id: 'import',
                icon: Icons.upload_file_outlined,
                label: 'Importação',
                collapsed: collapsed,
              ),
              _NavigationItem(
                id: 'support',
                icon: Icons.support_agent_outlined,
                label: 'Suporte',
                collapsed: collapsed,
              ),
              _NavigationItem(
                id: 'audit',
                icon: Icons.security_outlined,
                label: 'Auditoria',
                collapsed: collapsed,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space2,
            CoeloSpacing.space1,
            CoeloSpacing.space2,
            CoeloSpacing.space3,
          ),
          child: _ThemeModeControl(collapsed: collapsed),
        ),
      ],
    );
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
    final size = collapsed ? const Size(48, 96) : const Size(176, 48);

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
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(CoeloSpacing.space2),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.primary.withValues(alpha: 0.25),
                            blurRadius: CoeloSpacing.space2,
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
    this.selectedIcon,
    this.isActive = false,
  });

  final String id;
  final IconData icon;
  final IconData? selectedIcon;
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
        ? colors.primary
        : _highlighted
        ? colors.primaryContainer
        : Colors.transparent;
    final foreground = widget.isActive
        ? colors.onPrimary
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
          Icon(
            widget.isActive ? widget.selectedIcon ?? widget.icon : widget.icon,
            color: foreground,
            size: CoeloSize.iconMd,
          ),
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
    return PopupMenuButton<_ProfileAction>(
      key: const Key('superadmin-profile-menu'),
      tooltip: 'Abrir menu do usuário',
      position: PopupMenuPosition.under,
      borderRadius: BorderRadius.circular(CoeloRadius.full),
      offset: const Offset(0, CoeloSpacing.space2),
      color: colors.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      onSelected: (action) {
        switch (action) {
          case _ProfileAction.profile:
            _showMessage(context, 'O perfil será implementado em breve.');
          case _ProfileAction.settings:
            _showMessage(context, 'Configurações será implementado em breve.');
          case _ProfileAction.logout:
            onLogout();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          key: Key('superadmin-profile-action'),
          value: _ProfileAction.profile,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.person_outline),
            title: Text('Perfil'),
          ),
        ),
        const PopupMenuItem(
          key: Key('superadmin-settings-action'),
          value: _ProfileAction.settings,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.settings_outlined),
            title: Text('Configurações'),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          key: Key('superadmin-logout-action'),
          value: _ProfileAction.logout,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.logout),
            title: Text('Sair'),
          ),
        ),
      ],
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
    );
  }
}

enum _ProfileAction { profile, settings, logout }

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
