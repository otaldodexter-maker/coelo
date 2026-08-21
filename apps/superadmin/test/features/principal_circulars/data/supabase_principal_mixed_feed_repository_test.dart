import 'dart:convert';

import 'package:coelo_superadmin/features/principal_circulars/data/supabase_principal_mixed_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/principal_happens_mixed_feed.dart';
import 'package:coelo_superadmin/features/principal_circulars/domain/circular_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps a heterogeneous authorized feed without duplicating Circular content', () async {
    final client = SupabaseClient(
      'https://coelo.test',
      'publishable-key',
      httpClient: MockClient(
        (request) async => http.Response(
          jsonEncode([
            {
              'item_type': 'post',
              'item_id': 'post-1',
              'effective_published_at': '2026-08-21T12:00:00Z',
              'payload': {
                'author_name': 'Professor',
                'context_label': 'Turma',
                'caption': 'Acontece',
                'media': [
                  {'read_ticket': 'ticket-2', 'mime_type': 'video/mp4', 'display_order': 1},
                  {'read_ticket': 'ticket-1', 'mime_type': 'image/jpeg', 'display_order': 0},
                ],
              },
            },
            {
              'item_type': 'circular',
              'item_id': 'circular-1',
              'effective_published_at': '2026-08-21T11:00:00Z',
              'payload': {
                'author_name': 'Colégio',
                'context_label': 'Instituição',
                'title': 'Circular',
                'excerpt': 'Resumo',
                'attachment_count': 0,
                'question_count': 1,
                'response_state': 'unanswered',
              },
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        ),
      ),
    );
    addTearDown(client.dispose);

    final page = await SupabasePrincipalMixedFeedRepository(
      client,
    ).list(const CircularScope(institutionId: 'institution-1'), limit: 2);

    final post = page.items.first as PrincipalHappensPostItem;
    expect(post.media.map((item) => item.readTicket), ['ticket-1', 'ticket-2']);
    expect(page.items.last, isA<PrincipalHappensCircularItem>());
    expect(page.nextCursor?.itemType, 'circular');
  });
}
