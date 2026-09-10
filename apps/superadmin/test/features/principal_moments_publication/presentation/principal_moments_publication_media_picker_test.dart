import 'dart:convert';
import 'dart:typed_data';

import 'package:coelo_superadmin/features/principal_moments_publication/application/moments_publication_controller.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/domain/moments_publication.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_page.dart';
import 'package:coelo_superadmin/features/principal_moments_publication/presentation/principal_moments_publication_route.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Smallest decodable PNG, so the surface renders real selected bytes.
  final pixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );

  MomentsMediaCandidate image({
    String name = 'momento.png',
    String mimeType = 'image/png',
    Uint8List? bytes,
  }) => MomentsMediaCandidate(name: name, mimeType: mimeType, bytes: bytes ?? pixel);

  Future<void> pumpRoute(
    WidgetTester tester, {
    required MomentsPublicationRepository repository,
    required MomentsMediaPicker mediaPicker,
    Size size = const Size(768, 1024),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPublicationRoute(
          repository: repository,
          publicationContext: MomentsPublicationContext.demo,
          mediaPicker: mediaPicker,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<MomentsPublicationController> pumpPage(
    WidgetTester tester, {
    required MomentsPublicationRepository repository,
    MomentsMediaPicker? mediaPicker,
    Size size = const Size(768, 1024),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = MomentsPublicationController(
      repository: repository,
      context: MomentsPublicationContext.demo,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        home: PrincipalMomentsPublicationPage(controller: controller, mediaPicker: mediaPicker),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  Future<void> tapAddMedia(WidgetTester tester) async {
    final empty = find.byKey(const Key('moments-publication-empty-add-media'));
    final target = empty.evaluate().isEmpty
        ? find.byKey(const Key('moments-publication-add-media'))
        : empty;
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets('productive route offers media selection instead of failing closed', (tester) async {
    final repository = _SpyMomentsRepository();
    var pickerCalls = 0;
    await pumpRoute(
      tester,
      repository: repository,
      mediaPicker: () async {
        pickerCalls += 1;
        return [image()];
      },
    );

    expect(find.byKey(const Key('moments-publication-empty-media')), findsOneWidget);
    await tapAddMedia(tester);

    expect(pickerCalls, 1);
    expect(find.text('Adicionar mídia está indisponível sem a integração autorizada.'), findsNothing);
    expect(find.byKey(const Key('moments-publication-primary-media')), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('1 mídia selecionada. O envio acontece ao publicar.'), findsOneWidget);
    expect(repository.saveCalls, 0);
    expect(repository.publishCalls, 0);
  });

  testWidgets('valid selection reaches the controller with its bytes and mime type', (
    tester,
  ) async {
    final repository = _SpyMomentsRepository();
    final controller = await pumpPage(
      tester,
      repository: repository,
      mediaPicker: () async => [image(name: 'passeio.webp', mimeType: 'image/webp')],
    );

    await tapAddMedia(tester);

    expect(controller.state.draft.media, hasLength(1));
    final media = controller.state.draft.media.single;
    expect(media.name, 'passeio.webp');
    expect(media.mimeType, 'image/webp');
    expect(media.bytes.lengthInBytes, pixel.lengthInBytes);
    expect(media.remoteAssetId, isNull, reason: 'upload only happens server-side at publish');
    expect(repository.saveCalls, 0);
    expect(repository.publishCalls, 0);
  });

  testWidgets('refuses an unsupported type without touching the backend', (tester) async {
    final repository = _SpyMomentsRepository();
    final controller = await pumpPage(
      tester,
      repository: repository,
      mediaPicker: () async => [image(name: 'circular.pdf', mimeType: 'application/pdf')],
    );

    await tapAddMedia(tester);

    expect(controller.state.draft.media, isEmpty);
    expect(find.text('Formato não aceito. Use JPG, PNG ou WEBP.'), findsOneWidget);
    expect(repository.saveCalls, 0);
    expect(repository.publishCalls, 0);
  });

  testWidgets('refuses a file above the media byte limit', (tester) async {
    final repository = _SpyMomentsRepository();
    final controller = await pumpPage(
      tester,
      repository: repository,
      mediaPicker: () async => [
        image(bytes: Uint8List(MomentsMediaLimits.maxBytes + 1)),
      ],
    );

    await tapAddMedia(tester);

    expect(controller.state.draft.media, isEmpty);
    expect(
      find.text('Cada arquivo deve ter até ${MomentsMediaLimits.maxMegabytes} MB.'),
      findsOneWidget,
    );
    expect(repository.publishCalls, 0);
  });

  testWidgets('refuses the sixth media without opening the selection', (tester) async {
    final repository = _SpyMomentsRepository(
      draft: MomentsDraft(media: List.generate(MomentsMediaLimits.maxItems, MomentsMediaDraft.demo)),
    );
    var pickerCalls = 0;
    final controller = await pumpPage(
      tester,
      repository: repository,
      mediaPicker: () async {
        pickerCalls += 1;
        return [image()];
      },
    );

    await tapAddMedia(tester);

    expect(pickerCalls, 0);
    expect(controller.state.draft.media, hasLength(MomentsMediaLimits.maxItems));
    expect(
      find.text('Você pode adicionar até ${MomentsMediaLimits.maxItems} mídias.'),
      findsOneWidget,
    );
  });

  testWidgets('accepts what fits and reports the media refused by the quantity limit', (
    tester,
  ) async {
    final repository = _SpyMomentsRepository(
      draft: MomentsDraft(
        media: List.generate(MomentsMediaLimits.maxItems - 1, MomentsMediaDraft.demo),
      ),
    );
    final controller = await pumpPage(
      tester,
      repository: repository,
      mediaPicker: () async => [image(name: 'a.png'), image(name: 'b.png')],
    );

    await tapAddMedia(tester);

    expect(controller.state.draft.media, hasLength(MomentsMediaLimits.maxItems));
    expect(
      find.text(
        '1 mídia selecionada. Você pode adicionar até ${MomentsMediaLimits.maxItems} mídias.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reports an honest failure when the selection cannot be opened', (tester) async {
    final repository = _SpyMomentsRepository();
    final controller = await pumpPage(
      tester,
      repository: repository,
      mediaPicker: () async => throw StateError('picker_unavailable'),
    );

    await tapAddMedia(tester);

    expect(controller.state.draft.media, isEmpty);
    expect(find.text('Não foi possível abrir seus arquivos. Tente novamente.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the honest unavailability when no selection port is injected', (tester) async {
    final repository = _SpyMomentsRepository();
    final controller = await pumpPage(tester, repository: repository);

    await tapAddMedia(tester);

    expect(controller.state.draft.media, isEmpty);
    expect(
      find.text('Adicionar mídia está indisponível sem a integração autorizada.'),
      findsOneWidget,
    );
  });
}

final class _SpyMomentsRepository implements MomentsPublicationRepository {
  _SpyMomentsRepository({this.draft});

  final MomentsDraft? draft;
  var saveCalls = 0;
  var publishCalls = 0;

  @override
  Future<MomentsDraft?> loadDraft(MomentsPublicationContext context) async => draft;

  @override
  Future<MomentsDraft> saveDraft(MomentsPublicationContext context, MomentsDraft draft) async {
    saveCalls += 1;
    return draft.copyWith(id: 'moment-draft-1', version: draft.version + 1);
  }

  @override
  Future<MomentsPublication> publish(
    MomentsPublicationContext context,
    MomentsDraft draft,
  ) async {
    publishCalls += 1;
    return const MomentsPublication(id: 'moment-publication-1', status: MomentsStatus.published);
  }
}
