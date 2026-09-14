import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ADR 0038 / OQ-028: expired e revoked aparecem como Concluído com motivo.
  test('closure reason enriches the completed label', () {
    expect(supportStatusLabel(SupportTicketStatus.completed), 'Concluído');
    expect(
      supportStatusLabel(SupportTicketStatus.completed, closureReason: 'expired'),
      'Concluído · Expirado',
    );
    expect(
      supportStatusLabel(SupportTicketStatus.completed, closureReason: 'revoked'),
      'Concluído · Revogado',
    );
    expect(supportStatusLabel(SupportTicketStatus.inProgress, closureReason: 'expired'), 'Em andamento');
  });

  test('copyWith keeps the closure reason unless cleared', () {
    final ticket = SupportTicket(
      id: 't',
      subject: 's',
      menu: 'm',
      screen: 'sc',
      description: 'd',
      requester: 'r',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      status: SupportTicketStatus.completed,
      closureReason: 'expired',
    );
    expect(ticket.copyWith(revision: 2).closureReason, 'expired');
    expect(ticket.copyWith(status: SupportTicketStatus.newRequest, clearClosureReason: true).closureReason, isNull);
  });
}
