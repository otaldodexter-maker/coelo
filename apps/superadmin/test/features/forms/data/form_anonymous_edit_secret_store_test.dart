import 'package:coelo_superadmin/features/forms/data/form_anonymous_edit_secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('generates 32-byte base64url secrets and stores them only by response id', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesFormAnonymousEditSecretStore(preferences);
    final first = store.generate();
    final second = store.generate();

    expect(first, hasLength(43));
    expect(first, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(second, isNot(first));

    await store.save(responseId: 'response-1', secret: first);
    expect(await store.read('response-1'), first);
    expect(preferences.getKeys(), {'coelo.forms.anonymous-edit-secret.response-1'});

    await store.bindOccurrence(occurrenceId: 'occurrence-1', responseId: 'response-1');
    expect(await store.responseIdForOccurrence('occurrence-1'), 'response-1');
    expect(preferences.getString('coelo.forms.anonymous-response.occurrence-1'), 'response-1');

    await store.remove('response-1');
    expect(await store.read('response-1'), isNull);
  });

  test('rejects malformed secrets instead of persisting recoverable aliases', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = SharedPreferencesFormAnonymousEditSecretStore(preferences);

    expect(() => store.save(responseId: 'response-1', secret: 'short'), throwsFormatException);
    expect(preferences.getKeys(), isEmpty);
  });
}
