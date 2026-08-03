import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/material.dart';

import '../data/fake_notice_repository.dart';
import '../domain/platform_notice.dart';

final class NoticeDirectoryPage extends StatefulWidget {
  const NoticeDirectoryPage({required this.repository, this.onCreate, this.onEdit, super.key});
  final FakeNoticeRepository repository;
  final VoidCallback? onCreate;
  final ValueChanged<String>? onEdit;
  @override
  State<NoticeDirectoryPage> createState() => _NoticeDirectoryPageState();
}

final class _NoticeDirectoryPageState extends State<NoticeDirectoryPage> {
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final notices = widget.repository.list(search: _search.text);
      return Padding(
        padding: EdgeInsets.all(
          constraints.maxWidth < 768 ? CoeloSpacing.space4 : CoeloSpacing.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Avisos', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: CoeloSpacing.space2),
            const Text('Componha comunicados oficiais do preview local.'),
            const SizedBox(height: CoeloSpacing.space4),
            CoeloAdminListingToolbar(
              search: SizedBox(
                width: 320,
                child: CoeloSearchField(
                  controller: _search,
                  semanticLabel: 'Buscar aviso',
                  hintText: 'Buscar aviso',
                  onChanged: (_) => setState(() {}),
                ),
              ),
              filters: const [],
              actions: const [],
            ),
            const SizedBox(height: CoeloSpacing.space4),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 380,
                  mainAxisExtent: 216,
                  mainAxisSpacing: CoeloSpacing.space6,
                  crossAxisSpacing: CoeloSpacing.space6,
                ),
                itemCount: notices.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return CoeloAdminCreateAction(
                      label: 'Novo aviso',
                      description: 'Crie um aviso local.',
                      onPressed: widget.onCreate,
                    );
                  }
                  final notice = notices[index - 1];
                  return CoeloAdminInteractiveCard(
                    onPressed: () => widget.onEdit?.call(notice.id),
                    semanticLabel: 'Abrir aviso ${notice.title}',
                    minHeight: 216,
                    child: Padding(
                      padding: const EdgeInsets.all(CoeloSpacing.space4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notice.title,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _status(context, notice.status),
                            ],
                          ),
                          const SizedBox(height: CoeloSpacing.space2),
                          Text('${notice.audience.label}: ${notice.audienceLabel}'),
                          Text(
                            '${notice.deliveredCount}/${notice.reach} entregues · ${notice.acceptedCount} aceites',
                          ),
                          const Spacer(),
                          Text(
                            notice.priority.label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _status(BuildContext context, NoticeStatus status) {
    final colors = Theme.of(context).colorScheme;
    final foreground = status == NoticeStatus.cancelled ? colors.error : colors.primary;
    final background = status == NoticeStatus.cancelled
        ? colors.errorContainer
        : colors.primaryContainer;
    return CoeloStatusChip(
      label: status.label,
      foregroundColor: foreground,
      backgroundColor: background,
    );
  }
}
