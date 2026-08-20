import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/principal_for_you/data/principal_for_you_communications_adapter.dart';
import 'package:coelo_superadmin/features/principal_for_you/domain/principal_for_you_preview_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20, 12);

  PlatformNotice communication({
    required CommunicationType type,
    NoticePriority priority = NoticePriority.routine,
    NoticeStatus status = NoticeStatus.active,
    DateTime? endsAt,
  }) => PlatformNotice(
    type: type,
    id: type.name,
    title: 'Conteúdo útil',
    message: 'Orientação para a família.',
    priority: priority,
    status: status,
    startsAt: now.subtract(const Duration(hours: 1)),
    endsAt: endsAt ?? now.add(const Duration(hours: 1)),
    audience: NoticeAudience.everyone,
    audienceLabel: 'Todos',
    behavior: NoticeBehavior.dismissible,
    targetDevice: NoticeTargetDevice.all,
    reach: 1,
    linkLabel: 'Saiba mais',
  );

  test('projects eligible communications and excludes popup notices', () {
    final highlights = PrincipalForYouCommunicationsAdapter.highlights([
      communication(type: CommunicationType.notice, priority: NoticePriority.urgent),
      communication(type: CommunicationType.forYou, priority: NoticePriority.important),
      communication(type: CommunicationType.highlight, priority: NoticePriority.urgent),
    ], now: now);

    expect(highlights, hasLength(2));
    expect(highlights.first.type, PrincipalForYouContentType.highlight);
    expect(highlights.last.type, PrincipalForYouContentType.forYou);
    expect(highlights.every((item) => item.eligible), isTrue);
  });

  test('keeps expired or inactive communications ineligible', () {
    final highlights = PrincipalForYouCommunicationsAdapter.highlights([
      communication(type: CommunicationType.content, endsAt: now),
      communication(type: CommunicationType.forYou, status: NoticeStatus.paused),
    ], now: now);

    expect(highlights.every((item) => !item.eligible), isTrue);
  });

  test('does not project popup-only behavior into the Principal model', () {
    final item = PrincipalForYouCommunicationsAdapter.highlights([
      communication(type: CommunicationType.forYou),
    ], now: now).single;

    expect(item.cta, 'Saiba mais');
    expect(item.type, PrincipalForYouContentType.forYou);
  });
}
