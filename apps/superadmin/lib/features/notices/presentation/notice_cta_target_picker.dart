import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../domain/notice_repository.dart';
import '../domain/platform_notice.dart';

String noticeCtaTargetKindLabel(NoticeCtaTargetKind kind) => switch (kind) {
  NoticeCtaTargetKind.none => 'Nenhum',
  NoticeCtaTargetKind.circular => 'Circular',
  NoticeCtaTargetKind.form => 'Formulário',
  NoticeCtaTargetKind.invite => 'Convite',
  NoticeCtaTargetKind.notice => 'Aviso',
};

/// Escolha do destino do CTA (spec 069 H13): busca no servidor por tipo e
/// devolve a [NoticeCtaTargetOption] escolhida.
final class NoticeCtaTargetPickerDialog extends StatefulWidget {
  const NoticeCtaTargetPickerDialog({super.key, required this.reader, required this.kind});

  final NoticeCtaTargetOptionsReader reader;
  final NoticeCtaTargetKind kind;

  @override
  State<NoticeCtaTargetPickerDialog> createState() => _NoticeCtaTargetPickerDialogState();
}

final class _NoticeCtaTargetPickerDialogState extends State<NoticeCtaTargetPickerDialog> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _generation = 0;
  List<NoticeCtaTargetOption> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.reader.fetchCtaTargetOptions(
        kind: widget.kind,
        search: _search.text.trim().isEmpty ? null : _search.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on NoticeRepositoryException catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error.safeMessage;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = const NoticeUnexpectedException().safeMessage;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text('Escolher ${noticeCtaTargetKindLabel(widget.kind).toLowerCase()}'),
      content: SizedBox(
        width: 480,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CoeloSearchField(
              key: const Key('notice-cta-target-search'),
              controller: _search,
              hintText: 'Buscar por título',
              semanticLabel: 'Buscar destino por título',
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), _load);
              },
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Expanded(
              child: switch ((_loading, _error)) {
                (true, _) => const Center(child: CircularProgressIndicator()),
                (false, final String message) => Center(
                  child: Text(message, style: theme.textTheme.bodyMedium),
                ),
                _ when _items.isEmpty => Center(
                  child: Text('Nenhum resultado', style: theme.textTheme.bodyMedium),
                ),
                _ => ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      key: Key('notice-cta-target-option-${item.id}'),
                      title: Text(item.label, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
      ],
    );
  }
}
