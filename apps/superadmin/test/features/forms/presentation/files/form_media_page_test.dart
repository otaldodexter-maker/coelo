import 'package:coelo_superadmin/features/forms/data/form_media_resolver.dart';
import 'package:coelo_superadmin/features/forms/presentation/files/form_media_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders only the reauthorized short-lived media', (tester) async {
    Uri? rendered;
    await tester.pumpWidget(
      MaterialApp(
        home: FormMediaPage(
          assetId: 'asset-1',
          resolve: ({required assetId, editSecret}) async => FormMediaDownloadTicket(
            signedUrl: Uri.parse('https://storage.example.test/opaque?token=short-lived'),
            expiresAt: DateTime.now().add(const Duration(minutes: 1)),
          ),
          imageBuilder: (context, url) {
            rendered = url;
            return const SizedBox(key: ValueKey('authorized-image'));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('authorized-image')), findsOneWidget);
    expect(rendered?.queryParameters['token'], 'short-lived');
  });

  testWidgets('fails closed when media authorization is denied', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FormMediaPage(
          assetId: 'asset-1',
          resolve: ({required assetId, editSecret}) async =>
              throw const FormMediaResolutionException('Mídia indisponível.'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mídia indisponível'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
