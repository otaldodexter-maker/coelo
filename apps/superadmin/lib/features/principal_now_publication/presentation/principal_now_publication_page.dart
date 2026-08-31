import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../principal_shared/presentation/principal_publication_frame.dart';
import '../../principal_shared/presentation/principal_preview_app_bar.dart';
import '../application/now_publication_controller.dart';
import '../domain/now_publication.dart';
import '../domain/now_media_metadata.dart';

typedef NowMediaPicker = Future<NowMediaDraft?> Function();
typedef NowAudioPicker = Future<NowAudioDraft?> Function();

bool _sameContext(NowPublicationContext left, NowPublicationContext right) =>
    left.tenantId == right.tenantId &&
    left.institutionId == right.institutionId &&
    left.unitId == right.unitId &&
    left.groupId == right.groupId &&
    left.institutionName == right.institutionName &&
    left.unitName == right.unitName &&
    left.groupName == right.groupName &&
    setEquals(left.allowedAudiences, right.allowedAudiences) &&
    left.capabilities.maxVideoDuration == right.capabilities.maxVideoDuration;

final class PrincipalNowPublicationPage extends StatefulWidget {
  const PrincipalNowPublicationPage({
    required this.repository,
    required this.publicationContext,
    this.embedded = false,
    this.mediaPicker,
    this.audioPicker,
    this.onClose,
    this.onCompleted,
    super.key,
  });

  const PrincipalNowPublicationPage.demo({
    required this.repository,
    this.publicationContext = NowPublicationContext.demo,
    this.embedded = false,
    this.mediaPicker,
    this.audioPicker,
    this.onClose,
    this.onCompleted,
    super.key,
  });

  final NowPublicationRepository repository;
  final bool embedded;
  final NowPublicationContext publicationContext;
  final NowMediaPicker? mediaPicker;
  final NowAudioPicker? audioPicker;
  final VoidCallback? onClose;
  final ValueChanged<NowPublication>? onCompleted;

  @override
  State<PrincipalNowPublicationPage> createState() => _PrincipalNowPublicationPageState();
}

final class _PrincipalNowPublicationPageState extends State<PrincipalNowPublicationPage> {
  late NowPublicationController controller;
  late final TextEditingController captionController;
  var _currentStep = 0;
  var _pickerGeneration = 0;
  var _overlayGeneration = 0;
  final _ownedOverlays = <(NavigatorState, Route<dynamic>)>{};

  @override
  void initState() {
    super.initState();
    captionController = TextEditingController();
    controller = _createController();
    controller.addListener(_synchronizeLoadedDraft);
    unawaited(controller.load());
  }

  NowPublicationController _createController() =>
      NowPublicationController(repository: widget.repository, context: widget.publicationContext);

  @override
  void didUpdateWidget(covariant PrincipalNowPublicationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.repository, widget.repository) &&
        _sameContext(oldWidget.publicationContext, widget.publicationContext)) {
      return;
    }
    _pickerGeneration += 1;
    _dismissOwnedOverlays();
    controller.removeListener(_synchronizeLoadedDraft);
    controller.dispose();
    captionController.value = TextEditingValue.empty;
    _currentStep = 0;
    controller = _createController();
    controller.addListener(_synchronizeLoadedDraft);
    unawaited(controller.load());
  }

  void _synchronizeLoadedDraft() {
    final caption = controller.state.draft.caption;
    if (captionController.text != caption && !captionController.selection.isValid) {
      captionController.value = TextEditingValue(
        text: caption,
        selection: TextSelection.collapsed(offset: caption.length),
      );
    }
  }

  @override
  void dispose() {
    _pickerGeneration += 1;
    _dismissOwnedOverlays();
    controller.removeListener(_synchronizeLoadedDraft);
    captionController.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<T?> _showOwnedDialog<T>({required WidgetBuilder builder}) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<T>(context: context, builder: builder);
    final entry = (navigator, route as Route<dynamic>);
    _ownedOverlays.add(entry);
    try {
      final result = await navigator.push<T>(route);
      await route.completed;
      return result;
    } finally {
      _ownedOverlays.remove(entry);
    }
  }

  Future<T?> _showOwnedBottomSheet<T>({
    required WidgetBuilder builder,
    required Color backgroundColor,
  }) async {
    final navigator = Navigator.of(context);
    final route = ModalBottomSheetRoute<T>(
      builder: builder,
      capturedThemes: InheritedTheme.capture(from: context, to: navigator.context),
      backgroundColor: backgroundColor,
      showDragHandle: true,
      isScrollControlled: true,
    );
    final entry = (navigator, route as Route<dynamic>);
    _ownedOverlays.add(entry);
    try {
      final result = await navigator.push<T>(route);
      await route.completed;
      return result;
    } finally {
      _ownedOverlays.remove(entry);
    }
  }

  void _dismissOwnedOverlays() {
    _overlayGeneration += 1;
    for (final (navigator, route) in _ownedOverlays.toList(growable: false)) {
      if (route.isActive) navigator.removeRoute(route);
    }
    _ownedOverlays.clear();
  }

  Future<void> _pickMedia() async {
    final generation = _pickerGeneration;
    final media = await (widget.mediaPicker?.call() ?? _defaultMediaPicker());
    if (!mounted || generation != _pickerGeneration) return;
    if (media != null) controller.setMedia(media);
  }

  Future<NowMediaDraft?> _defaultMediaPicker() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'mp4'],
    );
    final file = result?.files.singleOrNull;
    if (file?.bytes == null) return null;
    final mime = _mime(file!.extension);
    if (mime.startsWith('video/')) {
      return NowMediaDraft.video(
        localId: '${DateTime.now().microsecondsSinceEpoch}-${file.name}',
        name: file.name,
        mimeType: mime,
        bytes: file.bytes!,
        duration: readMp4Duration(file.bytes!) ?? Duration.zero,
      );
    }
    return NowMediaDraft.image(
      localId: '${DateTime.now().microsecondsSinceEpoch}-${file.name}',
      name: file.name,
      mimeType: mime,
      bytes: file.bytes!,
    );
  }

  Future<void> _pickAudio() async {
    final generation = _pickerGeneration;
    final audio = await (widget.audioPicker?.call() ?? _defaultAudioPicker());
    if (!mounted || generation != _pickerGeneration) return;
    if (audio != null) {
      controller.setAudio(audio);
      if (mounted) await _showAudioRights();
    }
  }

  Future<NowAudioDraft?> _defaultAudioPicker() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'wav', 'aac'],
    );
    final file = result?.files.singleOrNull;
    if (file?.bytes == null) return null;
    return NowAudioDraft(
      localId: '${DateTime.now().microsecondsSinceEpoch}-${file!.name}',
      name: file.name,
      mimeType: _audioMime(file.extension),
      bytes: file.bytes!,
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      if (controller.state.phase == NowPublicationPhase.loading) {
        return const Material(
          child: Center(child: CircularProgressIndicator(key: Key('now-publication-loading'))),
        );
      }
      if (controller.state.phase == NowPublicationPhase.unauthorized) {
        return _stateScaffold(
          key: const Key('now-publication-unauthorized'),
          title: 'Publicação indisponível',
          message: controller.state.message ?? 'Você não pode publicar neste contexto.',
          icon: Icons.lock_outline_rounded,
        );
      }
      if (controller.state.phase == NowPublicationPhase.conflict) {
        return _stateScaffold(
          key: const Key('now-publication-conflict'),
          title: 'Rascunho desatualizado',
          message: controller.state.message ?? 'Recarregue antes de continuar.',
          icon: Icons.sync_problem_rounded,
          actionLabel: 'Recarregar rascunho',
          onAction: _retry,
        );
      }
      if (controller.state.phase == NowPublicationPhase.failure) {
        return _stateScaffold(
          key: const Key('now-publication-failure'),
          title: controller.state.message == 'Não foi possível carregar o rascunho.'
              ? 'Não foi possível carregar'
              : 'Não foi possível concluir',
          message: controller.state.message ?? 'Tente novamente.',
          icon: Icons.cloud_off_outlined,
          actionLabel: 'Tentar novamente',
          onAction: _retry,
        );
      }
      final busy = {
        NowPublicationPhase.uploading,
        NowPublicationPhase.saving,
        NowPublicationPhase.publishing,
      }.contains(controller.state.phase);
      return LayoutBuilder(
        builder: (context, constraints) => Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: widget.embedded
              ? null
              : PrincipalPreviewAppBar(
                  keyPrefix: 'principal-now-publication',
                  onReportBug: () => _unavailable('Reporte de bug'),
                  onOpenNotifications: () => _unavailable('Notificações'),
                  onOpenContext: () => _unavailable('Troca de contexto'),
                ),
          body: SafeArea(
            top: !widget.embedded,
            bottom: !widget.embedded,
            left: !widget.embedded,
            right: !widget.embedded,
            child: PrincipalPublicationFrame(
              navigation: ExcludeFocus(
                key: const Key('now-publication-navigation-focus-lock'),
                excluding: busy,
                child: AbsorbPointer(
                  absorbing: busy,
                  child: PrincipalPublicationStepNavigation(
                    steps: [
                      PrincipalPublicationStep(
                        label: 'Mídia',
                        status: _currentStep == 0
                            ? PrincipalPublicationStepStatus.current
                            : PrincipalPublicationStepStatus.complete,
                      ),
                      PrincipalPublicationStep(
                        label: 'Detalhes',
                        status: _currentStep == 1
                            ? PrincipalPublicationStepStatus.current
                            : PrincipalPublicationStepStatus.incomplete,
                        enabled: _currentStep == 1,
                      ),
                    ],
                    currentIndex: _currentStep,
                    onStepSelected: (step) {
                      if (step <= _currentStep) setState(() => _currentStep = step);
                    },
                  ),
                ),
              ),
              scrollKey: Key('now-publication-step-$_currentStep'),
              body: ExcludeFocus(
                key: const Key('now-publication-body-focus-lock'),
                excluding: busy,
                child: AbsorbPointer(
                  key: const Key('now-publication-body-lock'),
                  absorbing: busy,
                  child: _stepBody(),
                ),
              ),
              footer: _PublicationFooter(
                currentStep: _currentStep,
                controller: controller,
                onCancel: widget.onClose ?? () => Navigator.maybePop(context),
                onPrevious: () => setState(() => _currentStep = 0),
                onContinue: () => setState(() => _currentStep = 1),
                onCompleted: widget.onCompleted,
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _stateScaffold({
    required Key key,
    required String title,
    required String message,
    required IconData icon,
    String? actionLabel,
    VoidCallback? onAction,
  }) => Scaffold(
    key: key,
    backgroundColor: Theme.of(context).colorScheme.surface,
    appBar: widget.embedded
        ? null
        : PrincipalPreviewAppBar(
            keyPrefix: 'principal-now-publication',
            onReportBug: () => _unavailable('Reporte de bug'),
            onOpenNotifications: () => _unavailable('Notificações'),
            onOpenContext: () => _unavailable('Troca de contexto'),
          ),
    body: CoeloStatePanel(
      title: title,
      message: message,
      icon: icon,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
  );

  Future<void> _retry() async {
    final publication = await controller.retry();
    if (!mounted || publication == null) return;
    widget.onCompleted?.call(publication);
  }

  Widget _stepBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Sua publicação', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: CoeloSpacing.space1),
      Text('Publicar no Agora', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: CoeloSpacing.space1),
      Text(
        _currentStep == 0 ? 'Escolha e prepare a mídia.' : 'Defina público e publicação.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: CoeloSpacing.space5),
      LayoutBuilder(
        builder: (context, constraints) {
          final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
          final editor = _currentStep == 0
              ? _MediaAndTools(
                  controller: controller,
                  width: constraints.maxWidth >= CoeloBreakpoints.medium.minWidth ? 300 : 220,
                  onPickMedia: _pickMedia,
                  onText: _showTextEditor,
                  onMusic: _pickAudio,
                  onCrop: _showCropEditor,
                  onCover: _showCoverEditor,
                )
              : _Details(controller: controller, captionController: captionController);
          if (constraints.maxWidth < 840 || enlargedText) return editor;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: editor),
              const SizedBox(width: CoeloSpacing.space5),
              SizedBox(
                key: const Key('now-publication-desktop-preview'),
                width: 320,
                child: _NowPublicationPreview(controller: controller, onPick: _pickMedia),
              ),
            ],
          );
        },
      ),
    ],
  );

  void _unavailable(String label) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('$label estará disponível na experiência completa.')));

  Future<void> _showTextEditor() async {
    final requestedController = controller;
    final generation = _overlayGeneration;
    final text = TextEditingController(text: requestedController.state.draft.overlayText);
    await _showOwnedDialog<void>(
      builder: (context) => _NowDialog(
        title: 'Texto sobre a mídia',
        body: CoeloFormTextField(
          fieldKey: const Key('now-overlay-field'),
          controller: text,
          labelText: 'Texto sobre a mídia',
          hintText: 'Digite uma mensagem curta',
          prefixIcon: Icons.text_fields_rounded,
          maxLength: 60,
          onChanged: (value) {
            if (generation == _overlayGeneration && identical(requestedController, controller)) {
              requestedController.setOverlayText(value);
            }
          },
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Concluir')),
        ],
      ),
    );
    text.dispose();
  }

  Future<void> _showCropEditor() => _showSliderSheet(
    title: 'Cortar mídia',
    label: 'Ajustar enquadramento',
    value: controller.state.draft.media?.cropScale ?? 1,
    min: 1,
    max: 2,
    onChanged: (value) {
      final media = controller.state.draft.media;
      controller.setCrop(scale: value, x: media?.cropX ?? 0, y: media?.cropY ?? 0);
    },
  );

  Future<void> _showCoverEditor() => _showSliderSheet(
    title: 'Escolher capa',
    label: 'Posição no vídeo',
    value: controller.state.draft.media?.coverPosition ?? 0,
    min: 0,
    max: 1,
    onChanged: controller.setCoverPosition,
  );

  Future<void> _showSliderSheet({
    required String title,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) async {
    final requestedController = controller;
    final generation = _overlayGeneration;
    final current = ValueNotifier(value);
    await _showOwnedBottomSheet<void>(
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space5),
          child: ValueListenableBuilder<double>(
            valueListenable: current,
            builder: (context, selected, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space4),
                Text(label),
                Slider(
                  value: selected,
                  min: min,
                  max: max,
                  onChanged: (next) {
                    current.value = next;
                    if (generation == _overlayGeneration &&
                        identical(requestedController, controller)) {
                      onChanged(next);
                    }
                  },
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Concluir'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    current.dispose();
  }

  Future<void> _showAudioRights() async {
    final requestedController = controller;
    final generation = _overlayGeneration;
    await _showOwnedDialog<void>(
      builder: (context) => _NowDialog(
        title: 'Usar áudio próprio',
        body: const Text('Confirme que você tem autorização para usar este áudio.'),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () {
              if (generation == _overlayGeneration && identical(requestedController, controller)) {
                requestedController.removeAudio();
              }
              Navigator.pop(context);
            },
            child: const Text('Remover'),
          ),
          FilledButton(
            onPressed: () {
              if (generation == _overlayGeneration && identical(requestedController, controller)) {
                requestedController.confirmAudioRights(true);
              }
              Navigator.pop(context);
            },
            child: const Text('Confirmar direitos'),
          ),
        ],
      ),
    );
  }
}

final class _NowPublicationPreview extends StatelessWidget {
  const _NowPublicationPreview({required this.controller, required this.onPick});

  final NowPublicationController controller;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      borderRadius: BorderRadius.circular(CoeloRadius.lg),
    ),
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Prévia do Agora',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          AspectRatio(
            aspectRatio: 9 / 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(CoeloRadius.md),
              child: _MediaPreview(controller: controller, onPick: onPick, readOnly: true),
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          Text(
            'Disponível por 24 horas',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    ),
  );
}

final class _MediaAndTools extends StatelessWidget {
  const _MediaAndTools({
    required this.controller,
    required this.width,
    required this.onPickMedia,
    required this.onText,
    required this.onMusic,
    required this.onCrop,
    required this.onCover,
  });
  final NowPublicationController controller;
  final double width;
  final VoidCallback onPickMedia;
  final VoidCallback onText;
  final VoidCallback onMusic;
  final VoidCallback onCrop;
  final VoidCallback onCover;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
      final stackTools = enlargedText || constraints.maxWidth < width + 120;
      final stage = SizedBox(
        key: const Key('now-media-stage'),
        width: width,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CoeloRadius.lg),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLowest,
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: _MediaPreview(controller: controller, onPick: onPickMedia),
            ),
          ),
        ),
      );
      final tools = <Widget>[
        _Tool(icon: Icons.text_fields_rounded, label: 'Texto', onPressed: onText),
        _Tool(icon: Icons.music_note_rounded, label: 'Música', onPressed: onMusic),
        _Tool(icon: Icons.crop_rounded, label: 'Cortar', onPressed: onCrop),
        _Tool(icon: Icons.image_outlined, label: 'Capa', onPressed: onCover),
      ];
      if (stackTools) {
        return Column(
          children: [
            stage,
            const SizedBox(height: CoeloSpacing.space2),
            Wrap(alignment: WrapAlignment.center, spacing: CoeloSpacing.space2, children: tools),
          ],
        );
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          stage,
          const SizedBox(width: CoeloSpacing.space3),
          Column(mainAxisSize: MainAxisSize.min, children: tools),
        ],
      );
    },
  );
}

final class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.controller, required this.onPick, this.readOnly = false});
  final NowPublicationController controller;
  final VoidCallback onPick;
  final bool readOnly;
  @override
  Widget build(BuildContext context) {
    final media = controller.state.draft.media;
    if (media == null) {
      final enlargedText = MediaQuery.textScalerOf(context).scale(1) > 1.5;
      if (readOnly) {
        return DecoratedBox(
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerLow),
          child: Center(
            child: Text(
              'Prévia sem mídia',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }
      return _PrincipalInteractiveSurface(
        semanticLabel: 'Adicionar mídia ao Agora',
        onPressed: onPick,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                size: enlargedText ? 32 : 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: enlargedText ? CoeloSpacing.space1 : CoeloSpacing.space2),
              Text(
                'Adicionar mídia',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: CoeloSpacing.space1),
              const Text('Imagem ou vídeo vertical', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (media.isVideo)
          const _NowVideoPreview()
        else
          Transform.scale(
            key: const Key('now-media-crop'),
            scale: media.cropScale,
            alignment: Alignment(media.cropX, media.cropY),
            child: media.bytes.isEmpty && media.remoteUrl != null
                ? Image.network(
                    media.remoteUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _UnavailableNowMedia(),
                  )
                : Image.memory(
                    media.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _UnavailableNowMedia(),
                  ),
          ),
        if (media.isVideo)
          Align(
            alignment: Alignment(0, (media.coverPosition * 2) - 1),
            child: Semantics(
              label: 'Capa selecionada em ${(media.coverPosition * 100).round()} por cento',
              child: Container(
                key: const Key('now-cover-position-indicator'),
                height: 3,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        if (controller.state.draft.overlayText.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(CoeloSpacing.space4),
              child: Text(
                controller.state.draft.overlayText,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w800,
                  shadows: [Shadow(color: Theme.of(context).colorScheme.scrim, blurRadius: 8)],
                ),
              ),
            ),
          ),
        Positioned(
          top: CoeloSpacing.space3,
          left: CoeloSpacing.space3,
          child: _Duration(media: media),
        ),
        if (!readOnly)
          Positioned(
            bottom: CoeloSpacing.space3,
            right: CoeloSpacing.space3,
            child: IconButton.filledTonal(
              tooltip: 'Trocar mídia',
              onPressed: onPick,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
      ],
    );
  }
}

final class _NowVideoPreview extends StatelessWidget {
  const _NowVideoPreview();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('now-video-preview'),
    color: Theme.of(context).colorScheme.inverseSurface,
    child: Center(
      child: Icon(
        Icons.play_circle_fill_rounded,
        color: Theme.of(context).colorScheme.onInverseSurface,
        size: 56,
      ),
    ),
  );
}

final class _UnavailableNowMedia extends StatelessWidget {
  const _UnavailableNowMedia();

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('now-media-unavailable'),
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    child: Semantics(
      label: 'Mídia indisponível',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: CoeloSize.iconLg,
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Text(
                'Mídia indisponível',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

final class _Duration extends StatelessWidget {
  const _Duration({required this.media});
  final NowMediaDraft media;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(CoeloRadius.full),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CoeloSpacing.space2,
        vertical: CoeloSpacing.space1,
      ),
      child: Text(
        media.duration == null ? 'Imagem' : _durationLabel(media.duration!),
        style: TextStyle(color: Theme.of(context).colorScheme.onInverseSurface),
      ),
    ),
  );
}

final class _PrincipalInteractiveSurface extends StatefulWidget {
  const _PrincipalInteractiveSurface({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
    this.selected = false,
    this.borderRadius = CoeloRadius.lg,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;
  final bool selected;
  final double borderRadius;

  @override
  State<_PrincipalInteractiveSurface> createState() => _PrincipalInteractiveSurfaceState();
}

final class _PrincipalInteractiveSurfaceState extends State<_PrincipalInteractiveSurface> {
  bool highlighted = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => highlighted = true),
        onExit: (_) => setState(() => highlighted = false),
        child: FocusableActionDetector(
          onShowFocusHighlight: (value) => setState(() => highlighted = value),
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: highlighted || widget.selected ? 1 : 0),
            duration: reduceMotion ? Duration.zero : CoeloMotion.standard,
            curve: Curves.easeOutCubic,
            builder: (context, progress, child) => DecoratedBox(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: Color.lerp(
                    colors.outlineVariant,
                    colors.primary.withValues(alpha: 0.64),
                    progress,
                  )!,
                  width: 1 + (0.5 * progress),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.10 * progress),
                    blurRadius: 10 * progress,
                    offset: Offset(0, 2 * progress),
                  ),
                ],
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onPressed,
                child: child,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

final class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space2),
    child: Column(
      children: [
        IconButton.outlined(
          tooltip: label,
          onPressed: onPressed,
          style: ButtonStyle(
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)) {
                return Theme.of(context).colorScheme.primary;
              }
              return Theme.of(context).colorScheme.onSurface;
            }),
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
            side: WidgetStateProperty.resolveWith((states) {
              final highlighted =
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed);
              return BorderSide(
                color: highlighted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              );
            }),
          ),
          icon: Icon(icon),
          constraints: const BoxConstraints.tightFor(
            width: CoeloSize.touchMin,
            height: CoeloSize.touchMin,
          ),
        ),
        const SizedBox(height: CoeloSpacing.space1),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    ),
  );
}

final class _Details extends StatelessWidget {
  const _Details({required this.controller, required this.captionController});
  final NowPublicationController controller;
  final TextEditingController captionController;
  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final draft = state.draft;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CoeloFormTextField(
          fieldKey: const Key('now-caption-field'),
          controller: captionController,
          labelText: 'Contexto opcional',
          hintText: 'Escreva algo (opcional)',
          prefixIcon: Icons.short_text_rounded,
          maxLength: 60,
          maxLines: 3,
          onChanged: controller.setCaption,
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _ContextCard(
          contextData: controller.context,
          selected: draft.audiences.contains(NowAudience.families),
          onTap: () => controller.toggleAudience(NowAudience.families),
        ),
        const SizedBox(height: CoeloSpacing.space3),
        _ScheduleCard(controller: controller),
        const SizedBox(height: CoeloSpacing.space3),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(CoeloRadius.md),
          ),
          child: const Padding(
            padding: EdgeInsets.all(CoeloSpacing.space4),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded),
                SizedBox(width: CoeloSpacing.space3),
                Expanded(child: Text('Publicações ficam disponíveis por 24 horas no Agora.')),
              ],
            ),
          ),
        ),
        if (state.draft.audio != null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Container(
            padding: const EdgeInsets.all(CoeloSpacing.space3),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(CoeloRadius.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.music_note_rounded),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.draft.audio!.name),
                      Text(
                        state.draft.audio!.rightsConfirmed
                            ? 'Direitos confirmados'
                            : 'Confirme os direitos',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remover música',
                  color: Theme.of(context).colorScheme.error,
                  hoverColor: Theme.of(context).colorScheme.errorContainer,
                  focusColor: Theme.of(context).colorScheme.errorContainer,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onPressed: controller.removeAudio,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ],
        if (state.message != null) ...[
          const SizedBox(height: CoeloSpacing.space3),
          Text(state.message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
      ],
    );
  }
}

final class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.contextData, required this.selected, required this.onTap});
  final NowPublicationContext contextData;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _PrincipalInteractiveSurface(
    key: const Key('now-context-surface'),
    semanticLabel: 'Público e contexto',
    selected: selected,
    onPressed: onTap,
    borderRadius: CoeloRadius.md,
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: CoeloSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Público e contexto',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: CoeloSpacing.space1),
                Text(
                  '${contextData.institutionName}\n${contextData.unitName}\n${contextData.groupName}\nFamílias',
                ),
              ],
            ),
          ),
          Icon(
            selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
            color: selected ? Theme.of(context).colorScheme.primary : null,
          ),
        ],
      ),
    ),
  );
}

final class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.controller});
  final NowPublicationController controller;
  @override
  Widget build(BuildContext context) {
    final scheduled = controller.state.draft.publishAt != null;
    final busy = {
      NowPublicationPhase.uploading,
      NowPublicationPhase.saving,
      NowPublicationPhase.publishing,
    }.contains(controller.state.phase);
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrincipalPublicationToggleField(
          key: const Key('now-schedule-toggle'),
          label: 'Agendar publicação',
          description: 'Defina data e horário para publicar automaticamente.',
          value: scheduled,
          onChanged: busy
              ? null
              : (value) {
                  if (!value) return controller.setPublishAt(null);
                  final tomorrow = now.add(const Duration(days: 1));
                  controller.setPublishAt(DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8));
                },
        ),
        if (scheduled) ...[
          const SizedBox(height: CoeloSpacing.space2),
          CoeloDateTimeField(
            key: const Key('now-schedule-field'),
            value: controller.state.draft.publishAt,
            onChanged: controller.setPublishAt,
            firstDate: now,
            lastDate: DateTime(now.year + 2, 12, 31),
            currentDate: now,
            labelText: 'Data e hora da publicação',
          ),
        ],
      ],
    );
  }
}

final class _PublicationFooter extends StatelessWidget {
  const _PublicationFooter({
    required this.currentStep,
    required this.controller,
    required this.onCancel,
    required this.onPrevious,
    required this.onContinue,
    this.onCompleted,
  });
  final int currentStep;
  final NowPublicationController controller;
  final VoidCallback onCancel;
  final VoidCallback onPrevious;
  final VoidCallback onContinue;
  final ValueChanged<NowPublication>? onCompleted;
  @override
  Widget build(BuildContext context) {
    final busy = {
      NowPublicationPhase.uploading,
      NowPublicationPhase.saving,
      NowPublicationPhase.publishing,
    }.contains(controller.state.phase);
    final publish = FilledButton(
      onPressed: busy
          ? null
          : () async {
              final result = await controller.publish();
              if (result != null) onCompleted?.call(result);
            },
      child: Text(busy ? 'Publicando…' : 'Publicar agora'),
    );
    final secondary = OutlinedButton(
      onPressed: busy ? null : controller.saveDraft,
      child: const Text('Salvar rascunho'),
    );
    return PrincipalPublicationActionFooter(
      surfaceKey: const Key('now-publication-footer'),
      tertiaryAction: TextButton(onPressed: busy ? null : onCancel, child: const Text('Cancelar')),
      continuationActions: [
        if (currentStep > 0)
          OutlinedButton(onPressed: busy ? null : onPrevious, child: const Text('Anterior')),
        if (currentStep == 0)
          FilledButton(onPressed: busy ? null : onContinue, child: const Text('Continuar'))
        else ...[
          secondary,
          publish,
        ],
      ],
    );
  }
}

final class _NowDialog extends StatelessWidget {
  const _NowDialog({required this.title, required this.body, required this.actions});

  final String title;
  final Widget body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoeloRadius.lg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    key: const Key('now-dialog-close'),
                    tooltip: 'Fechar',
                    style: ButtonStyle(
                      minimumSize: const WidgetStatePropertyAll(Size.square(CoeloSize.touchMin)),
                      foregroundColor: WidgetStatePropertyAll(colors.error),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) =>
                            states.contains(WidgetState.hovered) ||
                                states.contains(WidgetState.focused) ||
                                states.contains(WidgetState.pressed)
                            ? colors.errorContainer
                            : colors.surface,
                      ),
                      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space4),
              Flexible(child: body),
              const SizedBox(height: CoeloSpacing.space5),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (actions.length == 1) {
                    return SizedBox(width: double.infinity, child: actions.single);
                  }
                  final minimumActionWidth = actions.length == 2 ? 160.0 : 144.0;
                  final requiredWidth =
                      (minimumActionWidth * actions.length) +
                      (CoeloSpacing.space3 * (actions.length - 1));
                  final stackActions =
                      constraints.maxWidth < requiredWidth ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.5;
                  if (stackActions) {
                    return Column(
                      key: const Key('now-dialog-actions-stacked'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = 0; index < actions.length; index++) ...[
                          if (index > 0) const SizedBox(height: CoeloSpacing.space2),
                          SizedBox(width: double.infinity, child: actions[index]),
                        ],
                      ],
                    );
                  }
                  return Row(
                    key: const Key('now-dialog-actions-row'),
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        if (index > 0) const SizedBox(width: CoeloSpacing.space3),
                        Expanded(child: actions[index]),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _mime(String? extension) => switch (extension?.toLowerCase()) {
  'jpg' || 'jpeg' => 'image/jpeg',
  'png' => 'image/png',
  'webp' => 'image/webp',
  'mp4' => 'video/mp4',
  _ => 'application/octet-stream',
};

String _audioMime(String? extension) => switch (extension?.toLowerCase()) {
  'mp3' => 'audio/mpeg',
  'm4a' => 'audio/mp4',
  'wav' => 'audio/wav',
  'aac' => 'audio/aac',
  _ => 'application/octet-stream',
};

String _durationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60);
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
