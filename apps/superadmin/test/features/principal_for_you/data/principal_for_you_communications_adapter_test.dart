import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:coelo_superadmin/features/principal_for_you/data/principal_for_you_communications_adapter.dart';
import 'package:coelo_superadmin/features/principal_for_you/domain/principal_for_you_preview_data.dart';
import 'package:coelo_superadmin/features/principal_shared/domain/principal_runtime_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 8, 20, 12);

  PlatformNotice communication({
    required CommunicationType type,
    NoticePriority priority = NoticePriority.routine,
    NoticeStatus status = NoticeStatus.active,
    DateTime? startsAt,
    DateTime? endsAt,
    NoticeAudience audience = NoticeAudience.everyone,
    NoticeAudienceSelection audienceSelection = const NoticeAudienceSelection(),
    String? id,
  }) => PlatformNotice(
    type: type,
    id: id ?? type.name,
    title: 'Conteúdo útil',
    message: 'Orientação para a família.',
    priority: priority,
    status: status,
    startsAt: startsAt ?? now.subtract(const Duration(hours: 1)),
    endsAt: endsAt ?? now.add(const Duration(hours: 1)),
    audience: audience,
    audienceLabel: 'Todos',
    audienceSelection: audienceSelection,
    behavior: NoticeBehavior.dismissible,
    targetDevice: NoticeTargetDevice.all,
    reach: 1,
    linkLabel: 'Saiba mais',
  );

  const scope = PrincipalForYouAudienceScope(
    institutionId: 'inst-1',
    unitId: 'unit-1',
    groupId: 'group-1',
    personId: 'person-1',
    roleCode: 'guardian',
    membershipId: 'membership-1',
  );

  bool eligibleFor(PlatformNotice item, {PrincipalForYouAudienceScope? actor = scope}) =>
      PrincipalForYouCommunicationsAdapter.highlights([
        item,
      ], now: now, scope: actor).single.eligible;

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

  test('never projects popup communications even with an actor scope', () {
    final highlights = PrincipalForYouCommunicationsAdapter.highlights([
      communication(type: CommunicationType.notice),
    ], now: now, scope: scope);

    expect(highlights, isEmpty);
  });

  test('keeps expired or inactive communications ineligible', () {
    final highlights = PrincipalForYouCommunicationsAdapter.highlights([
      communication(type: CommunicationType.content, endsAt: now),
      communication(type: CommunicationType.forYou, status: NoticeStatus.paused),
    ], now: now);

    expect(highlights.every((item) => !item.eligible), isTrue);
  });

  test('keeps communications ineligible before the validity window', () {
    final item = communication(
      type: CommunicationType.content,
      startsAt: now.add(const Duration(minutes: 1)),
    );

    expect(eligibleFor(item), isFalse);
  });

  test('keeps communications eligible when there is no end date', () {
    final item = communication(
      type: CommunicationType.content,
      endsAt: now.subtract(const Duration(days: 1)),
    ).copyWith(clearEndsAt: true);

    expect(eligibleFor(item), isTrue);
  });

  test('does not project popup-only behavior into the Principal model', () {
    final item = PrincipalForYouCommunicationsAdapter.highlights([
      communication(type: CommunicationType.forYou),
    ], now: now).single;

    expect(item.cta, 'Saiba mais');
    expect(item.type, PrincipalForYouContentType.forYou);
  });

  group('audiência', () {
    test('everyone e platform selectAll alcançam qualquer ator', () {
      expect(eligibleFor(communication(type: CommunicationType.content)), isTrue);
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audienceSelection: const NoticeAudienceSelection(
              rules: [NoticeAudienceRule(dimension: NoticeAudienceDimension.platform, selectAll: true)],
            ),
          ),
        ),
        isTrue,
      );
    });

    test('instituição correspondente e não correspondente', () {
      NoticeAudienceSelection institution(String id) => NoticeAudienceSelection(
        rules: [
          NoticeAudienceRule(
            dimension: NoticeAudienceDimension.institution,
            targetIds: [id],
          ),
        ],
      );

      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audience: NoticeAudience.institution,
            audienceSelection: institution('inst-1'),
          ),
        ),
        isTrue,
      );
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audience: NoticeAudience.institution,
            audienceSelection: institution('inst-2'),
          ),
        ),
        isFalse,
      );
    });

    test('unidade e turma respeitam o escopo do ator', () {
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audience: NoticeAudience.unit,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(
                  dimension: NoticeAudienceDimension.unit,
                  targetIds: ['unit-1'],
                ),
              ],
            ),
          ),
        ),
        isTrue,
      );
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audience: NoticeAudience.unit,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(
                  dimension: NoticeAudienceDimension.unit,
                  targetIds: ['unit-9'],
                ),
              ],
            ),
          ),
        ),
        isFalse,
      );
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audience: NoticeAudience.group,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(
                  dimension: NoticeAudienceDimension.group,
                  targetIds: ['group-1'],
                ),
              ],
            ),
          ),
        ),
        isTrue,
      );
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audience: NoticeAudience.group,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(
                  dimension: NoticeAudienceDimension.group,
                  targetIds: ['group-2'],
                ),
              ],
            ),
          ),
        ),
        isFalse,
      );
    });

    test('pessoa e papel alcançam apenas o ator correspondente', () {
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.forYou,
            audience: NoticeAudience.person,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(
                  dimension: NoticeAudienceDimension.person,
                  targetIds: ['person-1'],
                ),
              ],
            ),
          ),
        ),
        isTrue,
      );
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.forYou,
            audience: NoticeAudience.role,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(dimension: NoticeAudienceDimension.platform, selectAll: true),
              ],
              roleCodes: ['teacher'],
            ),
          ),
        ),
        isFalse,
      );
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.forYou,
            audience: NoticeAudience.role,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(dimension: NoticeAudienceDimension.platform, selectAll: true),
              ],
              roleCodes: ['guardian'],
            ),
          ),
        ),
        isTrue,
      );
    });

    test('exclusão explícita reprova mesmo com selectAll', () {
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audience: NoticeAudience.institution,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(
                  dimension: NoticeAudienceDimension.institution,
                  selectAll: true,
                  excludedIds: ['inst-1'],
                ),
              ],
            ),
          ),
        ),
        isFalse,
      );
      expect(
        eligibleFor(
          communication(
            type: CommunicationType.content,
            audienceSelection: const NoticeAudienceSelection(
              rules: [
                NoticeAudienceRule(
                  dimension: NoticeAudienceDimension.platform,
                  selectAll: true,
                  excludedIds: ['unit-1'],
                ),
              ],
            ),
          ),
        ),
        isFalse,
      );
    });

    test('sem escopo o comportamento anterior é preservado', () {
      final item = communication(
        type: CommunicationType.content,
        audience: NoticeAudience.institution,
        audienceSelection: const NoticeAudienceSelection(
          rules: [
            NoticeAudienceRule(
              dimension: NoticeAudienceDimension.institution,
              targetIds: ['inst-9'],
            ),
          ],
        ),
      );

      expect(eligibleFor(item, actor: null), isTrue);
    });

    test('escopo derivado do runtime context reaproveita a mesma avaliação', () {
      const context = PrincipalRuntimeContext(
        membershipId: 'membership-1',
        personId: 'person-1',
        institutionId: 'inst-1',
        institutionName: 'Colégio Coelo',
        roleCode: 'guardian',
        scopeKind: 'group',
        unitId: 'unit-1',
        groupId: 'group-1',
      );

      final highlights = PrincipalForYouCommunicationsAdapter.highlightsForContext([
        communication(
          type: CommunicationType.content,
          audience: NoticeAudience.group,
          audienceSelection: const NoticeAudienceSelection(
            rules: [
              NoticeAudienceRule(
                dimension: NoticeAudienceDimension.group,
                targetIds: ['group-1'],
              ),
            ],
          ),
        ),
      ], now: now, context: context);

      expect(highlights.single.eligible, isTrue);
    });
  });

  test('ordena por prioridade urgente, importante e rotina', () {
    final highlights = PrincipalForYouCommunicationsAdapter.highlights([
      communication(
        type: CommunicationType.content,
        priority: NoticePriority.routine,
        id: 'routine',
      ),
      communication(
        type: CommunicationType.forYou,
        priority: NoticePriority.urgent,
        id: 'urgent',
      ),
      communication(
        type: CommunicationType.highlight,
        priority: NoticePriority.important,
        id: 'important',
      ),
    ], now: now, scope: scope);

    expect(highlights.map((item) => item.id).toList(), ['urgent', 'important', 'routine']);
  });
}
