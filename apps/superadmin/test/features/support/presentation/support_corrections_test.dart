import 'package:coelo_superadmin/features/support/domain/support_ticket.dart';
import 'package:coelo_superadmin/features/support/presentation/view_models/support_prototype_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 28, 12);

  SupportTicket ticket(int index, {Set<String> assigneeIds = const {}}) {
    return SupportTicket(
      id: 'SUP-${index.toString().padLeft(3, '0')}',
      subject: 'Chamado $index',
      menu: index.isEven ? 'Pessoas' : 'Instituicoes',
      screen: 'Diretorio',
      description: 'Descricao $index',
      requester: 'Pessoa $index',
      assigneeIds: assigneeIds,
      createdAt: now.subtract(Duration(days: index)),
      updatedAt: now.subtract(Duration(hours: index)),
      status: SupportTicketStatus.newRequest,
    );
  }

  test('uses one equivalent immutable assignee set for assignment and status validation', () {
    final controller = SupportPrototypeController(initialTickets: [ticket(1)], clock: () => now);
    addTearDown(controller.dispose);

    expect(controller.changeStatus('SUP-001', SupportTicketStatus.inProgress), isFalse);
    controller.setAssignees('SUP-001', {'member-dev', 'member-support'});
    expect(controller.tickets.single.assigneeIds, {'member-dev', 'member-support'});
    expect(() => controller.tickets.single.assigneeIds.add('member-qa'), throwsUnsupportedError);
    expect(controller.changeStatus('SUP-001', SupportTicketStatus.inProgress), isTrue);
  });

  test('sorts and paginates table results and resets to page one after changes', () {
    final controller = SupportPrototypeController(
      initialTickets: [for (var index = 1; index <= 22; index++) ticket(index)],
    );
    addTearDown(controller.dispose);

    expect(controller.pageSize, 9);
    expect(controller.totalPages, 3);
    expect(controller.visibleTickets, hasLength(9));

    controller.setPage(3);
    expect(controller.visibleTickets, hasLength(4));
    controller.setSort(SupportSortColumn.subject);
    expect(controller.currentPage, 1);
    expect(controller.sortAscending, isTrue);
    controller.setSort(SupportSortColumn.subject);
    expect(controller.sortAscending, isFalse);

    controller.setPage(2);
    controller.setPageSize(20);
    expect(controller.currentPage, 1);
    expect(controller.pageSize, 20);
    expect(controller.visibleTickets, hasLength(20));

    controller.setPage(2);
    controller.updateFilters(SupportFilters(search: 'Chamado 1'));
    expect(controller.currentPage, 1);
  });

  test('records local history for creation, assignment, status, and reply', () {
    final controller = SupportPrototypeController(initialTickets: [ticket(1)], clock: () => now);
    addTearDown(controller.dispose);

    controller.setAssignees('SUP-001', {'member-support'});
    controller.changeStatus('SUP-001', SupportTicketStatus.inProgress);
    controller.sendReply('SUP-001', 'Estamos verificando.');

    expect(
      controller.tickets.single.activities.map((activity) => activity.kind),
      containsAll([
        SupportActivityKind.assignmentChanged,
        SupportActivityKind.statusChanged,
        SupportActivityKind.replySent,
      ]),
    );
  });

  test('clamps the current page when a ticket leaves the active filter', () {
    final controller = SupportPrototypeController(
      initialTickets: [
        for (var index = 1; index <= 10; index++)
          ticket(
            index,
          ).copyWith(assigneeIds: const {'member-support'}, status: SupportTicketStatus.inProgress),
      ],
      clock: () => now,
    );
    addTearDown(controller.dispose);

    controller.updateFilters(SupportFilters(statuses: {SupportTicketStatus.inProgress}));
    controller.setPage(2);
    expect(controller.visibleTickets, hasLength(1));

    controller.changeStatus('SUP-010', SupportTicketStatus.completed);

    expect(controller.currentPage, 1);
    expect(controller.visibleTickets, hasLength(9));
  });
}
