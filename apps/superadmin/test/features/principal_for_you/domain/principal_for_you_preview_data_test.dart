import 'package:coelo_superadmin/features/principal_for_you/domain/principal_for_you_preview_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects the first eligible highlight from the supplied order', () {
    final data = PrincipalForYouPreviewData.demo;

    expect(data.primaryHighlight?.title, 'Feira Cultural hoje!');
    expect(data.primaryHighlight?.type, PrincipalForYouContentType.highlight);
  });

  test('returns no primary highlight when every item is ineligible', () {
    final data = PrincipalForYouPreviewData.demo.copyWith(
      highlights: PrincipalForYouPreviewData.demo.highlights
          .map((item) => item.copyWith(eligible: false))
          .toList(growable: false),
    );

    expect(data.primaryHighlight, isNull);
  });

  test('orders highlights outside the presentation by priority', () {
    final highlights = PrincipalForYouPreviewData.orderHighlights([
      PrincipalForYouPreviewData.demo.highlights.first.copyWith(priority: 30),
      PrincipalForYouPreviewData.demo.highlights.last.copyWith(priority: 10),
    ]);

    expect(highlights.first.priority, 10);
    expect(highlights.last.priority, 30);
    expect(() => highlights.add(highlights.first), throwsUnsupportedError);
  });
}
