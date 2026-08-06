import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets/superadmin_advanced_color_picker_dialog.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../data/fake_notice_repository.dart';
import '../domain/platform_notice.dart';
import 'notice_form_controller.dart';
import 'notice_popup_preview.dart';
import 'notice_preview_dialog.dart';

final class NoticeFormPage extends StatefulWidget {
  const NoticeFormPage({
    required this.repository,
    this.noticeId,
    this.onSaved,
    this.onCancel,
    super.key,
  });

  final FakeNoticeRepository repository;
  final String? noticeId;
  final ValueChanged<PlatformNotice>? onSaved;
  final VoidCallback? onCancel;

  @override
  State<NoticeFormPage> createState() => _NoticeFormPageState();
}

final class _NoticeFormPageState extends State<NoticeFormPage> {
  late final NoticeFormController _controller;
  double _footerHeight = 0;
  bool _previewCheckboxChecked = false;

  @override
  void initState() {
    super.initState();
    _controller = NoticeFormController(repository: widget.repository, noticeId: widget.noticeId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _wizardBody(compact: constraints.maxWidth < CoeloBreakpoints.medium.minWidth),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space4,
            CoeloSpacing.space2,
            CoeloSpacing.space4,
            CoeloSpacing.space4,
          ),
          child: _footer(),
        ),
      ],
    ),
  );

  Widget _wizardBody({required bool compact}) {
    final navigation = SuperadminFormStepNavigation(
      steps: NoticeFormStep.values
          .map(
            (step) => SuperadminFormStep(
              label: step.label,
              status: _controller.statusFor(step),
              enabled: step.index <= _controller.furthestStep,
            ),
          )
          .toList(growable: false),
      currentIndex: _controller.currentStep.index,
      onStepSelected: _controller.goToStep,
    );
    final content = Expanded(
      child: SingleChildScrollView(
        key: Key('notice-step-${_controller.currentStep.name}'),
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _controller.isEditing ? 'Editar aviso' : 'Novo aviso',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  _controller.currentStep.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                if (_controller.stepsWithErrors.contains(_controller.currentStep)) ...[
                  _errorBanner(_errorFor(_controller.currentStep)),
                  const SizedBox(height: CoeloSpacing.space3),
                ],
                _buildStep(_controller.currentStep),
              ],
            ),
          ),
        ),
      ),
    );
    if (compact) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              CoeloSpacing.space4,
              CoeloSpacing.space4,
              CoeloSpacing.space4,
              0,
            ),
            child: navigation,
          ),
          content,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CoeloSpacing.space4,
            CoeloSpacing.space4,
            0,
            CoeloSpacing.space4,
          ),
          child: navigation,
        ),
        content,
      ],
    );
  }

  Widget _buildStep(NoticeFormStep step) => switch (step) {
    NoticeFormStep.identity => _identityStep(),
    NoticeFormStep.content => _contentStep(),
    NoticeFormStep.audience => _audienceStep(),
    NoticeFormStep.schedule => _scheduleStep(),
    NoticeFormStep.review => _reviewStep(),
  };

  Widget _identityStep() => _sectionCard(
    title: 'Identidade do aviso',
    description: 'Dê um nome claro para localizar e priorizar este comunicado.',
    children: [
      CoeloFormTextField(
        key: const Key('notice-title'),
        controller: _controller.titleController,
        labelText: 'Título',
        hintText: 'Ex.: Comunicado de rotina',
        prefixIcon: Icons.campaign_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<NoticePriority>(
        label: 'Prioridade',
        value: _controller.priority,
        options: NoticePriority.values,
        optionLabel: _priorityLabel,
        onChanged: _controller.setPriority,
      ),
    ],
  );

  Widget _contentStep() => _sectionCard(
    title: 'Conteúdo e aparência',
    description: 'Configure a mensagem, a interação e a apresentação visual do popup.',
    children: [
      CoeloFormTextField(
        key: const Key('notice-message'),
        controller: _controller.messageController,
        labelText: 'Mensagem',
        hintText: 'Escreva o conteúdo exibido para o público.',
        prefixIcon: Icons.subject_rounded,
        maxLines: 5,
      ),
      const SizedBox(height: CoeloSpacing.space4),
      _formGrid([
        CoeloAdminSingleSelectField<NoticeContentFormat>(
          label: 'Formato',
          value: _controller.contentFormat,
          options: NoticeContentFormat.values,
          optionLabel: _contentFormatLabel,
          onChanged: _controller.setContentFormat,
        ),
        CoeloAdminSingleSelectField<NoticeBehavior>(
          label: 'Interação',
          value: _controller.behavior,
          options: NoticeBehavior.values,
          optionLabel: _behaviorLabel,
          onChanged: _controller.setBehavior,
        ),
      ]),
      if (_controller.contentFormat == NoticeContentFormat.image) ...[
        const SizedBox(height: CoeloSpacing.space4),
        _formGrid([
          CoeloAdminSingleSelectField<NoticeImageOrientation>(
            label: 'Orientação da imagem',
            value: _controller.imageOrientation,
            options: NoticeImageOrientation.values,
            optionLabel: _orientationLabel,
            onChanged: _controller.setImageOrientation,
          ),
          CoeloAdminToggleField(
            label: 'Placeholder de imagem',
            description: 'Simula a área ocupada pela mídia no popup.',
            value: _controller.showImagePlaceholder,
            onChanged: _controller.setShowImagePlaceholder,
          ),
        ]),
      ],
      const SizedBox(height: CoeloSpacing.space4),
      _formGrid([
        _colorButton(
          key: const Key('notice-background-color'),
          label: 'Cor de fundo',
          color: _controller.backgroundColor,
          onPressed: () => _pickColor(background: true),
        ),
        _colorButton(
          key: const Key('notice-text-color'),
          label: 'Cor do texto',
          color: _controller.textColor,
          onPressed: () => _pickColor(background: false),
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloFormTextField(
        controller: _controller.buttonLabelController,
        labelText: 'Rótulo do botão principal',
        hintText: 'Confirmar',
        prefixIcon: Icons.smart_button_outlined,
      ),
    ],
  );

  Widget _audienceStep() => _sectionCard(
    title: 'Público e dispositivos',
    description: 'Escolha um único nível de público e onde o aviso será exibido.',
    children: [
      _formGrid([
        CoeloAdminSingleSelectField<NoticeAudience>(
          label: 'Alvo hierárquico',
          value: _controller.audience,
          options: NoticeFormController.allowedAudiences,
          optionLabel: _audienceTypeLabel,
          onChanged: _controller.setAudience,
        ),
        CoeloAdminSingleSelectField<NoticeTargetDevice>(
          label: 'Dispositivo',
          value: _controller.targetDevice,
          options: NoticeTargetDevice.values,
          optionLabel: _deviceLabel,
          onChanged: _controller.setTargetDevice,
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      _formGrid([
        CoeloFormTextField(
          key: const Key('notice-audience-label'),
          controller: _controller.audienceLabelController,
          labelText: 'Nome do público',
          hintText: 'Ex.: Todas as instituições',
          prefixIcon: Icons.groups_outlined,
        ),
        CoeloFormTextField(
          controller: _controller.audienceRoleLabelController,
          labelText: 'Papel no público (opcional)',
          hintText: 'Ex.: Responsáveis',
          prefixIcon: Icons.badge_outlined,
        ),
      ]),
    ],
  );

  Widget _scheduleStep() => _sectionCard(
    title: 'Exibição e recorrência',
    description: 'Defina a vigência e, quando necessário, a regra de repetição.',
    children: [
      _formGrid([
        _dateField(
          label: 'Data de início',
          value: _controller.startsAt,
          onChanged: (value) {
            if (value != null) _controller.setStartsAt(value);
          },
        ),
        _dateField(
          label: 'Data de término (opcional)',
          value: _controller.endsAt,
          onChanged: _controller.setEndsAt,
          canClear: true,
        ),
      ]),
      const SizedBox(height: CoeloSpacing.space4),
      CoeloAdminSingleSelectField<NoticeRecurrence>(
        label: 'Recorrência',
        value: _controller.recurrence,
        options: NoticeRecurrence.values,
        optionLabel: _recurrenceLabel,
        onChanged: _controller.setRecurrence,
      ),
      if (_controller.recurrence == NoticeRecurrence.weekly) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminMultiSelectField<int>(
          label: 'Dias da semana',
          options: List.generate(7, (index) => index + 1),
          selectedValues: _controller.selectedWeekdays,
          optionLabel: _weekdayLabel,
          onChanged: _controller.setSelectedWeekdays,
          prefixIcon: Icons.calendar_view_week_rounded,
          emptyLabel: 'Selecionar dias',
        ),
      ],
      if (_controller.recurrence == NoticeRecurrence.monthly) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: _controller.dayOfMonthController,
          labelText: 'Dia do mês',
          hintText: '1 a 31',
          prefixIcon: Icons.calendar_today_outlined,
          keyboardType: TextInputType.number,
        ),
      ],
      if (_controller.recurrence == NoticeRecurrence.interval) ...[
        const SizedBox(height: CoeloSpacing.space4),
        CoeloFormTextField(
          controller: _controller.intervalDaysController,
          labelText: 'Intervalo em dias',
          hintText: '1 a 30',
          prefixIcon: Icons.repeat_rounded,
          keyboardType: TextInputType.number,
        ),
      ],
      if (_controller.recurrence != NoticeRecurrence.oneTime) ...[
        const SizedBox(height: CoeloSpacing.space4),
        _dateField(
          label: 'Fim da recorrência (opcional)',
          value: _controller.recurrenceUntil,
          onChanged: _controller.setRecurrenceUntil,
          canClear: true,
        ),
      ],
    ],
  );

  Widget _reviewStep() {
    final notice = _controller.previewNotice;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          title: 'Revisão e publicação',
          description: 'Confira o alcance, a configuração e a experiência antes de publicar.',
          children: [
            _reviewLine('Título', notice.title),
            _reviewLine('Prioridade', _priorityLabel(notice.priority)),
            _reviewLine('Formato', _contentFormatLabel(notice.contentFormat)),
            _reviewLine('Interação', _behaviorLabel(notice.behavior)),
            _reviewLine(
              'Público',
              '${_audienceTypeLabel(notice.audience)} · ${notice.audienceLabel}',
            ),
            if (notice.audienceRoleLabel case final role?) _reviewLine('Papel', role),
            _reviewLine('Dispositivo', _deviceLabel(notice.targetDevice)),
            _reviewLine(
              'Vigência',
              '${_formatDate(notice.startsAt)} — ${_formatOptionalDate(notice.endsAt)}',
            ),
            _reviewLine('Recorrência', _recurrenceSummary(notice)),
          ],
        ),
        const SizedBox(height: CoeloSpacing.space4),
        _metrics(notice),
        const SizedBox(height: CoeloSpacing.space4),
        _sectionCard(
          title: 'Prévia no dispositivo',
          description: 'Representação local do popup no destino selecionado.',
          children: [
            NoticePopupPreview(
              notice: notice,
              device: notice.targetDevice,
              checkboxChecked: _previewCheckboxChecked,
              onCheckboxChanged: notice.behavior == NoticeBehavior.checkboxConfirmation
                  ? (value) => setState(() => _previewCheckboxChecked = value)
                  : null,
            ),
            const SizedBox(height: CoeloSpacing.space3),
            OutlinedButton.icon(
              onPressed: _onPreview,
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Ver popup final'),
            ),
          ],
        ),
        if (!_controller.hasAccessibleContrast) ...[
          const SizedBox(height: CoeloSpacing.space3),
          _errorBanner(
            'O contraste atual é ${_controller.contrastRatio.toStringAsFixed(2)}:1. '
            'Ajuste as cores para atingir pelo menos 4,5:1 antes de publicar.',
          ),
        ],
      ],
    );
  }

  Widget _footer() {
    const style = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, CoeloSize.touchMin)));
    return SuperadminFormActionFooter(
      surfaceKey: const Key('notice-form-footer-surface'),
      onHeightChanged: _updateFooterHeight,
      tertiaryAction: TextButton(
        style: style,
        onPressed: widget.onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (_controller.currentStep.index > 0)
          OutlinedButton(
            style: style,
            onPressed: _controller.previousStep,
            child: const Text('Anterior'),
          ),
        OutlinedButton(style: style, onPressed: _onSaveDraft, child: const Text('Salvar rascunho')),
        FilledButton(
          style: style,
          onPressed: _controller.isReviewStep
              ? (_controller.hasAccessibleContrast ? _onSaveAndPublish : null)
              : _controller.continueFromCurrentStep,
          child: Text(_controller.isReviewStep ? 'Publicar aviso' : 'Continuar'),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required String description,
    required List<Widget> children,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

  Widget _formGrid(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 680;
      final width = compact
          ? constraints.maxWidth
          : (constraints.maxWidth - CoeloSpacing.space3) / 2;
      return Wrap(
        spacing: CoeloSpacing.space3,
        runSpacing: CoeloSpacing.space3,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    },
  );

  Widget _colorButton({
    required Key key,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) => OutlinedButton(
    key: key,
    onPressed: onPressed,
    style: const ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(double.infinity, CoeloSize.touchMin)),
      alignment: Alignment.centerLeft,
    ),
    child: Row(
      children: [
        Container(
          width: CoeloSize.iconMd,
          height: CoeloSize.iconMd,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(label)),
        const Icon(Icons.palette_outlined),
      ],
    ),
  );

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    bool canClear = false,
  }) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          key: ValueKey('notice-date-$label'),
          onPressed: () => _pickDate(value: value, onChanged: onChanged),
          style: OutlinedButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(
              horizontal: CoeloSpacing.space3,
              vertical: CoeloSpacing.space2,
            ),
            minimumSize: const Size.fromHeight(CoeloSpacing.space16),
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
                    Text(value == null ? 'Selecionar data' : _formatDate(value)),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded),
            ],
          ),
        ),
      ),
      if (canClear && value != null) ...[
        const SizedBox(width: CoeloSpacing.space1),
        IconButton(
          tooltip: 'Limpar $label',
          onPressed: () => onChanged(null),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ],
  );

  Widget _reviewLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: CoeloSpacing.space2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 132, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
        const SizedBox(width: CoeloSpacing.space2),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _metrics(PlatformNotice notice) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 560 ? 2 : 4;
      final width = (constraints.maxWidth - (columns - 1) * CoeloSpacing.space2) / columns;
      final values = [
        ('Alcance', notice.reach),
        ('Entregues', notice.deliveredCount),
        ('Visualizações', notice.viewedCount),
        ('Aceites', notice.acceptedCount),
      ];
      return Wrap(
        spacing: CoeloSpacing.space2,
        runSpacing: CoeloSpacing.space2,
        children: [
          for (final metric in values)
            SizedBox(
              width: width,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(CoeloSpacing.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${metric.$2}', style: Theme.of(context).textTheme.titleLarge),
                      Text(metric.$1, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _errorBanner(String message) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );

  Future<void> _pickColor({required bool background}) async {
    final selected = await showSuperadminAdvancedColorPicker(
      context,
      initialColor: background ? _controller.backgroundColor : _controller.textColor,
      title: background ? 'Selecionar cor de fundo' : 'Selecionar cor do texto',
    );
    if (!mounted || selected == null) return;
    if (background) {
      _controller.setBackgroundColor(selected);
    } else {
      _controller.setTextColor(selected);
    }
  }

  Future<void> _pickDate({
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final now = DateTime.now();
    final initial = value ?? now;
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2060),
      locale: const Locale('pt', 'BR'),
      barrierLabel: 'Selecionar data',
    );
    if (mounted && selected != null) onChanged(selected);
  }

  PlatformNotice _persistDraft() {
    final draft = _controller.draft;
    final saved = _controller.savedNotice;
    final notice = saved == null
        ? widget.repository.create(draft)
        : widget.repository.update(saved.id, draft);
    _controller.recordSaved(notice);
    return notice;
  }

  Future<void> _onSaveDraft() async {
    if (!_controller.validateAll()) return;
    try {
      final notice = _persistDraft();
      widget.onSaved?.call(notice);
      _showFeedback('Rascunho salvo: ${notice.title}');
    } on Object catch (error) {
      _showFeedback(_cleanError(error));
    }
  }

  Future<void> _onSaveAndPublish() async {
    if (!_controller.validateAll(requireContrast: true)) return;
    try {
      final saved = _persistDraft();
      final notice = saved.status == NoticeStatus.active || saved.status == NoticeStatus.scheduled
          ? saved
          : widget.repository.publish(saved.id);
      _controller.recordSaved(notice);
      widget.onSaved?.call(notice);
      _showFeedback('Aviso publicado: ${notice.title}');
    } on Object catch (error) {
      _showFeedback(_cleanError(error));
    }
  }

  Future<void> _onPreview() =>
      showNoticePreview(context, _controller.previewNotice, onAccepted: null);

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('StateError: ', '').replaceFirst('Invalid argument(s): ', '');

  void _updateFooterHeight(double height) {
    if ((height - _footerHeight).abs() < 0.5 || !mounted) return;
    setState(() => _footerHeight = height);
  }

  String _errorFor(NoticeFormStep step) => switch (step) {
    NoticeFormStep.identity => 'Informe o título do aviso para continuar.',
    NoticeFormStep.content => 'Informe a mensagem do aviso para continuar.',
    NoticeFormStep.audience => 'Selecione um público válido e informe seu nome.',
    NoticeFormStep.schedule => 'Revise as datas e a configuração de recorrência.',
    NoticeFormStep.review => 'Revise as etapas e ajuste o contraste antes de publicar.',
  };

  String _priorityLabel(NoticePriority value) => switch (value) {
    NoticePriority.routine => 'Rotina',
    NoticePriority.important => 'Importante',
    NoticePriority.urgent => 'Urgente',
  };
  String _contentFormatLabel(NoticeContentFormat value) => switch (value) {
    NoticeContentFormat.textBackground => 'Texto sobre fundo',
    NoticeContentFormat.image => 'Imagem',
  };
  String _audienceTypeLabel(NoticeAudience value) => switch (value) {
    NoticeAudience.everyone => 'Global',
    NoticeAudience.institution => 'Instituição',
    NoticeAudience.unit => 'Unidade',
    NoticeAudience.group => 'Turma',
    _ => 'Fora do escopo',
  };
  String _deviceLabel(NoticeTargetDevice value) => switch (value) {
    NoticeTargetDevice.all => 'Todos',
    NoticeTargetDevice.web => 'Web',
    NoticeTargetDevice.mobile => 'Mobile',
    NoticeTargetDevice.tablet => 'Tablet',
  };
  String _behaviorLabel(NoticeBehavior value) => switch (value) {
    NoticeBehavior.dismissible => 'Apenas fechar',
    NoticeBehavior.confirmation => 'Confirmação obrigatória',
    NoticeBehavior.checkboxConfirmation => 'Checkbox de aceite + confirmar',
  };
  String _recurrenceLabel(NoticeRecurrence value) => switch (value) {
    NoticeRecurrence.oneTime => 'Única',
    NoticeRecurrence.daily => 'Diária',
    NoticeRecurrence.weekly => 'Semanal',
    NoticeRecurrence.monthly => 'Mensal',
    NoticeRecurrence.interval => 'Intervalo de dias',
  };
  String _orientationLabel(NoticeImageOrientation value) => switch (value) {
    NoticeImageOrientation.vertical => 'Vertical',
    NoticeImageOrientation.horizontal => 'Horizontal',
  };
  String _weekdayLabel(int day) => const ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'][day - 1];

  String _recurrenceSummary(PlatformNotice notice) => switch (notice.recurrence) {
    NoticeRecurrence.oneTime => 'Única',
    NoticeRecurrence.daily => 'Diária${_untilSuffix(notice.recurrenceUntil)}',
    NoticeRecurrence.weekly =>
      'Semanal (${notice.weeklyDays.map(_weekdayLabel).join(', ')})${_untilSuffix(notice.recurrenceUntil)}',
    NoticeRecurrence.monthly =>
      'Mensal, dia ${notice.dayOfMonth}${_untilSuffix(notice.recurrenceUntil)}',
    NoticeRecurrence.interval =>
      'A cada ${notice.intervalDays} dia(s)${_untilSuffix(notice.recurrenceUntil)}',
  };
  String _untilSuffix(DateTime? date) => date == null ? '' : ' até ${_formatDate(date)}';
  String _formatOptionalDate(DateTime? value) => value == null ? 'sem término' : _formatDate(value);
  String _formatDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}
