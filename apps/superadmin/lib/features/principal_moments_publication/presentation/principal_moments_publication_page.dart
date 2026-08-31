import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../principal_shared/presentation/principal_publication_frame.dart';
import '../../principal_shared/presentation/principal_preview_app_bar.dart';
import '../application/moments_publication_controller.dart';
import '../domain/moments_publication.dart';

part 'principal_moments_publication_components.dart';

class PrincipalMomentsPublicationPage extends StatefulWidget {
  const PrincipalMomentsPublicationPage({
    required this.controller,
    super.key,
    this.onAddMedia,
    this.onEditCover,
    this.onSelectContext,
    this.onOpenSchedule,
    this.onDraftSaved,
    this.onPublished,
    this.onClose,
    this.embedded = false,
  }) : demo = false;

  const PrincipalMomentsPublicationPage.demo({
    super.key,
    this.onAddMedia,
    this.onEditCover,
    this.onSelectContext,
    this.onOpenSchedule,
    this.onDraftSaved,
    this.onPublished,
    this.onClose,
    this.embedded = false,
  }) : controller = null,
       demo = true;

  final MomentsPublicationController? controller;
  final bool demo;
  final VoidCallback? onAddMedia;
  final VoidCallback? onEditCover;
  final VoidCallback? onSelectContext;
  final VoidCallback? onOpenSchedule;
  final ValueChanged<MomentsDraft>? onDraftSaved;
  final ValueChanged<MomentsPublication>? onPublished;
  final VoidCallback? onClose;
  final bool embedded;

  @override
  State<PrincipalMomentsPublicationPage> createState() => _PrincipalMomentsPublicationPageState();
}

class _PrincipalMomentsPublicationPageState extends State<PrincipalMomentsPublicationPage> {
  late final MomentsPublicationController _controller;
  late final bool _ownsController;
  late final TextEditingController _captionController;
  int _selectedMediaIndex = 0;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.demo;
    _controller = widget.demo ? _createDemoController() : widget.controller!;
    _captionController = TextEditingController();
    _controller.addListener(_syncCaption);
    unawaited(_load());
  }

  MomentsPublicationController _createDemoController() {
    final draft = MomentsDraft(
      caption:
          'Aprender juntos é crescer juntos.\n\n'
          'Momentos que fortalecem laços, despertam curiosidade e constroem o futuro.\n\n'
          '#coelomomentos',
      audiences: const {MomentsAudienceKind.families},
      media: List.generate(5, MomentsMediaDraft.demo),
    );
    return MomentsPublicationController(
      repository: InMemoryMomentsPublicationRepository(draft: draft),
      context: MomentsPublicationContext.demo,
    );
  }

  Future<void> _load() async {
    await _controller.load();
    if (!mounted) return;
    _syncCaption();
  }

  void _syncCaption() {
    final caption = _controller.state.draft.caption;
    if (_captionController.text == caption) return;
    _captionController.value = TextEditingValue(
      text: caption,
      selection: TextSelection.collapsed(offset: caption.length),
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_syncCaption);
    _captionController.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: widget.embedded
          ? null
          : PrincipalPreviewAppBar(
              keyPrefix: 'principal-moments-publication',
              onReportBug: () => _unavailable('Reporte de bug'),
              onOpenNotifications: () => _unavailable('Notificações'),
              onOpenContext: () => _unavailable('Troca de contexto'),
            ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.state.phase == MomentsPublicationPhase.loading) {
            return const Center(
              child: CircularProgressIndicator(key: Key('moments-publication-loading')),
            );
          }
          if (_controller.state.phase == MomentsPublicationPhase.unauthorized) {
            return KeyedSubtree(
              key: const Key('moments-publication-unauthorized'),
              child: CoeloStatePanel(
                title: 'Publicação indisponível',
                message: _controller.state.message ?? 'Você não pode publicar neste contexto.',
                icon: Icons.lock_outline_rounded,
              ),
            );
          }
          if (_controller.state.phase == MomentsPublicationPhase.conflict) {
            return KeyedSubtree(
              key: const Key('moments-publication-conflict'),
              child: CoeloStatePanel(
                title: 'Rascunho desatualizado',
                message: _controller.state.message ?? 'Recarregue antes de continuar.',
                icon: Icons.sync_problem_rounded,
                actionLabel: 'Recarregar rascunho',
                onAction: _retry,
              ),
            );
          }
          if (_controller.state.phase == MomentsPublicationPhase.failure) {
            return KeyedSubtree(
              key: const Key('moments-publication-failure'),
              child: CoeloStatePanel(
                title: _controller.state.message == 'Não foi possível carregar o rascunho.'
                    ? 'Não foi possível carregar'
                    : 'Não foi possível concluir',
                message: _controller.state.message ?? 'Tente novamente.',
                icon: Icons.cloud_off_outlined,
                actionLabel: 'Tentar novamente',
                onAction: _retry,
              ),
            );
          }
          final publishing = _controller.state.phase == MomentsPublicationPhase.publishing;
          return PrincipalPublicationFrame(
            scrollKey: const Key('moments-publication-scroll'),
            navigation: ExcludeFocus(
              key: const Key('moments-publication-navigation-focus-lock'),
              excluding: publishing,
              child: AbsorbPointer(absorbing: publishing, child: _stepNavigation()),
            ),
            body: ExcludeFocus(
              key: const Key('moments-publication-body-focus-lock'),
              excluding: publishing,
              child: AbsorbPointer(
                key: const Key('moments-publication-body-lock'),
                absorbing: publishing,
                child: _stepBody(),
              ),
            ),
            footer: _ActionFooter(
              state: _controller.state,
              currentStep: _currentStep,
              onCancel: _cancel,
              onPrevious: _previousStep,
              onContinue: _continueStep,
              onSave: _saveDraft,
              onPublish: _publish,
            ),
          );
        },
      ),
    );
  }

  void _unavailable(String label) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label estará disponível na experiência completa.')));

  Future<void> _retry() async {
    final publication = await _controller.retry();
    if (!mounted || publication == null) return;
    widget.onPublished?.call(publication);
    widget.onClose?.call();
  }

  Widget _stepNavigation() => PrincipalPublicationStepNavigation(
    currentIndex: _currentStep,
    onStepSelected: (index) => setState(() => _currentStep = index),
    steps: [
      for (var index = 0; index < 3; index++)
        PrincipalPublicationStep(
          key: Key('moments-publication-step-$index'),
          label: const ['Conteúdo', 'Público', 'Revisão'][index],
          enabled: index <= _currentStep,
          status: index < _currentStep
              ? PrincipalPublicationStepStatus.complete
              : index == _currentStep
              ? PrincipalPublicationStepStatus.current
              : PrincipalPublicationStepStatus.incomplete,
        ),
    ],
  );

  Widget _stepBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Sua publicação',
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(
        'Publicar em Momentos · ${const ['Conteúdo', 'Público', 'Revisão'][_currentStep]}',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      LayoutBuilder(
        builder: (context, constraints) {
          final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
          final useColumns = constraints.maxWidth >= 700 && !enlargedText;
          final content = switch (_currentStep) {
            0 => _contentStep(useColumns),
            1 => _audienceStep(useColumns),
            _ => _reviewStep(useColumns, showPreview: constraints.maxWidth < 840 || enlargedText),
          };
          if (constraints.maxWidth < 840 || enlargedText) return content;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: content),
              const SizedBox(width: CoeloSpacing.space5),
              SizedBox(
                key: const Key('moments-publication-desktop-preview'),
                width: 320,
                child: _previewPanel(),
              ),
            ],
          );
        },
      ),
    ],
  );

  Widget _contentStep(bool useColumns) {
    if (!useColumns) {
      return Column(
        children: [
          _mediaPanel(),
          const SizedBox(height: CoeloSpacing.space4),
          _captionCard(),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 4, child: _mediaPanel()),
        const SizedBox(width: CoeloSpacing.space4),
        Expanded(flex: 5, child: _captionCard()),
      ],
    );
  }

  Widget _audienceStep(bool useColumns) {
    final settings = Column(
      children: [
        _scheduleCard(),
        const SizedBox(height: CoeloSpacing.space4),
        _optionsCard(),
      ],
    );
    if (!useColumns) {
      return Column(
        children: [
          _audienceCard(),
          const SizedBox(height: CoeloSpacing.space4),
          settings,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _audienceCard()),
        const SizedBox(width: CoeloSpacing.space4),
        Expanded(child: settings),
      ],
    );
  }

  Widget _reviewStep(bool useColumns, {required bool showPreview}) {
    final settings = Column(
      children: [
        _audienceCard(),
        const SizedBox(height: CoeloSpacing.space4),
        _scheduleCard(),
        const SizedBox(height: CoeloSpacing.space4),
        _optionsCard(),
      ],
    );
    if (!showPreview) return settings;
    if (!useColumns) {
      return Column(
        children: [
          _previewPanel(),
          const SizedBox(height: CoeloSpacing.space4),
          settings,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _previewPanel()),
        const SizedBox(width: CoeloSpacing.space4),
        Expanded(child: settings),
      ],
    );
  }

  Widget _mediaPanel() {
    final media = _controller.state.draft.media;
    if (media.isEmpty) {
      return _SectionCard(
        label: 'Mídia',
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: _EmptyMomentMedia(onPressed: _addMedia),
        ),
      );
    }
    final selectedIndex = media.isEmpty ? 0 : _selectedMediaIndex.clamp(0, media.length - 1);
    final selected = media[selectedIndex];
    return _SectionCard(
      label: 'Mídia',
      child: Column(
        children: [
          AspectRatio(
            key: const Key('moments-publication-primary-media'),
            aspectRatio: 9 / 16,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MomentAsset(media: selected, radius: CoeloRadius.md),
                Positioned(
                  right: CoeloSpacing.space2,
                  top: CoeloSpacing.space2,
                  child: _MediaBadge(label: '${selectedIndex + 1}/${media.length}'),
                ),
                Positioned(
                  left: CoeloSpacing.space2,
                  bottom: CoeloSpacing.space2,
                  child: FilledButton.tonalIcon(
                    key: const Key('moments-publication-edit-cover'),
                    onPressed: _editCover,
                    icon: const Icon(Icons.edit_outlined, size: CoeloSize.iconSm),
                    label: const Text('Editar capa'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.66),
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: const Size(48, 48),
                      overlayColor: Colors.transparent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: CoeloSpacing.space2),
          SizedBox(
            height: 64,
            child: Row(
              children: [
                _AddMediaButton(onPressed: _addMedia),
                const SizedBox(width: CoeloSpacing.space2),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: media.length,
                    separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space2),
                    itemBuilder: (context, index) => _MediaThumbnail(
                      key: ValueKey('moments-media-${media[index].localId}'),
                      media: media[index],
                      selected: index == selectedIndex,
                      onPressed: () => setState(() => _selectedMediaIndex = index),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _captionCard() => _SectionCard(
    label: 'Legenda',
    trailing: Text('${_controller.state.draft.captionCharacters}/2200'),
    child: CoeloFormTextField(
      fieldKey: const Key('moments-publication-caption'),
      controller: _captionController,
      labelText: 'Legenda',
      prefixIcon: Icons.notes_rounded,
      hintText: 'Conte o que torna este momento especial.',
      onChanged: _controller.setCaption,
      maxLines: 6,
    ),
  );

  Widget _audienceCard() {
    final context = _controller.context;
    return _SectionCard(
      label: 'Público e contexto',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContextTile(context: context, onPressed: _selectContext),
          const SizedBox(height: CoeloSpacing.space3),
          Wrap(
            spacing: CoeloSpacing.space2,
            runSpacing: CoeloSpacing.space2,
            children: MomentsAudienceKind.values
                .map(
                  (audience) => _AudienceChip(
                    key: Key('moments-audience-${audience.keyName}'),
                    audience: audience,
                    selected: _controller.state.draft.audiences.contains(audience),
                    onSelected: () => _controller.toggleAudience(audience),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }

  Widget _scheduleCard() => _SectionCard(
    label: 'Agendamento',
    child: _SettingRow(
      key: const Key('moments-publication-schedule'),
      icon: Icons.calendar_today_outlined,
      label: 'Publicar agora',
      valueColor: true,
      trailing: Icons.keyboard_arrow_down_rounded,
      onPressed: _openSchedule,
    ),
  );

  Widget _optionsCard() => _SectionCard(
    label: 'Opções',
    child: _MomentToggleField(
      key: const Key('moments-publication-save-toggle'),
      label: 'Salvar como rascunho',
      value: _controller.state.draft.saveAsDraft,
      onChanged: _controller.setSaveAsDraft,
    ),
  );

  Widget _previewPanel() => _SectionCard(
    key: const Key('moments-publication-preview'),
    label: 'Prévia do momento',
    trailing: const Tooltip(
      message: 'Simulação de como a publicação aparecerá em Momentos.',
      child: Icon(Icons.info_outline_rounded, size: CoeloSize.iconSm),
    ),
    child: _MomentPreview(draft: _controller.state.draft, context: _controller.context),
  );

  void _cancel() {
    if (widget.onClose case final callback?) {
      callback();
      return;
    }
    Navigator.maybePop(context);
  }

  void _previousStep() {
    if (_currentStep == 0) return;
    setState(() => _currentStep -= 1);
  }

  void _continueStep() {
    if (_currentStep >= 2) return;
    setState(() => _currentStep += 1);
  }

  void _addMedia() {
    if (widget.onAddMedia case final callback?) {
      callback();
      return;
    }
    if (!widget.demo) {
      _showMessage('Adicionar mídia está indisponível sem a integração autorizada.');
      return;
    }
    _controller.addMedia(MomentsMediaDraft.demo(_controller.state.draft.media.length));
    if (_controller.state.draft.media.isNotEmpty) {
      setState(() => _selectedMediaIndex = _controller.state.draft.media.length - 1);
    }
    _showMessage(_controller.state.message ?? 'Mídia adicionada à demonstração.');
  }

  void _editCover() {
    if (widget.onEditCover case final callback?) {
      callback();
      return;
    }
    _showMessage('Ajustar capa está indisponível sem a integração de mídia autorizada.');
  }

  void _selectContext() {
    if (widget.onSelectContext case final callback?) {
      callback();
      return;
    }
    _showMessage('Selecionar contexto está indisponível sem a integração autorizada.');
  }

  void _openSchedule() {
    if (widget.onOpenSchedule case final callback?) {
      callback();
      return;
    }
    _showMessage('Agendamento está indisponível sem a integração autorizada.');
  }

  Future<void> _saveDraft() async {
    await _controller.saveDraft();
    if (!mounted) return;
    if ({
      MomentsPublicationPhase.failure,
      MomentsPublicationPhase.conflict,
      MomentsPublicationPhase.unauthorized,
    }.contains(_controller.state.phase)) {
      return;
    }
    _showMessage(_controller.state.message ?? 'Rascunho salvo.');
    if (_controller.state.phase == MomentsPublicationPhase.saved) {
      widget.onDraftSaved?.call(_controller.state.draft);
      widget.onClose?.call();
    }
  }

  Future<void> _publish() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final publication = await _controller.publish();
    if (!mounted) return;
    if ({
      MomentsPublicationPhase.failure,
      MomentsPublicationPhase.conflict,
      MomentsPublicationPhase.unauthorized,
    }.contains(_controller.state.phase)) {
      return;
    }
    _showMessage(
      publication == null
          ? (_controller.state.message ?? 'Revise os dados antes de publicar.')
          : 'Momento publicado.',
    );
    if (publication != null) {
      widget.onPublished?.call(publication);
      widget.onClose?.call();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(
            CoeloSpacing.space4,
            CoeloSpacing.space4,
            CoeloSpacing.space4,
            96,
          ),
        ),
      );
  }
}
