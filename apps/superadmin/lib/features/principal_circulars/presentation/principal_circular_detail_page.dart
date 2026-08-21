import 'dart:math';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import '../domain/circular_repository.dart';
import 'principal_circular_reader.dart';

final class PrincipalCircularDetailPage extends StatefulWidget {
  const PrincipalCircularDetailPage({
    required this.circularId,
    required this.repository,
    required this.responseRepository,
    this.childContextId,
    super.key,
  });

  final String circularId;
  final String? childContextId;
  final CircularRepository repository;
  final CircularResponseRepository responseRepository;

  @override
  State<PrincipalCircularDetailPage> createState() => _PrincipalCircularDetailPageState();
}

final class _PrincipalCircularDetailPageState extends State<PrincipalCircularDetailPage> {
  CircularDetail? _detail;
  Object? _error;
  var _loading = true;
  var _responseVersion = 0;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await widget.repository.getVisible(
        widget.circularId,
        childContextId: widget.childContextId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _sessionId = detail.responseSessionId;
        _responseVersion = detail.responseVersion;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _submit(Map<String, List<String>> answers) async {
    final detail = _detail!;
    final draft = await widget.responseRepository.saveDraft(
      requestId: _uuid(),
      revisionId: detail.revisionId,
      childContextId: widget.childContextId,
      answers: answers,
      expectedVersion: _responseVersion,
    );
    _sessionId = draft.sessionId;
    _responseVersion = draft.version;
    final submitted = await widget.responseRepository.submit(
      requestId: _uuid(),
      sessionId: _sessionId!,
      expectedVersion: _responseVersion,
    );
    _responseVersion = submitted.version;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: AppBar(
      title: const Text('Circular'),
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    body: _body(),
  );

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
      detail: _detail!,
      initialAnswers: _detail!.initialAnswers,
      onSubmit: _submit,
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
