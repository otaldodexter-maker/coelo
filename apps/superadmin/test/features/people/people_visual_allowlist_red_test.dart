import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RED: People directory no longer depends on a legacy visual allowlist', () {
    final file = File('../catalog/assets/admin-visual-contract-allowlist.json');
    final payload = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final entries = payload.values
        .whereType<List<dynamic>>()
        .expand((value) => value)
        .whereType<Map<String, dynamic>>();

    expect(
      entries.where(
        (entry) =>
            entry['path'] ==
            'apps/superadmin/lib/features/people/presentation/person_directory_page.dart',
      ),
      isEmpty,
      reason: 'People must use the canonical interactive card instead of allowlisting InkWell.',
    );
  });
}
