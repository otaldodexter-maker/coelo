import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:coelo_superadmin/features/forms/data/development_forms_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevelopmentFormsApi.seeded', () {
    test('provides every directory lifecycle with deterministic fixture data', () async {
      final api = DevelopmentFormsApi.seeded();

      final first = await api.listDirectory(const FormDirectoryQuery(limit: 100));
      final second = await api.listDirectory(const FormDirectoryQuery(limit: 100));

      expect(first.items, hasLength(30));
      expect(first.nextCursor, isNull);
      expect(
        first.items.map((item) => item.id),
        orderedEquals(second.items.map((item) => item.id)),
      );
      expect(
        first.items.map((item) => item.operationalStatus).toSet(),
        FormOperationalStatus.values.toSet(),
      );
      expect(first.items.map((item) => item.identityMode).toSet(), FormIdentityMode.values.toSet());
      expect(first.items.map((item) => item.kind).toSet(), FormKind.values.toSet());
    });

    test('filters search, lifecycle, kind, institution and dates locally', () async {
      final api = DevelopmentFormsApi.seeded();

      final filtered = await api.listDirectory(
        FormDirectoryQuery(
          institutionId: DevelopmentFormsApi.institutionId,
          search: 'famílias',
          operationalStatuses: const {FormOperationalStatus.scheduled},
          kinds: const {FormKind.form},
          startsOnOrAfter: DateTime(2026, 8, 1),
          endsOnOrBefore: DateTime(2026, 8, 31, 23, 59, 59),
          limit: 100,
        ),
      );

      expect(filtered.items, isNotEmpty);
      expect(
        filtered.items,
        everyElement(
          isA<FormDirectoryItem>()
              .having((item) => item.kind, 'kind', FormKind.form)
              .having(
                (item) => item.operationalStatus,
                'operationalStatus',
                FormOperationalStatus.scheduled,
              ),
        ),
      );

      final otherInstitution = await api.listDirectory(
        const FormDirectoryQuery(institutionId: 'institution-outside-dev'),
      );
      expect(otherInstitution.items, isEmpty);
    });

    test('uses an opaque cursor without duplicates and rejects invalid cursors', () async {
      final api = DevelopmentFormsApi.seeded();
      final first = await api.listDirectory(const FormDirectoryQuery(limit: 7));
      final second = await api.listDirectory(
        FormDirectoryQuery(cursor: first.nextCursor, limit: 7),
      );

      expect(first.nextCursor, isNotNull);
      expect(second.items, hasLength(7));
      expect(
        first.items
            .map((item) => item.id)
            .toSet()
            .intersection(second.items.map((item) => item.id).toSet()),
        isEmpty,
      );

      expect(
        () => api.listDirectory(const FormDirectoryQuery(cursor: '7')),
        throwsA(
          isA<FormApiException>().having(
            (error) => error.kind,
            'kind',
            FormApiFailureKind.validation,
          ),
        ),
      );
    });
  });
}
