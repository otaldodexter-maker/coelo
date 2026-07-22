import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

import 'superadmin_notice.dart';

Future<void> showSuperadminBugReportDialog(BuildContext context, {required String currentScreen}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    builder: (context) => _SuperadminBugReportDialog(currentScreen: currentScreen),
  );
}

class _SuperadminBugReportDialog extends StatefulWidget {
  const _SuperadminBugReportDialog({required this.currentScreen});

  final String currentScreen;

  @override
  State<_SuperadminBugReportDialog> createState() => _SuperadminBugReportDialogState();
}

class _SuperadminBugReportDialogState extends State<_SuperadminBugReportDialog> {
  static const _menus = <String>[
    'Estrutura',
    'Acessos',
    'Operação',
    'Comunicação',
    'Governança',
    'Outros',
  ];
  static const _screensByMenu = <String, List<String>>{
    'Estrutura': ['Instituições', 'Unidades', 'Grupos', 'Outro'],
    'Acessos': ['Pessoas', 'Outro'],
    'Operação': ['Instituições', 'Unidades', 'Grupos', 'Outro'],
    'Comunicação': ['Instituições', 'Pessoas', 'Grupos', 'Outro'],
    'Governança': ['Instituições', 'Unidades', 'Outro'],
    'Outros': ['Outro'],
  };

  final _descriptionController = TextEditingController();
  late String _selectedMenu = _menus.firstWhere(
    (menu) => (_screensByMenu[menu] ?? const <String>[]).contains(widget.currentScreen),
    orElse: () => 'Outros',
  );
  late String _selectedScreen =
      (_screensByMenu[_selectedMenu] ?? const <String>[]).contains(widget.currentScreen)
      ? widget.currentScreen
      : (_screensByMenu[_selectedMenu] ?? const <String>[]).first;
  final _otherSubjectController = TextEditingController();
  var _attached = false;

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
                    child: Text(
                      'Informe qual bug ou problema achou',
                      style: theme.textTheme.headlineSmall,
                    ),
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
                items: _menus,
                itemKey: (value) => Key('superadmin-bug-menu-option-$value'),
                onChanged: (value) {
                  final screens = _screensByMenu[value] ?? const <String>[];
                  setState(() {
                    _selectedMenu = value;
                    _selectedScreen = screens.first;
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
              const SizedBox(height: CoeloSpacing.space3),
              _BugSingleSelect<String>(
                key: const Key('superadmin-bug-screen'),
                value: _selectedScreen,
                items: _screensByMenu[_selectedMenu] ?? const <String>[],
                itemKey: (value) => Key('superadmin-bug-screen-option-$value'),
                onChanged: (value) => setState(() => _selectedScreen = value),
              ),
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
              OutlinedButton.icon(
                key: const Key('superadmin-bug-attach'),
                onPressed: () => setState(() => _attached = true),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                ),
                icon: const Icon(Icons.attach_file_rounded),
                label: Text(_attached ? 'print-anexado.png' : 'Anexar print'),
              ),
              const SizedBox(height: CoeloSpacing.space5),
              FilledButton(
                key: const Key('superadmin-bug-submit'),
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                ),
                child: const Text('Bug? O Coelo resolve!'),
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
    return MenuAnchor(
      alignmentOffset: const Offset(0, CoeloSpacing.space1),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(colors.surface),
        elevation: const WidgetStatePropertyAll(6),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        maximumSize: const WidgetStatePropertyAll(Size(320, 360)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            side: BorderSide(color: colors.outlineVariant),
          ),
        ),
      ),
      menuChildren: [
        SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: items
                .map(
                  (item) => MenuItemButton(
                    key: itemKey(item),
                    onPressed: () => onChanged(item),
                    style: MenuItemButton.styleFrom(
                      foregroundColor: item == value ? colors.primary : colors.onSurfaceVariant,
                      backgroundColor: item == value ? colors.primaryContainer : Colors.transparent,
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
                return states.contains(WidgetState.hovered) || states.contains(WidgetState.focused)
                    ? colors.primary
                    : colors.onSurfaceVariant;
              }),
              side: WidgetStateProperty.resolveWith((states) {
                final active =
                    states.contains(WidgetState.hovered) || states.contains(WidgetState.focused);
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
  }
}
