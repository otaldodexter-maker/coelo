import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Um passo do tour: aponta para a âncora [anchorId] com [title] e [text].
final class CoeloTourStep {
  const CoeloTourStep({required this.anchorId, required this.title, required this.text});

  final String anchorId;
  final String title;
  final String text;
}

/// Como o tour terminou. `unavailable` significa que nenhum passo tinha
/// âncora visível (o balão nunca abriu).
enum CoeloTourOutcome { completed, skipped, unavailable }

/// Registro das âncoras montadas na tela. Uma mesma âncora pode estar
/// registrada mais de uma vez (menu lateral e drawer, por exemplo); vale a
/// primeira que estiver montada e com tamanho.
final class CoeloTourAnchorRegistry {
  final _keys = <String, List<GlobalKey>>{};

  void register(String id, GlobalKey key) {
    final keys = _keys.putIfAbsent(id, () => <GlobalKey>[]);
    if (!keys.contains(key)) keys.add(key);
  }

  void unregister(String id, GlobalKey key) {
    final keys = _keys[id];
    if (keys == null) return;
    keys.remove(key);
    if (keys.isEmpty) _keys.remove(id);
  }

  bool get isEmpty => _keys.isEmpty;

  /// Contexto da âncora montada, ou null se ela não está na tela.
  BuildContext? contextOf(String id) {
    for (final key in _keys[id] ?? const <GlobalKey>[]) {
      final context = key.currentContext;
      if (context == null || !context.mounted) continue;
      final box = context.findRenderObject();
      if (box is RenderBox && box.attached && box.hasSize) return context;
    }
    return null;
  }

  /// Retângulo global da âncora, ou null se ela não está na tela.
  Rect? rectOf(String id) {
    final context = contextOf(id);
    if (context == null) return null;
    final box = context.findRenderObject()! as RenderBox;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}

/// Disponibiliza o registro de âncoras para os [CoeloTourAnchor] abaixo.
final class CoeloTourScope extends InheritedWidget {
  const CoeloTourScope({required this.registry, required super.child, super.key});

  final CoeloTourAnchorRegistry registry;

  static CoeloTourAnchorRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CoeloTourScope>()?.registry;

  @override
  bool updateShouldNotify(CoeloTourScope oldWidget) => registry != oldWidget.registry;
}

/// Marca [child] como a âncora [id]. Sem [CoeloTourScope] acima, não faz
/// nada além de renderizar o filho.
final class CoeloTourAnchor extends StatefulWidget {
  const CoeloTourAnchor({required this.id, required this.child, super.key});

  final String id;
  final Widget child;

  @override
  State<CoeloTourAnchor> createState() => _CoeloTourAnchorState();
}

final class _CoeloTourAnchorState extends State<CoeloTourAnchor> {
  final _key = GlobalKey();
  CoeloTourAnchorRegistry? _registry;
  String? _registeredId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _attach(CoeloTourScope.maybeOf(context));
  }

  @override
  void didUpdateWidget(covariant CoeloTourAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) _attach(_registry);
  }

  void _attach(CoeloTourAnchorRegistry? registry) {
    if (_registry != null && _registeredId != null) _registry!.unregister(_registeredId!, _key);
    _registry = registry;
    _registeredId = registry == null ? null : widget.id;
    registry?.register(widget.id, _key);
  }

  @override
  void dispose() {
    if (_registry != null && _registeredId != null) _registry!.unregister(_registeredId!, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KeyedSubtree(key: _key, child: widget.child);
}

typedef CoeloTourPrepareStep = FutureOr<void> Function(CoeloTourStep step);
typedef CoeloTourStepAvailability = bool Function(CoeloTourStep step);

/// Abre o tour sobre o `Overlay` raiz e resolve quando ele termina.
///
/// Antes de cada passo, [onPrepareStep] é chamado para que o hospedeiro
/// abra grupos, drawer ou role até a âncora; só depois o balão é medido.
/// Passos cujo [isStepAvailable] devolve false, ou cuja âncora não está na
/// tela depois da preparação, são pulados sem aviso. Sem [isStepAvailable],
/// conta como disponível o passo cuja âncora está montada no início.
Future<CoeloTourOutcome> showCoeloTour(
  BuildContext context, {
  required List<CoeloTourStep> steps,
  required CoeloTourAnchorRegistry registry,
  CoeloTourPrepareStep? onPrepareStep,
  CoeloTourStepAvailability? isStepAvailable,
}) {
  final available = steps
      .where(isStepAvailable ?? (step) => registry.contextOf(step.anchorId) != null)
      .toList(growable: false);
  if (available.isEmpty) return Future.value(CoeloTourOutcome.unavailable);
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<CoeloTourOutcome>();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => CoeloTourOverlay(
      steps: available,
      registry: registry,
      onPrepareStep: onPrepareStep,
      onFinished: (outcome) {
        entry.remove();
        entry.dispose();
        if (!completer.isCompleted) completer.complete(outcome);
      },
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// Camada do tour: recorte escurecido ao redor da âncora e balão com título,
/// texto, contador e ações. Em largura menor que `expanded` o balão vira
/// folha inferior. Teclado: Esc pula, Enter e → avançam, ← volta.
final class CoeloTourOverlay extends StatefulWidget {
  const CoeloTourOverlay({
    required this.steps,
    required this.registry,
    required this.onFinished,
    this.onPrepareStep,
    super.key,
  });

  final List<CoeloTourStep> steps;
  final CoeloTourAnchorRegistry registry;
  final ValueChanged<CoeloTourOutcome> onFinished;
  final CoeloTourPrepareStep? onPrepareStep;

  @override
  State<CoeloTourOverlay> createState() => _CoeloTourOverlayState();
}

final class _CoeloTourOverlayState extends State<CoeloTourOverlay> {
  int? _index;
  Rect? _anchorRect;
  bool _busy = false;
  bool _finished = false;
  bool _shownAny = false;
  final _focusNode = FocusNode(debugLabel: 'coelo-tour');

  @override
  void initState() {
    super.initState();
    unawaited(_go(0, 1));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _go(int from, int direction) async {
    if (_busy || _finished) return;
    _busy = true;
    try {
      // Cede o turno: `initState` e cliques chegam no meio de um frame e o
      // hospedeiro pode precisar de setState ao preparar o passo.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || _finished) return;
      var index = from;
      while (index >= 0 && index < widget.steps.length) {
        final step = widget.steps[index];
        await widget.onPrepareStep?.call(step);
        if (!mounted || _finished) return;
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || _finished) return;
        var rect = widget.registry.rectOf(step.anchorId);
        // A âncora pode estar montando (menu abrindo, drawer, transição de
        // rota): tenta mais alguns frames antes de considerar o passo ausente.
        for (var retry = 0; rect == null && retry < 3; retry++) {
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted || _finished) return;
          rect = widget.registry.rectOf(step.anchorId);
        }
        if (rect != null) {
          setState(() {
            _index = index;
            _anchorRect = rect;
            _shownAny = true;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_finished) _focusNode.requestFocus();
          });
          return;
        }
        index += direction;
      }
      if (direction > 0) {
        _finish(_shownAny ? CoeloTourOutcome.completed : CoeloTourOutcome.unavailable);
      }
    } finally {
      _busy = false;
    }
  }

  void _finish(CoeloTourOutcome outcome) {
    if (_finished) return;
    _finished = true;
    widget.onFinished(outcome);
  }

  void _next() {
    final index = _index;
    if (index == null) return;
    if (index == widget.steps.length - 1) {
      _finish(CoeloTourOutcome.completed);
      return;
    }
    unawaited(_go(index + 1, 1));
  }

  void _back() {
    final index = _index;
    if (index == null || index == 0) return;
    unawaited(_go(index - 1, -1));
  }

  void _skip() => _finish(CoeloTourOutcome.skipped);

  @override
  Widget build(BuildContext context) {
    final index = _index;
    final rect = _anchorRect;
    if (index == null || rect == null) return const SizedBox.shrink();
    final step = widget.steps[index];
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < CoeloBreakpoints.expanded.minWidth;
        final highlight = rect.inflate(CoeloSpacing.space1);
        // Folha inferior por padrão; se a âncora está na metade de baixo da
        // tela (rodapé do drawer, por exemplo), a folha vai para o topo para
        // não cobrir o que está apontando.
        final sheetAtTop = narrow && highlight.center.dy > constraints.maxHeight / 2;
        return Stack(
          key: const Key('coelo-tour-overlay'),
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {},
              child: CustomPaint(
                painter: _CoeloTourScrimPainter(
                  highlight: highlight,
                  color: colors.scrim.withValues(alpha: 0.55),
                  ring: colors.primary,
                ),
              ),
            ),
            CustomSingleChildLayout(
              delegate: _CoeloTourBalloonLayout(
                anchor: highlight,
                narrow: narrow,
                sheetAtTop: sheetAtTop,
              ),
              child: _CoeloTourBalloon(
                focusNode: _focusNode,
                step: step,
                position: index + 1,
                total: widget.steps.length,
                narrow: narrow,
                sheetAtTop: sheetAtTop,
                onBack: index == 0 ? null : _back,
                onNext: _next,
                onSkip: _skip,
                isLast: index == widget.steps.length - 1,
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _CoeloTourScrimPainter extends CustomPainter {
  const _CoeloTourScrimPainter({required this.highlight, required this.color, required this.ring});

  final Rect highlight;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(highlight, const Radius.circular(CoeloRadius.md));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawRRect(
      hole,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = CoeloSpacing.spaceHalf
        ..color = ring,
    );
  }

  @override
  bool shouldRepaint(_CoeloTourScrimPainter oldDelegate) =>
      highlight != oldDelegate.highlight || color != oldDelegate.color || ring != oldDelegate.ring;
}

/// Em tela larga: à direita da âncora, senão à esquerda, senão abaixo/acima;
/// sempre dentro da margem. Em tela estreita: folha inferior de largura total.
final class _CoeloTourBalloonLayout extends SingleChildLayoutDelegate {
  const _CoeloTourBalloonLayout({
    required this.anchor,
    required this.narrow,
    required this.sheetAtTop,
  });

  final Rect anchor;
  final bool narrow;
  final bool sheetAtTop;

  static const _width = 320.0;
  static const _gap = CoeloSpacing.space3;
  static const _margin = CoeloSpacing.space4;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => narrow
      ? BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight)
      : BoxConstraints(
          maxWidth: _width.clamp(0, constraints.maxWidth - 2 * _margin),
          maxHeight: constraints.maxHeight - 2 * _margin,
        );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    if (narrow) return Offset(0, sheetAtTop ? 0 : size.height - childSize.height);
    double clampY(double y) =>
        y.clamp(_margin, (size.height - childSize.height - _margin).clamp(_margin, size.height));
    if (anchor.right + _gap + childSize.width <= size.width - _margin) {
      return Offset(anchor.right + _gap, clampY(anchor.top));
    }
    if (anchor.left - _gap - childSize.width >= _margin) {
      return Offset(anchor.left - _gap - childSize.width, clampY(anchor.top));
    }
    final x = anchor.left.clamp(
      _margin,
      (size.width - childSize.width - _margin).clamp(_margin, size.width),
    );
    if (anchor.bottom + _gap + childSize.height <= size.height - _margin) {
      return Offset(x, anchor.bottom + _gap);
    }
    return Offset(x, clampY(anchor.top - _gap - childSize.height));
  }

  @override
  bool shouldRelayout(_CoeloTourBalloonLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      narrow != oldDelegate.narrow ||
      sheetAtTop != oldDelegate.sheetAtTop;
}

final class _CoeloTourBalloon extends StatelessWidget {
  const _CoeloTourBalloon({
    required this.focusNode,
    required this.step,
    required this.position,
    required this.total,
    required this.narrow,
    required this.sheetAtTop,
    required this.onBack,
    required this.onNext,
    required this.onSkip,
    required this.isLast,
  });

  final FocusNode focusNode;
  final CoeloTourStep step;
  final int position;
  final int total;
  final bool narrow;
  final bool sheetAtTop;
  final VoidCallback? onBack;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final counter = '$position de $total';
    final body = Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space2),
          Text(step.text, style: theme.textTheme.bodyMedium),
          const SizedBox(height: CoeloSpacing.space4),
          Row(
            children: [
              Text(
                counter,
                key: const Key('coelo-tour-counter'),
                style: theme.textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const Spacer(),
              TextButton(
                key: const Key('coelo-tour-skip'),
                onPressed: onSkip,
                child: const Text('Pular tour'),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space2),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                key: const Key('coelo-tour-back'),
                onPressed: onBack,
                child: const Text('Voltar'),
              ),
              const SizedBox(width: CoeloSpacing.space2),
              FilledButton(
                key: const Key('coelo-tour-next'),
                onPressed: onNext,
                child: Text(isLast ? 'Concluir' : 'Próximo'),
              ),
            ],
          ),
        ],
      ),
    );
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): onSkip,
        const SingleActivator(LogicalKeyboardKey.enter): onNext,
        const SingleActivator(LogicalKeyboardKey.arrowRight): onNext,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => onBack?.call(),
      },
      child: Focus(
        focusNode: focusNode,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: '${step.title}. $counter.',
          child: Material(
            key: const Key('coelo-tour-balloon'),
            color: colors.surface,
            surfaceTintColor: Colors.transparent,
            elevation: CoeloElevation.level3,
            shadowColor: colors.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: !narrow
                  ? BorderRadius.circular(CoeloRadius.lg)
                  : sheetAtTop
                  ? const BorderRadius.vertical(bottom: Radius.circular(CoeloRadius.xl))
                  : const BorderRadius.vertical(top: Radius.circular(CoeloRadius.xl)),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: narrow ? SafeArea(top: sheetAtTop, bottom: !sheetAtTop, child: body) : body,
          ),
        ),
      ),
    );
  }
}
