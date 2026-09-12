import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato estatico entre as chamadas RPC do Superadmin e as funcoes que o
/// pacote `coelo_database` realmente cria.
///
/// Suite verde nao e producao: um nome de RPC errado, um parametro renomeado no
/// banco ou uma funcao que nunca entrou em migration passam por todos os testes
/// de widget e de repositorio, porque esses testes usam cliente falso ou
/// interceptam o transporte. O erro so aparece no primeiro uso real, como
/// PGRST202 ou undefined_function, e chega a tela como indisponibilidade
/// generica. Este teste fecha a lacuna lendo os dois lados do contrato.
void main() {
  final root = _repositoryRoot();
  final calls = _callSites(Directory('${root.path}/apps/superadmin/lib'));
  final declared = _declaredFunctions(Directory('${root.path}/packages/coelo_database'));

  test('reads quoted relation identifiers from the production dump', () {
    final fixture = Directory.systemTemp.createTempSync('coelo-contract-relations-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    File('${fixture.path}/baseline.sql').writeAsStringSync(
      'CREATE TABLE IF NOT EXISTS "public"."profile_about_pages" (id uuid);'
      'CREATE TABLE public.plain_table (id uuid);'
      'CREATE OR REPLACE VIEW "public"."about_view" AS SELECT 1;'
      'CREATE MATERIALIZED VIEW public.plain_view AS SELECT 1;',
    );
    expect(_declaredRelations(fixture), {
      'profile_about_pages', 'plain_table', 'about_view', 'plain_view',
    });
  });

  test('reads quoted function and parameter identifiers without changing required defaults', () {
    final fixture = Directory.systemTemp.createTempSync('coelo-contract-functions-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    File('${fixture.path}/baseline.sql').writeAsStringSync(
      'CREATE OR REPLACE FUNCTION "public"."get_profile_about"('
      '"p_subject_type" text, "p_subject_id" uuid, '
      '"p_preview_audience" text DEFAULT NULL) RETURNS jsonb AS NULL;'
      'CREATE FUNCTION public.plain_function(p_required uuid, p_optional text DEFAULT NULL) '
      'RETURNS jsonb AS NULL;',
    );
    final functions = _declaredFunctions(fixture);
    expect(functions.keys, containsAll(['get_profile_about', 'plain_function']));
    expect(functions['get_profile_about']!.required, {'p_subject_type', 'p_subject_id'});
    expect(functions['get_profile_about']!.all, {
      'p_subject_type', 'p_subject_id', 'p_preview_audience',
    });
    expect(functions['plain_function']!.required, {'p_required'});
  });

  test('excludes pgTAP declarations using native Windows or POSIX paths', () {
    final fixture = Directory.systemTemp.createTempSync('coelo-contract-tests-');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final tests = Directory('${fixture.path}/tests')..createSync();
    File('${tests.path}/fixture.sql').writeAsStringSync(
      'CREATE TABLE public.test_only_relation (id uuid);'
      'CREATE FUNCTION public.test_only_function() RETURNS jsonb AS NULL;',
    );
    File('${fixture.path}/migration.sql').writeAsStringSync(
      'CREATE TABLE public.real_relation (id uuid);'
      'CREATE FUNCTION public.real_function() RETURNS jsonb AS NULL;',
    );
    expect(_declaredRelations(fixture), {'real_relation'});
    expect(_declaredFunctions(fixture).keys, ['real_function']);
  });

  test('toda RPC chamada pelo Superadmin existe no pacote de banco', () {
    expect(calls, isNotEmpty, reason: 'o varredor nao encontrou chamadas .rpc');

    final missing = <String>{
      for (final call in calls)
        if (!declared.containsKey(call.name)) call.name,
    };

    expect(
      missing.difference(_rpcsAusentesConhecidas.keys.toSet()),
      isEmpty,
      reason:
          'Estas RPCs sao chamadas pelo cliente e nenhum arquivo de '
          'packages/coelo_database as cria. Ou a funcao foi instalada fora do '
          'versionamento, e entao o pacote nao descreve producao, ou a '
          'superficie falha no primeiro uso real.',
    );

    // O inverso tambem precisa valer: uma ausencia resolvida tem de sair da
    // lista, senao a lista envelhece e passa a esconder o problema seguinte.
    expect(
      _rpcsAusentesConhecidas.keys.where(declared.containsKey),
      isEmpty,
      reason:
          'A funcao passou a existir no pacote. Remova o nome de '
          '_rpcsAusentesConhecidas em vez de manter a excecao.',
    );
  });

  test('nenhuma chamada envia parametro fora da assinatura declarada', () {
    final offenders = <String>[];
    for (final call in calls) {
      final signature = declared[call.name];
      if (signature == null || call.keys == null) continue;
      final extra = call.keys!.difference(signature.all);
      if (extra.isNotEmpty) {
        offenders.add('${call.name} recebe ${extra.toList()..sort()} em ${call.where}');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('toda relacao lida direto pelo cliente existe no pacote', () {
    // Leitura direta por PostgREST e a outra aresta do mesmo contrato: a tela
    // depende de a relacao existir e de a RLS liberar a linha, e o teste de
    // repositorio nao ve nem uma coisa nem outra.
    final relations = _declaredRelations(Directory('${root.path}/packages/coelo_database'));
    final used = _relationReads(Directory('${root.path}/apps/superadmin/lib'));
    expect(used, isNotEmpty, reason: 'o varredor nao encontrou leitura .from');

    expect(
      used.difference(relations).difference(_relacoesAusentesConhecidas.keys.toSet()),
      isEmpty,
      reason:
          'O cliente le estas relacoes direto por PostgREST e nenhum arquivo de '
          'packages/coelo_database as cria.',
    );
    expect(
      _relacoesAusentesConhecidas.keys.where(relations.contains),
      isEmpty,
      reason:
          'A relacao passou a existir no pacote. Remova o nome de '
          '_relacoesAusentesConhecidas em vez de manter a excecao.',
    );
  });

  test('nenhuma chamada omite parametro obrigatorio da assinatura', () {
    final offenders = <String>[];
    for (final call in calls) {
      final signature = declared[call.name];
      if (signature == null || call.keys == null || call.spread) continue;
      // `required` e a intersecao das sobrecargas declaradas, entao este teste
      // acusa apenas a chamada que nao satisfaz NENHUMA forma existente. Uma
      // chamada que satisfaz somente a forma legada, como
      // meal_plan_request_image_delete sem p_expected_revision, continua
      // legitima para o banco e esta descrita no relatorio de contrato; nao
      // cabe a este teste decidir qual sobrecarga o produto deveria usar.
      final absent = signature.required.difference(call.keys!);
      if (absent.isEmpty) continue;
      offenders.add('${call.name} omite ${absent.toList()..sort()} em ${call.where}');
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}

/// Nomes chamados pelo cliente que nenhuma migration do pacote cria.
///
/// Ausências de 2026-09-10 reconciliadas em 2026-09-12: as cinco RPCs
/// de Unidades já pertencem ao pacote versionado. Relatório histórico:
/// docs/reviews/etapa-2-operacao/reports/E2-noturna-contrato-rpc-20260910.md
const _rpcsAusentesConhecidas = <String, String>{};

/// Exceções de relações reconciliadas com a baseline de produção em12/09.
/// profile_about_pages, sections e structured_fields são declaradas no dump;
/// nomes SQL entre aspas agora participam do mesmo censo das migrations.
const _relacoesAusentesConhecidas = <String, String>{};

final class _Call {
  _Call(this.name, this.where, this.keys, this.spread);

  final String name;
  final String where;
  final Set<String>? keys;
  final bool spread;
}

final class _Signature {
  _Signature(this.required, this.all);

  final Set<String> required;
  final Set<String> all;
}

Directory _repositoryRoot() {
  var directory = Directory.current;
  for (var level = 0; level < 6; level++) {
    if (Directory('${directory.path}/packages/coelo_database').existsSync()) return directory;
    directory = directory.parent;
  }
  throw StateError(
    'packages/coelo_database nao encontrado a partir de ${Directory.current.path}',
  );
}

List<_Call> _callSites(Directory lib) {
  final calls = <_Call>[];
  final pattern = RegExp(r'\.rpc(?:<[^>()]*>)?\(');
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final text = file.readAsStringSync();
    for (final match in pattern.allMatches(text)) {
      final close = _span(text, match.end - 1, '(', ')');
      if (close < 0) continue;
      final inner = text.substring(match.end, close);
      final name = RegExp("^\\s*'([A-Za-z0-9_]+)'").firstMatch(inner);
      if (name == null) continue;
      final rest = inner.substring(name.end);
      final brace = rest.indexOf('{');
      Set<String>? keys;
      var spread = false;
      if (brace >= 0) {
        final end = _span(rest, brace, '{', '}');
        if (end > 0) {
          final body = _topLevel(rest.substring(brace + 1, end));
          keys = RegExp("'([A-Za-z0-9_]+)'\\s*:")
              .allMatches(body)
              .map((entry) => entry.group(1)!)
              .toSet();
          spread = body.contains('...');
        }
      }
      final line = text.substring(0, match.start).split('\n').length;
      calls.add(_Call(name.group(1)!, '${file.uri.pathSegments.last}:$line', keys, spread));
    }
  }
  return calls;
}

Map<String, _Signature> _declaredFunctions(Directory package) {
  final declared = <String, _Signature>{};
  final pattern = RegExp(
    r'create\s+(?:or\s+replace\s+)?function\s+(?:"?[A-Za-z0-9_]+"?\.)?"?([A-Za-z0-9_]+)"?\s*\(',
    caseSensitive: false,
  );
  for (final file in package.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.sql')) continue;
    // Testes pgTAP criam funcoes auxiliares que nao fazem parte do contrato.
    if (file.path.replaceAll(r'\', '/').contains('/tests/')) continue;
    final text = file.readAsStringSync();
    for (final match in pattern.allMatches(text)) {
      final close = _span(text, match.end - 1, '(', ')');
      if (close < 0) continue;
      final required = <String>{};
      final all = <String>{};
      for (final argument in _splitTopLevel(text.substring(match.end, close))) {
        final words = argument.trim().split(RegExp(r'\s+'));
        if (words.isEmpty || words.first.isEmpty) continue;
        final qualifier = RegExp(r'^(?:out|inout|in|variadic)$', caseSensitive: false);
        final rawName = qualifier.hasMatch(words.first)
            ? (words.length > 1 ? words[1] : '')
            : words.first;
        final name = rawName.startsWith('"') && rawName.endsWith('"')
            ? rawName.substring(1, rawName.length - 1)
            : rawName;
        if (name.isEmpty) continue;
        all.add(name);
        if (!RegExp(r'\bdefault\b|=', caseSensitive: false).hasMatch(argument)) {
          required.add(name);
        }
      }
      final key = match.group(1)!;
      final previous = declared[key];
      declared[key] = _Signature(
        // Sobrecargas convivem: exigir a intersecao evita acusar uma chamada
        // que satisfaz uma das formas declaradas.
        previous == null ? required : previous.required.intersection(required),
        previous == null ? all : previous.all.union(all),
      );
    }
  }
  return declared;
}

int _span(String text, int start, String open, String close) {
  var depth = 0;
  for (var index = start; index < text.length; index++) {
    if (text[index] == open) {
      depth++;
    } else if (text[index] == close) {
      depth--;
      if (depth == 0) return index;
    }
  }
  return -1;
}

String _topLevel(String body) {
  final buffer = StringBuffer();
  var depth = 0;
  for (final character in body.split('')) {
    if ('{[('.contains(character)) {
      depth++;
    } else if ('}])'.contains(character)) {
      depth--;
    } else if (depth == 0) {
      buffer.write(character);
    }
  }
  return buffer.toString();
}

List<String> _splitTopLevel(String arguments) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final character in arguments.split('')) {
    if (character == '(') depth++;
    if (character == ')') depth--;
    if (character == ',' && depth == 0) {
      parts.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(character);
    }
  }
  parts.add(buffer.toString());
  return parts;
}

Set<String> _relationReads(Directory lib) {
  final relations = <String>{};
  final pattern = RegExp(r"\.from\(\s*'([A-Za-z0-9_]+)'");
  for (final file in lib.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart')) continue;
    final text = file.readAsStringSync();
    for (final match in pattern.allMatches(text)) {
      // storage.from nomeia bucket, nao relacao do Postgres.
      final before = text.substring(0, match.start);
      if (before.trimRight().endsWith('storage')) continue;
      relations.add(match.group(1)!);
    }
  }
  return relations;
}

Set<String> _declaredRelations(Directory package) {
  final relations = <String>{};
  final pattern = RegExp(
    r'create\s+(?:or\s+replace\s+)?(?:materialized\s+)?(?:table|view)\s+'
    r'(?:if\s+not\s+exists\s+)?(?:"?[A-Za-z0-9_]+"?\.)?"?([A-Za-z0-9_]+)"?',
    caseSensitive: false,
  );
  for (final file in package.listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.sql')) continue;
    if (file.path.replaceAll(r'\', '/').contains('/tests/')) continue;
    for (final match in pattern.allMatches(file.readAsStringSync())) {
      relations.add(match.group(1)!);
    }
  }
  return relations;
}
