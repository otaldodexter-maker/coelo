import 'dart:io';

import 'package:coelo_api/children.dart';
import 'package:test/test.dart';

/// The CHILD read compared against the function that answers it.
///
/// This is the read `students.list` stands on - the one action in Alunos that
/// reaches real data in production - and it was the last contract in Estruturas
/// with no measurement across the two sides. Seventeen tests cover the decoder's
/// behaviour; none of them had ever looked at the migration.
///
/// The measurement finds nothing wrong, and that is worth saying plainly rather
/// than leaving unsaid: the four parameters match by name, both sides refuse a
/// limit outside 1..50, and every key the function builds is a key the decoder
/// accepts. Four other contracts I measured tonight were not in that state.
///
/// What the test is for is the next change. The decoder takes closed key sets,
/// so a field added on the server does not arrive half-read - the whole payload
/// is refused. That is the right failure, and it is loud, but it happens in
/// production. Here it happens in the suite instead.
const _migration =
    '../coelo_database/migrations/'
    '20260908051500_superadmin_child_context_directory_v2.sql';

String _sql() => File(_migration).readAsStringSync();

/// The declared parameter names of the directory function.
Set<String> _parameters(String sql) {
  final start = sql.indexOf('create function public.superadmin_child_context_directory_v2(');
  if (start == -1) {
    throw StateError('the migration no longer declares the directory function');
  }
  final close = RegExp(r'\)\s*returns').firstMatch(sql.substring(start));
  if (close == null) {
    throw StateError('could not bound the signature');
  }
  return RegExp(
    r'\b(p_[a-z_]+)\b',
  ).allMatches(sql.substring(start, start + close.start)).map((match) => match.group(1)!).toSet();
}

/// The keys of one `jsonb_build_object(...)` chosen by a key it must contain.
Set<String> _built(String sql, String anchor) {
  final at = sql.indexOf(anchor);
  if (at == -1) {
    throw StateError('the construction anchored at $anchor is gone');
  }
  final open = sql.lastIndexOf('jsonb_build_object(', at);
  // Balance the parentheses rather than guessing a terminator: the cursor call
  // ends with ');' and the item call with '))', and a guess picked up the block
  // that followed.
  var depth = 0;
  var end = open;
  for (var i = sql.indexOf('(', open); i < sql.length; i += 1) {
    if (sql[i] == '(') depth += 1;
    if (sql[i] == ')') {
      depth -= 1;
      if (depth == 0) {
        end = i;
        break;
      }
    }
  }
  final chunk = sql.substring(open, end);
  return RegExp("'([a-z_]+)'").allMatches(chunk).map((match) => match.group(1)!).toSet();
}

void main() {
  final sql = _sql();

  test('the four parameters are the four the client sends, by name', () {
    final declared = _parameters(sql);
    final sent = const ChildDirectoryRequest(limit: 20).toRpcParams().keys.toSet();
    expect(sent, equals(declared));
  });

  test('both sides refuse the same page size, so neither surprises the other', () {
    // The function raises outside 1..50; the request refuses to be built.
    expect(sql, contains('p_limit < 1 or p_limit > 50'));
    expect(() => const ChildDirectoryRequest(limit: 0).toRpcParams(), throwsFormatException);
    expect(() => const ChildDirectoryRequest(limit: 51).toRpcParams(), throwsFormatException);
    expect(const ChildDirectoryRequest(limit: 50).toRpcParams()['p_limit'], 50);
  });

  test('every key the function builds for an item is a key the decoder accepts', () {
    final built = _built(sql, "'person_name', row_record.display_name");
    expect(
      built,
      equals({'context_id', 'person_id', 'person_name', 'institution_id', 'institution_name'}),
      reason:
          'the item projection changed; the decoder takes a closed set and '
          'would refuse the whole payload rather than read it in part',
    );

    // Proven against the decoder itself, not against a copy of the list.
    final page = decodeChildDirectory({
      'ok': true,
      'data': {
        'items': [
          {
            for (final key in built)
              key: key.endsWith('_id')
                  ? '10000000-0000-4000-8000-00000000000${built.toList().indexOf(key) + 1}'
                  : 'Nome $key',
          },
        ],
        'next_cursor': null,
      },
      'error': null,
    }, request: const ChildDirectoryRequest(limit: 20));
    expect(page.items, hasLength(1));
  });

  test('the cursor the function builds is the cursor the decoder reads', () {
    expect(_built(sql, "'context_id',last_id"), equals({'name', 'context_id'}));
  });

  test('a key the function does not build is refused rather than ignored', () {
    expect(
      () => decodeChildDirectory({
        'ok': true,
        'data': {
          'items': [
            {
              'context_id': '10000000-0000-4000-8000-000000000001',
              'person_id': '10000000-0000-4000-8000-000000000002',
              'person_name': 'Ana',
              'institution_id': '10000000-0000-4000-8000-000000000003',
              'institution_name': 'Casa Nuvem',
              'guardian_email': 'ana@example.com',
            },
          ],
          'next_cursor': null,
        },
        'error': null,
      }, request: const ChildDirectoryRequest(limit: 20)),
      throwsFormatException,
      reason: 'a child read must not quietly carry a field nobody agreed to',
    );
  });
}
