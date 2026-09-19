import 'dart:math' as math;

import 'package:coelo_domain/locations.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/widgets/superadmin_form_section.dart';
import '../domain/location_map.dart';

/// Mapa da instituição / unidade (spec 067): planta com pontos e áreas em
/// coordenadas relativas. Toque no mapa cria um ponto; "Desenhar área" junta
/// toques até "Concluir". Sem imagem da planta o mapa é uma grade neutra —
/// os marcadores continuam válidos quando a planta for anexada.
final class LocationMapPanel extends StatefulWidget {
  const LocationMapPanel({
    super.key,
    required this.scope,
    required this.reader,
    this.writer,
    this.sessionAvailable = false,
    this.contextRevision = 0,
    this.background,
  });

  final LocationScope scope;
  final LocationMapReader reader;

  /// Nulo quando o ator não escreve: o mapa é só leitura.
  final LocationMapWriter? writer;
  final bool sessionAvailable;
  final int contextRevision;

  /// Imagem da planta (quando existir); a grade é o fallback.
  final Widget? background;

  @override
  State<LocationMapPanel> createState() => _LocationMapPanelState();
}

final class _LocationMapPanelState extends State<LocationMapPanel> {
  LocationMap? _map;
  Object? _error;
  bool _loading = false;
  bool _drawingArea = false;
  final _draft = <(double, double)>[];
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant LocationMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope ||
        oldWidget.contextRevision != widget.contextRevision ||
        oldWidget.sessionAvailable != widget.sessionAvailable) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.sessionAvailable) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final map = await widget.reader.fetchMap(widget.scope);
      if (!mounted || generation != _generation) return;
      setState(() {
        _map = map;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _onTap(double x, double y) async {
    if (widget.writer == null) return;
    if (_drawingArea) {
      setState(() => _draft.add((x, y)));
      return;
    }
    await _createMarker(LocationMapShape.point, x, y, const []);
  }

  Future<void> _finishArea() async {
    if (_draft.length < 3) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Uma área precisa de pelo menos três pontos.')));
      return;
    }
    final points = List.of(_draft);
    final cx = points.map((p) => p.$1).reduce((a, b) => a + b) / points.length;
    final cy = points.map((p) => p.$2).reduce((a, b) => a + b) / points.length;
    setState(() {
      _drawingArea = false;
      _draft.clear();
    });
    await _createMarker(LocationMapShape.area, cx, cy, points);
  }

  Future<void> _createMarker(
    LocationMapShape shape,
    double x,
    double y,
    List<(double, double)> points,
  ) async {
    final result = await showDialog<_MarkerDialogResult>(
      context: context,
      barrierColor: context.coeloScrim,
      builder: (_) => _MarkerDialog(
        title: shape == LocationMapShape.area ? 'Nova área' : 'Novo ponto',
        locations: _map?.locations ?? const [],
      ),
    );
    if (result == null || !mounted || result.remove) return;
    await _run(() async {
      await widget.writer!.saveMarker(
        widget.scope,
        LocationMapMarkerDraft(
          label: result.label,
          shape: shape,
          x: x,
          y: y,
          points: points,
          visibility: result.visibility,
          locationId: result.locationId,
        ),
        requestId: _requestId(),
      );
    });
  }

  Future<void> _editMarker(LocationMapMarker marker) async {
    if (widget.writer == null) return;
    final result = await showDialog<_MarkerDialogResult>(
      context: context,
      barrierColor: context.coeloScrim,
      builder: (_) => _MarkerDialog(
        title: marker.shape == LocationMapShape.area ? 'Editar área' : 'Editar ponto',
        locations: _map?.locations ?? const [],
        initial: marker,
      ),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      if (result.remove) {
        await widget.writer!.removeMarker(
          marker.id,
          requestId: _requestId(),
          expectedVersion: marker.managementVersion,
        );
        return;
      }
      await widget.writer!.saveMarker(
        widget.scope,
        LocationMapMarkerDraft(
          label: result.label,
          shape: marker.shape,
          x: marker.x,
          y: marker.y,
          points: marker.points,
          visibility: result.visibility,
          locationId: result.locationId,
        ),
        requestId: _requestId(),
        markerId: marker.id,
        expectedVersion: marker.managementVersion,
      );
    });
  }

  Future<void> _run(Future<void> Function() command) async {
    try {
      await command();
    } on LocationMapConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('O mapa foi alterado por outra pessoa. Recarregado.')),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Não foi possível salvar o marcador.')));
      }
    }
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final map = _map;
    return SuperadminFormSection(
      title: 'Mapa',
      description: map?.addressLine == null
          ? 'Planta com pontos e áreas. O endereço vem do cadastro.'
          : 'Endereço do cadastro: ${map!.addressLine}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: CoeloSpacing.space3),
              child: Text(
                'Não foi possível carregar o mapa.',
                key: const Key('location-map-error'),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
              ),
            ),
          if (widget.writer != null)
            Wrap(
              spacing: CoeloSpacing.space2,
              runSpacing: CoeloSpacing.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _drawingArea
                      ? 'Toque nos vértices da área (${_draft.length}) e conclua.'
                      : 'Toque no mapa para marcar um ponto.',
                  style: theme.textTheme.bodySmall,
                ),
                if (_drawingArea) ...[
                  FilledButton.tonal(
                    key: const Key('location-map-finish-area'),
                    onPressed: _finishArea,
                    child: const Text('Concluir área'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _drawingArea = false;
                      _draft.clear();
                    }),
                    child: const Text('Cancelar'),
                  ),
                ] else
                  OutlinedButton.icon(
                    key: const Key('location-map-draw-area'),
                    onPressed: () => setState(() => _drawingArea = true),
                    icon: const Icon(Icons.pentagon_outlined),
                    label: const Text('Desenhar área'),
                  ),
              ],
            ),
          const SizedBox(height: CoeloSpacing.space3),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(constraints.maxWidth, constraints.maxHeight);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(CoeloRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.background ?? const LocationMapGridBackground(),
                      CustomPaint(
                        painter: _AreasPainter(
                          areas: [
                            for (final m in map?.markers ?? const <LocationMapMarker>[])
                              if (m.shape == LocationMapShape.area) m.points,
                          ],
                          draft: _draft,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      GestureDetector(
                        key: const Key('location-map-canvas'),
                        behavior: HitTestBehavior.opaque,
                        // A posição do toque é o dado; um nó de semântica aqui
                        // reduziria o gesto ao centro. Leitores de tela usam a
                        // lista de marcadores abaixo.
                        excludeFromSemantics: true,
                        onTapUp: widget.writer == null
                            ? null
                            : (details) => _onTap(
                                (details.localPosition.dx / size.width).clamp(0.0, 1.0),
                                (details.localPosition.dy / size.height).clamp(0.0, 1.0),
                              ),
                      ),
                      for (final marker in map?.markers ?? const <LocationMapMarker>[])
                        Positioned(
                          left: (marker.x * size.width - 14).clamp(
                            0.0,
                            math.max(0, size.width - 28),
                          ),
                          top: (marker.y * size.height - 14).clamp(
                            0.0,
                            math.max(0, size.height - 28),
                          ),
                          child: Tooltip(
                            message: marker.locationName == null
                                ? marker.label
                                : '${marker.label} · ${marker.locationName}',
                            child: Material(
                              color: marker.shape == LocationMapShape.area
                                  ? theme.colorScheme.secondaryContainer
                                  : theme.colorScheme.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                key: Key('location-map-marker-${marker.id}'),
                                customBorder: const CircleBorder(),
                                onTap: widget.writer == null ? null : () => _editMarker(marker),
                                child: SizedBox.square(
                                  dimension: 28,
                                  child: Icon(
                                    marker.shape == LocationMapShape.area
                                        ? Icons.crop_square_rounded
                                        : Icons.place_rounded,
                                    size: 16,
                                    color: marker.shape == LocationMapShape.area
                                        ? theme.colorScheme.onSecondaryContainer
                                        : theme.colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_loading)
                        const Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: EdgeInsets.all(CoeloSpacing.space2),
                            child: SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          if (map != null && map.markers.isEmpty)
            Text(
              'Nenhum marcador ainda.',
              key: const Key('location-map-empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          for (final marker in map?.markers ?? const <LocationMapMarker>[])
            ListTile(
              key: Key('location-map-row-${marker.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                marker.shape == LocationMapShape.area
                    ? Icons.crop_square_rounded
                    : Icons.place_rounded,
              ),
              title: Text(marker.label),
              subtitle: Text(
                [
                  ?marker.locationName,
                  'Visível para: ${marker.visibility.label.toLowerCase()}',
                ].join(' · '),
              ),
              trailing: widget.writer == null ? null : const Icon(Icons.edit_outlined),
              onTap: widget.writer == null ? null : () => _editMarker(marker),
            ),
        ],
      ),
    );
  }

  String _requestId() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Grade neutra do mapa; é o fundo quando a planta (entity image `floor_plan`)
/// ainda não existe e o fallback do [EntityImageView] que a exibe.
final class LocationMapGridBackground extends StatelessWidget {
  const LocationMapGridBackground({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _GridPainter(
      line: Theme.of(context).colorScheme.outlineVariant,
      fill: Theme.of(context).colorScheme.surfaceContainerLow,
    ),
  );
}

final class _GridPainter extends CustomPainter {
  const _GridPainter({required this.line, required this.fill});
  final Color line;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = fill);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1;
    const step = 40.0;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.line != line || oldDelegate.fill != fill;
}

final class _AreasPainter extends CustomPainter {
  const _AreasPainter({required this.areas, required this.draft, required this.color});
  final List<List<(double, double)>> areas;
  final List<(double, double)> draft;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.18);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final area in areas) {
      if (area.length < 3) continue;
      final path = Path()..moveTo(area.first.$1 * size.width, area.first.$2 * size.height);
      for (final point in area.skip(1)) {
        path.lineTo(point.$1 * size.width, point.$2 * size.height);
      }
      path.close();
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, stroke);
    }
    if (draft.isNotEmpty) {
      final dashed = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final path = Path()..moveTo(draft.first.$1 * size.width, draft.first.$2 * size.height);
      for (final point in draft.skip(1)) {
        path.lineTo(point.$1 * size.width, point.$2 * size.height);
      }
      canvas.drawPath(path, dashed);
      for (final point in draft) {
        canvas.drawCircle(
          Offset(point.$1 * size.width, point.$2 * size.height),
          5,
          Paint()..color = color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AreasPainter oldDelegate) =>
      oldDelegate.areas != areas || oldDelegate.draft != draft || oldDelegate.color != color;
}

final class _MarkerDialogResult {
  const _MarkerDialogResult({
    required this.label,
    required this.visibility,
    this.locationId,
    this.remove = false,
  });
  final String label;
  final LocationMapVisibility visibility;
  final String? locationId;
  final bool remove;
}

final class _MarkerDialog extends StatefulWidget {
  const _MarkerDialog({required this.title, required this.locations, this.initial});
  final String title;
  final List<LocationMapLocationOption> locations;
  final LocationMapMarker? initial;

  @override
  State<_MarkerDialog> createState() => _MarkerDialogState();
}

final class _MarkerDialogState extends State<_MarkerDialog> {
  late final _label = TextEditingController(text: widget.initial?.label ?? '');
  late LocationMapVisibility _visibility = widget.initial?.visibility ?? LocationMapVisibility.all;
  late String _locationId = widget.initial?.locationId ?? '';

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = ['', for (final item in widget.locations) item.id];
    if (!options.contains(_locationId)) _locationId = '';
    return CoeloAdminDialogShell(
      dialogKey: const Key('location-map-marker-dialog'),
      title: widget.title,
      closeTooltip: 'Fechar',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CoeloFormTextField(
            key: const Key('location-map-marker-label'),
            controller: _label,
            labelText: 'Nome',
            hintText: 'Ex.: Quadra coberta',
            prefixIcon: Icons.label_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloAdminSingleSelectField<String>(
            key: const Key('location-map-marker-location'),
            label: 'Local do catálogo (opcional)',
            value: _locationId,
            options: options,
            optionLabel: (id) => id.isEmpty
                ? 'Sem vínculo'
                : widget.locations.firstWhere((item) => item.id == id).name,
            onChanged: (value) => setState(() => _locationId = value),
          ),
          const SizedBox(height: CoeloSpacing.space3),
          CoeloAdminSingleSelectField<LocationMapVisibility>(
            key: const Key('location-map-marker-visibility'),
            label: 'Visível para',
            value: _visibility,
            options: LocationMapVisibility.values,
            optionLabel: (value) => value.label,
            onChanged: (value) => setState(() => _visibility = value),
          ),
        ],
      ),
      secondaryAction: widget.initial == null
          ? OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            )
          : OutlinedButton(
              key: const Key('location-map-marker-remove'),
              onPressed: () => Navigator.of(context).pop(
                const _MarkerDialogResult(
                  label: '',
                  visibility: LocationMapVisibility.all,
                  remove: true,
                ),
              ),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Remover'),
            ),
      primaryAction: FilledButton(
        key: const Key('location-map-marker-save'),
        onPressed: _label.text.trim().isEmpty
            ? null
            : () => Navigator.of(context).pop(
                _MarkerDialogResult(
                  label: _label.text.trim(),
                  visibility: _visibility,
                  locationId: _locationId.isEmpty ? null : _locationId,
                ),
              ),
        child: const Text('Salvar'),
      ),
    );
  }
}
