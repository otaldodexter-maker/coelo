import 'dart:async';
import 'dart:io';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/groups/domain/group_detail.dart';
import 'package:coelo_superadmin/features/groups/presentation/group_detail_page.dart';
import 'package:coelo_superadmin/features/units/domain/unit_detail.dart';
import 'package:coelo_superadmin/features/units/presentation/unit_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
  for (final entity in ['unit', 'group']) {
    for (final width in [375.0, 1440.0]) {
      testWidgets('$entity approved D01 new baseline $width ready focus reload', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final unitRepository = _Units();
        final groupRepository = _Groups();
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: CoeloTheme.light,
            darkTheme: CoeloTheme.dark,
            themeMode: width == 375 ? ThemeMode.light : ThemeMode.dark,
            themeAnimationStyle: AnimationStyle.noAnimation,
            builder: (context, child) => RepaintBoundary(
              key: const Key('detail-golden-root'),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
            ),
            home: entity == 'unit'
                ? UnitDetailPage(
                    repository: unitRepository,
                    id: 'unit',
                    logout: _logout,
                    onBack: () {},
                    onDestinationSelected: (_) {},
                  )
                : GroupDetailPage(
                    repository: groupRepository,
                    id: 'group',
                    logout: _logout,
                    onBack: () {},
                    onDestinationSelected: (_) {},
                  ),
          ),
        );
        await tester.pumpAndSettle();
        final prefix = 'goldens/${entity}_detail_${width == 375 ? 'light_375' : 'dark_1440'}';
        await expectLater(
          find.byKey(const Key('detail-golden-root')),
          matchesGoldenFile('${prefix}_ready.png'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        Focus.of(tester.element(find.text('Recarregar'))).requestFocus();
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('detail-golden-root')),
          matchesGoldenFile('${prefix}_focus.png'),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byKey(Key('$entity-detail-loading')), findsOneWidget);
        expect(
          tester.widget<OutlinedButton>(find.byKey(Key('$entity-detail-reload'))).onPressed,
          isNull,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(entity == 'unit' ? 'Unidade Aurora' : 'Turma Girassol'), findsNothing);
        expect(entity == 'unit' ? unitRepository.calls : groupRepository.calls, 2);
        await expectLater(
          find.byKey(const Key('detail-golden-root')),
          matchesGoldenFile('${prefix}_reload.png'),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<LogoutResult> _logout() async => const LogoutResult.success();

class _Units implements UnitDetailRepository {
  var calls = 0;
  @override
  Future<UnitDetail> fetchById(String id) async {
    if (++calls > 1) return Completer<UnitDetail>().future;
    return UnitDetail(
      id: id,
      name: 'Unidade Aurora',
      slug: 'aurora',
      status: 'active',
      institutionId: 'institution',
      institutionName: 'Instituição Horizonte',
      institutionType: const UnitDetailType(id: 'type', name: 'Educação'),
      unitType: const UnitDetailType(id: 'unit-type', name: 'Escola'),
      address: null,
      contact: null,
      effectivePlan: null,
    );
  }
}

class _Groups implements GroupDetailRepository {
  var calls = 0;
  @override
  Future<GroupDetail> fetchById(String id) async {
    if (++calls > 1) return Completer<GroupDetail>().future;
    return GroupDetail(
      id: id,
      institutionId: 'institution',
      institutionName: 'Instituição Horizonte',
      unitId: 'unit',
      unitName: 'Unidade Aurora',
      name: 'Turma Girassol',
      groupType: 'class',
      groupTypeOtherText: null,
      status: 'active',
      inheritAppearance: true,
      inheritAccess: true,
      inheritActivities: false,
      managementVersion: 1,
      createdAt: DateTime.utc(2026, 9, 7),
      updatedAt: DateTime.utc(2026, 9, 7),
    );
  }
}
