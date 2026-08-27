import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_action_footer.dart';
import '../../../shared/presentation/widgets/superadmin_form_frame.dart';
import '../../../shared/presentation/widgets/superadmin_form_step_navigation.dart';
import '../application/moments_publication_controller.dart';
import '../domain/moments_publication.dart';

part 'principal_moments_publication_components.dart';

class PrincipalMomentsPublicationPage extends StatefulWidget {
  const PrincipalMomentsPublicationPage({
    super.key,
    this.controller,
    this.onAddMedia,
    this.onEditCover,
    this.onSelectContext,
    this.onOpenSchedule,
    this.onDraftSaved,
    this.onPublished,
    this.onClose,
  });

  final MomentsPublicationController? controller;
  final VoidCallback? onAddMedia;
  final VoidCallback? onEditCover;
  final VoidCallback? onSelectContext;
  final VoidCallback? onOpenSchedule;
  final ValueChanged<MomentsDraft>? onDraftSaved;
  final ValueChanged<MomentsPublication>? onPublished;
  final VoidCallback? onClose;

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
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? _createDemoController();
    _captionController = TextEditingController();
    _controller.addListener(_syncCaption);
    unawaited(_load());
  }

  MomentsPublicationController _createDemoController() {
    final draft = MomentsDraft(
      caption:
          'Aprender juntos é crescer juntos. 🌱\n\n'
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
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => SuperadminFormFrame(
          viewportWidth: MediaQuery.sizeOf(context).width,
          scrollKey: const Key('moments-publication-scroll'),
          navigation: _stepNavigation(),
          body: _stepBody(),
          footer: _ActionFooter(
            state: _controller.state,
            currentStep: _currentStep,
            onCancel: _cancel,
            onPrevious: _previousStep,
            onContinue: _continueStep,
            onSave: _saveDraft,
            onPublish: _publish,
          ),
        ),
      ),
    );
  }

  Widget _stepNavigation() => SuperadminFormStepNavigation(
    currentIndex: _currentStep,
    onStepSelected: (index) => setState(() => _currentStep = index),
    steps: [
      for (var index = 0; index < 3; index++)
        SuperadminFormStep(
          key: Key('moments-publication-step-$index'),
          label: const ['Conteúdo', 'Público', 'Revisão'][index],
          enabled: index <= _currentStep,
          status: index < _currentStep
              ? SuperadminFormStepStatus.complete
              : index == _currentStep
              ? SuperadminFormStepStatus.current
              : SuperadminFormStepStatus.incomplete,
        ),
    ],
  );

  Widget _stepBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        const [
          'Conteúdo do momento',
          'Público e publicação',
          'Revise antes de publicar',
        ][_currentStep],
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: CoeloSpacing.space2),
      Text(
        const [
          'Escolha a mídia e escreva a legenda.',
          'Defina quem verá o momento e quando ele será publicado.',
          'Confira a prévia e as configurações antes de publicar.',
        ][_currentStep],
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      LayoutBuilder(
        builder: (context, constraints) {
          final useColumns = constraints.maxWidth >= 700;
          return switch (_currentStep) {
            0 => _contentStep(useColumns),
            1 => _audienceStep(useColumns),
            _ => _reviewStep(useColumns),
          };
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

  Widget _reviewStep(bool useColumns) {
    final settings = Column(
      children: [
        _audienceCard(),
        const SizedBox(height: CoeloSpacing.space4),
        _scheduleCard(),
        const SizedBox(height: CoeloSpacing.space4),
        _optionsCard(),
      ],
    );
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
    final selectedIndex = media.isEmpty ? 0 : _selectedMediaIndex.clamp(0, media.length - 1);
    final selected = media.isEmpty ? MomentsMediaDraft.demo(0) : media[selectedIndex];
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
                  child: _MediaBadge(
                    label: '${selectedIndex + 1}/${media.isEmpty ? 1 : media.length}',
                  ),
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
    _showMessage('A capa será ajustada no fluxo de mídia.');
  }

  void _selectContext() {
    if (widget.onSelectContext case final callback?) {
      callback();
      return;
    }
    _showMessage('A seleção de contexto será aberta no fluxo de publicação.');
  }

  void _openSchedule() {
    if (widget.onOpenSchedule case final callback?) {
      callback();
      return;
    }
    _showMessage('O agendamento permanece em “Publicar agora” nesta versão.');
  }

  Future<void> _saveDraft() async {
    await _controller.saveDraft();
    if (!mounted) return;
    _showMessage(_controller.state.message ?? 'Rascunho salvo.');
    if (_controller.state.phase == MomentsPublicationPhase.saved) {
      widget.onDraftSaved?.call(_controller.state.draft);
      widget.onClose?.call();
    }
  }

  Future<void> _publish() async {
    final publication = await _controller.publish();
    if (!mounted) return;
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
    if (Scaffold.maybeOf(context) == null) return;
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
