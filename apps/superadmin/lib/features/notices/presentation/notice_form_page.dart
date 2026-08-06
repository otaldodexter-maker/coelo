import 'dart:math' as math;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../data/fake_notice_repository.dart';
import '../domain/platform_notice.dart';
import 'notice_preview_dialog.dart';

final class NoticeFormPage extends StatefulWidget {
  const NoticeFormPage({
    required this.repository,
    this.noticeId,
    this.onSaved,
    this.onCancel,
    this.embedded = false,
    super.key,
  });

  final FakeNoticeRepository repository;
  final String? noticeId;
  final ValueChanged<PlatformNotice>? onSaved;
  final VoidCallback? onCancel;
  final bool embedded;

  @override
  State<NoticeFormPage> createState() => _NoticeFormPageState();
}

final class _NoticeFormPageState extends State<NoticeFormPage> {
  final _form = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _message;
  late final TextEditingController _audienceLabel;
  late final TextEditingController _buttonLabel;
  late final TextEditingController _linkLabel;
  late final TextEditingController _intervalDays;
  late final TextEditingController _dayOfMonth;
  late PlatformNotice? _saved;
  late NoticePriority _priority;
  late NoticeAudience _audience;
  late NoticeBehavior _behavior;
  late NoticeTargetDevice _targetDevice;
  late NoticeRecurrence _recurrence;
  late NoticeImageOrientation _imageOrientation;
  late NoticeVisualTone _backgroundTone;
  late NoticeVisualTone _textTone;
  bool _mandatory = false;
  bool _showImagePlaceholder = false;
  DateTime? _startsAt;
  DateTime? _endsAt;
  DateTime? _recurrenceUntil;
  final Set<int> _selectedWeekdays = {};

  @override
  void initState() {
    super.initState();
    final notice = widget.noticeId == null ? null : widget.repository.find(widget.noticeId!);
    _saved = notice;
    _title = TextEditingController(text: notice?.title ?? '');
    _message = TextEditingController(text: notice?.message ?? '');
    _audienceLabel = TextEditingController(text: notice?.audienceLabel ?? 'Equipe Coelo');
    _buttonLabel = TextEditingController(text: notice?.buttonLabel ?? 'Confirmar');
    _linkLabel = TextEditingController(text: notice?.linkLabel ?? '');
    _intervalDays = TextEditingController(text: notice?.intervalDays?.toString() ?? '');
    _dayOfMonth = TextEditingController(text: notice?.dayOfMonth?.toString() ?? '');
    _priority = notice?.priority ?? NoticePriority.important;
    _audience = notice?.audience ?? NoticeAudience.coeloTeam;
    _behavior = notice?.behavior ?? NoticeBehavior.confirmation;
    _targetDevice = notice?.targetDevice ?? NoticeTargetDevice.all;
    _recurrence = notice?.recurrence ?? NoticeRecurrence.oneTime;
    _imageOrientation = notice?.imageOrientation ?? NoticeImageOrientation.vertical;
    _backgroundTone = notice?.backgroundTone ?? NoticeVisualTone.brand;
    _textTone = notice?.textTone ?? NoticeVisualTone.light;
    _mandatory = notice?.mandatory ?? false;
    _showImagePlaceholder = notice?.showImagePlaceholder ?? false;
    _startsAt = notice?.startsAt;
    _endsAt = notice?.endsAt;
    _recurrenceUntil = notice?.recurrenceUntil;
    _selectedWeekdays.clear();
    _selectedWeekdays.addAll(notice?.weeklyDays ?? <int>[]);
    for (final controller in [
      _title,
      _message,
      _audienceLabel,
      _buttonLabel,
      _linkLabel,
      _intervalDays,
      _dayOfMonth,
    ]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _audienceLabel.dispose();
    _buttonLabel.dispose();
    _linkLabel.dispose();
    _intervalDays.dispose();
    _dayOfMonth.dispose();
    super.dispose();
  }

  bool get _editing => _saved != null;
  String get _titleText => _editing ? 'Editar aviso' : 'Novo aviso';
  void _markDirty() => setState(() {});

  NoticeDraft get _draft => NoticeDraft(
    title: _title.text,
    message: _message.text,
    priority: _priority,
    audience: _audience,
    audienceLabel: _audienceLabel.text,
    behavior: _behavior,
    mandatory: _mandatory,
    targetDevice: _targetDevice,
    buttonLabel: _buttonLabel.text,
    linkLabel: _linkLabel.text.isEmpty ? null : _linkLabel.text,
    recurrence: _recurrence,
    intervalDays: _intValue(_intervalDays),
    weeklyDays: List.of(_selectedWeekdays)..sort(),
    dayOfMonth: _dayOfMonthValue,
    recurrenceUntil: _recurrenceUntil,
    imageOrientation: _imageOrientation,
    showImagePlaceholder: _showImagePlaceholder,
    backgroundTone: _backgroundTone,
    textTone: _textTone,
    startsAt: _startsAt,
    endsAt: _endsAt,
  );

  int? get _dayOfMonthValue {
    final value = int.tryParse(_dayOfMonth.text.trim());
    if (value == null || value < 1) return null;
    return value > 31 ? 31 : value;
  }

  PlatformNotice get _previewNotice => PlatformNotice(
    id: 'notice-preview',
    title: _title.text.isEmpty ? 'Prévia do aviso' : _title.text,
    message: _message.text.isEmpty ? 'Mensagem do aviso.' : _message.text,
    priority: _priority,
    status: NoticeStatus.active,
    startsAt: _startsAt ?? DateTime.now(),
    endsAt: _endsAt,
    audience: _audience,
    audienceLabel: _audienceLabel.text,
    behavior: _behavior,
    mandatory: _mandatory,
    targetDevice: _targetDevice,
    reach: 0,
    recurrence: _recurrence,
    intervalDays: _intValue(_intervalDays),
    weeklyDays: List.of(_selectedWeekdays),
    dayOfMonth: _dayOfMonthValue,
    recurrenceUntil: _recurrenceUntil,
    imageOrientation: _imageOrientation,
    showImagePlaceholder: _showImagePlaceholder,
    backgroundTone: _backgroundTone,
    textTone: _textTone,
    buttonLabel: _buttonLabel.text.isEmpty ? 'Confirmar' : _buttonLabel.text,
    linkLabel: _linkLabel.text.isEmpty ? null : _linkLabel.text,
  );

  PlatformNotice _saveDraft() {
    if (!_form.currentState!.validate()) {
      throw StateError('Preencha os campos obrigatórios.');
    }
    final draft = _draft;
    if (_saved == null) {
      final created = widget.repository.create(draft);
      _saved = created;
      return created;
    }
    final updated = widget.repository.update(_saved!.id, draft);
    _saved = updated;
    return updated;
  }

  Future<void> _onSaveDraft() async {
    try {
      final notice = _saveDraft();
      widget.onSaved?.call(notice);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Rascunho salvo: ${notice.title}')));
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _onSaveAndPublish() async {
    try {
      final saved = _saveDraft();
      final notice = saved.status == NoticeStatus.active || saved.status == NoticeStatus.scheduled
          ? saved
          : widget.repository.publish(saved.id);
      widget.onSaved?.call(notice);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Aviso publicado: ${notice.title}')));
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  Future<void> _onPreview() async {
    await showNoticePreview(context, _previewNotice, onAccepted: null);
  }

  Future<void> _pickDate({
    required bool isStart,
    DateTime? current,
    required ValueChanged<DateTime?> onDate,
    bool canClear = false,
  }) async {
    final now = DateTime.now();
    final baseDate = current ?? now;
    final minDate = isStart ? DateTime(2020) : (_startsAt ?? now);
    final maxDate = isStart ? (_endsAt ?? DateTime(2060)) : DateTime(2060);
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(baseDate.year, baseDate.month, baseDate.day),
      firstDate: minDate.isAfter(maxDate) ? maxDate : minDate,
      lastDate: maxDate,
      locale: const Locale('pt', 'BR'),
      barrierLabel: 'Selecionar data',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(colorScheme: Theme.of(context).colorScheme),
        child: child!,
      ),
    );
    if (!mounted) return;
    if (selected == null && canClear) {
      onDate(null);
      return;
    }
    if (selected != null) {
      onDate(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < CoeloBreakpoints.medium.minWidth;
    final inset = isCompact ? CoeloSpacing.space4 : CoeloSpacing.space6;
    final contentWidth = widget.embedded ? double.infinity : 920.0;
    final backgroundColor = _toneToColor(_backgroundTone);
    final textColor = _toneToColor(_textTone, forText: true);
    final contrast = _contrastRatio(backgroundColor, textColor);
    final lowContrast = contrast < 4.5;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentWidth),
        child: Form(
          key: _form,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              inset,
              isCompact || widget.embedded ? inset : inset + CoeloSpacing.space2,
              inset,
              inset,
            ),
            children: [
              Text(_titleText, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: CoeloSpacing.space1),
              Text(
                _editing
                    ? 'Edite conteúdo, público e calendário sem sair da tela de lista.'
                    : 'Monte o popup em preview local antes de publicar.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _statusTag(context),
              const SizedBox(height: CoeloSpacing.space4),
              _sectionCard(
                context,
                title: 'Conteúdo',
                description: 'Mensagem, rótulo e comportamento principal do popup.',
                children: [
                  CoeloFormTextField(
                    controller: _title,
                    labelText: 'Título',
                    hintText: 'Ex.: Comunicado de rotina',
                    prefixIcon: Icons.campaign_outlined,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Informe um título.' : null,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloFormTextField(
                    controller: _message,
                    labelText: 'Mensagem',
                    hintText: 'Descreva o conteúdo que será exibido.',
                    prefixIcon: Icons.subject_rounded,
                    maxLines: 4,
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Informe uma mensagem.' : null,
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloAdminSingleSelectField<NoticeImageOrientation>(
                    label: 'Orientação da imagem',
                    value: _imageOrientation,
                    options: NoticeImageOrientation.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => setState(() => _imageOrientation = value),
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloAdminToggleField(
                    label: 'Incluir placeholder de imagem',
                    description: 'Ative para simular o enquadramento da mídia no popup.',
                    value: _showImagePlaceholder,
                    onChanged: (value) => setState(() => _showImagePlaceholder = value),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  _MiniPopupPreview(
                    title: _title.text.isEmpty ? 'Título do aviso' : _title.text,
                    message: _message.text.isEmpty ? 'Texto do aviso' : _message.text,
                    buttonLabel: _buttonLabel.text.isEmpty ? 'Confirmar' : _buttonLabel.text,
                    orientation: _imageOrientation,
                    backgroundColor: backgroundColor,
                    textColor: textColor,
                    showImagePlaceholder: _showImagePlaceholder,
                  ),
                  if (lowContrast)
                    Padding(
                      padding: const EdgeInsets.only(top: CoeloSpacing.space2),
                      child: Text(
                        'Atenção: contraste abaixo de AA (${contrast.toStringAsFixed(2)}). Ajuste cor de texto e fundo.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _sectionCard(
                context,
                title: 'Visual e plataforma',
                description: 'Defina paleta visual e destino do popup.',
                children: [
                  _formGrid(
                    context: context,
                    children: [
                      CoeloAdminSingleSelectField<NoticeVisualTone>(
                        label: 'Cor de fundo',
                        value: _backgroundTone,
                        options: NoticeVisualTone.values,
                        optionLabel: (value) => value.label,
                        onChanged: (value) => setState(() => _backgroundTone = value),
                      ),
                      CoeloAdminSingleSelectField<NoticeVisualTone>(
                        label: 'Cor do texto',
                        value: _textTone,
                        options: NoticeVisualTone.values,
                        optionLabel: (value) => value.label,
                        onChanged: (value) => setState(() => _textTone = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  _formGrid(
                    context: context,
                    children: [
                      CoeloAdminSingleSelectField<NoticeTargetDevice>(
                        label: 'Plataforma',
                        value: _targetDevice,
                        options: NoticeTargetDevice.values,
                        optionLabel: (value) => value.label,
                        onChanged: (value) => setState(() => _targetDevice = value),
                      ),
                      CoeloFormTextField(
                        controller: _audienceLabel,
                        labelText: 'Público-alvo',
                        prefixIcon: Icons.groups_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  CoeloAdminSingleSelectField<NoticeAudience>(
                    label: 'Tipo de público',
                    value: _audience,
                    options: NoticeAudience.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => setState(() => _audience = value),
                  ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _sectionCard(
                context,
                title: 'Agendamento e recorrência',
                description: 'Crie agendamento e regras de repetição.',
                children: [
                  _formGrid(
                    context: context,
                    children: [
                      _dateField(
                        label: 'Data de início',
                        value: _startsAt,
                        onPick: (value) => setState(() => _startsAt = value),
                        isStart: true,
                      ),
                      _dateField(
                        label: 'Data de término',
                        value: _endsAt,
                        onPick: (value) => setState(() => _endsAt = value),
                        canClear: true,
                        isStart: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                  CoeloAdminSingleSelectField<NoticeRecurrence>(
                    label: 'Recorrência',
                    value: _recurrence,
                    options: NoticeRecurrence.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => setState(() => _recurrence = value),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  Text('Resumo: ${_previewNotice.recurrenceLabel}'),
                  const SizedBox(height: CoeloSpacing.space3),
                  if (_recurrence == NoticeRecurrence.weekly) ...[
                    Text(
                      'Escolha os dias de recorrência:',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: CoeloSpacing.space2),
                    CoeloAdminMultiSelectField<int>(
                      label: 'Dias de recorrência',
                      options: List.generate(7, (index) => index + 1),
                      selectedValues: _selectedWeekdays,
                      optionLabel: _weekdayLabel,
                      onChanged: (value) => setState(() {
                        _selectedWeekdays
                          ..clear()
                          ..addAll(value);
                      }),
                      prefixIcon: Icons.calendar_view_week_rounded,
                      emptyLabel: 'Selecionar dias',
                    ),
                  ],
                  if (_recurrence == NoticeRecurrence.interval) ...[
                    CoeloFormTextField(
                      controller: _intervalDays,
                      labelText: 'Intervalo de dias',
                      hintText: 'Ex.: 2',
                      prefixIcon: Icons.repeat_on_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _markDirty(),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed < 1 || parsed > 30) {
                          return 'Informe um intervalo entre 1 e 30 dias.';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_recurrence == NoticeRecurrence.monthly) ...[
                    CoeloFormTextField(
                      controller: _dayOfMonth,
                      labelText: 'Dia do mês',
                      hintText: '1 a 31',
                      prefixIcon: Icons.calendar_today_rounded,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => _markDirty(),
                      validator: (value) {
                        final parsed = int.tryParse(value ?? '');
                        if (parsed == null || parsed < 1 || parsed > 31) {
                          return 'Informe um dia entre 1 e 31.';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_recurrence == NoticeRecurrence.daily ||
                      _recurrence == NoticeRecurrence.interval) ...[
                    const SizedBox(height: CoeloSpacing.space2),
                    _dateField(
                      label: 'Fim da recorrência',
                      value: _recurrenceUntil,
                      onPick: (value) => setState(() => _recurrenceUntil = value),
                      canClear: true,
                      isStart: false,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              _sectionCard(
                context,
                title: 'Comportamento e aceite',
                description: 'Ajuste obrigatoriedade, risco e texto de ação.',
                children: [
                  CoeloAdminSingleSelectField<NoticePriority>(
                    label: 'Prioridade',
                    value: _priority,
                    options: NoticePriority.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => setState(() => _priority = value),
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  CoeloAdminSingleSelectField<NoticeBehavior>(
                    label: 'Tipo de interação',
                    value: _behavior,
                    options: NoticeBehavior.values,
                    optionLabel: (value) => value.label,
                    onChanged: (value) => setState(() => _behavior = value),
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  CoeloAdminToggleField(
                    label: 'Aviso obrigatório',
                    description:
                        'Quando ativo, o usuário não pode ignorar o popup sem realizar a ação.',
                    value: _mandatory,
                    onChanged: (value) => setState(() => _mandatory = value),
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  _formGrid(
                    context: context,
                    children: [
                      CoeloFormTextField(
                        controller: _buttonLabel,
                        labelText: 'Rótulo do botão principal',
                        prefixIcon: Icons.smart_button_outlined,
                      ),
                      CoeloFormTextField(
                        controller: _linkLabel,
                        labelText: 'Rótulo do link externo (opcional)',
                        prefixIcon: Icons.link_rounded,
                        hintText: 'Abrir mais detalhes',
                      ),
                    ],
                  ),
                  const SizedBox(height: CoeloSpacing.space3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _behavior == NoticeBehavior.dismissible
                              ? 'Risco: baixo (não requer aceite)'
                              : 'Risco: médio (pode interferir no fluxo do usuário)',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space6),
              _actions(context),
              const SizedBox(height: CoeloSpacing.space4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusTag(BuildContext context) {
    final notice = _saved;
    if (notice == null) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    final (background, foreground) = switch (notice.status) {
      NoticeStatus.draft => (colors.surfaceContainerHighest, colors.onSurfaceVariant),
      NoticeStatus.scheduled => (colors.secondaryContainer, colors.onSecondaryContainer),
      NoticeStatus.active => (colors.primaryContainer, colors.onPrimaryContainer),
      NoticeStatus.paused => (colors.tertiaryContainer, colors.onTertiaryContainer),
      NoticeStatus.ended => (colors.surfaceDim, colors.onSurfaceVariant),
      NoticeStatus.cancelled => (colors.errorContainer, colors.onErrorContainer),
    };
    return CoeloAdminExpandableStatusIndicator(
      label: notice.status.label,
      backgroundColor: background,
      foregroundColor: foreground,
      semanticLabel: 'Status ${notice.status.label.toLowerCase()}',
    );
  }

  Widget _actions(BuildContext context) {
    const actionStyle = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, CoeloSize.touchMin)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: CoeloSpacing.space3)),
    );
    final previewButton = OutlinedButton.icon(
      style: actionStyle,
      onPressed: _onPreview,
      icon: const Icon(Icons.visibility_outlined),
      label: const Text('Ver popup final'),
    );
    final saveDraftButton = OutlinedButton(
      style: actionStyle,
      onPressed: _onSaveDraft,
      child: Text(_saved == null ? 'Salvar rascunho' : 'Salvar edição'),
    );
    final publishButton = FilledButton(
      style: actionStyle,
      onPressed: _onSaveAndPublish,
      child: Text(_saved == null ? 'Publicar aviso' : 'Publicar/Atualizar'),
    );
    if (widget.embedded) {
      return SuperadminFormActionFooter(
        surfaceKey: const Key('notice-form-footer-surface-embedded'),
        tertiaryAction: const SizedBox.shrink(),
        continuationActions: [previewButton, saveDraftButton, publishButton],
      );
    }
    return SuperadminFormActionFooter(
      surfaceKey: const Key('notice-form-footer-surface'),
      tertiaryAction: TextButton(
        style: actionStyle,
        onPressed: widget.onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [previewButton, saveDraftButton, publishButton],
    );
  }

  Widget _sectionCard(
    BuildContext context, {
    required String title,
    required String description,
    required List<Widget> children,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: CoeloSpacing.space1),
          Text(description, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: CoeloSpacing.space4),
          ...children,
        ],
      ),
    ),
  );

  Widget _formGrid({
    required BuildContext context,
    required List<Widget> children,
    int maxColumns = 2,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 680;
      final columns = compact || children.length < 2 ? 1 : maxColumns;
      final width = compact || columns == 1
          ? double.infinity
          : (constraints.maxWidth - CoeloSpacing.space3) / columns;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space3,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onPick,
    required bool isStart,
    bool canClear = false,
  }) => LayoutBuilder(
    builder: (context, constraints) {
      return SizedBox(
        height: CoeloSpacing.space16,
        width: constraints.maxWidth,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                key: ValueKey('notice-date-$label'),
                onPressed: () =>
                    _pickDate(isStart: isStart, current: value, onDate: onPick, canClear: canClear),
                style: OutlinedButton.styleFrom(
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoeloSpacing.space3,
                    vertical: CoeloSpacing.space2,
                  ),
                  minimumSize: const Size.fromHeight(CoeloSize.touchMin),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.date_range_rounded),
                    const SizedBox(width: CoeloSpacing.space3),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: Theme.of(context).textTheme.labelSmall),
                          const SizedBox(height: CoeloSpacing.space1),
                          Text(
                            value == null ? 'Selecionar data' : _formatDate(value),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded),
                  ],
                ),
              ),
            ),
            if (canClear) ...[
              const SizedBox(width: CoeloSpacing.space2),
              TextButton(onPressed: () => onPick(null), child: const Text('Limpar')),
            ],
          ],
        ),
      );
    },
  );

  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _weekdayLabel(int day) => switch (day) {
    1 => 'Seg',
    2 => 'Ter',
    3 => 'Qua',
    4 => 'Qui',
    5 => 'Sex',
    6 => 'Sáb',
    _ => 'Dom',
  };

  int? _intValue(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value < 1) return null;
    return value;
  }
}

final class _MiniPopupPreview extends StatelessWidget {
  const _MiniPopupPreview({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.orientation,
    required this.backgroundColor,
    required this.textColor,
    required this.showImagePlaceholder,
  });

  final String title;
  final String message;
  final String buttonLabel;
  final NoticeImageOrientation orientation;
  final Color backgroundColor;
  final Color textColor;
  final bool showImagePlaceholder;

  @override
  Widget build(BuildContext context) {
    final isVertical = orientation == NoticeImageOrientation.vertical;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: isVertical ? 260 : 220,
        minHeight: isVertical ? 160 : 140,
      ),
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CoeloRadius.md),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showImagePlaceholder)
            SizedBox(
              width: isVertical ? 90 : 132,
              height: isVertical ? 132 : 90,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: const Icon(Icons.image_outlined),
              ),
            ),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Container(
              height: isVertical ? 132 : 90,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(CoeloRadius.sm),
              ),
              padding: const EdgeInsets.all(CoeloSpacing.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: CoeloSpacing.space1),
                  Expanded(
                    child: Text(message, style: TextStyle(color: textColor), maxLines: 2),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      buttonLabel,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _contrastRatio(Color background, Color text) {
  final bgLuminance = _relativeLuminance(background);
  final textLuminance = _relativeLuminance(text);
  final l1 = bgLuminance + 0.05;
  final l2 = textLuminance + 0.05;
  final ratio = l1 > l2 ? l1 / l2 : l2 / l1;
  return ratio;
}

double _relativeLuminance(Color color) {
  double channel(double value) {
    final normalized = value / 255;
    return normalized <= 0.03928
        ? normalized / 12.92
        : math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = channel(color.r * 255);
  final g = channel(color.g * 255);
  final b = channel(color.b * 255);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

Color _toneToColor(NoticeVisualTone tone, {bool forText = false}) => switch (tone) {
  NoticeVisualTone.brand => forText ? const Color(0xFFFFF3E0) : const Color(0xFFD63C00),
  NoticeVisualTone.dark => forText ? const Color(0xFFF5F5F5) : const Color(0xFF3F4549),
  NoticeVisualTone.light => forText ? const Color(0xFF232B34) : const Color(0xFFEEF2F4),
  NoticeVisualTone.neutral => forText ? const Color(0xFF232B34) : const Color(0xFFE8EAED),
  NoticeVisualTone.success => forText ? const Color(0xFFF0FFF4) : const Color(0xFF2E7D32),
  NoticeVisualTone.warning => forText ? const Color(0xFF3D2E00) : const Color(0xFFFFB300),
  NoticeVisualTone.danger => forText ? const Color(0xFFFFF1F1) : const Color(0xFFD32F2F),
};
