import 'package:coelo_ui_admin/coelo_ui_admin.dart';

import '../domain/institution_record.dart';

List<CoeloAdminContextOption> institutionContextOptions(Iterable<InstitutionRecord> records) {
  return [
    for (final institution in records)
      CoeloAdminContextOption(
        id: institution.id,
        label: institution.publicName,
        kind: CoeloAdminContextKind.institution,
        subtitle: institution.status.label,
        children: [
          for (final unit in institution.units)
            CoeloAdminContextOption(
              id: unit.id,
              label: unit.name,
              kind: CoeloAdminContextKind.unit,
              children: [
                for (final group in unit.groups)
                  CoeloAdminContextOption(
                    id: group.id,
                    label: group.name,
                    kind: CoeloAdminContextKind.group,
                  ),
              ],
            ),
        ],
      ),
  ];
}
