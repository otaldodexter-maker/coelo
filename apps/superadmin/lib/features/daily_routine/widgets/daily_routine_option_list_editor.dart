import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/routine_contract.dart';

final class DailyRoutineOptionListEditor extends StatelessWidget {
  const DailyRoutineOptionListEditor({
    required this.options,
    required this.enabled,
    required this.onAdd,
    required this.onLabelChanged,
    required this.onRemove,
    required this.onReorder,
    super.key,
  });

  final List<RoutineFieldOption> options;
  final bool enabled;
  final VoidCallback onAdd;
  final void Function(RoutineFieldOption option, String label) onLabelChanged;
  final ValueChanged<RoutineFieldOption> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final ordered = [...options]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      key: const Key('daily-routine-option-list'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < ordered.length; index++) ...[
          _OptionRow(
            key: ValueKey('daily-routine-option-row-${ordered[index].id}'),
            option: ordered[index],
            index: index,
            count: ordered.length,
            enabled: enabled,
            onLabelChanged: (label) => onLabelChanged(ordered[index], label),
            onRemove: () => onRemove(ordered[index]),
            onMoveUp: index == 0 ? null : () => onReorder(index, index - 1),
            onMoveDown: index == ordered.length - 1 ? null : () => onReorder(index, index + 2),
          ),
          if (index != ordered.length - 1) const SizedBox(height: CoeloSpacing.space2),
        ],
        const SizedBox(height: CoeloSpacing.space2),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('daily-routine-add-option'),
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar opcao'),
          ),
        ),
      ],
    );
  }
}

final class _OptionRow extends StatefulWidget {
  const _OptionRow({
    required this.option,
    required this.index,
    required this.count,
    required this.enabled,
    required this.onLabelChanged,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    super.key,
  });

  final RoutineFieldOption option;
  final int index;
  final int count;
  final bool enabled;
  final ValueChanged<String> onLabelChanged;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

final class _OptionRowState extends State<_OptionRow> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.option.label);
  }

  @override
  void didUpdateWidget(covariant _OptionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.option.label != widget.option.label && controller.text != widget.option.label) {
      controller.text = widget.option.label;
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: CoeloFormTextField(
          fieldKey: Key('daily-routine-option-${widget.index}'),
          controller: controller,
          labelText: 'Opcao ${widget.index + 1}',
          prefixIcon: Icons.radio_button_unchecked_rounded,
          enabled: widget.enabled,
          onChanged: widget.onLabelChanged,
        ),
      ),
      const SizedBox(width: CoeloSpacing.space1),
      _OptionAction(
        key: Key('daily-routine-option-${widget.index}-move-up'),
        tooltip: 'Mover opcao para cima',
        onPressed: widget.enabled ? widget.onMoveUp : null,
        icon: Icons.keyboard_arrow_up_rounded,
      ),
      _OptionAction(
        key: Key('daily-routine-option-${widget.index}-move-down'),
        tooltip: 'Mover opcao para baixo',
        onPressed: widget.enabled ? widget.onMoveDown : null,
        icon: Icons.keyboard_arrow_down_rounded,
      ),
      _OptionAction(
        key: Key('daily-routine-option-${widget.index}-remove'),
        tooltip: 'Remover opcao',
        onPressed: widget.enabled ? widget.onRemove : null,
        icon: Icons.delete_outline_rounded,
        negative: true,
      ),
    ],
  );
}

final class _OptionAction extends StatelessWidget {
  const _OptionAction({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.negative = false,
    super.key,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool negative;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    color: negative ? Theme.of(context).colorScheme.error : null,
    style: const ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
      overlayColor: WidgetStatePropertyAll(Colors.transparent),
    ),
    icon: Icon(icon),
  );
}
