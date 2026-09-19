import 'dart:async';
import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../activity/superadmin_activity.dart';
import '../brand/superadmin_brand_mark.dart';
import '../navigation/superadmin_navigation.dart';
import '../../features/auth/domain/logout_action.dart';
import '../../features/chat/domain/chat_repository.dart';
import '../../features/chat/presentation/widgets/superadmin_chat_launcher.dart';
import '../../features/support/domain/support_ticket.dart';
import '../theme/superadmin_theme_mode_scope.dart';
import '../tour/superadmin_menu_tour_steps.dart';
import '../tour/superadmin_screen_tours.dart';
import '../tour/superadmin_tour_store.dart';
import '../widgets/superadmin_page_heading.dart';
import 'superadmin_notice.dart';
import 'widgets/shell_header_utility_actions.dart';
import 'widgets/shell_onboarding_tour_button.dart';
import 'widgets/shell_profile_summary.dart';
import 'widgets/shell_theme_mode_control.dart';
import 'widgets/superadmin_tour_scope.dart';

const _sidebarMotionDuration = CoeloMotion.emphasized;
const _sidebarMotionCurve = Cubic(0.4, 0, 0.2, 1);

const _headerHeight = CoeloSpacing.space20 + CoeloSpacing.space2;
const _expandedSidebarWidth = 260.0;
const _collapsedSidebarWidth = CoeloSpacing.space20 + CoeloSpacing.space2;
const _shellGutter = CoeloSpacing.space3;

/// Envio do relato do botão de Bug. Pode ser síncrono (protótipo local) ou
/// assíncrono (repositório produtivo); a shell aguarda e avisa o resultado.
typedef SuperadminBugReportSubmit = FutureOr<void> Function(SupportReportDraft draft);

@immutable
class SuperadminHeaderProfile {
  const SuperadminHeaderProfile({
    required this.name,
    required this.role,
    required this.initials,
    required this.avatarBackgroundColor,
    this.avatarImage,
  });

  /// Identidade determinística usada pelo preview `/dev` e pelos goldens.
  ///
  /// O cabeçalho global só é estável em teste quando a identidade não depende
  /// de sessão nem de carga assíncrona; este fixture é a mesma composição
  /// (avatar de iniciais em `orange50`, nome e papel) das referências visuais
  /// aprovadas. Produção nunca usa este valor: o host resolve o perfil da
  /// sessão e, sem sessão, cai no placeholder `–`/`Conta`.
  const SuperadminHeaderProfile.preview()
    : name = 'Owner Coelo',
      role = 'Superadmin',
      initials = 'OC',
      avatarBackgroundColor = CoeloPalette.orange50,
      avatarImage = null;

  final String name;
  final String role;
  final String initials;
  final Color avatarBackgroundColor;
  final ImageProvider? avatarImage;
}

/// Fornece um [SuperadminHeaderProfile] a shells que não recebem o perfil por
/// parâmetro nem por host (páginas montadas isoladamente em catálogo, preview
/// ou golden). A ordem de resolução do cabeçalho é: `headerProfile` do shell,
/// depois o host persistente, depois este escopo; sem nenhum, o placeholder.
class SuperadminHeaderProfileScope extends InheritedWidget {
  const SuperadminHeaderProfileScope({required this.profile, required super.child, super.key});

  final SuperadminHeaderProfile profile;

  static SuperadminHeaderProfile? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SuperadminHeaderProfileScope>()?.profile;
  }

  @override
  bool updateShouldNotify(SuperadminHeaderProfileScope oldWidget) => profile != oldWidget.profile;
}

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
    this.chatRecentConversationsLoader,
    this.onBugReportSubmitted,
    this.showChatLauncher = true,
    this.chatLauncherBottomInset = 0,
    this.isHost = false,
    this.frameHostedContent = false,
    this.canAccessCapability,
    this.headerProfile,
    this.tourStore,
    this.menuTourSteps = superadminMenuTourSteps,
    this.screenTours = superadminScreenTourList,
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
    this.chatRecentConversationsLoader,
    this.canAccessCapability,
    this.headerProfile,
    this.tourStore,
    this.menuTourSteps = superadminMenuTourSteps,
    this.screenTours = superadminScreenTourList,
    this.frameHostedContent = false,
    this.chatLauncherBottomInset = 0,
    super.key,
  }) : title = '',
       subtitle = '',
       actions = const [],
       compactActions = const [],
       onOpenConversations = null,
       showChatLauncher = true,
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

  /// Conversas recentes autorizadas para a faixa de iniciais do launcher.
  final Future<List<ChatConversationSummary>> Function()? chatRecentConversationsLoader;
  final SuperadminBugReportSubmit? onBugReportSubmitted;
  final bool showChatLauncher;
  final double chatLauncherBottomInset;
  final bool isHost;

  /// Frames raw feature pages that do not provide an embedded shell surface.
  final bool frameHostedContent;

  /// Destinos em que o balao "Mensagens" nunca aparece, mesmo com
  /// [showChatLauncher] verdadeiro. Conversas e o Chat do Principal porque o
  /// launcher abriria o chat por cima do proprio chat; os demais pela Decisao 7
  /// do Owner (10/09/2026): sem balao em criar, editar e publicar, nem no Agora
  /// aberto e no Momentos aberto. As paginas do Principal nao embutem um shell
  /// proprio, entao o hospedeiro decide pelo destino.
  static const Set<String> chatLauncherHiddenDestinations = {
    'conversations',
    'principal-chat',
    'principal-now',
    'principal-now-publish',
    'principal-happens-publish',
    'principal-moments',
    'principal-moments-publish',
  };

  /// Registra uma supressao do balao "Mensagens" no shell hospedeiro mais
  /// proximo e devolve o callback que a libera. Usado pelo SuperadminFormFrame
  /// para que nenhuma tela de criar, editar ou publicar mostre o balao
  /// (Decisao 7) nem o deixe cobrir o rodape ancorado, em largura nenhuma.
  /// Sem hospedeiro (shell isolado) devolve null: a pagina ja decide por
  /// [showChatLauncher]. O callback devolvido e seguro em dispose porque nao
  /// consulta ancestrais.
  static VoidCallback? suppressChatLauncher(BuildContext context) {
    final scope =
        context.getElementForInheritedWidgetOfExactType<_SuperadminShellHostScope>()?.widget
            as _SuperadminShellHostScope?;
    if (scope == null) return null;
    final notify = scope.onChatLauncherSuppressionChanged;
    notify(true);
    return () => notify(false);
  }

  final CoeloNavigationCapabilityCheck? canAccessCapability;
  final SuperadminHeaderProfile? headerProfile;

  /// Preferência local "tour do menu já visto". Com store, o shell que
  /// desenha o menu abre o tour uma vez no primeiro acesso; sem store, só
  /// pelo botão "Fazer tour".
  final SuperadminTourStore? tourStore;

  /// Passos do tour do menu (texto em `superadmin_menu_tour_steps.dart`).
  final List<CoeloTourStep> menuTourSteps;

  /// Tours por tela, na ordem do menu (texto em `tour/screens/`). O tour
  /// desta tela usa o do [currentDestination]; o completo percorre todos.
  final List<SuperadminScreenTour> screenTours;

  @override
  State<SuperadminShell> createState() => _SuperadminShellState();
}

class _SuperadminShellState extends State<SuperadminShell> with TickerProviderStateMixin {
  bool _sidebarCollapsed = false;
  bool _drawerOpen = false;
  late final AnimationController _sidebarController;
  late SuperadminActivityController _activityController;
  late final SuperadminChatLauncherPositionController _chatLauncherPositionController;
  late bool _ownsActivityController;
  double _embeddedChatLauncherBottomInset = 0;
  bool _embeddedChatLauncherVisible = true;
  int _chatLauncherSuppressors = 0;
  _SuperadminShellHostScope? _hostScope;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _tourRegistry = CoeloTourAnchorRegistry();
  final _revealController = CoeloNavigationRevealController();
  final _tourMenus = SuperadminTourMenuHandles();
  bool _tourRunning = false;
  // Primeiro acesso: `_autoTourResolved` fecha quando o store responde sim ou
  // não; enquanto responde "não sei" (usuário ainda não identificado logo após
  // o login), cada build do shell tenta de novo.
  bool _autoTourResolved = false;
  bool _autoTourChecking = false;
  // Tour completo: retoma após reload a partir da tela gravada no store.
  bool _completeResumeResolved = false;
  bool _completeResumeChecking = false;
  final _pageBodyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _sidebarController = AnimationController(vsync: this, duration: _sidebarMotionDuration);
    _ownsActivityController = widget.activityController == null;
    _activityController = widget.activityController ?? SuperadminActivityController();
    _chatLauncherPositionController = SuperadminChatLauncherPositionController(persist: true);
  }

  /// O menu do shell hospedeiro respeita a checagem de capacidade do router.
  /// Fora do hospedeiro (testes, previews e rotas isoladas) o menu completo da
  /// referência aprovada (MENU) é exibido; visibilidade de menu não é
  /// autorização, que continua no servidor e nas rotas.
  CoeloNavigationCapabilityCheck? get _menuCapabilityCheck =>
      widget.canAccessCapability ?? (widget.isHost ? null : (_) => true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion && _sidebarController.isAnimating) {
      _sidebarController.value = _sidebarCollapsed ? 1 : 0;
    }
  }

  @override
  void didUpdateWidget(covariant SuperadminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.activityController, widget.activityController)) {
      final previous = _activityController;
      final ownedPrevious = _ownsActivityController;
      _ownsActivityController = widget.activityController == null;
      _activityController = widget.activityController ?? SuperadminActivityController();
      if (ownedPrevious) {
        // Let the center detach its old listener and open-state first.
        WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
      }
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    _sidebarController.dispose();
    if (_ownsActivityController) {
      _activityController.dispose();
    }
    _chatLauncherPositionController.dispose();
    // Ao sair de uma tela sem balao, o host volta ao padrao (visivel) ate a
    // proxima pagina embutida dizer o contrario.
    _hostScope?.onChatLauncherVisibilityChanged(true);
    super.dispose();
  }

  bool get _reduceMotion => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Decisao 7 do Owner: sem balao de chat em criar, editar e publicar. A
  /// pagina embutida diz ao host se o launcher pode aparecer; o host, que e
  /// quem desenha o launcher, obedece.
  void _handleEmbeddedChatLauncherVisibility(bool visible) {
    if (_embeddedChatLauncherVisible == visible) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _embeddedChatLauncherVisible == visible) return;
      setState(() => _embeddedChatLauncherVisible = visible);
    });
  }

  /// Componentes de criar/editar/publicar (SuperadminFormFrame) se registram
  /// aqui enquanto estao montados; com um registrado, o balao nao aparece em
  /// largura nenhuma, independentemente da flag da pagina embutida.
  void _handleChatLauncherSuppression(bool suppressed) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final next = (_chatLauncherSuppressors + (suppressed ? 1 : -1)).clamp(0, 1 << 20);
      if (next == _chatLauncherSuppressors) return;
      setState(() => _chatLauncherSuppressors = next);
    });
  }

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
          style: coeloDestructiveFilledButtonStyle(dialogContext),
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

  bool get _isNarrow => MediaQuery.sizeOf(context).width < CoeloBreakpoints.expanded.minWidth;

  CoeloNavigationEnvironment get _navigationEnvironment => coeloNavigationEnvironmentOf(context);

  /// Passos do shell (busca, sino, conta, botão) sempre contam; nós do menu
  /// só quando o nó e seus ancestrais estão visíveis neste ambiente e com
  /// esta capacidade. Passo indisponível é pulado sem aviso.
  bool _isTourStepAvailable(CoeloTourStep step) {
    if (superadminTourShellAnchors.contains(step.anchorId)) return true;
    return coeloNavigationNodeVisible(
      step.anchorId,
      environment: _navigationEnvironment,
      canAccess: _menuCapabilityCheck,
    );
  }

  Future<void> _waitMotion(Duration duration) async {
    if (_reduceMotion) return;
    await Future<void>.delayed(duration);
  }

  /// Antes de cada passo: em tela estreita abre o drawer para os passos do
  /// menu e fecha para os do cabeçalho; no menu, revela o nó (abrindo o grupo)
  /// e rola até a âncora.
  Future<void> _prepareTourStep(CoeloTourStep step) async {
    final id = step.anchorId;
    final inHeader =
        id == 'report-bug' ||
        id == 'notifications' ||
        id == 'account' ||
        superadminTourAccountMenuAnchors.contains(id);
    final accountMenu = _tourMenus.account;
    // Itens do menu da conta: o menu precisa estar aberto; nos demais passos,
    // fechado (o menu fica acima do overlay do tour).
    if (superadminTourAccountMenuAnchors.contains(id)) {
      if (accountMenu != null && !accountMenu.isOpen) {
        accountMenu.open();
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
    } else if (accountMenu != null && accountMenu.isOpen) {
      accountMenu.close();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final scaffold = _scaffoldKey.currentState;
    if (_isNarrow && scaffold != null) {
      if (inHeader && scaffold.isDrawerOpen) {
        scaffold.closeDrawer();
        await _waitMotion(const Duration(milliseconds: 300));
      } else if (!inHeader && !scaffold.isDrawerOpen) {
        scaffold.openDrawer();
        await _waitMotion(const Duration(milliseconds: 300));
      }
    }
    if (!mounted) return;
    if (!superadminTourShellAnchors.contains(id)) {
      _revealController.reveal(id);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final anchorContext = _tourRegistry.contextOf(id);
    if (anchorContext == null || !anchorContext.mounted) return;
    await Scrollable.ensureVisible(
      anchorContext,
      alignment: 0.5,
      duration: _reduceMotion ? Duration.zero : CoeloMotion.short,
    );
  }

  /// Fecha o que o tour abriu (drawer, menu da conta).
  void _closeTourSurfaces() {
    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
    if (_tourMenus.account?.isOpen ?? false) _tourMenus.account!.close();
  }

  /// Abre o tour do menu (sidebar expandida antes) e devolve o resultado.
  Future<CoeloTourOutcome> _runMenuTour({
    CoeloTourSegment segment = CoeloTourSegment.single,
  }) async {
    if (!_isNarrow && _sidebarCollapsed) {
      _toggleSidebar();
      await _waitMotion(_sidebarMotionDuration);
      if (!mounted) return CoeloTourOutcome.unavailable;
    }
    final outcome = await showCoeloTour(
      context,
      steps: widget.menuTourSteps,
      registry: _tourRegistry,
      isStepAvailable: _isTourStepAvailable,
      onPrepareStep: _prepareTourStep,
      segment: segment,
    );
    if (mounted) _closeTourSurfaces();
    return outcome;
  }

  Future<void> _startMenuTour() async {
    if (_tourRunning || !mounted) return;
    _tourRunning = true;
    try {
      final outcome = await _runMenuTour();
      if (!mounted) return;
      if (outcome != CoeloTourOutcome.unavailable) {
        await widget.tourStore?.markMenuTour(
          outcome == CoeloTourOutcome.completed ? 'done' : 'skipped',
        );
      }
    } finally {
      _tourRunning = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Tour desta tela e tour completo

  SuperadminScreenTour? get _currentScreenTour {
    for (final tour in widget.screenTours) {
      if (tour.destinationId == widget.currentDestination) return tour;
    }
    return null;
  }

  /// Telas do tour completo: as que têm tour e cujo destino está visível no
  /// menu deste ambiente e capacidade.
  List<SuperadminScreenTour> get _completeTourScreens => [
    for (final tour in widget.screenTours)
      if (coeloNavigationNodeVisible(
        tour.destinationId,
        environment: _navigationEnvironment,
        canAccess: _menuCapabilityCheck,
      ))
        tour,
  ];

  /// Antes de cada passo de tela: fecha drawer e menu da conta (ficam acima
  /// do overlay), rola a página até a âncora aparecer (listas preguiçosas só
  /// montam o que está visível) e centraliza a âncora.
  Future<void> _prepareScreenStep(CoeloTourStep step) async {
    final id = step.anchorId;
    final accountMenu = _tourMenus.account;
    if (accountMenu != null && accountMenu.isOpen) {
      accountMenu.close();
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    final scaffold = _scaffoldKey.currentState;
    if (_isNarrow && scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      await _waitMotion(const Duration(milliseconds: 300));
      if (!mounted) return;
    }
    if (_tourRegistry.contextOf(id) == null) {
      await _scrollPageUntilAnchor(id);
      if (!mounted) return;
    }
    final anchorContext = _tourRegistry.contextOf(id);
    if (anchorContext == null || !anchorContext.mounted) return;
    await Scrollable.ensureVisible(
      anchorContext,
      alignment: 0.5,
      duration: _reduceMotion ? Duration.zero : CoeloMotion.short,
    );
  }

  /// Listas verticais montadas na página (as mais externas primeiro).
  List<ScrollableState> _pageScrollables() {
    final root = _pageBodyKey.currentContext;
    if (root == null) return const [];
    final scrollables = <ScrollableState>[];
    void visit(Element element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final state = element.state as ScrollableState;
        if (state.widget.axis == Axis.vertical) scrollables.add(state);
      }
      element.visitChildElements(visit);
    }

    (root as Element).visitChildElements(visit);
    return scrollables;
  }

  /// Rola as listas verticais da página, uma tela por vez, até [stop]
  /// devolver true. Sem sucesso, devolve cada lista à posição inicial.
  Future<bool> _scrollPage(bool Function() stop) async {
    for (final scrollable in _pageScrollables()) {
      final position = scrollable.position;
      if (!position.hasContentDimensions || !position.hasViewportDimension) continue;
      final initial = position.pixels;
      var offset = initial;
      while (offset < position.maxScrollExtent) {
        offset = (offset + position.viewportDimension * 0.8).clamp(0.0, position.maxScrollExtent);
        position.jumpTo(offset);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return false;
        if (stop()) return true;
      }
      position.jumpTo(initial);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
    }
    return false;
  }

  Future<void> _scrollPageUntilAnchor(String id) =>
      _scrollPage(() => _tourRegistry.contextOf(id) != null);

  /// Quais âncoras do tour existem nesta tela: as montadas agora e as que
  /// aparecem ao rolar a página uma vez (listas preguiçosas só montam o que
  /// está visível). Assim o contador "n de N" conta só passos reais.
  Future<Set<String>> _discoverScreenAnchors(SuperadminScreenTour tour) async {
    final ids = {for (final step in tour.steps) step.anchorId};
    final seen = <String>{};
    void collect() {
      for (final id in ids) {
        if (_tourRegistry.contextOf(id) != null) seen.add(id);
      }
    }

    collect();
    if (seen.length == ids.length) return seen;
    await _scrollPage(() {
      collect();
      return seen.length == ids.length;
    });
    if (!mounted) return seen;
    // Volta ao topo: o primeiro passo costuma estar lá.
    for (final scrollable in _pageScrollables()) {
      if (scrollable.position.hasContentDimensions) scrollable.position.jumpTo(0);
    }
    await WidgetsBinding.instance.endOfFrame;
    return seen;
  }

  Future<CoeloTourOutcome> _runScreenTour(
    SuperadminScreenTour tour, {
    CoeloTourSegment segment = CoeloTourSegment.single,
  }) async {
    // Passo sem elemento na tela (estado vazio, sem permissão, largura
    // estreita) fica fora do tour sem aviso; o mecanismo ainda pula, na hora,
    // o que sumir depois da preparação.
    final available = await _discoverScreenAnchors(tour);
    if (!mounted) return CoeloTourOutcome.unavailable;
    final outcome = await showCoeloTour(
      context,
      steps: tour.steps,
      registry: _tourRegistry,
      isStepAvailable: (step) => available.contains(step.anchorId),
      onPrepareStep: _prepareScreenStep,
      segment: segment,
    );
    if (mounted) _closeTourSurfaces();
    return outcome;
  }

  /// "Tour desta tela": o tour do destino atual. Devolve false quando a tela
  /// não tem tour (o botão avisa).
  Future<bool> _startScreenTour() async {
    final tour = _currentScreenTour;
    if (tour == null) return false;
    if (_tourRunning || !mounted) return true;
    _tourRunning = true;
    try {
      await _runScreenTour(tour);
    } finally {
      _tourRunning = false;
    }
    return true;
  }

  int _mountedAnchorCount(SuperadminScreenTour tour) =>
      tour.steps.where((step) => _tourRegistry.contextOf(step.anchorId) != null).length;

  /// Espera a página do destino montar (qualquer âncora do tour), até
  /// [frames] frames, e depois assentar: telas que carregam dados mostram o
  /// cabeçalho antes do conteúdo, então aguarda pelo menos 1,5 s (até 4 s)
  /// enquanto novas âncoras aparecem. Com animações desligadas não espera.
  Future<void> _waitForScreen(SuperadminScreenTour tour, {int frames = 120}) async {
    var mountedAny = false;
    for (var frame = 0; frame < frames; frame++) {
      if (widget.currentDestination == tour.destinationId && _mountedAnchorCount(tour) > 0) {
        mountedAny = true;
        break;
      }
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (!mountedAny || _reduceMotion) return;
    final started = DateTime.now();
    var last = _mountedAnchorCount(tour);
    while (DateTime.now().difference(started) < const Duration(seconds: 4)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      final count = _mountedAnchorCount(tour);
      if (count == tour.steps.length) break;
      final settled = DateTime.now().difference(started) >= const Duration(milliseconds: 1500);
      if (settled && count == last) break;
      last = count;
    }
  }

  /// "Tour completo": o tour do menu e, em seguida, cada tela com tour na
  /// ordem do menu, navegando de tela em tela. Contador global; "Pular tour"
  /// encerra tudo; "Voltar" no primeiro passo de uma tela volta ao último da
  /// anterior; ao fim volta à tela de origem. [resumeAt] retoma numa tela
  /// (índice gravado no store antes do reload).
  Future<void> _startCompleteTour({int? resumeAt}) async {
    if (_tourRunning || !mounted) return;
    _tourRunning = true;
    final store = widget.tourStore;
    try {
      final origin = widget.currentDestination;
      final screens = _completeTourScreens;
      final menuCount = widget.menuTourSteps.where(_isTourStepAvailable).length;
      final offsets = <int>[];
      var total = menuCount;
      for (final tour in screens) {
        offsets.add(total);
        total += tour.steps.length;
      }
      // -1 é o tour do menu.
      var index = resumeAt == null ? -1 : resumeAt.clamp(0, screens.length);
      var startAtLast = false;
      while (mounted) {
        if (index < 0) {
          final outcome = await _runMenuTour(
            segment: CoeloTourSegment(
              counterTotal: total,
              continuesAfter: screens.isNotEmpty,
              startAtLast: startAtLast,
            ),
          );
          if (!mounted) return;
          if (outcome == CoeloTourOutcome.skipped) {
            await store?.markCompleteTour('skipped');
            break;
          }
          await store?.markMenuTour(outcome == CoeloTourOutcome.completed ? 'done' : 'skipped');
          index = 0;
          startAtLast = false;
          continue;
        }
        if (index >= screens.length) {
          await store?.markCompleteTour('done');
          break;
        }
        final tour = screens[index];
        await store?.saveCompleteTourProgress(index);
        if (!mounted) return;
        if (widget.currentDestination != tour.destinationId) {
          widget.onDestinationSelected?.call(tour.destinationId);
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) return;
        }
        await _waitForScreen(tour);
        if (!mounted) return;
        final outcome = await _runScreenTour(
          tour,
          segment: CoeloTourSegment(
            counterOffset: offsets[index],
            counterTotal: total,
            continuesAfter: index < screens.length - 1,
            allowBackFromFirst: true,
            startAtLast: startAtLast,
          ),
        );
        if (!mounted) return;
        switch (outcome) {
          case CoeloTourOutcome.skipped:
            await store?.markCompleteTour('skipped');
            index = screens.length + 1;
          case CoeloTourOutcome.back:
            index -= 1;
            startAtLast = true;
          case CoeloTourOutcome.completed:
          case CoeloTourOutcome.unavailable:
            index += 1;
            startAtLast = false;
        }
        if (index > screens.length) break;
      }
      if (mounted && widget.currentDestination != origin) {
        widget.onDestinationSelected?.call(origin);
      }
    } finally {
      _tourRunning = false;
    }
  }

  /// Após reload no meio do tour completo: com índice gravado no store, retoma
  /// naquela tela assim que o shell assentar.
  void _scheduleCompleteTourResume() {
    final store = widget.tourStore;
    if (store == null || _completeResumeResolved || _completeResumeChecking) return;
    _completeResumeChecking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Sem usuário identificado (logo após o login) o store devolve null e
      // o shell repergunta no próximo build.
      final seen = await store.hasSeenMenuTour();
      _completeResumeChecking = false;
      if (!mounted || seen == null) return;
      _completeResumeResolved = true;
      final progress = await store.completeTourProgress();
      if (!mounted || progress == null) return;
      await _startCompleteTour(resumeAt: progress);
    });
  }

  /// Primeiro acesso: com store e sem registro de "visto", abre o tour do
  /// menu uma única vez depois do primeiro frame do shell que desenha o menu.
  void _scheduleFirstAccessTour() {
    final store = widget.tourStore;
    if (store == null || _autoTourResolved || _autoTourChecking) return;
    _autoTourChecking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final seen = await store.hasSeenMenuTour();
      _autoTourChecking = false;
      if (!mounted || seen == null) return;
      _autoTourResolved = true;
      if (seen) return;
      // Logo após o login o shell ainda está assentando (perfil do cabeçalho,
      // transição de rota): espera a âncora do primeiro passo existir para
      // não pulá-lo.
      final first = widget.menuTourSteps.firstOrNull?.anchorId;
      for (var frame = 0; frame < 30 && first != null; frame++) {
        if (_tourRegistry.contextOf(first) != null) break;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }
      await _startMenuTour();
    });
  }

  Widget _withTourScope(Widget child) {
    _scheduleFirstAccessTour();
    _scheduleCompleteTourResume();
    return CoeloTourScope(
      registry: _tourRegistry,
      child: SuperadminTourScope(
        startMenuTour: _startMenuTour,
        startScreenTour: _startScreenTour,
        startCompleteTour: _startCompleteTour,
        menus: _tourMenus,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageBody = widget.isHost
        ? KeyedSubtree(key: _pageBodyKey, child: widget.child ?? const SizedBox.expand())
        : widget.child ?? const SizedBox.expand();
    final hostScope = _SuperadminShellHostScope.maybeOf(context);
    final headerProfile = widget.headerProfile ?? SuperadminHeaderProfileScope.maybeOf(context);
    if (!widget.isHost && hostScope != null) {
      _hostScope = hostScope;
      hostScope.onChatLauncherVisibilityChanged(widget.showChatLauncher);
      hostScope.onChatLauncherBottomInsetChanged(
        widget.showChatLauncher ? widget.chatLauncherBottomInset : 0,
      );
      return _buildEmbeddedPage(pageBody, hostScope);
    }
    return _withTourScope(
      LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= CoeloBreakpoints.expanded.minWidth;
          if (!isDesktop) {
            if (widget.isHost) {
              return _withChatLauncher(
                Scaffold(
                  key: _scaffoldKey,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  appBar: widget.frameHostedContent
                      ? null
                      : _CompactAppBar(
                          drawerOpen: _drawerOpen,
                          onLogout: _handleLogout,
                          onDestinationSelected: widget.onDestinationSelected,
                          activityController: _activityController,
                          headerProfile: headerProfile,
                          currentScreen:
                              coeloNavigationNodeById(widget.currentDestination)?.label ??
                              widget.currentDestination,
                          onBugReportSubmitted: widget.onBugReportSubmitted,
                        ),
                  onDrawerChanged: (open) => setState(() => _drawerOpen = open),
                  drawer: _buildDrawer(context),
                  body: SuperadminNoticeHost(child: _hostedContent(pageBody, isDesktop: false)),
                ),
                onDestinationSelected: widget.onDestinationSelected,
                positionController: _chatLauncherPositionController,
                reservedBottomInset: MediaQuery.paddingOf(context).bottom,
              );
            }
            return _withChatLauncher(
              Scaffold(
                key: _scaffoldKey,
                backgroundColor: Theme.of(context).colorScheme.surface,
                appBar: _CompactAppBar(
                  drawerOpen: _drawerOpen,
                  onLogout: _handleLogout,
                  onDestinationSelected: widget.onDestinationSelected,
                  activityController: _activityController,
                  headerProfile: headerProfile,
                  currentScreen: widget.title,
                  onBugReportSubmitted: widget.onBugReportSubmitted,
                ),
                onDrawerChanged: (open) => setState(() => _drawerOpen = open),
                drawer: _buildDrawer(context),
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
                        headerProfile: headerProfile,
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
                ? _hostedContent(
                    widget.frameHostedContent
                        ? _FloatingSurface(
                            key: const Key('superadmin-floating-content'),
                            clip: true,
                            child: pageBody,
                          )
                        : pageBody,
                    isDesktop: true,
                  )
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
                          headerProfile: headerProfile,
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
                          (_expandedSidebarWidth - _collapsedSidebarWidth) *
                              _sidebarController.value;
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
                                        canAccessCapability: _menuCapabilityCheck,
                                        revealController: _revealController,
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
      ),
    );
  }

  /// Drawer da tela estreita: marca, menu e o botão "Fazer tour" (mesmo
  /// rodapé da sidebar larga, para o tour poder ser refeito em qualquer
  /// largura).
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
                canAccessCapability: _menuCapabilityCheck,
                revealController: _revealController,
              ),
            ),
            const _InsetDivider(),
            const Padding(
              padding: EdgeInsets.all(CoeloSpacing.space2),
              child: ShellOnboardingTourButton(collapsed: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hostedContent(Widget child, {required bool isDesktop}) {
    return _SuperadminShellHostScope(
      isDesktop: isDesktop,
      headerProfile: widget.headerProfile ?? SuperadminHeaderProfileScope.maybeOf(context),
      onDestinationSelected: widget.onDestinationSelected!,
      chatLauncherPositionController: _chatLauncherPositionController,
      onChatLauncherBottomInsetChanged: _handleEmbeddedChatLauncherBottomInset,
      onChatLauncherVisibilityChanged: _handleEmbeddedChatLauncherVisibility,
      onChatLauncherSuppressionChanged: _handleChatLauncherSuppression,
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
                  headerProfile:
                      widget.headerProfile ??
                      hostScope.headerProfile ??
                      SuperadminHeaderProfileScope.maybeOf(context),
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
                headerProfile:
                    widget.headerProfile ??
                    hostScope.headerProfile ??
                    SuperadminHeaderProfileScope.maybeOf(context),
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
    if (!widget.showChatLauncher ||
        (widget.isHost && (!_embeddedChatLauncherVisible || _chatLauncherSuppressors > 0)) ||
        SuperadminShell.chatLauncherHiddenDestinations.contains(widget.currentDestination)) {
      return child;
    }
    final openConversations =
        widget.onOpenConversations ??
        (destinationHandler == null ? null : () => destinationHandler('conversations'));
    if (openConversations == null) return child;
    final pageBottomInset = widget.isHost
        ? math.max(widget.chatLauncherBottomInset, _embeddedChatLauncherBottomInset)
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
              loadRecentConversations: widget.chatRecentConversationsLoader,
            ),
          ),
      ],
    );
  }
}

class _SuperadminShellHostScope extends InheritedWidget {
  const _SuperadminShellHostScope({
    required this.isDesktop,
    required this.headerProfile,
    required this.onDestinationSelected,
    required this.chatLauncherPositionController,
    required this.onChatLauncherBottomInsetChanged,
    required this.onChatLauncherVisibilityChanged,
    required this.onChatLauncherSuppressionChanged,
    required super.child,
  });

  final bool isDesktop;
  final SuperadminHeaderProfile? headerProfile;
  final ValueChanged<String> onDestinationSelected;
  final SuperadminChatLauncherPositionController chatLauncherPositionController;
  final ValueChanged<double> onChatLauncherBottomInsetChanged;
  final ValueChanged<bool> onChatLauncherVisibilityChanged;
  final ValueChanged<bool> onChatLauncherSuppressionChanged;

  static _SuperadminShellHostScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_SuperadminShellHostScope>();
  }

  @override
  bool updateShouldNotify(_SuperadminShellHostScope oldWidget) {
    return isDesktop != oldWidget.isDesktop ||
        headerProfile != oldWidget.headerProfile ||
        onDestinationSelected != oldWidget.onDestinationSelected ||
        chatLauncherPositionController != oldWidget.chatLauncherPositionController ||
        onChatLauncherBottomInsetChanged != oldWidget.onChatLauncherBottomInsetChanged ||
        onChatLauncherVisibilityChanged != oldWidget.onChatLauncherVisibilityChanged ||
        onChatLauncherSuppressionChanged != oldWidget.onChatLauncherSuppressionChanged;
  }
}

class _SidebarTransition extends StatelessWidget {
  const _SidebarTransition({
    required this.progress,
    required this.currentDestination,
    required this.onDestinationSelected,
    this.canAccessCapability,
    this.revealController,
  });

  final double progress;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;
  final CoeloNavigationCapabilityCheck? canAccessCapability;
  final CoeloNavigationRevealController? revealController;

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
                canAccessCapability: canAccessCapability,
                revealController: revealController,
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
    this.canAccessCapability,
    this.revealController,
  });

  final bool collapsed;
  final String currentDestination;
  final ValueChanged<String>? onDestinationSelected;
  final CoeloNavigationCapabilityCheck? canAccessCapability;
  final CoeloNavigationRevealController? revealController;

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
            canAccessCapability: canAccessCapability,
            revealController: revealController,
          ),
        ),
        const _InsetDivider(),
        Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space2),
          child: ShellOnboardingTourButton(collapsed: collapsed),
        ),
        const _InsetDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space2,
            CoeloSpacing.space3,
          ),
          child: ShellThemeModeControl(collapsed: collapsed),
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
    return MergeSemantics(
      child: Semantics(
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
      ),
    );
  }
}

class _CompactAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CompactAppBar({
    required this.drawerOpen,
    required this.onLogout,
    required this.onDestinationSelected,
    required this.activityController,
    this.headerProfile,
    required this.currentScreen,
    this.onBugReportSubmitted,
  });

  final bool drawerOpen;
  final VoidCallback onLogout;
  final ValueChanged<String>? onDestinationSelected;
  final SuperadminActivityController activityController;
  final SuperadminHeaderProfile? headerProfile;
  final String currentScreen;
  final SuperadminBugReportSubmit? onBugReportSubmitted;

  @override
  Size get preferredSize => const Size.fromHeight(CoeloSpacing.space16);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AppBar(
      toolbarHeight: CoeloSpacing.space16,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 148,
      leading: Builder(
        builder: (context) => Tooltip(
          message: drawerOpen ? 'Menu aberto' : 'Abrir menu',
          child: TextButton(
            key: const Key('superadmin-mobile-menu'),
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurface,
              padding: const EdgeInsetsDirectional.only(start: CoeloSpacing.space4),
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () => Scaffold.of(context).openDrawer(),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SuperadminBrandMark(size: 36),
                  const SizedBox(width: CoeloSpacing.space2),
                  Text('Coelo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: CoeloSpacing.space1),
                  Icon(
                    drawerOpen ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                    key: const Key('superadmin-mobile-menu-chevron'),
                    size: CoeloSize.iconSm,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      titleSpacing: 0,
      title: const SizedBox.shrink(),
      actionsPadding: const EdgeInsetsDirectional.only(
        top: CoeloSpacing.space1,
        end: CoeloSpacing.space5,
      ),
      actions: [
        ShellHeaderUtilityActions(
          activityController: activityController,
          currentScreen: currentScreen,
          onBugReportSubmitted: onBugReportSubmitted,
        ),
        ShellProfileSummary(
          onLogout: onLogout,
          onDestinationSelected: onDestinationSelected,
          compact: true,
          headerProfile: headerProfile,
        ),
        const SizedBox(width: CoeloSpacing.space2),
      ],
    );
  }
}

/// Âncoras do tour por tela no cabeçalho de qualquer página embutida:
/// `page.header` (título e subtítulo) e `page.actions` (botões da página).
abstract final class SuperadminPageTourAnchors {
  static const header = 'page.header';
  static const actions = 'page.actions';
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
    this.headerProfile,
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
  final SuperadminHeaderProfile? headerProfile;
  final SuperadminBugReportSubmit? onBugReportSubmitted;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactProfile = constraints.maxWidth < 900;
        final visibleActions = compact && compactActions.isNotEmpty ? compactActions : actions;
        // No compacto com ações o espaço é curto: gaps menores.
        final tight = compact && visibleActions.isNotEmpty;
        final actionGap = tight ? CoeloSpacing.space1 : CoeloSpacing.space2;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _headerHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space5),
            child: Row(
              children: [
                Expanded(
                  child: CoeloTourAnchor(
                    id: SuperadminPageTourAnchors.header,
                    child: SuperadminPageHeading(
                      title: title,
                      subtitle: subtitle,
                      singleLine: !compact,
                    ),
                  ),
                ),
                if (visibleActions.isNotEmpty) ...[
                  SizedBox(width: tight ? CoeloSpacing.space1 : CoeloSpacing.space4),
                  CoeloTourAnchor(
                    id: SuperadminPageTourAnchors.actions,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: visibleActions
                          .expand((action) => [action, SizedBox(width: actionGap)])
                          .toList(growable: false),
                    ),
                  ),
                ],
                if (!compact) ...[
                  ShellHeaderUtilityActions(
                    activityController: activityController,
                    currentScreen: title,
                    onBugReportSubmitted: onBugReportSubmitted,
                  ),
                  const SizedBox(width: CoeloSpacing.space2),
                  ShellProfileSummary(
                    onLogout: onLogout,
                    onDestinationSelected: onDestinationSelected,
                    compact: compactProfile,
                    headerProfile: headerProfile,
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
                  child: ShellOnboardingTourButton(collapsed: collapsed),
                ),
                const _InsetDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    CoeloSpacing.space2,
                    CoeloSpacing.space2,
                    CoeloSpacing.space2,
                    CoeloSpacing.space3,
                  ),
                  child: ShellThemeModeControl(collapsed: collapsed),
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
      items: shellTourFlyoutItems,
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
