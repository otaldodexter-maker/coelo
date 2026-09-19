import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/staff_access.dart';
import '../domain/staff_access_popup_text.dart';

/// Campos da regra de acesso compartilhados entre o formulário do vínculo
/// (Acesso de funcionários) e o do perfil (Perfis e permissões › Utilização do
/// app). Sem estado próprio: recebem o rascunho e devolvem o novo valor.

/// Superfícies liberadas (uma linha por superfície).
final class StaffAccessSurfaceToggles extends StatelessWidget {
  const StaffAccessSurfaceToggles({
    required this.surfaces,
    required this.onChanged,
    this.keyPrefix = 'staff-access',
    super.key,
  });

  final Set<StaffAccessSurface> surfaces;
  final ValueChanged<Set<StaffAccessSurface>> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final surface in StaffAccessSurface.values)
        Padding(
          padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
          child: CoeloAdminToggleField(
            key: Key('$keyPrefix-surface-${surface.name}'),
            label: surface.label,
            description: surface == StaffAccessSurface.installedApp
                ? 'Vale quando o app instalado existir (Etapa 4).'
                : null,
            value: surfaces.contains(surface),
            onChanged: (value) =>
                onChanged(value ? {...surfaces, surface} : ({...surfaces}..remove(surface))),
          ),
        ),
      if (surfaces.isEmpty)
        Text(
          'Escolha ao menos uma superfície.',
          key: Key('$keyPrefix-surfaces-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ],
  );
}

/// Vigência (de/até, inclusivas) e as superfícies a que ela se aplica.
final class StaffAccessValidityFields extends StatelessWidget {
  const StaffAccessValidityFields({
    required this.validFrom,
    required this.validUntil,
    required this.validitySurfaces,
    required this.onChanged,
    this.keyPrefix = 'staff-access',
    super.key,
  });

  final DateTime? validFrom;
  final DateTime? validUntil;
  final Set<StaffAccessSurface> validitySurfaces;
  final void Function(DateTime? from, DateTime? until, Set<StaffAccessSurface> surfaces) onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < CoeloBreakpoints.medium.minWidth;
          final from = StaffAccessDateField(
            key: Key('$keyPrefix-valid-from'),
            label: 'De',
            value: validFrom,
            onChanged: (value) => onChanged(value, validUntil, validitySurfaces),
          );
          final until = StaffAccessDateField(
            key: Key('$keyPrefix-valid-until'),
            label: 'Até',
            value: validUntil,
            onChanged: (value) => onChanged(validFrom, value, validitySurfaces),
          );
          if (stack) {
            return Column(children: [from, const SizedBox(height: CoeloSpacing.space3), until]);
          }
          return Row(
            children: [
              Expanded(child: from),
              const SizedBox(width: CoeloSpacing.space4),
              Expanded(child: until),
            ],
          );
        },
      ),
      if (validFrom != null && validUntil != null && validUntil!.isBefore(validFrom!))
        Padding(
          padding: const EdgeInsets.only(top: CoeloSpacing.space2),
          child: Text(
            'A vigência precisa terminar depois de começar.',
            key: Key('$keyPrefix-validity-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminMultiSelectField<StaffAccessSurface>(
        key: Key('$keyPrefix-validity-surfaces'),
        label: 'Superfícies da vigência',
        options: StaffAccessSurface.values,
        selectedValues: validitySurfaces,
        optionLabel: (surface) => surface.label,
        onChanged: (value) => onChanged(validFrom, validUntil, value),
        prefixIcon: Icons.devices_outlined,
        emptyLabel: 'Todas as superfícies',
      ),
    ],
  );
}

/// Popup informativo (só informa; desligar não desliga a restrição) com prévia.
final class StaffAccessPopupFields extends StatelessWidget {
  const StaffAccessPopupFields({
    required this.popupEnabled,
    required this.popupShowValidity,
    required this.windows,
    required this.validFrom,
    required this.validUntil,
    required this.onChanged,
    this.keyPrefix = 'staff-access',
    super.key,
  });

  final bool popupEnabled;
  final bool popupShowValidity;
  final List<StaffAccessWindow> windows;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final void Function(bool enabled, bool showValidity) onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      CoeloAdminToggleField(
        key: Key('$keyPrefix-popup-toggle'),
        label: 'Mostrar o horário permitido ao funcionário',
        value: popupEnabled,
        onChanged: (value) => onChanged(value, popupShowValidity),
      ),
      const SizedBox(height: CoeloSpacing.space2),
      CoeloAdminToggleField(
        key: Key('$keyPrefix-popup-validity-toggle'),
        label: 'Incluir as datas da vigência no popup',
        value: popupShowValidity,
        onChanged: popupEnabled ? (value) => onChanged(popupEnabled, value) : null,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      StaffAccessInfoBanner(
        icon: Icons.visibility_outlined,
        text: 'Prévia: ${staffAccessPopupPreview(
          windows: windows,
          validFrom: popupShowValidity ? validFrom : null,
          validUntil: popupShowValidity ? validUntil : null,
          enabled: popupEnabled,
        )}',
      ),
    ],
  );
}

/// Editor completo (superfícies, horários, vigência, popup) numa coluna só:
/// usado no passo "Utilização do app" do perfil de funcionário.
final class StaffAccessRuleEditor extends StatelessWidget {
  const StaffAccessRuleEditor({
    required this.draft,
    required this.onChanged,
    this.timezone = 'America/Sao_Paulo',
    this.keyPrefix = 'staff-access',
    super.key,
  });

  final StaffAccessRuleDraft draft;
  final ValueChanged<StaffAccessRuleDraft> onChanged;
  final String timezone;
  final String keyPrefix;

  StaffAccessRuleDraft _with({
    Set<StaffAccessSurface>? surfaces,
    List<StaffAccessWindow>? windows,
    DateTime? Function()? validFrom,
    DateTime? Function()? validUntil,
    Set<StaffAccessSurface>? validitySurfaces,
    bool? popupEnabled,
    bool? popupShowValidity,
  }) => StaffAccessRuleDraft(
    surfaces: surfaces ?? draft.surfaces,
    windows: windows ?? draft.windows,
    validFrom: validFrom == null ? draft.validFrom : validFrom(),
    validUntil: validUntil == null ? draft.validUntil : validUntil(),
    validitySurfaces: validitySurfaces ?? draft.validitySurfaces,
    popupEnabled: popupEnabled ?? draft.popupEnabled,
    popupShowValidity: popupShowValidity ?? draft.popupShowValidity,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget heading(String title, String description) => Padding(
      padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: CoeloSpacing.space1),
          Text(
            description,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        heading('Superfícies liberadas', 'Onde este perfil pode usar o app.'),
        StaffAccessSurfaceToggles(
          surfaces: draft.surfaces,
          keyPrefix: keyPrefix,
          onChanged: (value) => onChanged(_with(surfaces: value)),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        heading(
          'Dias e horários',
          'Sem janelas = qualquer horário. Fim antes do início cruza a meia-noite. Fuso: $timezone.',
        ),
        StaffAccessWindowsEditor(
          windows: draft.windows,
          keyPrefix: keyPrefix,
          onChanged: (value) => onChanged(_with(windows: value)),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        heading('Vigência do acesso', 'Opcional. Datas inclusivas; fora dela o acesso é negado.'),
        StaffAccessValidityFields(
          validFrom: draft.validFrom,
          validUntil: draft.validUntil,
          validitySurfaces: draft.validitySurfaces,
          keyPrefix: keyPrefix,
          onChanged: (from, until, surfaces) => onChanged(
            _with(validFrom: () => from, validUntil: () => until, validitySurfaces: surfaces),
          ),
        ),
        const SizedBox(height: CoeloSpacing.space5),
        heading('Popup informativo', 'Só informa. Desligar o popup não desliga a restrição.'),
        StaffAccessPopupFields(
          popupEnabled: draft.popupEnabled,
          popupShowValidity: draft.popupShowValidity,
          windows: draft.windows,
          validFrom: draft.validFrom,
          validUntil: draft.validUntil,
          keyPrefix: keyPrefix,
          onChanged: (enabled, showValidity) =>
              onChanged(_with(popupEnabled: enabled, popupShowValidity: showValidity)),
        ),
      ],
    );
  }
}

/// Aviso neutro com ícone (usado nas seções dos formulários de acesso).
final class StaffAccessInfoBanner extends StatelessWidget {
  const StaffAccessInfoBanner({required this.icon, required this.text, this.trailing, super.key});
  final IconData icon;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: CoeloSize.iconSm, color: colors.onSurfaceVariant),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          if (trailing != null) ...[const SizedBox(width: CoeloSpacing.space2), trailing!],
        ],
      ),
    );
  }
}

/// Grade dias × janelas com adicionar/remover. Uma linha por dia da semana.
final class StaffAccessWindowsEditor extends StatelessWidget {
  const StaffAccessWindowsEditor({
    required this.windows,
    required this.onChanged,
    this.keyPrefix = 'staff-access',
    super.key,
  });

  final List<StaffAccessWindow> windows;
  final ValueChanged<List<StaffAccessWindow>> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var weekday = 1; weekday <= 7; weekday++) ...[
          _WeekdayRow(
            weekday: weekday,
            keyPrefix: keyPrefix,
            windows: [
              for (var i = 0; i < windows.length; i++)
                if (windows[i].weekday == weekday) (i, windows[i]),
            ],
            onAdd: () => onChanged([
              ...windows,
              StaffAccessWindow(weekday: weekday, start: '08:00', end: '18:00'),
            ]),
            onRemove: (index) => onChanged([...windows]..removeAt(index)),
            onEdit: (index, value) {
              final next = [...windows];
              next[index] = value;
              onChanged(next);
            },
          ),
          if (weekday < 7) Divider(height: CoeloSpacing.space4, color: colors.outlineVariant),
        ],
        const SizedBox(height: CoeloSpacing.space3),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: Key('$keyPrefix-windows-weekdays'),
            onPressed: () => onChanged([
              for (var d = 1; d <= 5; d++)
                if (!windows.any((w) => w.weekday == d))
                  StaffAccessWindow(weekday: d, start: '08:00', end: '18:00'),
              ...windows,
            ]..sort((a, b) => a.weekday.compareTo(b.weekday))),
            icon: const Icon(Icons.work_history_outlined),
            label: const Text('Preencher seg–sex 08:00–18:00'),
          ),
        ),
      ],
    );
  }
}

final class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({
    required this.weekday,
    required this.windows,
    required this.onAdd,
    required this.onRemove,
    required this.onEdit,
    required this.keyPrefix,
  });

  final int weekday;
  final String keyPrefix;
  final List<(int, StaffAccessWindow)> windows;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, StaffAccessWindow value) onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                StaffAccessWindow.weekdayLabels[weekday]!,
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (windows.isEmpty)
              Text(
                'Sem acesso',
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            const SizedBox(width: CoeloSpacing.space2),
            TextButton.icon(
              key: Key('$keyPrefix-window-add-$weekday'),
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Janela'),
            ),
          ],
        ),
        for (final (index, window) in windows)
          Padding(
            padding: const EdgeInsets.only(top: CoeloSpacing.space2),
            child: _WindowRow(
              index: index,
              keyPrefix: keyPrefix,
              window: window,
              onRemove: () => onRemove(index),
              onChanged: (value) => onEdit(index, value),
            ),
          ),
      ],
    );
  }
}

final class _WindowRow extends StatelessWidget {
  const _WindowRow({
    required this.index,
    required this.window,
    required this.onRemove,
    required this.onChanged,
    required this.keyPrefix,
  });

  final int index;
  final String keyPrefix;
  final StaffAccessWindow window;
  final VoidCallback onRemove;
  final ValueChanged<StaffAccessWindow> onChanged;

  TimeOfDay _time(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _text(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final start = CoeloTimeField(
      key: Key('$keyPrefix-window-start-$index'),
      labelText: 'Início',
      value: _time(window.start),
      onChanged: (value) {
        if (value == null) return;
        onChanged(StaffAccessWindow(weekday: window.weekday, start: _text(value), end: window.end));
      },
    );
    final end = CoeloTimeField(
      key: Key('$keyPrefix-window-end-$index'),
      labelText: window.crossesMidnight ? 'Fim (dia seguinte)' : 'Fim',
      value: _time(window.end),
      onChanged: (value) {
        if (value == null) return;
        onChanged(StaffAccessWindow(weekday: window.weekday, start: window.start, end: _text(value)));
      },
    );
    final remove = IconButton(
      key: Key('$keyPrefix-window-remove-$index'),
      tooltip: 'Remover janela',
      onPressed: onRemove,
      icon: Icon(Icons.delete_outline_rounded, color: colors.error),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < CoeloBreakpoints.medium.minWidth) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              start,
              const SizedBox(height: CoeloSpacing.space2),
              end,
              Align(alignment: Alignment.centerRight, child: remove),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: start),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(child: end),
            const SizedBox(width: CoeloSpacing.space2),
            Padding(padding: const EdgeInsets.only(bottom: CoeloSpacing.space1), child: remove),
          ],
        );
      },
    );
  }
}

/// Campo de data (mesma anatomia do campo de data de Medicação).
final class StaffAccessDateField extends StatelessWidget {
  const StaffAccessDateField({required this.label, required this.value, required this.onChanged, super.key});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: CoeloAdminInteractiveCard(
          semanticLabel: '$label: ${value == null ? 'Não informada' : staffAccessDateLabel(value!)}',
          minHeight: CoeloSize.touchMin,
          onPressed: () async {
            final now = DateUtils.dateOnly(DateTime.now());
            final selected = await showCoeloDateRangePicker(
              context: context,
              value: value == null ? null : DateTimeRange(start: value!, end: value!),
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 10, 12, 31),
              currentDate: now,
              showQuickRanges: false,
              selectionMode: CoeloDateSelectionMode.single,
            );
            if (!context.mounted || selected == null) return;
            onChanged(DateUtils.dateOnly(selected.start));
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: const Icon(Icons.calendar_today_outlined),
              floatingLabelBehavior: FloatingLabelBehavior.always,
            ),
            child: Text(value == null ? 'Sem limite' : staffAccessDateLabel(value!)),
          ),
        ),
      ),
      if (value != null)
        IconButton(
          tooltip: 'Limpar $label',
          onPressed: () => onChanged(null),
          icon: const Icon(Icons.close_rounded),
        ),
    ],
  );
}
