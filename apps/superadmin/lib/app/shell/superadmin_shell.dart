import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:go_router/go_router.dart';

import '../activity/superadmin_activity.dart';
import '../brand/superadmin_brand_mark.dart';
import '../navigation/superadmin_navigation.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import '../../features/support/domain/support_ticket.dart';
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
const _compactProfileMenuWidth = 236.0;
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
    this.currentDestination = 'institutions',
    this.onDestinationSelected,
    this.onOpenConversations,
    this.chatUnreadCountLoader,
    this.onBugReportSubmitted,
    this.showChatLauncher = true,
    this.chatLauncherBottomInset = 0,
    this.isHost = false,
    super.key,
  }) : assert(chatLauncherBottomInset >= 0);

  const SuperadminShell.host({
    required this.logout,
    required this.child,
    required this.currentDestination,
    required this.onDestinationSelected,
    this.activityController,
    this.onBugReportSubmitted,
    this.chatUnreadCountLoader,
    super.key,
  }) : title = '',
       subtitle = '',
       actions = const [],
       compactActions = const [],
       onOpenConversations = null,
       showChatLauncher = true,
       chatLauncherBottomInset = 0,
       isHost = true;

  final LogoutAction logout;
  final Widget? child;
  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> compactActions;
  final SuperadminActivityController? activityController;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;
  final VoidCallback? onOpenConversations;
  final Future<int> Function()? chatUnreadCountLoader;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final bool showChatLauncher;
  final double chatLauncherBottomInset;
  final bool isHost;

  @override
  State<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends State<SuperadminShell> with TickerProviderStateMixin {
  bool _sidebarCollapsed = false;
  bool _drawerOpen = false;
  late final AnimationController _sidebarController;
  late final SuperadminActivityController _activityController;
  late final SuperadminChatLauncherPositionController _chatLauncherPositionController;
  late final bool _ownsActivityController;
  double _embeddedChatLauncherBottomInset = 0;

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(vsync: this, duration: _sidebarMotionDuration);
    _ownsActivityController = widget.activityController == null;
    _activityController = widget.activityController ?? SuperadminActivityController();
    _chatLauncherPositionController = SuperadminChatLauncherPositionController(persist: true);
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
    _chatLauncherPositionController.dispose();
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  void _handleEmbeddedChatLauncherBottomInset(double inset) {
    if ((_embeddedChatLauncherBottomInset - inset).abs() < .5) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || (_embeddedChatLauncherBottomInset - inset).abs() < .5) return;
      setState(() => _embeddedChatLauncherBottomInset = inset);
    });
  }

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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => CoeloAdminDialogShell(
        dialogKey: const Key('superadmin-logout-dialog'),
        title: 'Sair do Coelo?',
        body: const Text('Sua sessão será encerrada neste dispositivo.'),
        secondaryAction: OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        primaryAction: FilledButton(
          key: const Key('superadmin-logout-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          child: const Text('Sair'),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await _performLogout();
  }

  Future<void> _performLogout() async {
    final result = await widget.logout();
    if (result.isSuccess) {
      _chatLauncherPositionController.reset();
    }
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
    final hostScope = _SuperadminShellHostScope.maybeOf(context);
    if (!widget.isHost && hostScope != null) {
      hostScope.onChatLauncherBottomInsetChanged(
        widget.showChatLauncher ? widget.chatLauncherBottomInset : 0,
      );
      return _buildEmbeddedPage(pageBody, hostScope);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
        if (!isDesktop) {
          if (widget.isHost) {
            return _withChatLauncher(
              Scaffold(
                backgroundColor: Theme.of(context).colorScheme.surface,
                appBar: _CompactAppBar(
                  onLogout: _handleLogout,
                  onDestinationSelected: widget.onDestinationSelected,
                  activityController: _activityController,
                  currentScreen: widget.currentDestination,
                  onBugReportSubmitted: widget.onBugReportSubmitted,
                ),
                onDrawerChanged: (open) => setState(() => _drawerOpen = open),
                drawer: Drawer(
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(right: Radius.circular(CoeloRadius.xl)),
                  ),
                  child: SafeArea(
                    child: Column(
                      children: [
                        _BrandHeader(
                          collapsed: false,
                          currentDestination: widget.currentDestination,
                          onDestinationSelected: widget.onDestinationSelected,
                        ),
                        const _InsetDivider(key: Key('superadmin-brand-divider')),
                        Expanded(
                          child: CoeloNavigationContent(
                            collapsed: false,
                            currentDestination: widget.currentDestination,
                            onDestinationSelected: widget.onDestinationSelected,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                body: SuperadminNoticeHost(child: _hostedContent(pageBody, isDesktop: false)),
              ),
              onDestinationSelected: widget.onDestinationSelected,
              positionController: _chatLauncherPositionController,
              reservedBottomInset: MediaQuery.paddingOf(context).bottom,
            );
          }
          return _withChatLauncher(
            Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              appBar: _CompactAppBar(
                onLogout: _handleLogout,
                onDestinationSelected: widget.onDestinationSelected,
                activityController: _activityController,
                currentScreen: widget.title,
                onBugReportSubmitted: widget.onBugReportSubmitted,
              ),
              onDrawerChanged: (open) => setState(() => _drawerOpen = open),
              drawer: Drawer(
                backgroundColor: Theme.of(context).colorScheme.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(CoeloRadius.xl)),
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      _BrandHeader(
                        collapsed: false,
                        currentDestination: widget.currentDestination,
                        onDestinationSelected: widget.onDestinationSelected,
                      ),
                      const _InsetDivider(key: Key('superadmin-brand-divider')),
                      Expanded(
                        child: CoeloNavigationContent(
                          collapsed: false,
                          currentDestination: widget.currentDestination,
                          onDestinationSelected: widget.onDestinationSelected,
                        ),
                      ),
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
                      onDestinationSelected: widget.onDestinationSelected,
                      activityController: _activityController,
                      compact: true,
                      onBugReportSubmitted: widget.onBugReportSubmitted,
                    ),
                    const _InsetDivider(key: Key('superadmin-page-divider')),
                    Expanded(child: pageBody),
                  ],
                ),
              ),
            ),
            reservedBottomInset: MediaQuery.paddingOf(context).bottom,
          );
        }

        final contentSurface = Expanded(
          child: widget.isHost
              ? _hostedContent(pageBody, isDesktop: true)
              : _FloatingSurface(
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
                        onDestinationSelected: widget.onDestinationSelected,
                        activityController: _activityController,
                        onBugReportSubmitted: widget.onBugReportSubmitted,
                      ),
                      const _InsetDivider(key: Key('superadmin-page-divider')),
                      Expanded(child: pageBody),
                    ],
                  ),
                ),
        );
        return _withChatLauncher(
          Scaffold(
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
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: sidebarWidth + _shellGutter,
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: SizedBox(
                                  key: const Key('superadmin-sidebar'),
                                  width: sidebarWidth,
                                  height: double.infinity,
                                  child: _FloatingSurface(
                                    key: const Key('superadmin-floating-sidebar'),
                                    child: _SidebarTransition(
                                      progress: _sidebarController.value,
                                      currentDestination: widget.currentDestination,
                                      onDestinationSelected: widget.onDestinationSelected,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            content!,
                          ],
                        ),
                        Positioned(
                          left: sidebarWidth - CoeloSpacing.space6 - CoeloSpacing.space1,
                          top: CoeloSpacing.space5,
                          child: _SidebarToggle(
                            collapsed: _sidebarCollapsed,
                            progress: _sidebarController.value,
                            onPressed: _toggleSidebar,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _hostedContent(Widget child, {required bool isDesktop}) {
    return _SuperadminShellHostScope(
      isDesktop: isDesktop,
      onDestinationSelected: widget.onDestinationSelected!,
      chatLauncherPositionController: _chatLauncherPositionController,
      onChatLauncherBottomInsetChanged: _handleEmbeddedChatLauncherBottomInset,
      child: KeyedSubtree(key: const Key('superadmin-content-transition'), child: child),
    );
  }

  Widget _buildEmbeddedPage(Widget pageBody, _SuperadminShellHostScope hostScope) {
    final content = hostScope.isDesktop
        ? _FloatingSurface(
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
                  onDestinationSelected: hostScope.onDestinationSelected,
                  activityController: _activityController,
                  onBugReportSubmitted: widget.onBugReportSubmitted,
                ),
                const _InsetDivider(key: Key('superadmin-page-divider')),
                Expanded(child: pageBody),
              ],
            ),
          )
        : Column(
            children: [
              _PageHeader(
                title: widget.title,
                subtitle: widget.subtitle,
                actions: widget.actions,
                compactActions: widget.compactActions,
                onLogout: _handleLogout,
                onDestinationSelected: hostScope.onDestinationSelected,
                activityController: _activityController,
                compact: true,
                onBugReportSubmitted: widget.onBugReportSubmitted,
              ),
              const _InsetDivider(key: Key('superadmin-page-divider')),
              Expanded(child: pageBody),
            ],
          );
    return content;
  }

  Widget _withChatLauncher(
    Widget child, {
    ValueChanged<String>? onDestinationSelected,
    SuperadminChatLauncherPositionController? positionController,
    double reservedBottomInset = 0,
  }) {
    final destinationHandler = onDestinationSelected ?? widget.onDestinationSelected;
    if (!widget.showChatLauncher || widget.currentDestination == 'conversations') {
      return child;
    }
    final openConversations =
        widget.onOpenConversations ??
        (destinationHandler == null ? () {} : () => destinationHandler('conversations'));
    final pageBottomInset = widget.isHost
        ? _embeddedChatLauncherBottomInset
        : widget.chatLauncherBottomInset;
    final effectiveBottomInset = pageBottomInset + reservedBottomInset;
    final launcherReservedBottom = effectiveBottomInset > 0
        ? _shellGutter + effectiveBottomInset
        : 0.0;
    final launcherBottom = CoeloSpacing.space4 + launcherReservedBottom;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (!_drawerOpen)
          Positioned(
            right: CoeloSpacing.space4,
            bottom: launcherBottom,
            child: SuperadminChatLauncher(
              onOpenConversations: openConversations,
              bottomClearance: launcherReservedBottom,
              positionController: positionController ?? _chatLauncherPositionController,
              loadUnreadCount: widget.chatUnreadCountLoader,
            ),
          ),
      ],
    );
  }
}

class _SuperadminShellHostScope extends InheritedWidget {
  const _SuperadminShellHostScope({
    required this.isDesktop,
    required this.onDestinationSelected,
    required this.chatLauncherPositionController,
    required this.onChatLauncherBottomInsetChanged,
    required super.child,
  });

  final bool isDesktop;
  final ValueChanged<String> onDestinationSelected;
  final SuperadminChatLauncherPositionController chatLauncherPositionController;
  final ValueChanged<double> onChatLauncherBottomInsetChanged;

  static _SuperadminShellHostScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SuperadminShellHostScope>();
  }

  @override
  bool updateShouldNotify(_SuperadminShellHostScope oldWidget) {
    return isDesktop != oldWidget.isDesktop ||
        onDestinationSelected != oldWidget.onDestinationSelected ||
        chatLauncherPositionController != oldWidget.chatLauncherPositionController ||
        onChatLauncherBottomInsetChanged != oldWidget.onChatLauncherBottomInsetChanged;
  }
}

class _SidebarTransition extends StatelessWidget {
  const _SidebarTransition({
    required this.progress,
    required this.currentDestination,
    required this.onDestinationSelected,
  });

  final double progress;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final collapsed = progress >= 0.5;
    final distanceFromMidpoint = ((progress - 0.5).abs() * 2).clamp(0.0, 1.0);
    final opacity = Curves.easeInOut.transform(distanceFromMidpoint);
    return ClipRect(
      child: Opacity(
        opacity: opacity,
        child: SizedBox.expand(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: SizedBox(
              width: collapsed ? _collapsedSidebarWidth : null,
              height: double.infinity,
              child: _Sidebar(
                collapsed: collapsed,
                currentDestination: currentDestination,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.collapsed,
    required this.currentDestination,
    required this.onDestinationSelected,
  });

  final bool collapsed;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BrandHeader(
          collapsed: collapsed,
          currentDestination: currentDestination,
          onDestinationSelected: onDestinationSelected,
        ),
        const _InsetDivider(key: Key('superadmin-brand-divider')),
        Expanded(
          child: CoeloNavigationContent(
            collapsed: collapsed,
            currentDestination: currentDestination,
            onDestinationSelected: onDestinationSelected,
          ),
        ),
        const _InsetDivider(),
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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(CoeloRadius.xl),
      side: BorderSide(color: colors.outlineVariant),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CoeloRadius.xl),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: CoeloSpacing.space3,
            offset: const Offset(0, CoeloSpacing.space1),
          ),
        ],
      ),
      child: Material(
        color: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        clipBehavior: clip ? Clip.antiAlias : Clip.none,
        child: child,
      ),
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
  const _BrandHeader({
    required this.collapsed,
    required this.currentDestination,
    required this.onDestinationSelected,
  });

  final bool collapsed;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;

  void _openHome(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }
    if (currentDestination != 'home') {
      onDestinationSelected?.call('home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: _headerHeight,
      child: Tooltip(
        message: 'Ir para Home',
        excludeFromSemantics: true,
        child: Semantics(
          label: 'Ir para Home',
          button: true,
          excludeSemantics: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: const Key('superadmin-brand-home'),
              onTap: () => _openHome(context),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: collapsed ? CoeloSpacing.space5 : CoeloSpacing.space4,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showDetails = !collapsed && constraints.maxWidth >= 60;
                    return Row(
                      mainAxisAlignment: showDetails
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        const SuperadminBrandMark(),
                        if (showDetails) ...[
                          const SizedBox(width: CoeloSpacing.space3),
                          Expanded(child: Text('Superadmin', style: theme.textTheme.titleMedium)),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.collapsed, required this.progress, required this.onPressed});

  final bool collapsed;
  final double progress;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: collapsed ? 'Expandir menu' : 'Recolher menu',
      button: true,
      child: IconButton(
        key: const Key('superadmin-sidebar-collapse'),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(CoeloSize.touchMin),
          maximumSize: const Size.square(CoeloSize.touchMin),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        icon: DecoratedBox(
          key: const Key('superadmin-sidebar-collapse-visual'),
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
            child: Transform.rotate(
              key: const Key('superadmin-sidebar-collapse-chevron'),
              angle: math.pi * progress,
              child: const Icon(Icons.chevron_left_rounded, size: CoeloSpacing.space4),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationData {
  const _NavigationDestinationData(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

const _accountDestinations = <_NavigationDestinationData>[
  _NavigationDestinationData('profile', 'Perfil', Icons.person_outline),
  _NavigationDestinationData('settings', 'Configurações', Icons.settings_outlined),
];

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
    return CoeloAdminFlyout<String>(
      items: _tourFlyoutItems,
      onSelected: (selection) {
        final message = switch (selection) {
          'screen' => 'O tour desta tela ser\u00e1 implementado na etapa final.',
          'menu' => 'O tour do menu ser\u00e1 implementado na etapa final.',
          'complete' => 'O tour completo ser\u00e1 implementado na etapa final.',
          _ => null,
        };
        if (message != null) _showMessage(context, message);
      },
      alignmentOffset: Offset(
        widget.collapsed ? CoeloSize.touchMin + CoeloSpacing.space4 + CoeloSpacing.space1 : 252,
        0,
      ),
      builder: (context, controller) {
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

const _tourFlyoutItems = <CoeloAdminFlyoutItem<String>>[
  CoeloAdminFlyoutItem<String>(
    value: 'screen',
    label: 'Tour desta tela',
    icon: Icons.web_asset_outlined,
  ),
  CoeloAdminFlyoutItem<String>(value: 'menu', label: 'Tour do menu', icon: Icons.menu_open_rounded),
  CoeloAdminFlyoutItem<String>(
    value: 'complete',
    label: 'Tour completo',
    icon: Icons.play_circle_outline_rounded,
  ),
];

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
          final useCompactLayout =
              collapsed ||
              constraints.maxWidth < 180 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.5;
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

class _CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompactAppBar({
    required this.onLogout,
    required this.onDestinationSelected,
    required this.activityController,
    required this.currentScreen,
    this.onBugReportSubmitted,
  });

  final VoidCallback onLogout;
  final ValueChanged<String>? onDestinationSelected;
  final SuperadminActivityController activityController;
  final String currentScreen;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;

  @override
  Size get preferredSize => const Size.fromHeight(CoeloSize.touchMin);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (context) => IconButton(
          key: const Key('superadmin-mobile-menu'),
          tooltip: 'Abrir menu',
          onPressed: () => Scaffold.of(context).openDrawer(),
          icon: const Icon(Icons.menu),
        ),
      ),
      titleSpacing: 0,
      title: Semantics(label: 'Coelo Superadmin', image: true, child: const SuperadminBrandMark()),
      actionsPadding: const EdgeInsetsDirectional.only(
        top: CoeloSpacing.space1,
        end: CoeloSpacing.space5,
      ),
      actions: [
        _HeaderUtilityActions(
          activityController: activityController,
          currentScreen: currentScreen,
          onBugReportSubmitted: onBugReportSubmitted,
        ),
        _ProfileSummary(
          onLogout: onLogout,
          onDestinationSelected: onDestinationSelected,
          compact: true,
        ),
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
    required this.onDestinationSelected,
    required this.activityController,
    this.onBugReportSubmitted,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final List<Widget> actions;
  final List<Widget> compactActions;
  final VoidCallback onLogout;
  final ValueChanged<String>? onDestinationSelected;
  final SuperadminActivityController activityController;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactProfile = constraints.maxWidth < 900;
        final visibleActions = compact && compactActions.isNotEmpty ? compactActions : actions;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _headerHeight),
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
                    onBugReportSubmitted: onBugReportSubmitted,
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  _ProfileSummary(
                    onLogout: onLogout,
                    onDestinationSelected: onDestinationSelected,
                    compact: compactProfile,
                  ),
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
  const _ProfileSummary({
    required this.onLogout,
    required this.onDestinationSelected,
    required this.compact,
  });

  final VoidCallback onLogout;
  final ValueChanged<String>? onDestinationSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final items = <CoeloAdminFlyoutItem<String>>[
      for (final destination in _accountDestinations)
        CoeloAdminFlyoutItem<String>(
          value: destination.id,
          label: destination.label,
          icon: destination.icon,
        ),
      const CoeloAdminFlyoutItem<String>(
        value: 'logout',
        label: 'Sair',
        icon: Icons.logout,
        startsGroup: true,
        tone: CoeloAdminFlyoutTone.negative,
      ),
    ];
    return CoeloAdminFlyout<String>(
      items: items,
      onSelected: (selection) {
        if (selection == 'logout') {
          onLogout();
          return;
        }
        onDestinationSelected?.call(selection);
        final router = GoRouter.maybeOf(context);
        final isDevelopmentPreview =
            router?.routeInformationProvider.value.uri.path.startsWith('/dev/') ?? false;
        final prefix = isDevelopmentPreview ? '/dev' : '';
        router?.go('$prefix/$selection');
      },
      alignmentOffset: Offset(
        compact ? _compactProfileTriggerWidth - _compactProfileMenuWidth : 0,
        CoeloSpacing.space2,
      ),
      builder: (context, controller) {
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
  const _HeaderUtilityActions({
    required this.activityController,
    required this.currentScreen,
    this.onBugReportSubmitted,
  });

  final SuperadminActivityController activityController;
  final String currentScreen;
  final ValueChanged<SupportReportDraft>? onBugReportSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hoverColor = theme.extension<CoeloActionColors>()?.primaryHover ?? colors.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onBugReportSubmitted != null)
          IconButton(
            key: const Key('superadmin-report-bug'),
            tooltip: 'Reportar bug',
            onPressed: () async {
              final draft = await showSuperadminBugReportDialog(
                context,
                currentScreen: currentScreen,
                sections: {
                  for (final section in coeloSuperadminNavigation.where(
                    (node) => node.children.isNotEmpty,
                  ))
                    section.label: [...section.children.map((node) => node.label), 'Outro'],
                  'Conta': [
                    ..._accountDestinations.map((destination) => destination.label),
                    'Outros',
                  ],
                  'Outros': const [],
                },
              );
              if (draft == null || !context.mounted) {
                return;
              }
              onBugReportSubmitted!(draft);
              showSuperadminNotice(
                context,
                'Relato enviado com sucesso.',
                icon: Icons.check_circle_outline_rounded,
              );
            },
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
  MenuController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller?.open();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return CoeloAdminFlyout<String>(
      items: _tourFlyoutItems,
      onSelected: _ignoreTourSelection,
      builder: (context, controller) {
        _controller = controller;
        return const SizedBox.square(dimension: CoeloSize.touchMin);
      },
    );
  }
}

void _ignoreThemeMode(ThemeMode mode) {}

void _ignoreTourSelection(String selection) {}
