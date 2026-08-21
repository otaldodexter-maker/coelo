import 'dart:convert';

import 'package:coelo_superadmin/features/principal_happens/data/supabase_principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_feed_repository.dart';
import 'package:coelo_superadmin/features/principal_happens/domain/principal_happens_preview_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('maps only the minimal feed projection and preserves media order', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode([
          {
            'author_name': 'Equipe Coelo',
            'author_initials': 'EC',
            'context_label': '3º ano A',
            'caption': 'Registro autorizado.',
            'published_at': DateTime.now().toUtc().toIso8601String(),
            'media': [
              {'read_ticket': 'ticket-2', 'mime_type': 'video/mp4', 'display_order': 1},
              {'read_ticket': 'ticket-1', 'mime_type': 'image/jpeg', 'display_order': 0},
            ],
            'likes_count': 999,
            'liked_by_label': 'não faz parte do contrato',
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);
    final repository = SupabasePrincipalHappensFeedRepository(client);

    final posts = await repository.listVisiblePosts(
      const PrincipalHappensFeedScope(
        institutionId: 'institution-1',
        unitId: 'unit-1',
        groupId: 'group-1',
      ),
    );

    expect(requestBody, {
      'p_institution_id': 'institution-1',
      'p_unit_id': 'unit-1',
      'p_group_id': 'group-1',
      'p_limit': 20,
    });
    expect(posts.single.likes, isNull);
    expect(posts.single.likedBy, isNull);
    expect(posts.single.media.map((item) => item.readTicket), ['ticket-1', 'ticket-2']);
  });

  test('redeems a media ticket through action read without exposing storage paths', () async {
    late Map<String, dynamic> requestBody;
    final client = _client((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'signed_url': 'https://signed.example/media',
          'mime_type': 'image/jpeg',
          'expires_in': 60,
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: request,
      );
    });
    addTearDown(client.dispose);
    final repository = SupabasePrincipalHappensFeedRepository(client);

    final read = await repository.resolveMedia(
      const PrincipalHappensMediaDescriptor(
        readTicket: 'opaque-ticket',
        mimeType: 'image/jpeg',
        displayOrder: 0,
      ),
    );

    expect(requestBody, {'action': 'read', 'read_ticket': 'opaque-ticket'});
    expect(read.signedUrl, 'https://signed.example/media');
    expect(read.expiresIn, const Duration(seconds: 60));
  });
}

SupabaseClient _client(Future<http.Response> Function(http.Request request) handler) =>
    SupabaseClient('https://coelo.test', 'publishable-key', httpClient: MockClient(handler));
