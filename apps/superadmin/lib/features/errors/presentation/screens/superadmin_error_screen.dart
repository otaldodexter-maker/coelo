import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

enum SuperadminErrorKind {
  forbidden(
    code: '403',
    message: 'Você não tem permissão para acessar esta área.',
    actionLabel: 'Voltar ao início',
  ),
  notFound(
    code: '404',
    message: 'Não encontramos a página que você procura.',
    actionLabel: 'Voltar ao início',
  ),
  conflict(
    code: '409',
    message: 'Esta ação não pode ser concluída no estado atual.',
    actionLabel: 'Voltar ao início',
  ),
  internal(
    code: '500',
    message: 'Não foi possível concluir esta ação.',
    actionLabel: 'Tentar novamente',
  ),
  unavailable(
    code: '503',
    message: 'O Coelo está temporariamente indisponível.',
    actionLabel: 'Tentar novamente',
  );

  const SuperadminErrorKind({required this.code, required this.message, required this.actionLabel});

  final String code;
  final String message;
  final String actionLabel;

  static SuperadminErrorKind fromCode(String? code) {
    return SuperadminErrorKind.values.firstWhere(
      (kind) => kind.code == code,
      orElse: () => SuperadminErrorKind.notFound,
    );
  }
}

final class SuperadminErrorScreen extends StatefulWidget {
  const SuperadminErrorScreen({
    required this.kind,
    required this.onAction,
    this.actionLabel,
    super.key,
  });

  final SuperadminErrorKind kind;
  final FutureOr<void> Function() onAction;
  final String? actionLabel;

  @override
  State<SuperadminErrorScreen> createState() => _SuperadminErrorScreenState();
}

final class _SuperadminErrorScreenState extends State<SuperadminErrorScreen> {
  final _actionFocus = FocusNode();
  var _running = false;
  var _actionFailed = false;
  var _revision = 0;

  @override
  void didUpdateWidget(covariant SuperadminErrorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onAction != widget.onAction || oldWidget.kind != widget.kind) {
      _revision++;
      _running = false;
      _actionFailed = false;
    }
  }

  Future<void> _runAction() async {
    if (_running) return;
    final revision = _revision;
    final restoreFocus = _actionFocus.hasFocus;
    setState(() {
      _running = true;
      _actionFailed = false;
    });
    var failed = false;
    try {
      await widget.onAction();
    } on Object {
      failed = true;
    }
    if (!mounted || revision != _revision) return;
    setState(() {
      _running = false;
      _actionFailed = failed;
    });
    if (restoreFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || revision != _revision) return;
        final current = FocusManager.instance.primaryFocus;
        if (current == null || current is FocusScopeNode || current == _actionFocus) {
          _actionFocus.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _revision++;
    _actionFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final message = _actionFailed ? 'Não foi possível concluir esta ação.' : kind.message;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.primaryContainer,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final useHorizontalLayout =
                constraints.maxWidth > CoeloBreakpoints.compact.maxWidth && textScale <= 1.5;
            final horizontalPadding = useHorizontalLayout
                ? CoeloSpacing.space10
                : CoeloSpacing.space4;

            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: CoeloSpacing.space8,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        container: true,
                        liveRegion: _actionFailed,
                        label: 'Erro ${kind.code}. $message',
                        child: ExcludeSemantics(
                          child: useHorizontalLayout
                              ? _HorizontalErrorContent(
                                  kind: kind,
                                  message: message,
                                  color: colorScheme.onPrimaryContainer,
                                  textTheme: textTheme,
                                )
                              : _VerticalErrorContent(
                                  kind: kind,
                                  message: message,
                                  color: colorScheme.onPrimaryContainer,
                                  textTheme: textTheme,
                                ),
                        ),
                      ),
                      const SizedBox(height: CoeloSpacing.space6),
                      TextButton(
                        focusNode: _actionFocus,
                        onPressed: _running ? null : _runAction,
                        style: TextButton.styleFrom(
                          foregroundColor: colorScheme.onPrimaryContainer,
                        ),
                        child: Semantics(
                          liveRegion: _running,
                          child: Text(
                            _running ? 'Aguarde…' : widget.actionLabel ?? kind.actionLabel,
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
      ),
    );
  }
}

final class _HorizontalErrorContent extends StatelessWidget {
  const _HorizontalErrorContent({
    required this.kind,
    required this.message,
    required this.color,
    required this.textTheme,
  });

  final SuperadminErrorKind kind;
  final String message;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(kind.code, style: textTheme.titleMedium?.copyWith(color: color)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            child: VerticalDivider(color: color),
          ),
          Flexible(
            child: Text(message, style: textTheme.bodyLarge?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }
}

final class _VerticalErrorContent extends StatelessWidget {
  const _VerticalErrorContent({
    required this.kind,
    required this.message,
    required this.color,
    required this.textTheme,
  });

  final SuperadminErrorKind kind;
  final String message;
  final Color color;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(kind.code, style: textTheme.titleMedium?.copyWith(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
          child: Divider(color: color),
        ),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}
