import 'dart:async';

import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import 'child_directory_controller.dart';

/// Read-only list of the children a Superadmin actor is authorized to see.
///
/// The controller keeps a single page and only knows how to move forward, so
/// this panel offers exactly that: next page and reload. It never shows a
/// "previous" control the read path cannot honour, and it offers no management
/// action, because linking, transferring, editing and revoking have separate
/// contracts and must not be implied by this read-only surface.
class ChildDirectoryPanel extends StatefulWidget {
  const ChildDirectoryPanel({
    this.read,
    this.sessionAvailable = false,
    this.institutionId,
    this.revision = 0,
    this.expand = true,
    super.key,
  });

  /// Absent by default: composition must inject a real read, never a fixture.
  final ChildDirectoryRead? read;
  final bool sessionAvailable;
  final String? institutionId;

  /// Bumped by the composition whenever the session context changes.
  final int revision;

  /// Whether the panel owns the viewport and scrolls its own list.
  ///
  /// False when it is embedded in a page that already scrolls, where an
  /// [Expanded] would ask for unbounded height.
  final bool expand;

  @override
  State<ChildDirectoryPanel> createState() => _ChildDirectoryPanelState();
}

class _ChildDirectoryPanelState extends State<ChildDirectoryPanel> {
  late final ChildDirectoryController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChildDirectoryController(
      read: widget.read ?? unavailableChildDirectoryRead,
      sessionAvailable: widget.sessionAvailable,
      institutionId: widget.institutionId,
      revision: widget.revision,
    );
    unawaited(_controller.reload());
  }

  @override
  void didUpdateWidget(covariant ChildDirectoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionAvailable != widget.sessionAvailable ||
        oldWidget.institutionId != widget.institutionId ||
        oldWidget.revision != widget.revision ||
        !identical(oldWidget.read, widget.read)) {
      unawaited(
        _controller.setContext(
          sessionAvailable: widget.sessionAvailable,
          institutionId: widget.institutionId,
          revision: widget.revision,
          read: widget.read ?? unavailableChildDirectoryRead,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth < CoeloBreakpoints.medium.minWidth
            ? CoeloSpacing.space4
            : CoeloSpacing.space6;
        final page = _controller.page;
        final loading = _controller.state == ChildDirectoryState.loading;
        final content = <Widget>[
          Semantics(
            header: true,
            child: Text('Alunos', style: Theme.of(context).textTheme.headlineSmall),
          ),
          Text(
            'Consulta somente leitura dos vínculos autorizados.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: CoeloSpacing.space4),
          if (_controller.state == ChildDirectoryState.ready && page != null)
            LayoutBuilder(
              builder: (context, inner) {
                final columns = (inner.maxWidth / 340).floor().clamp(1, 4);
                final width = (inner.maxWidth - (columns - 1) * CoeloSpacing.space6) / columns;
                return Wrap(
                  spacing: CoeloSpacing.space6,
                  runSpacing: CoeloSpacing.space6,
                  children: [
                    for (final item in page.items)
                      SizedBox(
                        width: width,
                        child: CoeloAdminInteractiveCard(
                          key: Key('child-card-${item.contextId}'),
                          minHeight: 216,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: CoeloSpacing.space6,
                              vertical: CoeloSpacing.space4,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.personName,
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: CoeloSpacing.space3),
                                Text(item.institutionName),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          else
            ChildReadStatePanel(state: _controller.state),
        ];
        final actions = Padding(
          padding: EdgeInsets.symmetric(horizontal: padding, vertical: CoeloSpacing.space4),
          child: Wrap(
            spacing: CoeloSpacing.space3,
            runSpacing: CoeloSpacing.space3,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const Key('child-directory-reload'),
                onPressed: loading ? null : () => unawaited(_controller.reload()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Recarregar'),
              ),
              FilledButton.icon(
                key: const Key('child-directory-next'),
                onPressed: page?.nextCursor == null || loading
                    ? null
                    : () => unawaited(_controller.nextPage()),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Próxima página'),
              ),
            ],
          ),
        );
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: widget.expand
              ? Column(
                  children: [
                    Expanded(
                      child: ListView(
                        key: const Key('child-directory-content'),
                        padding: EdgeInsets.all(padding),
                        children: content,
                      ),
                    ),
                    const SizedBox(height: CoeloSpacing.space4),
                    actions,
                  ],
                )
              : Column(
                  key: const Key('child-directory-content'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: content,
                      ),
                    ),
                    actions,
                  ],
                ),
        );
      },
    ),
  );
}

class ChildReadStatePanel extends StatelessWidget {
  const ChildReadStatePanel({required this.state, super.key});

  final ChildDirectoryState state;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: state == ChildDirectoryState.loading ? 'Carregando alunos' : null,
    child: CoeloStatePanel(
      key: Key('child-directory-${state.name}'),
      loading: state == ChildDirectoryState.loading,
      title: switch (state) {
        ChildDirectoryState.loading => 'Carregando alunos',
        ChildDirectoryState.denied => 'Acesso não autorizado',
        ChildDirectoryState.empty => 'Nenhum aluno encontrado',
        _ => 'Não foi possível carregar os alunos',
      },
      message: switch (state) {
        ChildDirectoryState.loading => 'Aguarde a consulta dos dados autorizados.',
        ChildDirectoryState.denied => 'Você não tem permissão para consultar estes dados.',
        ChildDirectoryState.empty => 'Nenhum vínculo foi retornado para este contexto.',
        _ => 'Tente recarregar os dados.',
      },
    ),
  );
}
