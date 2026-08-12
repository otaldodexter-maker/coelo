import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/routine_contract.dart';

typedef RoutineReorder = void Function(int oldIndex, int newIndex);

final class DailyRoutineOrderedEditor extends StatelessWidget {
  const DailyRoutineOrderedEditor({
    required this.sections,
    required this.enabled,
    required this.onAddSection,
    required this.onEditSection,
    required this.onDuplicateSection,
    required this.onRemoveSection,
    required this.onReorderSections,
    required this.onAddField,
    required this.onEditField,
    required this.onDuplicateField,
    required this.onRemoveField,
    required this.onReorderFields,
    required this.onAddChildField,
    super.key,
  });

  final List<RoutineSection> sections;
  final bool enabled;
  final VoidCallback? onAddSection;
  final ValueChanged<RoutineSection> onEditSection;
  final ValueChanged<RoutineSection> onDuplicateSection;
  final ValueChanged<RoutineSection> onRemoveSection;
  final RoutineReorder onReorderSections;
  final ValueChanged<RoutineSection> onAddField;
  final void Function(RoutineSection, RoutineField) onEditField;
  final void Function(RoutineSection, RoutineField) onDuplicateField;
  final void Function(RoutineSection, RoutineField) onRemoveField;
  final void Function(RoutineSection, int, int) onReorderFields;
  final void Function(RoutineSection, RoutineField) onAddChildField;

  @override
  Widget build(BuildContext context) {
    final ordered = [...sections]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Column(
      key: const Key('daily-routine-ordered-editor'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (ordered.isEmpty)
          const CoeloStatePanel(
            title: 'Nenhuma secao configurada',
            message: 'Adicione a primeira secao para definir os campos da rotina.',
            icon: Icons.view_agenda_outlined,
          )
        else
          ReorderableListView.builder(
            key: const Key('daily-routine-section-list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: ordered.length,
            onReorderItem: enabled ? onReorderSections : (_, _) {},
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: MediaQuery.disableAnimationsOf(context) ? 0 : 2,
              child: child,
            ),
            itemBuilder: (context, index) {
              final section = ordered[index];
              return Padding(
                key: ValueKey('daily-routine-section-${section.id}'),
                padding: EdgeInsets.only(
                  bottom: index == ordered.length - 1 ? 0 : CoeloSpacing.space3,
                ),
                child: _SectionCard(
                  section: section,
                  index: index,
                  count: ordered.length,
                  enabled: enabled,
                  onEdit: () => onEditSection(section),
                  onDuplicate: () => onDuplicateSection(section),
                  onRemove: () => onRemoveSection(section),
                  onMoveUp: index == 0 ? null : () => onReorderSections(index, index - 1),
                  onMoveDown: index == ordered.length - 1
                      ? null
                      : () => onReorderSections(index, index + 1),
                  onAddField: () => onAddField(section),
                  onEditField: (field) => onEditField(section, field),
                  onDuplicateField: (field) => onDuplicateField(section, field),
                  onRemoveField: (field) => onRemoveField(section, field),
                  onReorderFields: (oldIndex, newIndex) =>
                      onReorderFields(section, oldIndex, newIndex),
                  onAddChildField: (field) => onAddChildField(section, field),
                ),
              );
            },
          ),
        const SizedBox(height: CoeloSpacing.space3),
        OutlinedButton.icon(
          key: const Key('daily-routine-add-section'),
          onPressed: enabled ? onAddSection : null,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Adicionar secao'),
        ),
      ],
    );
  }
}

final class _SectionCard extends StatefulWidget {
  const _SectionCard({
    required this.section,
    required this.index,
    required this.count,
    required this.enabled,
    required this.onEdit,
    required this.onDuplicate,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onAddField,
    required this.onEditField,
    required this.onDuplicateField,
    required this.onRemoveField,
    required this.onReorderFields,
    required this.onAddChildField,
  });

  final RoutineSection section;
  final int index;
  final int count;
  final bool enabled;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onAddField;
  final ValueChanged<RoutineField> onEditField;
  final ValueChanged<RoutineField> onDuplicateField;
  final ValueChanged<RoutineField> onRemoveField;
  final RoutineReorder onReorderFields;
  final ValueChanged<RoutineField> onAddChildField;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

final class _SectionCardState extends State<_SectionCard> {
  var expanded = true;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final fields = [...section.fields]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return CoeloAdminInteractiveCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CoeloSpacing.space6,
          vertical: CoeloSpacing.space4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  key: Key('daily-routine-section-${section.id}-drag-handle'),
                  index: widget.index,
                  enabled: widget.enabled,
                  child: const _DragHandle(label: 'Reordenar secao'),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.index + 1}. ${section.name}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        fields.isEmpty ? 'Nenhum campo' : '${fields.length} campo(s)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _Action(
                  tooltip: expanded ? 'Recolher secao' : 'Expandir secao',
                  onPressed: () => setState(() => expanded = !expanded),
                  icon: expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: CoeloSpacing.space1,
              runSpacing: CoeloSpacing.space1,
              children: [
                _Action(
                  key: Key('daily-routine-section-${section.id}-move-up'),
                  tooltip: 'Mover secao para cima',
                  onPressed: widget.enabled ? widget.onMoveUp : null,
                  icon: Icons.keyboard_arrow_up_rounded,
                ),
                _Action(
                  key: Key('daily-routine-section-${section.id}-move-down'),
                  tooltip: 'Mover secao para baixo',
                  onPressed: widget.enabled ? widget.onMoveDown : null,
                  icon: Icons.keyboard_arrow_down_rounded,
                ),
                _Action(
                  tooltip: 'Duplicar secao',
                  onPressed: widget.enabled ? widget.onDuplicate : null,
                  icon: Icons.content_copy_rounded,
                ),
                _Action(
                  tooltip: 'Editar secao',
                  onPressed: widget.enabled ? widget.onEdit : null,
                  icon: Icons.edit_outlined,
                ),
                _Action(
                  tooltip: 'Remover secao',
                  onPressed: widget.enabled ? widget.onRemove : null,
                  icon: Icons.delete_outline_rounded,
                  negative: true,
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: CoeloSpacing.space3),
              if (fields.isEmpty)
                const Text('Adicione um campo para comecar.')
              else
                ReorderableListView.builder(
                  key: Key('daily-routine-section-${section.id}-field-list'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  itemCount: fields.length,
                  onReorderItem: widget.enabled ? widget.onReorderFields : (_, _) {},
                  itemBuilder: (context, index) {
                    final field = fields[index];
                    return Padding(
                      key: ValueKey('daily-routine-field-${field.id}'),
                      padding: EdgeInsets.only(
                        bottom: index == fields.length - 1 ? 0 : CoeloSpacing.space2,
                      ),
                      child: _FieldRow(
                        field: field,
                        index: index,
                        count: fields.length,
                        enabled: widget.enabled,
                        onMoveUp: index == 0
                            ? null
                            : () => widget.onReorderFields(index, index - 1),
                        onMoveDown: index == fields.length - 1
                            ? null
                            : () => widget.onReorderFields(index, index + 1),
                        onAddChild: _depth(field) >= 4 ? null : () => widget.onAddChildField(field),
                        onEdit: () => widget.onEditField(field),
                        onDuplicate: () => widget.onDuplicateField(field),
                        onRemove: () => widget.onRemoveField(field),
                      ),
                    );
                  },
                ),
              const SizedBox(height: CoeloSpacing.space3),
              OutlinedButton.icon(
                key: Key('daily-routine-section-${section.id}-add-field'),
                onPressed: widget.enabled ? widget.onAddField : null,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Adicionar campo'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _FieldRow extends StatelessWidget {
  const _FieldRow({
    required this.field,
    required this.index,
    required this.count,
    required this.enabled,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onAddChild,
    required this.onEdit,
    required this.onDuplicate,
    required this.onRemove,
  });

  final RoutineField field;
  final int index;
  final int count;
  final bool enabled;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onAddChild;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space2),
        child: Column(
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  key: Key('daily-routine-field-${field.id}-drag-handle'),
                  index: index,
                  enabled: enabled,
                  child: const _DragHandle(label: 'Reordenar campo'),
                ),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${index + 1}. ${field.label}'),
                      Text(
                        '${_kindLabel(field.kind)} - ${field.isRequired ? 'Obrigatorio' : 'Opcional'}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: CoeloSpacing.space1,
              runSpacing: CoeloSpacing.space1,
              children: [
                _Action(
                  key: Key('daily-routine-field-${field.id}-move-up'),
                  tooltip: 'Mover campo para cima',
                  onPressed: enabled ? onMoveUp : null,
                  icon: Icons.keyboard_arrow_up_rounded,
                ),
                _Action(
                  key: Key('daily-routine-field-${field.id}-move-down'),
                  tooltip: 'Mover campo para baixo',
                  onPressed: enabled ? onMoveDown : null,
                  icon: Icons.keyboard_arrow_down_rounded,
                ),
                _Action(
                  tooltip: 'Adicionar campo filho',
                  onPressed: enabled ? onAddChild : null,
                  icon: Icons.account_tree_outlined,
                ),
                _Action(
                  tooltip: 'Duplicar campo',
                  onPressed: enabled ? onDuplicate : null,
                  icon: Icons.content_copy_rounded,
                ),
                _Action(
                  tooltip: 'Editar campo',
                  onPressed: enabled ? onEdit : null,
                  icon: Icons.edit_outlined,
                ),
                _Action(
                  tooltip: 'Remover campo',
                  onPressed: enabled ? onRemove : null,
                  icon: Icons.delete_outline_rounded,
                  negative: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    button: true,
    child: const SizedBox.square(
      dimension: CoeloSize.touchMin,
      child: Icon(Icons.drag_indicator_rounded),
    ),
  );
}

final class _Action extends StatelessWidget {
  const _Action({
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

int _depth(RoutineField field) {
  var result = 0;
  for (final condition in field.conditions) {
    if (condition.depth > result) result = condition.depth;
  }
  return result;
}

String _kindLabel(RoutineFieldKind kind) => switch (kind) {
  RoutineFieldKind.shortText => 'Texto curto',
  RoutineFieldKind.longText => 'Texto longo',
  RoutineFieldKind.number => 'Numero',
  RoutineFieldKind.boolean => 'Sim/Nao',
  RoutineFieldKind.singleChoice => 'Escolha unica',
  RoutineFieldKind.multipleChoice => 'Escolha multipla',
};
