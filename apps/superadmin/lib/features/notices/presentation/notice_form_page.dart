import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets/superadmin_advanced_color_picker_dialog.dart';
import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../domain/notice_repository.dart';
import '../domain/platform_notice.dart';
import 'notice_audience_selector.dart' as audience_picker;
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

  final NoticeRepository repository;
  final String? noticeId;
  final ValueChanged<PlatformNotice>? onSaved;
  final VoidCallback? onCancel;

  @override
  State<NoticeFormPage> createState() => _NoticeFormPageState();
}

final class _NoticeFormPageState extends State<NoticeFormPage> {
  late NoticeFormController _controller;
  bool _previewCheckboxChecked = false;
  NoticeTargetDevice _previewDevice = NoticeTargetDevice.web;
  int _commandGeneration = 0;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  @override
  void didUpdateWidget(covariant NoticeFormPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.noticeId != widget.noticeId ||
        !identical(oldWidget.repository, widget.repository)) {
      _commandGeneration++;
      _controller.dispose();
      _controller = _createController();
    }
  }

  NoticeFormController _createController() =>
      NoticeFormController(repository: widget.repository, noticeId: widget.noticeId);

  @override
  void dispose() {
    _commandGeneration++;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      if (_controller.isLoading || _controller.loadFailure != null) {
        return _loadState();
      }
      return SuperadminFormFrame(
        viewportWidth: MediaQuery.sizeOf(context).width,
        navigation: _navigation(),
        scrollKey: Key('notice-step-${_controller.currentStep.name}'),
        body: _wizardContent(),
        footer: _footer(),
      );
    },
  );

  Widget _loadState() {
    final failure = _controller.loadFailure;
    final panel = failure == null
        ? const CoeloStatePanel(
            key: Key('notice-form-loading'),
            title: 'Carregando comunicação',
            message: 'Aguarde enquanto os dados autorizados são carregados.',
            loading: true,
          )
        : CoeloStatePanel(
            key: const Key('notice-form-load-failure'),
            title: switch (failure) {
              NoticeUnauthorizedException() => 'Sem permissão',
              NoticeNotFoundException() => 'Comunicação não encontrada',
              _ => 'Não foi possível carregar',
            },
            message: failure.safeMessage,
            icon: failure is NoticeUnauthorizedException
                ? Icons.lock_outline_rounded
                : failure is NoticeNotFoundException
                ? Icons.search_off_rounded
                : Icons.error_outline_rounded,
            actionLabel: _controller.canRetryLoad ? 'Tentar novamente' : null,
            onAction: _controller.canRetryLoad ? _controller.retryLoad : null,
          );
    final width = MediaQuery.sizeOf(context).width;
    final padding = width >= CoeloBreakpoints.large.minWidth
        ? CoeloSpacing.space10
        : width < CoeloBreakpoints.medium.minWidth
        ? CoeloSpacing.space4
        : CoeloSpacing.space6;
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: panel),
      ),
    );
  }

  Widget _navigation() => SuperadminFormStepNavigation(
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

  Widget _wizardContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _controller.isEditing ? 'Editar comunicação' : 'Nova comunicação',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(
          _controller.currentStep.label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: CoeloSpacing.space4),
        if (_controller.errorMessage case final message?) ...[
          _errorBanner(message),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        if (_controller.stepsWithErrors.contains(_controller.currentStep)) ...[
          _errorBanner(_errorFor(_controller.currentStep)),
          const SizedBox(height: CoeloSpacing.space3),
        ],
        _buildStep(_controller.currentStep),
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
    title: 'Identidade da comunicação',
    description: 'Defina o tipo, um nome claro e a prioridade operacional.',
    children: [
      CoeloAdminSingleSelectField<CommunicationType>(
        key: const Key('communication-type'),
        label: 'Tipo',
        value: _controller.type,
        options: CommunicationType.values,
        optionLabel: (value) => value.label,
        onChanged: _controller.setType,
        prefixIcon: Icons.category_outlined,
      ),
      const SizedBox(height: CoeloSpacing.space4),
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
    description: _controller.type == CommunicationType.notice
        ? 'Configure a mensagem, a interação e a apresentação visual do popup.'
        : 'Configure o conteúdo. Este tipo não gera popup ou interrupção.',
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
      if (_controller.contentFormat == NoticeContentFormat.image) ...[
        _errorBanner(
          'Este aviso usa mídia legada. Novas imagens estão bloqueadas até a decisão '
          'Supabase Storage × R2. Converta para texto antes de salvar ou publicar.',
        ),
        const SizedBox(height: CoeloSpacing.space3),
        OutlinedButton.icon(
          onPressed: () => _controller.setContentFormat(NoticeContentFormat.textBackground),
          icon: const Icon(Icons.text_fields_rounded),
          label: const Text('Converter para texto'),
        ),
      ] else if (_controller.type == CommunicationType.notice)
        _formGrid([
          CoeloAdminSingleSelectField<NoticeContentFormat>(
            label: 'Formato',
            value: _controller.contentFormat,
            options: const [NoticeContentFormat.textBackground],
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
        ])
      else
        CoeloAdminSingleSelectField<NoticeContentFormat>(
          label: 'Formato',
          value: _controller.contentFormat,
          options: const [NoticeContentFormat.textBackground],
          optionLabel: _contentFormatLabel,
          onChanged: _controller.setContentFormat,
        ),
      if (_controller.type == CommunicationType.notice) ...[
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
          _colorButton(
            key: const Key('notice-button-color'),
            label: 'Cor do botão',
            color: _controller.buttonColor,
            onPressed: () => _pickColor(button: true),
          ),
        ]),
        const SizedBox(height: CoeloSpacing.space4),
        _formGrid([
          CoeloFormTextField(
            controller: _controller.buttonLabelController,
            labelText: 'Rótulo do botão principal',
            hintText: 'Confirmar',
            prefixIcon: Icons.smart_button_outlined,
          ),
          CoeloAdminSingleSelectField<NoticePopupSize>(
            key: const Key('notice-popup-size'),
            label: 'Tamanho do popup',
            value: _controller.popupSize,
            options: NoticePopupSize.values,
            optionLabel: _popupSizeLabel,
            onChanged: _controller.setPopupSize,
          ),
        ]),
        const SizedBox(height: CoeloSpacing.space4),
        CoeloAdminToggleField(
          key: const Key('notice-popup-outer-inset-toggle'),
          label: 'Espaçamento externo',
          description: _controller.popupSize == NoticePopupSize.fullscreen
              ? 'Tela cheia ocupa toda a área disponível.'
              : 'Mantém respiro entre o popup e as bordas da tela.',
          value: _controller.hasOuterInset,
          onChanged: _controller.popupSize == NoticePopupSize.fullscreen
              ? null
              : _controller.setHasOuterInset,
        ),
      ] else ...[
        const SizedBox(height: CoeloSpacing.space4),
        _infoBanner(
          '${_controller.type.label} será distribuído como conteúdo do app. '
          'A superfície final será definida no Principal e não usa popup.',
        ),
      ],
    ],
  );

  Widget _audienceStep() => _sectionCard(
    title: 'Público e dispositivos',
    description:
        'Escolha um nível hierárquico e selecione vários destinos ou todos os resultados filtrados.',
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
      if (_controller.audience == NoticeAudience.everyone)
        Semantics(
          label: 'Todos os públicos da plataforma selecionados',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: CoeloSpacing.space1),
                child: Icon(Icons.public_rounded),
              ),
              const SizedBox(width: CoeloSpacing.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Todos', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: CoeloSpacing.space1),
                    Text(
                      'A comunicação será destinada a todo o escopo autorizado.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
      else
        audience_picker.NoticeAudienceSelector(
          options: [
            for (final option in _controller.audienceOptions)
              audience_picker.NoticeAudienceOption(
                id: option.id,
                label: option.label,
                groupLabel: _audienceTypeLabel(_controller.audience),
              ),
          ],
          selection: _audiencePickerSelection,
          onChanged: (selection) => _controller.setAudienceTargets(
            selectAll: selection.allMatching,
            selectedIds: selection.selectedIds,
            excludedIds: selection.excludedIds,
          ),
          onQueryChanged: (query) => _controller.loadAudienceOptions(search: query),
          hasMore: _controller.hasMoreAudienceOptions,
          onLoadMore: _controller.loadMoreAudienceOptions,
          isLoading: _controller.isLoadingAudience,
          errorMessage: _controller.audienceErrorMessage,
          onRetry: _controller.loadAudienceOptions,
        ),
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
            _reviewLine('Tipo', notice.type.label),
            _reviewLine('Prioridade', _priorityLabel(notice.priority)),
            _reviewLine('Formato', _contentFormatLabel(notice.contentFormat)),
            if (notice.isPopup) _reviewLine('Interação', _behaviorLabel(notice.behavior)),
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
          title: notice.isPopup ? 'Prévia no dispositivo' : 'Prévia administrativa',
          description: notice.isPopup
              ? 'Alterne a largura para conferir o popup final antes de publicar.'
              : 'Confira a leitura operacional sem antecipar a tela futura do Principal.',
          children: [
            if (notice.isPopup) ...[
              CoeloAdminSingleSelectField<NoticeTargetDevice>(
                key: const Key('notice-preview-device'),
                label: 'Visualizar como',
                value: _previewDevice,
                options: const [
                  NoticeTargetDevice.web,
                  NoticeTargetDevice.tablet,
                  NoticeTargetDevice.mobile,
                ],
                optionLabel: _deviceLabel,
                onChanged: (value) => setState(() => _previewDevice = value),
              ),
              const SizedBox(height: CoeloSpacing.space4),
              NoticePopupPreview(
                notice: notice,
                device: _previewDevice,
                checkboxChecked: _previewCheckboxChecked,
                onCheckboxChanged: notice.behavior == NoticeBehavior.checkboxConfirmation
                    ? (value) => setState(() => _previewCheckboxChecked = value)
                    : null,
              ),
            ] else
              CommunicationPreviewCard(notice: notice),
            const SizedBox(height: CoeloSpacing.space3),
            OutlinedButton.icon(
              onPressed: _onPreview,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(notice.isPopup ? 'Ver popup final' : 'Abrir prévia'),
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
    final blocked =
        _controller.isLoading || _controller.loadFailure != null || _controller.isSaving;
    return SuperadminFormActionFooter(
      surfaceKey: const Key('notice-form-footer-surface'),
      tertiaryAction: TextButton(
        style: style,
        onPressed: widget.onCancel,
        child: const Text('Cancelar'),
      ),
      continuationActions: [
        if (_controller.currentStep.index > 0)
          OutlinedButton(
            style: style,
            onPressed: blocked ? null : _controller.previousStep,
            child: const Text('Anterior'),
          ),
        OutlinedButton(
          style: style,
          onPressed: blocked ? null : _onSaveDraft,
          child: Text(_controller.isSaving ? 'Salvando…' : 'Salvar rascunho'),
        ),
        FilledButton(
          style: style,
          onPressed: blocked
              ? null
              : _controller.isReviewStep
              ? (_controller.hasAccessibleContrast ? _onSaveAndPublish : null)
              : _controller.continueFromCurrentStep,
          child: Text(
            _controller.isSaving
                ? 'Processando…'
                : _controller.isReviewStep
                ? 'Publicar aviso'
                : 'Continuar',
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({
    required String title,
    required String description,
    required List<Widget> children,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space1),
      Text(description, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: CoeloSpacing.space5),
      ...children,
    ],
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
      return Semantics(
        key: const Key('notice-metrics-summary'),
        container: true,
        label: 'Resumo de desempenho do aviso',
        child: Wrap(
          spacing: CoeloSpacing.space2,
          runSpacing: CoeloSpacing.space2,
          children: [
            for (final metric in values)
              SizedBox(
                width: width,
                child: Semantics(
                  label: '${metric.$1}: ${metric.$2}',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: CoeloSpacing.space2,
                        vertical: CoeloSpacing.space3,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${metric.$2}', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: CoeloSpacing.space1),
                          Text(metric.$1, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
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

  Widget _infoBanner(String message) => Semantics(
    container: true,
    child: Container(
      padding: const EdgeInsets.all(CoeloSpacing.space3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(CoeloRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: CoeloSpacing.space2),
          Expanded(child: Text(message)),
        ],
      ),
    ),
  );

  Future<void> _pickColor({bool background = false, bool button = false}) async {
    final initialColor = button
        ? _controller.buttonColor
        : background
        ? _controller.backgroundColor
        : _controller.textColor;
    final targetLabel = button
        ? 'botão'
        : background
        ? 'fundo'
        : 'texto';
    final selected = await showSuperadminAdvancedColorPicker(
      context,
      initialColor: initialColor,
      title: 'Selecionar cor do $targetLabel',
    );
    if (!mounted || selected == null) return;
    if (button) {
      _controller.setButtonColor(selected);
    } else if (background) {
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
    final selected = await showCoeloDateRangePicker(
      context: context,
      value: DateTimeRange(
        start: DateTime(initial.year, initial.month, initial.day),
        end: DateTime(initial.year, initial.month, initial.day),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2060),
      selectionMode: CoeloDateSelectionMode.single,
      showQuickRanges: false,
    );
    if (mounted && selected != null) onChanged(selected.start);
  }

  Future<void> _onSaveDraft() async {
    if (!_controller.validateAll()) return;
    final controller = _controller;
    final generation = ++_commandGeneration;
    final notice = await controller.saveDraft();
    if (!_isCurrentCommand(generation, controller)) return;
    if (notice == null) {
      _showFeedback(_controller.errorMessage ?? 'Não foi possível salvar o rascunho.');
      return;
    }
    widget.onSaved?.call(notice);
    _showFeedback('Rascunho salvo: ${notice.title}');
  }

  Future<void> _onSaveAndPublish() async {
    if (!_controller.validateAll(requireContrast: true)) return;
    final controller = _controller;
    final generation = ++_commandGeneration;
    final notice = await controller.saveAndPublish();
    if (!_isCurrentCommand(generation, controller)) return;
    if (notice == null) {
      _showFeedback(_controller.errorMessage ?? 'Não foi possível publicar o aviso.');
      return;
    }
    widget.onSaved?.call(notice);
    _showFeedback('Aviso publicado: ${notice.title}');
  }

  bool _isCurrentCommand(int generation, NoticeFormController controller) =>
      mounted && generation == _commandGeneration && identical(controller, _controller);

  Future<void> _onPreview() =>
      showNoticePreview(context, _controller.previewNotice, onAccepted: null);

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
  String _popupSizeLabel(NoticePopupSize value) => switch (value) {
    NoticePopupSize.compact => 'Compacto',
    NoticePopupSize.standard => 'Padrão',
    NoticePopupSize.large => 'Grande',
    NoticePopupSize.fullscreen => 'Tela cheia',
  };

  audience_picker.NoticeAudiencePickerSelection get _audiencePickerSelection {
    final rules = _controller.audienceSelection.rules;
    if (rules.isEmpty) return const audience_picker.NoticeAudiencePickerSelection.explicit();
    final rule = rules.first;
    if (rule.selectAll) {
      return audience_picker.NoticeAudiencePickerSelection.allMatching(
        excludedIds: rule.excludedIds.toSet(),
      );
    }
    return audience_picker.NoticeAudiencePickerSelection.explicit(rule.targetIds.toSet());
  }

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
