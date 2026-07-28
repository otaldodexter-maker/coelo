import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class SupportReplyComposer extends StatefulWidget {
  const SupportReplyComposer({
    required this.controller,
    required this.onSend,
    this.hintText = 'Responder ao chamado',
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;

  @override
  State<SupportReplyComposer> createState() => _SupportReplyComposerState();
}

final class _SupportReplyComposerState extends State<SupportReplyComposer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant SupportReplyComposer oldWidget) {
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
    if (widget.controller.text.trim().isEmpty) return;
    widget.onSend();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.enter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _send();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final canSend = widget.controller.text.trim().isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Focus(
                onKeyEvent: _handleKey,
                child: TextField(
                  controller: widget.controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: CoeloSpacing.space2),
            IconButton(
              tooltip: 'Enviar mensagem',
              onPressed: canSend ? _send : null,
              constraints: const BoxConstraints.tightFor(
                width: CoeloSize.touchMin,
                height: CoeloSize.touchMin,
              ),
              style: IconButton.styleFrom(
                backgroundColor: canSend ? colors.primary : colors.surfaceContainerHighest,
                foregroundColor: canSend ? colors.onPrimary : colors.onSurfaceVariant,
              ),
              icon: const Icon(Icons.send_rounded, size: CoeloSize.iconMd),
            ),
          ],
        ),
      ),
    );
  }
}
