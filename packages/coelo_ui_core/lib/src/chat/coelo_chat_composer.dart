import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class CoeloChatComposer extends StatefulWidget {
  const CoeloChatComposer({
    required this.controller,
    required this.onSend,
    this.enabled = true,
    this.hintText = 'Mensagem',
    this.showMediaAction = false,
    this.showAudioAction = false,
    this.onMediaPressed,
    this.onAudioPressed,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;
  final String hintText;
  final bool showMediaAction;
  final bool showAudioAction;
  final VoidCallback? onMediaPressed;
  final VoidCallback? onAudioPressed;

  @override
  State<CoeloChatComposer> createState() => _CoeloChatComposerState();
}

final class _CoeloChatComposerState extends State<CoeloChatComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant CoeloChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _canSend => widget.enabled && widget.controller.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.sentiment_satisfied_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
                  ),
                ),
              ),
              if (widget.showAudioAction)
                IconButton(
                  tooltip: widget.onAudioPressed == null ? 'Áudio · Em breve' : 'Gravar áudio',
                  onPressed: widget.enabled ? widget.onAudioPressed : null,
                  icon: const Icon(Icons.mic_none_outlined),
                ),
              if (widget.showMediaAction)
                IconButton(
                  tooltip: widget.onMediaPressed == null ? 'Mídia · Em breve' : 'Adicionar mídia',
                  onPressed: widget.enabled ? widget.onMediaPressed : null,
                  icon: const Icon(Icons.image_outlined),
                ),
              IconButton(
                tooltip: 'Enviar mensagem',
                onPressed: _canSend ? widget.onSend : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
