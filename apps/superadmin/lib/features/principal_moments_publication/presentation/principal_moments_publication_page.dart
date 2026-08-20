import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width >= 1200) return _desktop(width);
              return _compactOrTablet(width);
            },
          ),
        ),
      ),
    );
  }

  Widget _compactOrTablet(double width) {
    final isTablet = width >= 700;
    final padding = isTablet ? CoeloSpacing.space6 : CoeloSpacing.space4;
    return Column(
      children: [
        if (isTablet) ...[
          _CompactHeader(onNotifications: _showNotifications),
          _PageHeading(onClose: widget.onClose),
        ] else
          _MobilePageHeader(onClose: widget.onClose, onNotifications: _showNotifications),
        Expanded(
          child: SingleChildScrollView(
            key: const Key('moments-publication-scroll'),
            padding: EdgeInsets.fromLTRB(padding, CoeloSpacing.space4, padding, 112),
            child: isTablet ? _tabletEditor() : _mobileEditor(),
          ),
        ),
        _ActionFooter(state: _controller.state, onSave: _saveDraft, onPublish: _publish),
      ],
    );
  }

  Widget _desktop(double width) => Column(
    children: [
      _DesktopHeader(onNotifications: _showNotifications),
      Expanded(
        child: Row(
          children: [
            const _DesktopRail(),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      key: const Key('moments-publication-scroll'),
                      padding: const EdgeInsets.all(CoeloSpacing.space8),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Publicar em Momentos',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: CoeloSpacing.space5),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 10, child: _mediaPanel()),
                                  const SizedBox(width: CoeloSpacing.space4),
                                  Expanded(flex: 10, child: _editorPanel()),
                                  const SizedBox(width: CoeloSpacing.space4),
                                  Expanded(flex: 8, child: _previewPanel()),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  _ActionFooter(
                    state: _controller.state,
                    onSave: _saveDraft,
                    onPublish: _publish,
                    maxWidth: 1120,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _mobileEditor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _mediaPanel(),
      const SizedBox(height: CoeloSpacing.space3),
      _captionCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _audienceCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _scheduleCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _optionsCard(),
    ],
  );

  Widget _tabletEditor() => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 11, child: _mediaPanel()),
          const SizedBox(width: CoeloSpacing.space4),
          Expanded(
            flex: 9,
            child: Column(
              children: [
                _captionCard(),
                const SizedBox(height: CoeloSpacing.space3),
                _audienceCard(),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: CoeloSpacing.space4),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _scheduleCard()),
          const SizedBox(width: CoeloSpacing.space4),
          Expanded(child: _optionsCard()),
        ],
      ),
    ],
  );

  Widget _editorPanel() => Column(
    children: [
      _captionCard(),
      const SizedBox(height: CoeloSpacing.space3),
      _audienceCard(),
      const SizedBox(height: CoeloSpacing.space3),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _scheduleCard()),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(child: _optionsCard()),
        ],
      ),
    ],
  );

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

  void _showNotifications() => _showMessage('Você não tem novas notificações.');
}
