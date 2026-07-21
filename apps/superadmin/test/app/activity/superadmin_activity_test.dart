import 'package:coelo_superadmin/app/activity/superadmin_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('simulates an import through the approved progress steps', () async {
    final controller = SuperadminActivityController(tickInterval: const Duration(milliseconds: 1));
    addTearDown(controller.dispose);

    controller.startDemoImport();

    expect(controller.activities, hasLength(1));
    expect(controller.activities.single.progress, 0);
    expect(controller.activities.single.status, SuperadminActivityStatus.inProgress);
    expect(controller.unreadCount, 0);

    await Future<void>.delayed(const Duration(milliseconds: 12));

    final activity = controller.activities.single;
    expect(activity.progress, 100);
    expect(activity.status, SuperadminActivityStatus.partial);
    expect(activity.summary, '24 importadas, 2 rejeitadas');
    expect(controller.unreadCount, 1);
  });

  test('keeps completions read while the activity center is open', () async {
    final controller = SuperadminActivityController(tickInterval: const Duration(milliseconds: 1));
    addTearDown(controller.dispose);

    controller
      ..setCenterOpen(true)
      ..startDemoImport();
    await Future<void>.delayed(const Duration(milliseconds: 12));

    expect(controller.activities.single.isRead, isTrue);
    expect(controller.unreadCount, 0);
  });

  test('opening the center marks existing completed activities as read', () {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);

    controller.completeDemoExport(SuperadminExportFormat.csv);
    expect(controller.unreadCount, 1);

    controller.setCenterOpen(true);

    expect(controller.unreadCount, 0);
    expect(controller.activities.single.isRead, isTrue);
  });

  test('creates completed export activities with their selected format', () {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);

    controller.completeDemoExport(SuperadminExportFormat.xlsx);

    final activity = controller.activities.single;
    expect(activity.kind, SuperadminActivityKind.export);
    expect(activity.status, SuperadminActivityStatus.succeeded);
    expect(activity.fileName, 'instituicoes.xlsx');
    expect(activity.subject, 'Instituições');
  });

  test('uses the injected clock for completed exports', () {
    final now = DateTime(2026, 7, 21, 14, 35);
    final controller = SuperadminActivityController(now: () => now);
    addTearDown(controller.dispose);

    controller.completeDemoExport(SuperadminExportFormat.xlsx);

    expect(controller.activities.single.createdAt, now);
  });

  test('uses the injected clock for started imports', () {
    final now = DateTime(2026, 7, 21, 14, 35);
    final controller = SuperadminActivityController(now: () => now);
    addTearDown(controller.dispose);

    controller.startDemoImport();

    expect(controller.activities.single.createdAt, now);
  });

  test('exposes activities as an unmodifiable list', () {
    final controller = SuperadminActivityController();
    addTearDown(controller.dispose);

    expect(
      () => controller.activities.add(
        SuperadminActivity.announcement(
          id: 'announcement',
          subject: 'Novidade no Superadmin',
          summary: 'Uma nova função está disponível.',
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('creates a stable seeded controller for previews', () {
    final controller = SuperadminActivityController.seeded([
      SuperadminActivity.announcement(
        id: 'announcement',
        subject: 'Novidade no Superadmin',
        summary: 'Uma nova função está disponível.',
      ),
    ]);
    addTearDown(controller.dispose);

    expect(controller.activities.single.kind, SuperadminActivityKind.announcement);
    expect(controller.unreadCount, 1);
  });

  test('keeps an injectable clock available on seeded controllers', () {
    final now = DateTime(2026, 7, 21, 14, 35);
    final controller = SuperadminActivityController.seeded([], now: () => now);
    addTearDown(controller.dispose);

    controller.completeDemoExport(SuperadminExportFormat.csv);

    expect(controller.activities.single.createdAt, now);
  });
}
