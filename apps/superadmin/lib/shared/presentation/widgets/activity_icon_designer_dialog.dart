import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets/superadmin_advanced_color_picker_dialog.dart';
import 'activity_icon_paths.dart';

/// Símbolo + cor do símbolo + cor do fundo. Vira PNG 512×512 (guardado no R2)
/// e a especificação (`{icon, color, background}`) para reeditar.
final class ActivityIconDesign {
  const ActivityIconDesign({required this.icon, required this.color, required this.background});

  final String icon;
  final Color color;
  final Color background;

  static const defaultDesign = ActivityIconDesign(
    icon: 'sports_soccer',
    color: Color(0xFFFFFFFF),
    background: Color(0xFFD63C00),
  );

  static ActivityIconDesign fromSpec(Map<String, Object?>? spec) {
    if (spec == null) return defaultDesign;
    return ActivityIconDesign(
      icon: activityIconCatalog.containsKey(spec['icon']) ? spec['icon'] as String : defaultDesign.icon,
      color: _parseColor(spec['color']) ?? defaultDesign.color,
      background: _parseColor(spec['background']) ?? defaultDesign.background,
    );
  }

  Map<String, Object?> toSpec() => {'icon': icon, 'color': _hex(color), 'background': _hex(background)};

  IconData get iconData => activityIconCatalog[icon] ?? Icons.local_activity_outlined;

  ActivityIconDesign copyWith({String? icon, Color? color, Color? background}) => ActivityIconDesign(
    icon: icon ?? this.icon,
    color: color ?? this.color,
    background: background ?? this.background,
  );

  /// PNG 512×512 com fundo arredondado e o glifo centralizado (fonte MaterialIcons).
  Future<Uint8List?> rasterize({int size = 512}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Offset.zero & Size.square(size.toDouble());
    canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(size * 0.22)), Paint()..color = background);
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: size * 0.62,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset((size - painter.width) / 2, (size - painter.height) / 2));
    final image = await recorder.endRecording().toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  /// O mesmo desenho em SVG (fundo arredondado + paths do símbolo), sem fonte,
  /// script nem referência externa — passa pelo contrato estreito da Edge.
  /// `null` quando o símbolo não tem path no catálogo vetorial.
  Uint8List? toSvg({int size = 512}) {
    final paths = activityIconPaths[icon];
    if (paths == null || paths.isEmpty) return null;
    final glyph = size * 0.62;
    final scale = glyph / 24;
    final offset = (size - glyph) / 2;
    final buffer = StringBuffer()
      ..write('<?xml version="1.0" encoding="UTF-8"?>\n')
      ..write('<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" viewBox="0 0 $size $size">')
      ..write('<rect width="$size" height="$size" rx="${(size * 0.22).toStringAsFixed(2)}" fill="${_hex(background)}"/>')
      ..write('<g transform="translate(${offset.toStringAsFixed(2)} ${offset.toStringAsFixed(2)}) scale(${scale.toStringAsFixed(4)})" fill="${_hex(color)}">');
    for (final path in paths) {
      buffer.write('<path d="$path"/>');
    }
    buffer.write('</g></svg>\n');
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static String _hex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color? _parseColor(Object? value) {
    if (value is! String) return null;
    final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
}

/// Catálogo de símbolos (Material Icons) — a chave é o que vai no `icon_spec`.
const activityIconCatalog = <String, IconData>{
  'sports_soccer': Icons.sports_soccer,
  'sports_basketball': Icons.sports_basketball,
  'sports_volleyball': Icons.sports_volleyball,
  'sports_tennis': Icons.sports_tennis,
  'sports_martial_arts': Icons.sports_martial_arts,
  'sports_gymnastics': Icons.sports_gymnastics,
  'pool': Icons.pool,
  'directions_run': Icons.directions_run,
  'directions_bike': Icons.directions_bike,
  'self_improvement': Icons.self_improvement,
  'music_note': Icons.music_note,
  'piano': Icons.piano,
  'theater_comedy': Icons.theater_comedy,
  'palette': Icons.palette,
  'brush': Icons.brush,
  'photo_camera': Icons.photo_camera,
  'menu_book': Icons.menu_book,
  'auto_stories': Icons.auto_stories,
  'translate': Icons.translate,
  'calculate': Icons.calculate,
  'science': Icons.science,
  'biotech': Icons.biotech,
  'computer': Icons.computer,
  'smart_toy': Icons.smart_toy,
  'extension': Icons.extension,
  'psychology': Icons.psychology,
  'public': Icons.public,
  'park': Icons.park,
  'eco': Icons.eco,
  'pets': Icons.pets,
  'restaurant': Icons.restaurant,
  'local_cafe': Icons.local_cafe,
  'bedtime': Icons.bedtime,
  'wb_sunny': Icons.wb_sunny,
  'favorite': Icons.favorite,
  'volunteer_activism': Icons.volunteer_activism,
  'groups': Icons.groups,
  'school': Icons.school,
  'workspace_premium': Icons.workspace_premium,
  'celebration': Icons.celebration,
  'toys': Icons.toys,
  'child_care': Icons.child_care,
  'medical_services': Icons.medical_services,
  'star': Icons.star,
  'lightbulb': Icons.lightbulb,
  'rocket_launch': Icons.rocket_launch,
  'construction': Icons.construction,
  'local_activity': Icons.local_activity,
};

final class ActivityIconDesignerDialog extends StatefulWidget {
  const ActivityIconDesignerDialog({required this.initial, super.key});

  final ActivityIconDesign initial;

  @override
  State<ActivityIconDesignerDialog> createState() => _ActivityIconDesignerDialogState();
}

final class _ActivityIconDesignerDialogState extends State<ActivityIconDesignerDialog> {
  late var _design = widget.initial;

  Future<void> _pickColor({required bool background}) async {
    final selected = await showSuperadminAdvancedColorPicker(
      context,
      initialColor: background ? _design.background : _design.color,
      title: background ? 'Cor do fundo' : 'Cor do ícone',
    );
    if (selected != null && mounted) {
      setState(() => _design = background ? _design.copyWith(background: selected) : _design.copyWith(color: selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CoeloAdminDialogShell(
      title: 'Ícone da atividade',
      maxWidth: 640,
      secondaryAction: OutlinedButton(onPressed: Navigator.of(context).pop, child: const Text('Cancelar')),
      primaryAction: FilledButton(
        key: const Key('activity-icon-apply'),
        onPressed: () => Navigator.of(context).pop(_design),
        child: const Text('Aplicar'),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: CoeloSpacing.space4,
            runSpacing: CoeloSpacing.space3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                key: const Key('activity-icon-preview'),
                width: CoeloSize.touchMin * 2,
                height: CoeloSize.touchMin * 2,
                decoration: BoxDecoration(
                  color: _design.background,
                  borderRadius: BorderRadius.circular(CoeloRadius.lg),
                ),
                child: Icon(_design.iconData, color: _design.color, size: CoeloSize.touchMin * 1.2),
              ),
              _ColorButton(
                key: const Key('activity-icon-color'),
                label: 'Cor do ícone',
                color: _design.color,
                onPressed: () => _pickColor(background: false),
              ),
              _ColorButton(
                key: const Key('activity-icon-background'),
                label: 'Cor do fundo',
                color: _design.background,
                onPressed: () => _pickColor(background: true),
              ),
            ],
          ),
          const SizedBox(height: CoeloSpacing.space4),
          Text('Símbolo', style: theme.textTheme.titleSmall),
          const SizedBox(height: CoeloSpacing.space2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: CoeloSize.touchMin + CoeloSpacing.space2,
                mainAxisSpacing: CoeloSpacing.space1,
                crossAxisSpacing: CoeloSpacing.space1,
              ),
              itemCount: activityIconCatalog.length,
              itemBuilder: (context, index) {
                final entry = activityIconCatalog.entries.elementAt(index);
                final selected = entry.key == _design.icon;
                return Semantics(
                  button: true,
                  selected: selected,
                  label: entry.key.replaceAll('_', ' '),
                  child: InkWell(
                    key: Key('activity-icon-${entry.key}'),
                    borderRadius: BorderRadius.circular(CoeloRadius.md),
                    onTap: () => setState(() => _design = _design.copyWith(icon: entry.key)),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected ? theme.colorScheme.primaryContainer : null,
                        borderRadius: BorderRadius.circular(CoeloRadius.md),
                        border: Border.all(
                          color: selected ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Icon(entry.value, color: theme.colorScheme.onSurface),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

final class _ColorButton extends StatelessWidget {
  const _ColorButton({required this.label, required this.color, required this.onPressed, super.key});

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: const SizedBox.square(dimension: CoeloSize.iconMd),
    ),
    label: Text(label),
  );
}
