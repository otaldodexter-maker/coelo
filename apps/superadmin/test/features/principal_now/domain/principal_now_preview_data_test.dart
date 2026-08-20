import 'package:coelo_superadmin/features/principal_now/domain/principal_now_preview_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo stories provide a safe five-second institutional sequence', () {
    final data = PrincipalNowPreviewData.demo;

    expect(data.stories, hasLength(5));
    expect(data.stories.every((story) => story.duration == const Duration(seconds: 5)), isTrue);
    expect(data.stories.every((story) => story.author.isNotEmpty), isTrue);
    expect(
      data.stories.every((story) => story.assetPath.startsWith('assets/principal_now/')),
      isTrue,
    );
  });
}
