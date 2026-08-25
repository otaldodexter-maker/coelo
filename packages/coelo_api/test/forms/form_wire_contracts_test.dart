import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  test('cursor is opaque base64url without padding and round-trips its key and id', () {
    const codec = FormCursorCodec();
    final cursor = codec.encode(
      const FormCursor(sortKey: '2026-08-13T12:30:00.000Z', id: 'response-42'),
    );

    expect(cursor, isNot(contains('=')));
    expect(cursor, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    expect(
      codec.decode(cursor),
      const FormCursor(sortKey: '2026-08-13T12:30:00.000Z', id: 'response-42'),
    );
    expect(() => codec.decode('not-a-valid-cursor'), throwsA(isA<WireFormatException>()));
  });

  test('typed command round-trips and rejects unknown envelope keys', () {
    final command = FormCommand<Map<String, Object?>>(
      requestId: 'request-1',
      expectedVersion: 4,
      payload: const {'title': 'Ficha'},
    );
    final json = command.toJson((payload) => payload);
    final decoded = FormCommand.fromJson(json, (payload) => payload);

    expect(decoded.requestId, 'request-1');
    expect(decoded.expectedVersion, 4);
    expect(decoded.payload, {'title': 'Ficha'});
    expect(
      () => FormCommand.fromJson({...json, 'actor_id': 'forged'}, (payload) => payload),
      throwsA(isA<WireFormatException>()),
    );
  });

  test('cursor page is immutable and never exposes offset', () {
    final source = ['one'];
    final page = FormCursorPage(items: source, nextCursor: 'next');
    source.add('two');

    expect(page.items, ['one']);
    expect(page.nextCursor, 'next');
  });

  test('directory query round-trips filters without an offset field', () {
    const query = FormDirectoryQuery(
      institutionId: '00000000-0000-4000-8000-000000000001',
      search: 'saúde',
      statuses: {FormStatus.published},
      operationalStatuses: {FormOperationalStatus.scheduled},
      kinds: {FormKind.form, FormKind.quickPoll},
      cursor: 'opaque',
      limit: 50,
    );
    final json = FormDirectoryQueryDto.fromDomain(query).toJson();
    final decoded = FormDirectoryQueryDto.fromJson(json).toDomain();

    expect(decoded.search, 'saúde');
    expect(decoded.statuses, {FormStatus.published});
    expect(decoded.operationalStatuses, {FormOperationalStatus.scheduled});
    expect(decoded.kinds, {FormKind.form, FormKind.quickPoll});
    expect(json['operational_statuses'], ['scheduled']);
    expect(json, isNot(contains('offset')));
    expect(
      () => FormDirectoryQueryDto.fromJson({...json, 'offset': 1000}),
      throwsA(isA<WireFormatException>()),
    );
  });

  test('RPC catalog remains synchronized with the approved backend contract', () {
    expect(FormsRpc.values.map((rpc) => rpc.functionName), {
      'form_list',
      'form_get_overview',
      'form_get_editor',
      'form_list_audience_candidates',
      'form_get_occurrence_for_response',
      'form_get_monitor',
      'form_list_monitor_hierarchy',
      'form_list_monitor_people',
      'form_list_responses',
      'form_get_response_detail',
      'form_list_file_jobs',
      'form_save_draft',
      'form_publish',
      'form_duplicate',
      'form_copy_or_move',
      'form_archive_or_delete',
      'form_save_application',
      'form_save_schedule',
      'form_remove_schedule',
      'form_open_response_draft',
      'form_save_response_draft',
      'form_submit_response',
      'form_edit_response',
      'form_prepare_asset_upload',
      'form_finalize_asset_upload',
      'form_discard_asset',
      'form_request_export',
      'form_anonymous_participation_lookup',
      'form_request_anonymous_participation_export',
    });
  });
}
