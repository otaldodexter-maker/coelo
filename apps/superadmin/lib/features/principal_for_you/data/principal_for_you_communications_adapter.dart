import '../../notices/domain/platform_notice.dart';
import '../domain/principal_for_you_preview_data.dart';

/// Projects the shared Communications contract into the read-only Principal hub.
///
/// Popup-only fields deliberately do not cross this boundary.
final class PrincipalForYouCommunicationsAdapter {
  const PrincipalForYouCommunicationsAdapter._();

  static List<PrincipalForYouHighlight> highlights(
    Iterable<PlatformNotice> communications, {
    required DateTime now,
  }) => PrincipalForYouPreviewData.orderHighlights(
    communications
        .where((item) => item.type != CommunicationType.notice)
        .map(
          (item) => PrincipalForYouHighlight(
            id: item.id,
            type: _type(item.type),
            priority: _priority(item.priority),
            eligible:
                item.status == NoticeStatus.active &&
                !item.startsAt.isAfter(now) &&
                (item.endsAt == null || item.endsAt!.isAfter(now)),
            title: item.title,
            body: item.message,
            cta: item.linkLabel ?? item.buttonLabel,
            assetPath: 'assets/principal_happens/now-strip.png',
            assetIndex: 2,
          ),
        ),
  );

  static PrincipalForYouContentType _type(CommunicationType type) => switch (type) {
    CommunicationType.highlight => PrincipalForYouContentType.highlight,
    CommunicationType.content => PrincipalForYouContentType.content,
    CommunicationType.forYou => PrincipalForYouContentType.forYou,
    CommunicationType.notice => throw ArgumentError.value(type, 'type'),
  };

  static int _priority(NoticePriority priority) => switch (priority) {
    NoticePriority.urgent => 0,
    NoticePriority.important => 10,
    NoticePriority.routine => 20,
  };
}
