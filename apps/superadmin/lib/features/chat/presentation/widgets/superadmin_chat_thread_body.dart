import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../chat_fixtures.dart';

final class SuperadminChatThreadBody extends StatefulWidget {
  const SuperadminChatThreadBody({required this.conversation, this.compact = false, super.key});

  final SuperadminChatConversation conversation;
  final bool compact;

  @override
  State<SuperadminChatThreadBody> createState() => _SuperadminChatThreadBodyState();
}

final class _SuperadminChatThreadBodyState extends State<SuperadminChatThreadBody> {
  final _composerController = TextEditingController();
  final _timers = <Timer>[];
  late List<_SimulatedMessage> _messages;
  String? _activityLabel;

  @override
  void initState() {
    super.initState();
    _messages = _initialMessages();
  }

  @override
  void didUpdateWidget(covariant SuperadminChatThreadBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversation.id != widget.conversation.id) {
      _cancelTimers();
      _composerController.clear();
      _messages = _initialMessages();
      _activityLabel = null;
    }
  }

  @override
  void dispose() {
    _cancelTimers();
    _composerController.dispose();
    super.dispose();
  }

  void _cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  List<_SimulatedMessage> _initialMessages() {
    return [
      const _SimulatedMessage(
        direction: CoeloMessageDirection.received,
        authorLabel: 'Marina · Professora',
        contextLabel: 'Turma Girassol',
        body: 'A atividade terminou e correu tudo bem.',
        timestamp: '10:32',
        childLabels: ['Lia'],
      ),
      const _SimulatedMessage(
        direction: CoeloMessageDirection.sent,
        contextLabel: 'Superadmin · contexto histórico',
        body: 'Obrigada. A família já foi avisada.',
        timestamp: '10:34',
        childLabels: ['Lia'],
        deliveryState: CoeloMessageDeliveryState.read,
      ),
    ];
  }

  void _sendText() {
    final body = _composerController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _messages.add(
        _SimulatedMessage(
          direction: CoeloMessageDirection.sent,
          body: body,
          timestamp: 'Agora',
          deliveryState: CoeloMessageDeliveryState.delivered,
        ),
      );
      _composerController.clear();
      _activityLabel = 'Enviando mensagem…';
    });
    _timers.add(
      Timer(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _activityLabel = 'Marina está digitando…');
      }),
    );
    _timers.add(
      Timer(const Duration(milliseconds: 1300), () {
        if (!mounted) return;
        setState(() {
          _messages.add(
            const _SimulatedMessage(
              direction: CoeloMessageDirection.received,
              authorLabel: 'Marina · Professora',
              contextLabel: 'Turma Girassol',
              body: 'Recebi sua mensagem. Vou verificar e retorno por aqui.',
              timestamp: 'Agora',
            ),
          );
          _activityLabel = null;
        });
      }),
    );
  }

  void _recordAudio() {
    setState(() => _activityLabel = 'Gravando áudio…');
    _timers.add(
      Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _activityLabel = 'Enviando áudio…');
      }),
    );
    _timers.add(
      Timer(const Duration(milliseconds: 1700), () {
        if (!mounted) return;
        setState(() {
          _messages.add(
            const _SimulatedMessage(
              direction: CoeloMessageDirection.sent,
              body: 'Mensagem de áudio · 0:08',
              timestamp: 'Agora',
              deliveryState: CoeloMessageDeliveryState.delivered,
            ),
          );
          _activityLabel = null;
        });
      }),
    );
  }

  void _attachMedia() {
    setState(() => _activityLabel = 'Carregando mídia… 48%');
    _timers.add(
      Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _activityLabel = 'Enviando mídia…');
      }),
    );
    _timers.add(
      Timer(const Duration(milliseconds: 1700), () {
        if (!mounted) return;
        setState(() {
          _messages.add(
            const _SimulatedMessage(
              direction: CoeloMessageDirection.sent,
              body: 'Imagem anexada · demonstração local',
              timestamp: 'Agora',
              deliveryState: CoeloMessageDeliveryState.delivered,
            ),
          );
          _activityLabel = null;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(widget.compact ? CoeloSpacing.space3 : CoeloSpacing.space4),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return CoeloMessageBubble(
                direction: message.direction,
                body: message.body,
                timestamp: message.timestamp,
                authorLabel: message.authorLabel,
                contextLabel: message.contextLabel,
                childLabels: message.childLabels,
                deliveryState: message.deliveryState,
              );
            },
          ),
        ),
        Semantics(
          liveRegion: true,
          child: SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _activityLabel == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space3),
                      child: Text(
                        _activityLabel!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        CoeloChatComposer(
          controller: _composerController,
          onSend: _sendText,
          showAudioAction: true,
          showMediaAction: true,
          onAudioPressed: _recordAudio,
          onMediaPressed: _attachMedia,
        ),
      ],
    );
  }
}

final class _SimulatedMessage {
  const _SimulatedMessage({
    required this.direction,
    required this.body,
    required this.timestamp,
    this.authorLabel,
    this.contextLabel,
    this.childLabels = const [],
    this.deliveryState = CoeloMessageDeliveryState.none,
  });

  final CoeloMessageDirection direction;
  final String body;
  final String timestamp;
  final String? authorLabel;
  final String? contextLabel;
  final List<String> childLabels;
  final CoeloMessageDeliveryState deliveryState;
}
