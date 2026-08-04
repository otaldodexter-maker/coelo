import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../data/agenda_prototype_store.dart';
import '../domain/agenda_models.dart';

final class AgendaEventFormPage extends StatefulWidget {
  const AgendaEventFormPage({
    required this.store,
    required this.onCancel,
    required this.onSaved,
    this.eventId,
    super.key,
  });
  final AgendaPrototypeStore store;
  final String? eventId;
  final VoidCallback onCancel;
  final ValueChanged<String> onSaved;

  @override
  State<AgendaEventFormPage> createState() => _AgendaEventFormPageState();
}

final class _AgendaEventFormPageState extends State<AgendaEventFormPage> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _details;
  late AgendaItemType _type;
  late AgendaPriority _priority;
  late DateTime _start;
  late DateTime _end;
  int _step = 0;

  AgendaItem? get _existing =>
      widget.eventId == null ? null : widget.store.itemById(widget.eventId!);

  @override
  void initState() {
    super.initState();
    final seed = _existing ?? widget.store.items.first;
    _title = TextEditingController(text: _existing?.title ?? 'Novo item da agenda');
    _location = TextEditingController(text: _existing?.location ?? 'Unidade Centro');
    _details = TextEditingController(text: _existing?.description ?? 'Detalhes para a família.');
    _type = _existing?.type ?? AgendaItemType.event;
    _priority = _existing?.priority ?? AgendaPriority.normal;
    _start = _existing?.startsAt ?? seed.startsAt.add(const Duration(days: 2));
    _end = _existing?.endsAt ?? _start.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _details.dispose();
    super.dispose();
  }

  void _save(AgendaItemStatus status) {
    if (_title.text.trim().isEmpty) return;
    final seed = _existing ?? widget.store.items.first;
    final id = widget.eventId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';
    widget.store.upsertItem(
      seed.copyWith(
        id: id,
        title: _title.text.trim(),
        type: _type,
        priority: _priority,
        status: status,
        startsAt: _start,
        endsAt: _end,
        location: _location.text.trim(),
        description: _details.text.trim(),
      ),
    );
    widget.onSaved(id);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= CoeloBreakpoints.large.minWidth;
      final nav = _WizardNav(step: _step, onSelect: (value) => setState(() => _step = value));
      return Padding(
        padding: EdgeInsets.all(wide ? CoeloSpacing.space10 : CoeloSpacing.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide) ...[
              SizedBox(width: 220, child: nav),
              const SizedBox(width: CoeloSpacing.space6),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.eventId == null ? 'Criar item' : 'Editar item',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text('Os dados ficam somente nesta sessão local.'),
                  const SizedBox(height: CoeloSpacing.space4),
                  if (!wide) ...[nav, const SizedBox(height: CoeloSpacing.space4)],
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('agenda-event-form-scroll'),
                      child: _content(),
                    ),
                  ),
                  SuperadminFormActionFooter(
                    tertiaryAction: TextButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancelar'),
                    ),
                    continuationActions: [
                      if (_step > 0)
                        OutlinedButton(
                          key: const Key('agenda-wizard-previous'),
                          onPressed: () => setState(() => _step--),
                          child: const Text('Anterior'),
                        ),
                      if (_step < 3)
                        FilledButton(
                          key: const Key('agenda-wizard-continue'),
                          onPressed: () => setState(() => _step++),
                          child: const Text('Continuar'),
                        )
                      else ...[
                        OutlinedButton(
                          key: const Key('agenda-wizard-save-draft'),
                          onPressed: () => _save(AgendaItemStatus.draft),
                          child: const Text('Salvar rascunho'),
                        ),
                        FilledButton(
                          key: const Key('agenda-wizard-publish'),
                          onPressed: () => _save(AgendaItemStatus.published),
                          child: const Text('Publicar localmente'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _content() => _Group(
    title: const [
      '1. Tipo e contexto',
      '2. Data e local',
      '3. Público e regras',
      '4. Revisão',
    ][_step],
    children: switch (_step) {
      0 => [
        CoeloFormTextField(
          controller: _title,
          labelText: 'Título',
          prefixIcon: Icons.title_rounded,
        ),
        CoeloAdminSingleSelectField<AgendaItemType>(
          label: 'Tipo',
          value: _type,
          options: AgendaItemType.values,
          optionLabel: (v) => v.label,
          onChanged: (v) => setState(() => _type = v),
        ),
        const _Fact(label: 'Contexto', value: 'Instituição Horizonte → Unidade Centro'),
      ],
      1 => [
        _Fact(label: 'Início', value: _date(_start)),
        _Fact(label: 'Fim', value: _date(_end)),
        _Fact(label: 'Duração calculada', value: '${_end.difference(_start).inMinutes} minutos'),
        CoeloFormTextField(
          controller: _location,
          labelText: 'Local',
          prefixIcon: Icons.place_outlined,
        ),
        const _Fact(label: 'Conflito', value: 'Há 1 item simultâneo neste período.'),
      ],
      2 => [
        CoeloAdminSingleSelectField<AgendaPriority>(
          label: 'Prioridade',
          value: _priority,
          options: AgendaPriority.values,
          optionLabel: (v) => _label(v.name),
          onChanged: (v) => setState(() => _priority = v),
        ),
        const _Fact(label: 'Audiência resolvida', value: 'Responsáveis e equipe da Unidade Centro'),
        CoeloFormTextField(
          controller: _details,
          labelText: 'Descrição',
          prefixIcon: Icons.notes_rounded,
          maxLines: 4,
        ),
      ],
      _ => [
        _Fact(label: 'Item', value: '${_title.text} · ${_type.label}'),
        _Fact(label: 'Período', value: '${_date(_start)} — ${_date(_end)}'),
        _Fact(label: 'Quem verá', value: 'Responsáveis e equipe da Unidade Centro'),
        const _Fact(label: 'Notificação simulada', value: 'Nenhuma mensagem real será enviada.'),
      ],
    },
  );
}

final class _WizardNav extends StatelessWidget {
  const _WizardNav({required this.step, required this.onSelect});
  final int step;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Etapa ${step + 1} de 4',
    child: Wrap(
      spacing: CoeloSpacing.space2,
      runSpacing: CoeloSpacing.space2,
      children: [
        for (var i = 0; i < 4; i++)
          TextButton(
            onPressed: i <= step ? () => onSelect(i) : null,
            child: Text('${i + 1}. ${const ['Tipo', 'Data', 'Público', 'Revisão'][i]}'),
          ),
      ],
    ),
  );
}

final class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: CoeloSpacing.space5),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: CoeloSpacing.space4),
          ],
          const SizedBox(height: CoeloSpacing.space6),
        ],
      ),
    ),
  );
}

final class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label: $value',
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      child: Text(value),
    ),
  );
}

String _date(DateTime v) =>
    '${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year} ${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';
String _label(String value) =>
    '${value[0].toUpperCase()}${value.substring(1).replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)!.toLowerCase()}')}';
