import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'superadmin_notice.dart';

Future<void> showSuperadminBugReportDialog(
  BuildContext context, {
  required String currentScreen,
  required Map<String, List<String>> sections,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    builder: (context) =>
        _SuperadminBugReportDialog(currentScreen: currentScreen, sections: sections),
  );
}

class _SuperadminBugReportDialog extends StatefulWidget {
  const _SuperadminBugReportDialog({required this.currentScreen, required this.sections});

  final String currentScreen;
  final Map<String, List<String>> sections;

  @override
  State<_SuperadminBugReportDialog> createState() => _SuperadminBugReportDialogState();
}

class _SuperadminBugReportDialogState extends State<_SuperadminBugReportDialog> {
  final _descriptionController = TextEditingController();
  late String _selectedMenu;
  String? _selectedScreen;
  final _otherSubjectController = TextEditingController();
  var _attached = false;

  @override
  void initState() {
    super.initState();
    _selectedMenu = widget.sections.keys.firstWhere(
      (menu) => (widget.sections[menu] ?? const <String>[]).contains(widget.currentScreen),
      orElse: () => 'Outros',
    );
    final screens = widget.sections[_selectedMenu] ?? const <String>[];
    _selectedScreen = screens.contains(widget.currentScreen)
        ? widget.currentScreen
        : (screens.isEmpty ? null : screens.first);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _otherSubjectController.dispose();
    super.dispose();
  }

  void _submit() {
    showSuperadminNotice(
      context,
      'Relato enviado com sucesso.',
      icon: Icons.check_circle_outline_rounded,
    );
    _closeDialog();
  }

  void _closeDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Dialog(
      key: const Key('superadmin-bug-report-dialog'),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(CoeloSpacing.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Bug? O Coelo resolve!', style: theme.textTheme.headlineSmall),
                  ),
                  IconButton(
                    key: const Key('superadmin-bug-report-close'),
                    tooltip: 'Fechar reporte de bug',
                    onPressed: _closeDialog,
                    style: IconButton.styleFrom(foregroundColor: colors.error),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: CoeloSpacing.space4),
              _BugSingleSelect<String>(
                key: const Key('superadmin-bug-menu'),
                value: _selectedMenu,
                items: widget.sections.keys.toList(growable: false),
                itemKey: (value) => Key('superadmin-bug-menu-option-$value'),
                onChanged: (value) {
                  final screens = widget.sections[value] ?? const <String>[];
                  setState(() {
                    _selectedMenu = value;
                    _selectedScreen = screens.isEmpty ? null : screens.first;
                  });
                },
              ),
              if (_selectedMenu == 'Outros') ...[
                const SizedBox(height: CoeloSpacing.space3),
                TextField(
                  key: const Key('superadmin-bug-other-subject'),
                  controller: _otherSubjectController,
                  decoration: const InputDecoration(hintText: 'Sobre o que é o assunto?'),
                ),
              ],
              if (_selectedMenu != 'Outros') ...[
                const SizedBox(height: CoeloSpacing.space3),
                _BugSingleSelect<String>(
                  key: const Key('superadmin-bug-screen'),
                  value: _selectedScreen!,
                  items: widget.sections[_selectedMenu] ?? const <String>[],
                  itemKey: (value) => Key('superadmin-bug-screen-option-$value'),
                  onChanged: (value) => setState(() => _selectedScreen = value),
                ),
              ],
              const SizedBox(height: CoeloSpacing.space4),
              TextField(
                key: const Key('superadmin-bug-description'),
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Digite seu texto',
                  hintText: 'Descreva o que aconteceu e o que esperava ver.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('superadmin-bug-attach'),
                  onPressed: () => setState(() => _attached = true),
                  style:
                      TextButton.styleFrom(
                        foregroundColor: colors.primary,
                        padding: EdgeInsets.zero,
                      ).copyWith(
                        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                        textStyle: WidgetStateProperty.resolveWith((states) {
                          final highlighted =
                              states.contains(WidgetState.hovered) ||
                              states.contains(WidgetState.focused);
                          return theme.textTheme.labelLarge?.copyWith(
                            decoration: highlighted
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor: colors.primary,
                          );
                        }),
                      ),
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(_attached ? 'evidencia-anexada.png' : 'Anexar Evidência'),
                ),
              ),
              Text(
                'Até 10 arquivos · PNG, JPG, JPEG, WEBP, PDF, DOCX, MP4, MOV ou WEBM.',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: CoeloSpacing.space5),
              FilledButton(
                key: const Key('superadmin-bug-submit'),
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                ),
                child: const Text('Enviar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BugSingleSelect<T> extends StatelessWidget {
  const _BugSingleSelect({
    required this.value,
    required this.items,
    required this.itemKey,
    required this.onChanged,
    super.key,
  });

  final T value;
  final List<T> items;
  final Key Function(T value) itemKey;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final label = '$value';
    return LayoutBuilder(
      builder: (context, constraints) {
        final menuWidth = constraints.maxWidth;
        return MenuAnchor(
          alignmentOffset: const Offset(0, CoeloSpacing.space1),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(colors.surface),
            elevation: const WidgetStatePropertyAll(6),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            maximumSize: WidgetStatePropertyAll(Size(menuWidth, 360)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoeloRadius.lg),
                side: BorderSide(color: colors.outlineVariant),
              ),
            ),
          ),
          menuChildren: [
            SizedBox(
              width: menuWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: items
                    .map(
                      (item) => MenuItemButton(
                        key: itemKey(item),
                        onPressed: () => onChanged(item),
                        style: MenuItemButton.styleFrom().copyWith(
                          foregroundColor: WidgetStateProperty.resolveWith((states) {
                            final highlighted =
                                states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused);
                            return item == value || highlighted
                                ? colors.primary
                                : colors.onSurfaceVariant;
                          }),
                          backgroundColor: WidgetStateProperty.resolveWith((states) {
                            final highlighted =
                                states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused);
                            return item == value || highlighted
                                ? colors.primaryContainer
                                : Colors.transparent;
                          }),
                          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                          shape: WidgetStateProperty.resolveWith((states) {
                            final highlighted =
                                states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused);
                            return RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                item == value || highlighted ? 0 : CoeloRadius.md,
                              ),
                            );
                          }),
                        ),
                        child: Text('$item'),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          builder: (context, controller, child) => OutlinedButton(
            onPressed: () => controller.isOpen ? controller.close() : controller.open(),
            style:
                OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                  padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
                  shape: const StadiumBorder(),
                ).copyWith(
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    return states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)
                        ? colors.primary
                        : colors.onSurfaceVariant;
                  }),
                  side: WidgetStateProperty.resolveWith((states) {
                    final active =
                        states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused);
                    return BorderSide(color: active ? colors.primary : colors.outlineVariant);
                  }),
                ),
            child: Row(
              children: [
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: CoeloSpacing.space1),
                const Icon(Icons.arrow_drop_down_rounded),
              ],
            ),
          ),
        );
      },
    );
  }
}
