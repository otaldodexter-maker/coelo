import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class SuperadminChatComposer extends StatefulWidget {
  const SuperadminChatComposer({
    required this.controller,
    required this.onSend,
    required this.onEmoji,
    required this.onAudio,
    required this.onImage,
    this.compact = false,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onEmoji;
  final VoidCallback onAudio;
  final VoidCallback onImage;
  final bool compact;

  @override
  State<SuperadminChatComposer> createState() => _SuperadminChatComposerState();
}

final class _SuperadminChatComposerState extends State<SuperadminChatComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SuperadminChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _send() {
    if (widget.controller.text.trim().isNotEmpty) widget.onSend();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored;
    _send();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? CoeloSpacing.space2 : CoeloSpacing.space3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _Action(
              icon: Icons.emoji_emotions_outlined,
              label: 'Adicionar emoji',
              onTap: widget.onEmoji,
            ),
            Expanded(
              child: Focus(
                onKeyEvent: _onKey,
                child: TextField(
                  key: const Key('superadmin-chat-composer-field'),
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: widget.compact ? 3 : 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Mensagem',
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(CoeloRadius.xl),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(CoeloRadius.xl),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
            if (!widget.compact) ...[
              _Action(icon: Icons.mic_none_rounded, label: 'Gravar áudio', onTap: widget.onAudio),
              _Action(icon: Icons.image_outlined, label: 'Adicionar imagem', onTap: widget.onImage),
            ],
            const SizedBox(width: CoeloSpacing.space1),
            IconButton(
              key: const Key('superadmin-chat-send'),
              tooltip: 'Enviar mensagem',
              onPressed: enabled ? _send : null,
              constraints: const BoxConstraints.tightFor(
                width: CoeloSize.touchMin,
                height: CoeloSize.touchMin,
              ),
              style: ButtonStyle(
                shape: const WidgetStatePropertyAll(CircleBorder()),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => enabled ? colors.primary : colors.surfaceContainerHighest,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => enabled ? colors.onPrimary : colors.onSurfaceVariant,
                ),
                overlayColor: WidgetStatePropertyAll(colors.onPrimary.withValues(alpha: 0.12)),
              ),
              icon: const Icon(Icons.send_rounded, size: CoeloSize.iconMd),
            ),
          ],
        ),
      ),
    );
  }
}

final class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(
        width: CoeloSize.touchMin,
        height: CoeloSize.touchMin,
      ),
      icon: Icon(icon, size: CoeloSize.iconMd),
    );
  }
}
