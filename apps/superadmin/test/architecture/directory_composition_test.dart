import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Decisão do Owner de 10/09/2026 (ADR 0034, Fase 0 da Rodada 3): o conceito
/// de família de diretório administrativo (cabeçalho, toolbar, abas, toggle,
/// grade com Criar, tabela, paginação) vive uma vez em `coelo_ui_admin`
/// (`CoeloAdminDirectory`) e no shell. Uma feature não declara widgets
/// próprios de Table, Toolbar, Pagination, Header ou Directory: ela fornece
/// cards, linhas, filtros e textos de domínio.
///
/// A allowlist abaixo registra o que ainda não foi migrado. Ela só pode
/// diminuir: uma entrada que deixa de existir precisa ser removida daqui, e
/// uma ocorrência nova fora da lista falha o teste.
/// `Header` é o cabeçalho de página/diretório (título, subtítulo, Bug, conta),
/// que pertence ao shell; cabeçalhos de card ou de seção são conteúdo.
const _reservedSuffixes = [
  'Table',
  'Toolbar',
  'Pagination',
  'PaginationFooter',
  'PageHeader',
  'DirectoryHeader',
  'ListingHeader',
  'Directory',
];

const _pendingMigration = <String, List<String>>{
  // Listagens fora dos 13 diretórios da Fase 0: renomear para *Rows/*Filters ao
  // migrar a tela para o composto (grupos das telas).
  'lib/features/agenda/presentation/agenda_approvals_page.dart': ['_ApprovalTable'],
  'lib/features/agenda/presentation/agenda_calendar_page.dart': ['_AgendaToolbar'],
  'lib/features/agenda/presentation/agenda_requests_page.dart': ['_RequestTable'],
  'lib/features/attendance/attendance_pages.dart': ['_AttendanceCallToolbar'],
  'lib/features/support/presentation/widgets/support_filter_toolbar.dart': ['SupportFilterToolbar'],
  'lib/features/support/presentation/widgets/support_ticket_table.dart': ['SupportTicketTable'],
};

final _declaration = RegExp(
  r'class\s+(\w+(?:' +
      _reservedSuffixes.join('|') +
      r'))(?:<[^>]*>)?\s+extends\s+(?:StatelessWidget|StatefulWidget)\b',
);

void main() {
  test('features não declaram Table, Toolbar, Pagination, Header ou Directory próprios', () {
    final root = Directory('lib/features');
    expect(root.existsSync(), isTrue, reason: 'executar a partir de apps/superadmin');
    final found = <String, List<String>>{};
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      final source = entity.readAsStringSync();
      for (final match in _declaration.allMatches(source)) {
        found.putIfAbsent(path, () => []).add(match.group(1)!);
      }
    }

    final newOffenders = <String>[];
    for (final entry in found.entries) {
      final allowed = _pendingMigration[entry.key] ?? const [];
      for (final name in entry.value) {
        if (!allowed.contains(name)) newOffenders.add('${entry.key}: $name');
      }
    }
    expect(
      newOffenders,
      isEmpty,
      reason:
          'Widget de família declarado em feature. Use CoeloAdminDirectory e '
          'forneça apenas conteúdo de domínio (cards, linhas, filtros).',
    );

    final stale = <String>[];
    for (final entry in _pendingMigration.entries) {
      final present = found[entry.key] ?? const [];
      for (final name in entry.value) {
        if (!present.contains(name)) stale.add('${entry.key}: $name');
      }
    }
    expect(
      stale,
      isEmpty,
      reason: 'Entrada da allowlist já migrada: remova-a para o gate continuar apertando.',
    );
  });

  test('features não redeclaram o modo de exibição do diretório', () {
    final root = Directory('lib/features');
    final displayEnum = RegExp(r'enum\s+\w*DirectoryDisplay\b|enum\s+_\w*Display\s*\{\s*cards');
    const pending = <String>{
      'lib/features/daily_routine/daily_routine_pages.dart',
      'lib/features/health_care/presentation/health_care_controller.dart',
    };
    final found = <String>{};
    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (displayEnum.hasMatch(entity.readAsStringSync())) found.add(path);
    }
    expect(
      found.difference(pending),
      isEmpty,
      reason: 'Use CoeloAdminDirectoryDisplay em vez de um enum local de cards/tabela.',
    );
    expect(
      pending.difference(found),
      isEmpty,
      reason: 'Entrada da allowlist já migrada: remova-a.',
    );
  });
}
