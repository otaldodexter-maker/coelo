import '../../chat/presentation/chat_models.dart';
import '../domain/institution_record.dart';

List<SuperadminChatContextOption> institutionContextOptions(Iterable<InstitutionRecord> records) {
  return [
    for (final institution in records)
      SuperadminChatContextOption(
        id: institution.id,
        label: institution.publicName,
        kind: ChatContextKind.institution,
        subtitle: institution.status.label,
        children: [
          for (final unit in institution.units)
            SuperadminChatContextOption(
              id: unit.id,
              label: unit.name,
              kind: ChatContextKind.unit,
              children: [
                for (final group in unit.groups)
                  SuperadminChatContextOption(
                    id: group.id,
                    label: group.name,
                    kind: ChatContextKind.group,
                  ),
              ],
            ),
        ],
      ),
  ];
}
