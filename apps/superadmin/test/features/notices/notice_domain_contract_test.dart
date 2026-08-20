import 'package:coelo_superadmin/features/notices/domain/platform_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommunicationType', () {
    test('keeps the four product types closed and labeled in pt-BR', () {
      expect(CommunicationType.values, [
        CommunicationType.notice,
        CommunicationType.content,
        CommunicationType.highlight,
        CommunicationType.forYou,
      ]);
      expect(CommunicationType.values.map((type) => type.label), [
        'Aviso',
        'Conteúdo',
        'Destaque',
        'Para você',
      ]);
    });

    test('normalizes legacy database values without losing popup semantics', () {
      for (final legacy in ['popup', 'notice', 'critical_notice']) {
        expect(communicationTypeFromStorage(legacy), CommunicationType.notice);
      }
      expect(communicationTypeFromStorage('content_card'), CommunicationType.content);
      expect(communicationTypeFromStorage('highlight'), CommunicationType.highlight);
      expect(communicationTypeFromStorage('for_you'), CommunicationType.forYou);
    });
  });

  group('NoticeAudienceSelection', () {
    test('round-trips mixed explicit and select-all rules without losing filters', () {
      const selection = NoticeAudienceSelection(
        rules: [
          NoticeAudienceRule(
            dimension: NoticeAudienceDimension.institution,
            targetIds: ['institution-1', 'institution-2'],
          ),
          NoticeAudienceRule(
            dimension: NoticeAudienceDimension.unit,
            selectAll: true,
            excludedIds: ['unit-blocked'],
            filters: {
              'institution_id': ['institution-1'],
              'status': ['active'],
            },
          ),
        ],
        roleCodes: ['guardian', 'professional'],
        planIds: ['plan-pro'],
      );

      final decoded = NoticeAudienceSelection.fromJson(selection.toJson());

      expect(decoded.rules, hasLength(2));
      expect(decoded.rules.first.dimension, NoticeAudienceDimension.institution);
      expect(decoded.rules.first.targetIds, ['institution-1', 'institution-2']);
      expect(decoded.rules.last.dimension, NoticeAudienceDimension.unit);
      expect(decoded.rules.last.selectAll, isTrue);
      expect(decoded.rules.last.excludedIds, ['unit-blocked']);
      expect(decoded.rules.last.filters, {
        'institution_id': ['institution-1'],
        'status': ['active'],
      });
      expect(decoded.roleCodes, ['guardian', 'professional']);
      expect(decoded.planIds, ['plan-pro']);
    });

    test('fails closed to an empty selection for absent collections', () {
      final decoded = NoticeAudienceSelection.fromJson(const {});

      expect(decoded.rules, isEmpty);
      expect(decoded.roleCodes, isEmpty);
      expect(decoded.planIds, isEmpty);
    });
  });

  group('NoticeAppearance', () {
    test('fullscreen never exposes an outer inset', () {
      const appearance = NoticeAppearance(
        popupSize: NoticePopupSize.fullscreen,
        hasOuterInset: true,
      );

      expect(appearance.effectiveHasOuterInset, isFalse);
    });

    test('non-fullscreen sizes preserve the configured outer inset', () {
      for (final size in [
        NoticePopupSize.compact,
        NoticePopupSize.standard,
        NoticePopupSize.large,
      ]) {
        expect(NoticeAppearance(popupSize: size).effectiveHasOuterInset, isTrue, reason: size.name);
        expect(
          NoticeAppearance(popupSize: size, hasOuterInset: false).effectiveHasOuterInset,
          isFalse,
          reason: size.name,
        );
      }
    });
  });

  group('Notice appearance persistence', () {
    test('draft retains custom button color and normalizes fullscreen inset', () {
      const draft = NoticeDraft(
        title: 'Alerta',
        message: 'Mensagem',
        priority: NoticePriority.important,
        audience: NoticeAudience.everyone,
        audienceLabel: 'Todos',
        behavior: NoticeBehavior.confirmation,
        buttonColorValue: 0xFFD63C00,
        popupSize: NoticePopupSize.fullscreen,
        hasOuterInset: true,
      );

      expect(draft.buttonColorValue, 0xFFD63C00);
      expect(draft.popupSize, NoticePopupSize.fullscreen);
      expect(draft.hasOuterInset, isFalse);
      expect(draft.appearance.effectiveHasOuterInset, isFalse);
    });

    test('non-popup draft strips popup-only configuration', () {
      const draft = NoticeDraft(
        type: CommunicationType.content,
        title: 'Boletim',
        message: 'Mensagem',
        priority: NoticePriority.routine,
        audience: NoticeAudience.everyone,
        audienceLabel: 'Todos',
        behavior: NoticeBehavior.checkboxConfirmation,
        popupSize: NoticePopupSize.fullscreen,
        hasOuterInset: false,
      );

      expect(draft.behavior, NoticeBehavior.dismissible);
      expect(draft.popupSize, NoticePopupSize.standard);
      expect(draft.hasOuterInset, isTrue);
      expect(draft.isPopup, isFalse);
    });

    test('notice copyWith carries audience and appearance contracts', () {
      const selection = NoticeAudienceSelection(
        rules: [
          NoticeAudienceRule(
            dimension: NoticeAudienceDimension.group,
            selectAll: true,
            excludedIds: ['group-3'],
          ),
        ],
      );
      final notice = _notice().copyWith(
        buttonColorValue: 0xFF0057B8,
        popupSize: NoticePopupSize.large,
        hasOuterInset: false,
        audienceSelection: selection,
      );

      expect(notice.buttonColorValue, 0xFF0057B8);
      expect(notice.popupSize, NoticePopupSize.large);
      expect(notice.hasOuterInset, isFalse);
      expect(notice.audienceSelection.rules.single.selectAll, isTrue);
      expect(notice.audienceSelection.rules.single.excludedIds, ['group-3']);
    });
  });
}

PlatformNotice _notice() => PlatformNotice(
  id: 'notice-1',
  title: 'Aviso',
  message: 'Mensagem segura',
  priority: NoticePriority.routine,
  status: NoticeStatus.draft,
  startsAt: DateTime.utc(2026, 8, 12),
  endsAt: null,
  audience: NoticeAudience.everyone,
  audienceLabel: 'Todos',
  behavior: NoticeBehavior.dismissible,
  targetDevice: NoticeTargetDevice.all,
  reach: 0,
);
