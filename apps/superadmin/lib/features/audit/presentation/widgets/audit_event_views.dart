import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';

import '../../domain/audit.dart';
import '../audit_directory_page.dart';
import 'audit_timeline.dart';

final class AuditEventViews extends StatelessWidget {
  const AuditEventViews({
    required this.events,
    required this.display,
    required this.selectedEventId,
    required this.onSelected,
    super.key,
  });

  final List<AuditEvent> events;
  final AuditDirectoryDisplay display;
  final String? selectedEventId;
  final ValueChanged<AuditEvent> onSelected;

  @override
  Widget build(BuildContext context) => display == AuditDirectoryDisplay.cards
      ? AuditTimeline(events: events, onSelected: onSelected)
      : CoeloAdminResizableTable<AuditEvent>(
          key: const Key('audit-table'),
          items: events,
          rowKey: (event) => event.id,
          headerHeight: 56,
          rowHeight: 64,
          onRowPressed: onSelected,
          isSelected: (event) => event.id == selectedEventId,
          pinnedColumn: _column(
            'instant',
            'Data/hora',
            (event) => auditInstantLabel(event.occurredAt),
            160,
          ),
          columns: [
            _column('actor', 'Ator', (event) => event.actor.displayName, 190),
            _column('action', 'Ação', (event) => event.actionCode, 190),
            _column('resource', 'Recurso', auditResourceLabel, 220),
            _outcomeColumn(),
            _column('origin', 'Origem', (event) => auditOriginLabel(event.origin), 170),
          ],
        );
}

CoeloAdminTableColumn<AuditEvent> _column(
  String id,
  String label,
  String Function(AuditEvent) value,
  double width,
) => CoeloAdminTableColumn<AuditEvent>(
  id: id,
  label: label,
  initialWidth: width,
  minWidth: 120,
  maxWidth: 420,
  cellBuilder: (context, event) => Align(
    alignment: Alignment.centerLeft,
    child: Text(value(event), maxLines: 1, overflow: TextOverflow.ellipsis),
  ),
);

CoeloAdminTableColumn<AuditEvent> _outcomeColumn() => CoeloAdminTableColumn<AuditEvent>(
  id: 'outcome',
  label: 'Resultado',
  initialWidth: 140,
  minWidth: 120,
  maxWidth: 220,
  cellBuilder: (context, event) {
    final negative = event.outcome != AuditOutcome.success;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        auditOutcomeLabel(event.outcome),
        style: negative
            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              )
            : null,
      ),
    );
  },
);
