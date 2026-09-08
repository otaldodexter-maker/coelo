import 'dart:async';
import 'dart:convert';

import 'package:coelo_superadmin/features/meal_plans/data/supabase_meal_plan_repository.dart';
import 'package:coelo_superadmin/features/meal_plans/domain/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('failed publication is reported without an automatic command retry', () async {
    var calls = 0;
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((_) async {
        calls++;
        throw ClientException('private transport detail');
      }),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseMealPlanRepository(client).publish('plan', 'intent', 1),
      throwsA(isA<MealPlanUnavailableException>()),
    );
    expect(calls, 1);
  });
  test('Auth exception remains unauthorized without exposing details', () async {
    final client = SupabaseClient(
      'https://example.supabase.co',
      'publishable-key',
      httpClient: MockClient((_) async => throw const AuthException('private auth detail')),
    );
    addTearDown(client.dispose);
    await expectLater(
      SupabaseMealPlanRepository(client).fetchAudienceOptions(),
      throwsA(isA<MealPlanUnauthorizedException>()),
    );
  });
  for (final failure in [
    ClientException('private transport detail'),
    TimeoutException('private timeout'),
  ]) {
    test('transport ${failure.runtimeType} becomes a safe domain failure', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient((_) async => throw failure),
      );
      addTearDown(client.dispose);
      final repository = SupabaseMealPlanRepository(client);
      await expectLater(
        repository.fetchTemplatePage(const MealPlanListFilter()),
        throwsA(
          isA<MealPlanUnavailableException>().having(
            (e) => e.message,
            'safe message',
            const MealPlanUnavailableException().message,
          ),
        ),
      );
    });
  }
  for (final code in ['42501', 'PGRST301']) {
    test('authorization code $code stays unauthorized', () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'publishable-key',
        httpClient: MockClient(
          (request) async => Response(
            jsonEncode({'code': code, 'message': 'private authorization detail'}),
            403,
            headers: {'content-type': 'application/json'},
            request: request,
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        SupabaseMealPlanRepository(client).fetchPage(const MealPlanListFilter()),
        throwsA(isA<MealPlanUnauthorizedException>()),
      );
    });
  }
}
