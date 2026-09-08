import 'dart:async';
import 'dart:io';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/domain/person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/presentation/person_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = '11111111-1111-4111-8111-111111111111';
void main() {
  setUpAll(() async {
    await (FontLoader(
      'Nunito Sans',
    )..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'))).load();
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final bytes = File(
      '${artifacts.path}/material_fonts/MaterialIcons-Regular.otf',
    ).readAsBytesSync();
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });
  for (final width in [375.0, 1440.0]) {
    testWidgets('PERS-READ01 candidate $width identity context focus loading denied unavailable', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final reader = _Reader();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: CoeloTheme.light,
          darkTheme: CoeloTheme.dark,
          themeMode: width == 375 ? ThemeMode.light : ThemeMode.dark,
          themeAnimationStyle: AnimationStyle.noAnimation,
          builder: (context, child) => RepaintBoundary(
            key: const Key('person-detail-golden-root'),
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
          home: PersonDetailPage(
            reader: reader,
            id: _id,
            logout: () async => const LogoutResult.success(),
            onBack: () {},
            onDestinationSelected: (_) {},
          ),
        ),
      );
      reader.calls.single.complete(_person);
      await tester.pumpAndSettle();
      final prefix = 'goldens/person_detail_${width == 375 ? 'light_375' : 'dark_1440'}';
      Future<void> capture(String state) => expectLater(
        find.byKey(const Key('person-detail-golden-root')),
        matchesGoldenFile('${prefix}_$state.png'),
      );
      await capture('identity');
      await tester.drag(find.byKey(const Key('person-detail-content')), const Offset(0, -850));
      await tester.pumpAndSettle();
      expect(find.text('Instituição Horizonte'), findsOneWidget);
      await capture('context');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      Focus.of(tester.element(find.text('Recarregar'))).requestFocus();
      await tester.pumpAndSettle();
      await capture('focus');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('person-detail-loading')), findsOneWidget);
      expect(find.text('Pessoa sintética'), findsNothing);
      expect(reader.calls, hasLength(2));
      await capture('loading');
      reader.calls.last.completeError(const PersonDirectoryUnauthorizedException());
      await tester.pumpAndSettle();
      await capture('denied');
      await tester.tap(find.byKey(const Key('person-detail-reload')));
      reader.calls.last.completeError(const PersonDirectoryUnavailableException());
      await tester.pumpAndSettle();
      await capture('unavailable');
      expect(tester.takeException(), isNull);
    });
  }
}

class _Reader implements PersonDetailReader {
  final calls = <Completer<PersonDirectoryItem>>[];
  @override
  Future<PersonDirectoryItem> fetchDetail(String id) {
    final call = Completer<PersonDirectoryItem>();
    calls.add(call);
    return call.future;
  }
}

final _person = PersonDirectoryItem(
  id: _id,
  displayName: 'Pessoa sintética',
  firstName: 'Pessoa',
  lastName: 'Sintética',
  type: PersonType.child,
  status: PersonStatus.active,
  childContexts: const [
    PersonChildContext(
      id: 'context',
      institutionId: 'institution',
      institutionName: 'Instituição Horizonte',
      unitName: 'Unidade Aurora',
      groupName: 'Turma Girassol',
    ),
  ],
  updatedAt: DateTime.utc(2026, 9, 7),
);
