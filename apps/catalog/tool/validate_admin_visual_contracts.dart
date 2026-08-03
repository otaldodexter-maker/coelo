import 'dart:convert';
import 'dart:io';

const _prohibitedSymbols = <String, String>{
  'PopupMenuButton': 'CoeloAdminFlyout',
  'PopupMenuItem': 'CoeloAdminFlyoutItem',
  'MenuAnchor': 'CoeloAdminFlyout',
  'MenuItemButton': 'CoeloAdminFlyoutItem',
  'InkWell': 'CoeloAdminInteractiveCard ou componente Coelo especializado',
};

class AdminVisualDiagnostic {
  const AdminVisualDiagnostic({
    required this.path,
    required this.line,
    required this.symbol,
    required this.message,
  });

  final String path;
  final int line;
  final String symbol;
  final String message;

  @override
  String toString() => '$path:$line [$symbol] $message';
}

List<AdminVisualDiagnostic> validateAdminVisualContracts({
  required Directory root,
  required File allowlist,
}) {
  final diagnostics = <AdminVisualDiagnostic>[];
  final entries = _readAllowlist(root, allowlist, diagnostics);
  final validEntries = <String, _AllowlistEntry>{};

  for (final entry in entries) {
    final key = '${entry.path}|${entry.symbol}';
    final invalidMessage = _invalidEntryMessage(root, entry, validEntries[key]);
    if (invalidMessage != null) {
      diagnostics.add(
        AdminVisualDiagnostic(
          path: entry.path,
          line: 1,
          symbol: 'allowlist',
          message: invalidMessage,
        ),
      );
      continue;
    }
    validEntries[key] = entry;
  }

  final features = Directory(_join(root.path, 'apps/superadmin/lib/features'));
  if (!features.existsSync()) {
    diagnostics.add(
      const AdminVisualDiagnostic(
        path: 'apps/superadmin/lib/features',
        line: 1,
        symbol: 'scanner',
        message: 'diretorio de features nao existe',
      ),
    );
    return _sorted(diagnostics);
  }

  final dartFiles =
      features
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in dartFiles) {
    final relativePath = _relativePath(root, file);
    final stripped = _stripCommentsAndStrings(file.readAsStringSync());
    for (final symbol in _prohibitedSymbols.keys) {
      final matches = _constructorMatches(stripped, symbol).toList();
      final allowed = validEntries['$relativePath|$symbol']?.maxOccurrences ?? 0;
      for (final match in matches.skip(allowed)) {
        diagnostics.add(
          AdminVisualDiagnostic(
            path: relativePath,
            line: _lineOf(stripped, match.start),
            symbol: symbol,
            message: allowed == 0
                ? 'uso cru proibido; substitua por ${_prohibitedSymbols[symbol]}'
                : 'ocorrencia ${matches.indexOf(match) + 1} excede a baseline '
                      '$allowed; substitua por ${_prohibitedSymbols[symbol]}',
          ),
        );
      }
    }
  }

  return _sorted(diagnostics);
}

List<_AllowlistEntry> _readAllowlist(
  Directory root,
  File allowlist,
  List<AdminVisualDiagnostic> diagnostics,
) {
  if (!allowlist.existsSync()) {
    diagnostics.add(
      AdminVisualDiagnostic(
        path: _relativePath(root, allowlist),
        line: 1,
        symbol: 'allowlist',
        message: 'arquivo de allowlist nao existe',
      ),
    );
    return const [];
  }
  try {
    final decoded = jsonDecode(allowlist.readAsStringSync());
    final rawEntries = (decoded as Map<String, dynamic>)['entries'] as List<dynamic>;
    return rawEntries.map((raw) => _AllowlistEntry.fromJson(raw as Map<String, dynamic>)).toList();
  } on Object catch (error) {
    diagnostics.add(
      AdminVisualDiagnostic(
        path: _relativePath(root, allowlist),
        line: 1,
        symbol: 'allowlist',
        message: 'JSON invalido: $error',
      ),
    );
    return const [];
  }
}

String? _invalidEntryMessage(Directory root, _AllowlistEntry entry, _AllowlistEntry? duplicate) {
  if (entry.reason.trim().isEmpty) return 'entrada possui reason vazio';
  if (!_prohibitedSymbols.containsKey(entry.symbol)) {
    return 'symbol desconhecido: ${entry.symbol}';
  }
  if (entry.maxOccurrences < 1) return 'maxOccurrences deve ser maior que zero';
  if (!entry.path.startsWith('apps/superadmin/lib/features/') || !entry.path.endsWith('.dart')) {
    return 'path deve apontar para uma feature Dart do Superadmin';
  }
  if (!File(_join(root.path, entry.path)).existsSync()) {
    return 'arquivo allowlistado nao existe';
  }
  if (duplicate != null) return 'entrada duplicada para path e symbol';
  return null;
}

Iterable<RegExpMatch> _constructorMatches(String source, String symbol) {
  return RegExp(
    '\\b${RegExp.escape(symbol)}(?:\\s*<[^;{}()]*>)?\\s*\\(',
    multiLine: true,
  ).allMatches(source);
}

String _stripCommentsAndStrings(String source) {
  final output = StringBuffer();
  var index = 0;
  while (index < source.length) {
    final current = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    if (current == '/' && next == '/') {
      output.write('  ');
      index += 2;
      while (index < source.length && source[index] != '\n') {
        output.write(' ');
        index++;
      }
      continue;
    }
    if (current == '/' && next == '*') {
      output.write('  ');
      index += 2;
      while (index < source.length) {
        if (index + 1 < source.length && source[index] == '*' && source[index + 1] == '/') {
          output.write('  ');
          index += 2;
          break;
        }
        output.write(source[index] == '\n' ? '\n' : ' ');
        index++;
      }
      continue;
    }
    if (current == "'" || current == '"') {
      final quote = current;
      final triple =
          index + 2 < source.length && source[index + 1] == quote && source[index + 2] == quote;
      final delimiterLength = triple ? 3 : 1;
      output.write(' ' * delimiterLength);
      index += delimiterLength;
      while (index < source.length) {
        if (!triple && source[index] == '\\' && index + 1 < source.length) {
          output.write('  ');
          index += 2;
          continue;
        }
        final closes = triple
            ? index + 2 < source.length &&
                  source[index] == quote &&
                  source[index + 1] == quote &&
                  source[index + 2] == quote
            : source[index] == quote;
        if (closes) {
          output.write(' ' * delimiterLength);
          index += delimiterLength;
          break;
        }
        output.write(source[index] == '\n' ? '\n' : ' ');
        index++;
      }
      continue;
    }
    output.write(current);
    index++;
  }
  return output.toString();
}

int _lineOf(String source, int offset) => '\n'.allMatches(source.substring(0, offset)).length + 1;

String _relativePath(Directory root, File file) {
  final rootPath = root.absolute.path.replaceAll('\\', '/');
  final filePath = file.absolute.path.replaceAll('\\', '/');
  if (filePath.startsWith('$rootPath/')) {
    return filePath.substring(rootPath.length + 1);
  }
  return filePath;
}

String _join(String root, String relative) =>
    '$root${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';

List<AdminVisualDiagnostic> _sorted(List<AdminVisualDiagnostic> diagnostics) =>
    diagnostics..sort((a, b) {
      final path = a.path.compareTo(b.path);
      if (path != 0) return path;
      final line = a.line.compareTo(b.line);
      if (line != 0) return line;
      return a.symbol.compareTo(b.symbol);
    });

class _AllowlistEntry {
  const _AllowlistEntry({
    required this.path,
    required this.symbol,
    required this.maxOccurrences,
    required this.reason,
  });

  factory _AllowlistEntry.fromJson(Map<String, dynamic> json) => _AllowlistEntry(
    path: json['path'] as String,
    symbol: json['symbol'] as String,
    maxOccurrences: json['maxOccurrences'] as int,
    reason: json['reason'] as String,
  );

  final String path;
  final String symbol;
  final int maxOccurrences;
  final String reason;
}

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln(
      'Uso: dart run tool/validate_admin_visual_contracts.dart '
      '<repo-root> <allowlist.json>',
    );
    exitCode = 64;
    return;
  }
  final diagnostics = validateAdminVisualContracts(
    root: Directory(arguments[0]),
    allowlist: File(arguments[1]),
  );
  for (final diagnostic in diagnostics) {
    stderr.writeln(diagnostic);
  }
  if (diagnostics.isNotEmpty) exitCode = 1;
}
