import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coelo_superadmin/features/principal_moments_publication/application/moments_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final source in ['bytes', 'url']) {
    for (final change in ['context', 'dispose', 'replace', 'denial']) {
      testWidgets('$source decoded cache is removed after $change', (tester) async {
        final decoded = await tester.runAsync(() async {
          final result = Completer<ui.Image>();
          ui.decodeImageFromPixels(
            Uint8List.fromList(List.filled(64, 255)),
            4,
            4,
            ui.PixelFormat.rgba8888,
            result.complete,
          );
          return result.future;
        });
        final media = MomentsMediaDraft(
          localId: 'synthetic',
          bytes: source == 'bytes' ? Uint8List.fromList([1, 2]) : null,
          remoteUrl: source == 'url' ? 'https://media.invalid/synthetic-ticket' : null,
        );
        final ImageProvider provider = source == 'bytes'
            ? MemoryImage(media.bytes)
            : NetworkImage(media.remoteUrl!);
        PaintingBinding.instance.imageCache.putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(Future.value(ImageInfo(image: decoded!))),
        );
        final repository = _CacheRepository(draft: MomentsDraft(media: [media]));
        final first = MomentsPublicationController(
          repository: repository,
          context: MomentsPublicationContext.demo,
        );
        final second = MomentsPublicationController(
          repository: InMemoryMomentsPublicationRepository(),
          context: MomentsPublicationContext.demo,
        );
        addTearDown(first.dispose);
        addTearDown(second.dispose);
        await tester.pumpWidget(
          MaterialApp(home: PrincipalMomentsPublicationPage(controller: first)),
        );
        await tester.pumpAndSettle();
        expect(find.byType(RawImage), findsWidgets);
        expect(PaintingBinding.instance.imageCache.statusForKey(provider).keepAlive, isTrue);
        if (change == 'replace') {
          first.removeMedia(0);
          first.addMedia(MomentsMediaDraft(localId: 'empty'));
        } else if (change == 'denial') {
          repository.denied = true;
          await first.saveDraft();
        } else {
          await tester.pumpWidget(
            MaterialApp(
              home: change == 'context'
                  ? PrincipalMomentsPublicationPage(controller: second)
                  : const SizedBox.shrink(),
            ),
          );
        }
        await tester.pumpAndSettle();
        final cached = PaintingBinding.instance.imageCache.statusForKey(provider);
        expect(cached.pending, isFalse);
        expect(cached.keepAlive, isFalse);
        expect(cached.live, isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

class _CacheRepository implements MomentsPublicationRepository {
  _CacheRepository({required MomentsDraft draft})
    : delegate = InMemoryMomentsPublicationRepository(draft: draft);
  final InMemoryMomentsPublicationRepository delegate;
  bool denied = false;
  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) => delegate.loadDraft(context);
  @override
  Future<MomentsPublication> publish(MomentsPublicationContext context, MomentsDraft draft) =>
      delegate.publish(context, draft);
  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) {
    if (denied) return Future.error(MomentsPublicationUnauthorized());
    return delegate.saveDraft(context, draft);
  }
}
