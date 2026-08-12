import 'dart:io';

import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:coelo_superadmin/features/audit/domain/audit.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_controller.dart';
import 'package:coelo_superadmin/features/audit/presentation/audit_directory_page.dart';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(_loadGoldenFonts);

  testWidgets('matches the required responsive light and dark matrix', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in const [
      (375.0, Brightness.light, 'mobile_light_375'),
      (768.0, Brightness.dark, 'tablet_dark_768'),
      (1024.0, Brightness.light, 'desktop_light_1024'),
      (1440.0, Brightness.dark, 'desktop_dark_1440'),
    ]) {
      tester.view.physicalSize = Size(configuration.$1, 900);
      await tester.pumpWidget(_app(configuration.$2));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('audit-directory-golden-root')),
        matchesGoldenFile('goldens/audit_directory_${configuration.$3}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('matches the canonical empty and failure states', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    for (final configuration in const [
      (_GoldenState.empty, 'empty_light_1440'),
      (_GoldenState.failure, 'failure_light_1440'),
    ]) {
      await tester.pumpWidget(
        _app(Brightness.light, repository: _GoldenAuditRepository(state: configuration.$1)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('audit-directory-golden-root')),
        matchesGoldenFile('goldens/audit_directory_${configuration.$2}.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Widget _app(Brightness brightness, {AuditRepository repository = const _GoldenAuditRepository()}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: CoeloTheme.light,
      darkTheme: CoeloTheme.dark,
      themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
      themeAnimationStyle: AnimationStyle.noAnimation,
      builder: (context, child) => RepaintBoundary(
        key: const Key('audit-directory-golden-root'),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
      home: AuditDirectoryPage(
        controller: AuditDirectoryController(repository: repository),
        activityController: SuperadminActivityController(),
        logout: unavailableSuperadminLogout,
        openDownloadUrl: (_) async => true,
      ),
    );

enum _GoldenState { content, empty, failure }

final class _GoldenAuditRepository implements AuditRepository {
  const _GoldenAuditRepository({this.state = _GoldenState.content});

  final _GoldenState state;

  @override
  Future<AuditPage> fetchPage(AuditQuery query) async {
    if (state == _GoldenState.failure) {
      throw const AuditUnavailableException();
    }
    return AuditPage(
      events: List.generate(
        state == _GoldenState.empty ? 0 : 4,
        (index) => AuditEvent(
          id: 'event-$index',
          actor: AuditActor(
            id: 'actor-$index',
            displayName: index.isEven ? 'Operadora Coelo' : 'Sistema Coelo',
            roleCode: index.isEven ? 'support' : 'system',
          ),
          institution: const AuditInstitution(id: 'institution-1', name: 'Escola Aurora'),
          actionCode: index.isEven ? 'session.denied' : 'institution.updated',
          resourceType: index.isEven ? 'session' : 'institution',
          resourceId: 'resource-$index',
          outcome: index == 0 ? AuditOutcome.denied : AuditOutcome.success,
          origin: 'edge_function',
          context: const AuditContext(kind: 'institution', id: 'institution-1'),
          occurredAt: DateTime.utc(2026, 8, 11, 12 - index),
        ),
      ),
      hasMore: false,
      totalCount: state == _GoldenState.empty ? 0 : 4,
      canExport: true,
    );
  }

  @override
  Future<AuditEventDetail> fetchDetail(String eventId) => throw UnimplementedError();

  @override
  Future<AuditExportJob> fetchExportStatus(String jobId) => throw UnimplementedError();

  @override
  Future<AuditExportJob> startExport(AuditExportRequest request) => throw UnimplementedError();
}

Future<void> _loadGoldenFonts() async {
  final nunitoSans = FontLoader('Nunito Sans')
    ..addFont(rootBundle.load('assets/brand/NunitoSans-VariableFont.ttf'));
  await nunitoSans.load();
  final flutterArtifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final materialIcons = File(
    '${flutterArtifacts.path}/material_fonts/MaterialIcons-Regular.otf',
  ).readAsBytesSync();
  final loader = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(materialIcons)));
  await loader.load();
}
