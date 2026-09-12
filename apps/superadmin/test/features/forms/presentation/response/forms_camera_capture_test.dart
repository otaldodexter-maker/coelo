import 'dart:async';
import 'dart:typed_data';

import 'package:coelo_api/coelo_api.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_camera_capture.dart';
import 'package:coelo_superadmin/features/forms/presentation/response/forms_camera_port.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('underlying form disposal purges camera during finalizeTree', (tester) async {
    final session = MediaSession();
    final camera = _Camera()..captureGate = Completer<Uint8List>();
    final visible = ValueNotifier<bool>(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(MaterialApp(home: ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, value, _) => value
          ? _SessionOwner(session: session, child: TextButton(
              onPressed: () => showDialog<Uint8List>(context: context,
                builder: (_) => FormsCameraCaptureDialog(session: session, createCamera: () => camera)),
              child: const Text('Open')))
          : const SizedBox.shrink(),
    )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar foto'));
    await tester.pump();
    visible.value = false;
    await tester.pump();
    expect(camera.closed, isTrue);
    expect(tester.takeException(), isNull);
    final bytes = Uint8List.fromList([1, 2, 3]);
    camera.captureGate!.complete(bytes);
    await tester.pumpAndSettle();
    expect(bytes, everyElement(0));
    expect(find.text('A sessão terminou. Abra novamente o formulário.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> open(
    WidgetTester tester,
    MediaSession session,
    FormsCameraFactory create, {
    void Function(Uint8List?)? onResult,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CoeloTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final bytes = await showDialog<Uint8List>(
                  context: context,
                  builder: (_) => FormsCameraCaptureDialog(session: session, createCamera: create),
                );
                onResult?.call(bytes);
              },
              child: const Text('Abrir câmera'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir câmera'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'camera preview and confirmation fit 375 at 200 percent and close before returning bytes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final camera = _Camera();
      Uint8List? result;
      await open(
        tester,
        MediaSession(),
        () => camera,
        textScale: 2,
        onResult: (bytes) {
          expect(camera.closed, isTrue);
          result = bytes;
        },
      );
      expect(find.byKey(const Key('camera-preview')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Usar foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usar foto'));
      await tester.pumpAndSettle();
      expect(result, [1, 2, 3]);
      expect(camera.captures, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('camera permission error closes resources and retry uses a new controller', (
    tester,
  ) async {
    final first = _Camera()..startError = true;
    final next = _Camera();
    var calls = 0;
    await open(tester, MediaSession(), () => calls++ == 0 ? first : next);
    expect(first.closed, isTrue);
    expect(find.textContaining('Confira a permissão'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('camera-preview')), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    expect(next.closed, isTrue);
    await tester.pumpAndSettle();
    expect(next.closed, isTrue);
  });

  testWidgets('cancel while permission is pending closes late camera without returning an image', (
    tester,
  ) async {
    final camera = _Camera()..startGate = Completer<void>();
    Uint8List? result;
    await open(tester, MediaSession(), () => camera, onResult: (value) => result = value);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(camera.closed, isTrue);
    camera.startGate!.complete();
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(camera.captures, 0);
    expect(tester.takeException(), isNull);
  });

  for (final reason in ['session', 'dispose']) {
    testWidgets('camera $reason closes and wipes late captured bytes', (tester) async {
      final session = MediaSession();
      final camera = _Camera()..captureGate = Completer<Uint8List>();
      Uint8List? result;
      await open(tester, session, () => camera, onResult: (value) => result = value);
      await tester.tap(find.text('Usar foto'));
      await tester.pump();
      if (reason == 'session') {
        await session.invalidate();
      } else {
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(camera.closed, isTrue);
      final bytes = Uint8List.fromList([1, 2, 3]);
      camera.captureGate!.complete(bytes);
      await tester.pumpAndSettle();
      expect(bytes, everyElement(0));
      expect(result, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('leaving the app stops the camera and requires explicit restart', (tester) async {
    final camera = _Camera();
    await open(tester, MediaSession(), () => camera);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    expect(camera.closed, isTrue);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Usar foto')).onPressed,
      isNull,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(camera.starts, 1);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('capture failure stops the camera and offers retry', (tester) async {
    final camera = _Camera()..captureError = true;
    await open(tester, MediaSession(), () => camera);
    await tester.tap(find.text('Usar foto'));
    await tester.pumpAndSettle();
    expect(camera.closed, isTrue);
    expect(find.text('Não foi possível capturar a foto. Tente novamente.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('old capture failure cannot close a replacement context camera', (tester) async {
    final first = _Camera()..captureGate = Completer<Uint8List>();
    final next = _Camera();
    Widget subject(MediaSession session, _Camera camera) => MaterialApp(
      home: Scaffold(
        body: FormsCameraCaptureDialog(session: session, createCamera: () => camera),
      ),
    );
    await tester.pumpWidget(subject(MediaSession(), first));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usar foto'));
    await tester.pump();
    await tester.pumpWidget(subject(MediaSession(), next));
    await tester.pumpAndSettle();
    first.captureGate!.completeError(StateError('obsolete synthetic capture'));
    await tester.pumpAndSettle();
    expect(first.closed, isTrue);
    expect(next.closed, isFalse);
    expect(find.byKey(const Key('camera-preview')), findsOneWidget);
    expect(find.textContaining('Não foi possível capturar'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(next.closed, isTrue);
  });
}

final class _SessionOwner extends StatefulWidget {
  const _SessionOwner({required this.session, required this.child});
  final MediaSession session;
  final Widget child;
  @override
  State<_SessionOwner> createState() => _SessionOwnerState();
}

final class _SessionOwnerState extends State<_SessionOwner> {
  @override
  void dispose() {
    unawaited(widget.session.invalidate());
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

final class _Camera implements FormsCameraPort {
  bool closed = false;
  bool startError = false;
  bool captureError = false;
  int starts = 0;
  int captures = 0;
  Completer<void>? startGate;
  Completer<Uint8List>? captureGate;

  @override
  Future<void> start() async {
    starts++;
    await startGate?.future;
    if (startError) throw StateError('synthetic private device detail');
  }

  @override
  Widget preview() => const ColoredBox(key: Key('camera-preview'), color: Colors.black);

  @override
  Future<Uint8List> capture() async {
    captures++;
    if (captureError) throw StateError('synthetic private device detail');
    return captureGate == null ? Uint8List.fromList([1, 2, 3]) : captureGate!.future;
  }

  @override
  void close() => closed = true;
}
