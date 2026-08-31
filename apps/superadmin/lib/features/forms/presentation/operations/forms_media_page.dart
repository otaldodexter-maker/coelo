import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

enum FormsMediaState { content, notFound, unavailable }

/// Protected media detail shared by production and `/dev` routes.
///
/// The production constructor is deliberately fail-closed. The development
/// constructor resolves only deterministic local metadata and never exposes a
/// storage identifier or persistent read address.
final class FormsMediaPage extends StatefulWidget {
  const FormsMediaPage({required this.assetId, this.onBack, super.key})
    : development = false,
      state = FormsMediaState.unavailable,
      onRequestTemporaryCopy = null;

  const FormsMediaPage.development({
    required this.assetId,
    this.state = FormsMediaState.content,
    this.onBack,
    this.onRequestTemporaryCopy,
    super.key,
  }) : development = true;

  static const developmentPreviewAssetId = 'asset-form-photo-01';

  final String assetId;
  final bool development;
  final FormsMediaState state;
  final VoidCallback? onBack;
  final VoidCallback? onRequestTemporaryCopy;

  @override
  State<FormsMediaPage> createState() => _FormsMediaPageState();
}

final class _FormsMediaPageState extends State<FormsMediaPage> {
  bool _previewVisible = false;

  @override
  Widget build(BuildContext context) {
    final fixture = widget.development && widget.state == FormsMediaState.content
        ? _fixtureFor(widget.assetId)
        : null;
    final state = !widget.development
        ? FormsMediaState.unavailable
        : widget.state == FormsMediaState.content && fixture == null
        ? FormsMediaState.notFound
        : widget.state;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inset = constraints.maxWidth >= CoeloBreakpoints.large.minWidth
              ? CoeloSpacing.space10
              : constraints.maxWidth >= CoeloBreakpoints.medium.minWidth
              ? CoeloSpacing.space6
              : CoeloSpacing.space4;
          return ListView(
            key: const Key('forms-media-page'),
            padding: EdgeInsets.fromLTRB(inset, CoeloSpacing.space5, inset, CoeloSpacing.space8),
            children: [
              _Header(onBack: state == FormsMediaState.notFound ? null : widget.onBack),
              const SizedBox(height: CoeloSpacing.space4),
              if (state == FormsMediaState.notFound)
                CoeloStatePanel(
                  key: const Key('forms-media-not-found'),
                  icon: Icons.hide_image_outlined,
                  title: 'Mídia não encontrada',
                  message: 'A referência não existe nesta fixture ou deixou de estar disponível.',
                  actionLabel: widget.onBack == null ? null : 'Voltar aos arquivos',
                  onAction: widget.onBack,
                )
              else ...[
                if (state == FormsMediaState.unavailable) ...[
                  const CoeloStatePanel(
                    key: Key('forms-media-unavailable'),
                    icon: Icons.lock_outline_rounded,
                    title: 'Mídia indisponível',
                    message:
                        'A leitura temporária e a autorização produtiva ainda não estão conectadas.',
                  ),
                  const SizedBox(height: CoeloSpacing.space4),
                ],
                _ProtectedMediaSurface(
                  fixture: state == FormsMediaState.content ? fixture : null,
                  previewVisible: _previewVisible,
                  onTogglePreview: state == FormsMediaState.content
                      ? () => setState(() => _previewVisible = !_previewVisible)
                      : null,
                  onRequestTemporaryCopy: state == FormsMediaState.content
                      ? _requestTemporaryCopy
                      : null,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _requestTemporaryCopy() {
    widget.onRequestTemporaryCopy?.call();
    if (widget.onRequestTemporaryCopy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cópia local preparada somente para esta demonstração.')),
      );
    }
  }
}

final class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (onBack != null) ...[
        TextButton.icon(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Voltar aos arquivos'),
        ),
        const SizedBox(height: CoeloSpacing.space2),
      ],
      Text('Mídia protegida', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: CoeloSpacing.space1),
      Text(
        'Consulte metadados autorizados e solicite uma cópia temporária.',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}

final class _ProtectedMediaSurface extends StatelessWidget {
  const _ProtectedMediaSurface({
    required this.fixture,
    required this.previewVisible,
    required this.onTogglePreview,
    required this.onRequestTemporaryCopy,
  });

  final _DevelopmentMediaFixture? fixture;
  final bool previewVisible;
  final VoidCallback? onTogglePreview;
  final VoidCallback? onRequestTemporaryCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('forms-media-protected-surface'),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(CoeloRadius.lg),
      ),
      padding: const EdgeInsets.all(CoeloSpacing.space4),
      child: fixture == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: CoeloSize.iconLg,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: CoeloSpacing.space3),
                Text(
                  'Nenhuma mídia autorizada carregada',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: CoeloSpacing.space4),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Preparar cópia temporária'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  image: true,
                  label: 'Prévia protegida de ${fixture!.title}',
                  child: Container(
                    key: previewVisible ? const Key('forms-media-local-preview') : null,
                    constraints: const BoxConstraints(minHeight: 220),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(CoeloRadius.md),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(CoeloSpacing.space4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          previewVisible ? Icons.image_rounded : Icons.lock_outline_rounded,
                          size: CoeloSize.iconLg,
                          color: colors.primary,
                        ),
                        const SizedBox(height: CoeloSpacing.space2),
                        Text(
                          previewVisible ? 'Prévia local efêmera' : 'Prévia protegida',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: CoeloSpacing.space4),
                Text(fixture!.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: CoeloSpacing.space3),
                Wrap(
                  spacing: CoeloSpacing.space4,
                  runSpacing: CoeloSpacing.space3,
                  children: [
                    _Metadata(label: 'Tipo', value: fixture!.typeLabel),
                    _Metadata(label: 'Tamanho', value: fixture!.sizeLabel),
                    _Metadata(label: 'Origem', value: fixture!.originLabel),
                    _Metadata(label: 'Disponibilidade', value: 'Sessão local'),
                  ],
                ),
                const SizedBox(height: CoeloSpacing.space4),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: CoeloSpacing.space2,
                  runSpacing: CoeloSpacing.space2,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onTogglePreview,
                      icon: Icon(
                        previewVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      ),
                      label: Text(previewVisible ? 'Ocultar prévia' : 'Mostrar prévia'),
                    ),
                    FilledButton.icon(
                      onPressed: onRequestTemporaryCopy,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Preparar cópia temporária'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

final class _Metadata extends StatelessWidget {
  const _Metadata({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: CoeloSpacing.space1),
        Text(value),
      ],
    ),
  );
}

final class _DevelopmentMediaFixture {
  const _DevelopmentMediaFixture({
    required this.title,
    required this.typeLabel,
    required this.sizeLabel,
    required this.originLabel,
  });

  final String title;
  final String typeLabel;
  final String sizeLabel;
  final String originLabel;
}

_DevelopmentMediaFixture? _fixtureFor(String assetId) => switch (assetId) {
  FormsMediaPage.developmentPreviewAssetId => const _DevelopmentMediaFixture(
    title: 'Comprovante da atividade',
    typeLabel: 'Imagem JPEG',
    sizeLabel: '248 KB',
    originLabel: 'Resposta anônima',
  ),
  _ => null,
};
