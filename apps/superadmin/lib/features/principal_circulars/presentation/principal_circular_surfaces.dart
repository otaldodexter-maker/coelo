import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../domain/circular.dart';
import '../domain/circular_repository.dart';

enum PrincipalProfileContentTab { happens, moments, circulars, about }

final class PrincipalProfileContentTabs extends StatelessWidget {
  const PrincipalProfileContentTabs({required this.selected, required this.onSelected, super.key});

  final PrincipalProfileContentTab selected;
  final ValueChanged<PrincipalProfileContentTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Conteúdo do perfil',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: PrincipalProfileContentTab.values
              .map(
                (tab) => _ProfileTabButton(
                  key: Key('profile-tab-${tab.name}'),
                  label: switch (tab) {
                    PrincipalProfileContentTab.happens => 'Acontece',
                    PrincipalProfileContentTab.moments => 'Momentos',
                    PrincipalProfileContentTab.circulars => 'Circulares',
                    PrincipalProfileContentTab.about => 'Sobre',
                  },
                  selected: selected == tab,
                  onPressed: () => onSelected(tab),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

final class _ProfileTabButton extends StatefulWidget {
  const _ProfileTabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  State<_ProfileTabButton> createState() => _ProfileTabButtonState();
}

final class _ProfileTabButtonState extends State<_ProfileTabButton> {
  var _focused = false;

  void _exposeSelection() {
    Scrollable.ensureVisible(
      context,
      alignment: .5,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: FocusableActionDetector(
        onShowFocusHighlight: (focused) {
          setState(() => _focused = focused);
          if (focused) _exposeSelection();
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: TextButton(
          onPressed: () {
            widget.onPressed();
            _exposeSelection();
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, CoeloSize.touchMin),
            shape: const RoundedRectangleBorder(),
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: CoeloSize.touchMin),
            padding: const EdgeInsets.symmetric(horizontal: CoeloSpacing.space4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: widget.selected ? colors.primary : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: widget.selected ? colors.primary : colors.onSurfaceVariant,
                fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                decoration: _focused ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class PrincipalProfileCircularsTab extends StatefulWidget {
  const PrincipalProfileCircularsTab({
    required this.repository,
    required this.scope,
    required this.onOpen,
    super.key,
  });

  final CircularRepository repository;
  final CircularScope scope;
  final ValueChanged<String> onOpen;

  @override
  State<PrincipalProfileCircularsTab> createState() => _PrincipalProfileCircularsTabState();
}

final class _PrincipalProfileCircularsTabState extends State<PrincipalProfileCircularsTab> {
  final _items = <CircularSummary>[];
  CircularCursor? _cursor;
  Object? _error;
  var _loading = true;
  var _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    setState(() {
      if (reset) {
        _loading = true;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });
    try {
      final page = await widget.repository.listProfile(
        widget.scope,
        cursor: reset ? null : _cursor,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(page.items);
        _cursor = page.nextCursor;
        _loading = false;
        _loadingMore = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(key: Key('circulars-loading'), child: CircularProgressIndicator());
    }
    if (_error case final error?) {
      return _CircularState(
        icon: error is CircularUnauthorized ? Icons.lock_outline_rounded : Icons.cloud_off_outlined,
        message: error is CircularUnauthorized
            ? 'Você não tem acesso a estas Circulares.'
            : 'Não foi possível carregar as Circulares.',
        actionLabel: error is CircularUnauthorized ? null : 'Tentar novamente',
        onAction: error is CircularUnauthorized ? null : () => _load(reset: true),
      );
    }
    if (_items.isEmpty) {
      return const _CircularState(
        icon: Icons.description_outlined,
        message: 'Nenhuma Circular publicada por aqui.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: CoeloSpacing.space3),
      itemCount: _items.length + (_cursor == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: CoeloSpacing.space3),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          return Center(
            child: OutlinedButton(
              onPressed: _loadingMore ? null : () => _load(reset: false),
              child: Text(_loadingMore ? 'Carregando…' : 'Carregar mais'),
            ),
          );
        }
        final item = _items[index];
        return _PrincipalCircularCard(
          key: Key('profile-circular-${item.id}'),
          item: item,
          onOpen: () => widget.onOpen(item.id),
        );
      },
    );
  }
}

final class PrincipalCircularFeedCard extends StatelessWidget {
  const PrincipalCircularFeedCard({required this.item, required this.onOpen, super.key});

  final CircularSummary item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _InteractiveSurface(
      semanticLabel: 'Circular ${item.title}',
      onPressed: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.primary,
                  child: Text(_initials(item.authorName)),
                ),
                const SizedBox(width: CoeloSpacing.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.authorName,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(item.contextLabel, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Row(
              children: [
                Icon(Icons.description_outlined, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: CoeloSpacing.space2),
                Text(
                  'Circular',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(
              item.title,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: CoeloSpacing.space2),
            Text(item.excerpt, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: CoeloSpacing.space3),
            Wrap(
              spacing: CoeloSpacing.space3,
              runSpacing: CoeloSpacing.space2,
              children: [
                if (item.attachmentCount > 0)
                  _Metadata(
                    icon: Icons.attach_file_rounded,
                    label: '${item.attachmentCount} anexos',
                  ),
                if (item.questionCount > 0)
                  _Metadata(
                    icon: Icons.help_outline_rounded,
                    label: '${item.questionCount} perguntas',
                  ),
                if (item.questionCount > 0)
                  _Metadata(
                    icon: _responseIcon(item.responseState),
                    label: _responseLabel(item.responseState),
                  ),
              ],
            ),
            const SizedBox(height: CoeloSpacing.space3),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Ler circular'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PrincipalCircularCard extends StatelessWidget {
  const _PrincipalCircularCard({required this.item, required this.onOpen, super.key});
  final CircularSummary item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = item.publishedAt.toLocal();
    return _InteractiveSurface(
      semanticLabel: 'Abrir Circular ${item.title}',
      onPressed: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(CoeloSpacing.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: CoeloSize.touchMin,
              height: CoeloSize.touchMin,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(CoeloRadius.md),
              ),
              child: Icon(Icons.description_outlined, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: CoeloSpacing.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: CoeloSpacing.space1),
                  Text(
                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${item.authorName} · ${item.contextLabel}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: CoeloSpacing.space2),
                  Text(item.excerpt, maxLines: 3, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: CoeloSpacing.space2),
                  Wrap(
                    spacing: CoeloSpacing.space3,
                    children: [
                      if (item.attachmentCount > 0)
                        _Metadata(
                          icon: Icons.attach_file_rounded,
                          label: '${item.attachmentCount}',
                        ),
                      if (item.questionCount > 0)
                        _Metadata(icon: Icons.help_outline_rounded, label: '${item.questionCount}'),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

final class _InteractiveSurface extends StatelessWidget {
  const _InteractiveSurface({
    required this.semanticLabel,
    required this.onPressed,
    required this.child,
  });
  final String semanticLabel;
  final VoidCallback onPressed;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return CoeloAdminInteractiveCard(
      semanticLabel: semanticLabel,
      onPressed: onPressed,
      child: child,
    );
  }
}

final class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: CoeloSpacing.space1),
      Text(label),
    ],
  );
}

final class _CircularState extends StatelessWidget {
  const _CircularState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(CoeloSpacing.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: CoeloSpacing.space3),
          Text(message, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: CoeloSpacing.space3),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    ),
  );
}

String _initials(String value) => value
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();
String _responseLabel(CircularResponseState state) => switch (state) {
  CircularResponseState.unanswered => 'Não respondida',
  CircularResponseState.partial => 'Resposta parcial',
  CircularResponseState.answered => 'Respondida',
};
IconData _responseIcon(CircularResponseState state) => switch (state) {
  CircularResponseState.unanswered => Icons.radio_button_unchecked_rounded,
  CircularResponseState.partial => Icons.timelapse_rounded,
  CircularResponseState.answered => Icons.check_circle_outline_rounded,
};
