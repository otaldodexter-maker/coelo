import 'dart:math';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/circular_repository.dart';
import 'principal_circular_reader.dart';

final class PrincipalCircularDetailPage extends StatefulWidget {
  const PrincipalCircularDetailPage({
    required this.circularId,
    required this.repository,
    required this.responseRepository,
    this.childContextId,
    this.onReturn,
    this.embedded = false,
    super.key,
  });

  final String circularId;
  final String? childContextId;
  final CircularRepository repository;
  final CircularResponseRepository responseRepository;
  final VoidCallback? onReturn;

  /// Marks the reading surface as hosted inside the Superadmin shell content
  /// area. The host keeps its own shell/menu visible (Owner decision of
  /// 2026-09-09) and already consumed the system insets, so the compact
  /// reading state stops behaving as if it owned the whole window.
  final bool embedded;

  @override
  State<PrincipalCircularDetailPage> createState() => _PrincipalCircularDetailPageState();
}

final class _PrincipalCircularDetailPageState extends State<PrincipalCircularDetailPage> {
  CircularDetail? _detail;
  Object? _error;
  var _loading = true;
  var _responseVersion = 0;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrincipalCircularDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circularId != widget.circularId ||
        oldWidget.childContextId != widget.childContextId ||
        !identical(oldWidget.repository, widget.repository) ||
        !identical(oldWidget.responseRepository, widget.responseRepository)) {
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _detail = null;
      _responseVersion = 0;
    });
    try {
      final detail = await widget.repository.getVisible(
        widget.circularId,
        childContextId: widget.childContextId,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _detail = detail;
        _responseVersion = detail.responseVersion;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _submit(Map<String, List<String>> answers) async {
    final detail = _detail!;
    final generation = _generation;
    final responses = widget.responseRepository;
    try {
      final draft = await responses.saveDraft(
        requestId: _uuid(),
        revisionId: detail.revisionId,
        childContextId: widget.childContextId,
        answers: answers,
        expectedVersion: _responseVersion,
      );
      if (!mounted || generation != _generation) return;
      _responseVersion = draft.version;
      final submitted = await responses.submit(
        requestId: _uuid(),
        sessionId: draft.sessionId,
        expectedVersion: _responseVersion,
      );
      if (!mounted || generation != _generation) return;
      _responseVersion = submitted.version;
    } on CircularUnauthorized catch (error) {
      if (mounted && generation == _generation) {
        _generation++;
        setState(() {
          _detail = null;
          _responseVersion = 0;
          _error = error;
          _loading = false;
        });
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {const SingleActivator(LogicalKeyboardKey.escape): _return},
    child: Focus(
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          return Scaffold(
            backgroundColor: Theme.of(context).colorScheme.surface,
            appBar: compact
                ? null
                : AppBar(
                    leading: IconButton(
                      tooltip: 'Voltar para Circulares',
                      onPressed: _return,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    title: const Text('Circular'),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    surfaceTintColor: Colors.transparent,
                    scrolledUnderElevation: 0,
                  ),
            body: compact
                ? SafeArea(
                    top: !widget.embedded,
                    bottom: !widget.embedded,
                    left: !widget.embedded,
                    right: !widget.embedded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('principal-circular-contextual-return'),
                            onPressed: _return,
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('Circular'),
                          ),
                        ),
                        Expanded(child: _body()),
                      ],
                    ),
                  )
                : _body(),
          );
        },
      ),
    ),
  );

  void _return() {
    final callback = widget.onReturn;
    if (callback != null) {
      callback();
      return;
    }
    Navigator.of(context).maybePop();
  }

  Widget _body() {
    if (_loading) {
      return const Center(key: Key('circular-detail-loading'), child: CircularProgressIndicator());
    }
    if (_error case final error?) {
      final unauthorized = error is CircularUnauthorized;
      final notAvailable = error is CircularNotAvailable;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                unauthorized
                    ? Icons.lock_outline_rounded
                    : notAvailable
                    ? Icons.schedule_outlined
                    : Icons.cloud_off_outlined,
                size: 48,
              ),
              const SizedBox(height: CoeloSpacing.space3),
              Text(
                unauthorized
                    ? 'Você não tem acesso a esta Circular.'
                    : notAvailable
                    ? 'Esta Circular ainda não está disponível.'
                    : 'Não foi possível carregar esta Circular.',
                textAlign: TextAlign.center,
              ),
              if (!unauthorized && !notAvailable) ...[
                const SizedBox(height: CoeloSpacing.space3),
                OutlinedButton(onPressed: _load, child: const Text('Tentar novamente')),
              ],
            ],
          ),
        ),
      );
    }
    return PrincipalCircularReader(
      key: ValueKey(_generation),
      detail: _detail!,
      initialAnswers: _detail!.initialAnswers,
      onSubmit: _submit,
      embedded: widget.embedded,
    );
  }
}

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final value = bytes.map(hex).join();
  return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
}
