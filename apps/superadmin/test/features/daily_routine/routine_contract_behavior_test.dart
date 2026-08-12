import 'package:coelo_superadmin/features/daily_routine/domain/routine_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  RoutineField field({
    required String id,
    RoutineFieldKind kind = RoutineFieldKind.boolean,
    Object? initialValue,
    num? minimumValue,
    num? maximumValue,
    List<RoutineFieldOption> options = const [],
    List<RoutineCondition> conditions = const [],
  }) => RoutineField(
    id: id,
    label: 'Campo $id',
    kind: kind,
    sortOrder: int.tryParse(id.replaceAll(RegExp(r'\D'), '')) ?? 0,
    initialValue: initialValue,
    minimumValue: minimumValue,
    maximumValue: maximumValue,
    options: options,
    conditions: conditions,
  );

  RoutineModel model(List<RoutineField> fields) => RoutineModel(
    id: 'model',
    name: 'Modelo',
    description: '',
    version: 1,
    status: RoutineModelStatus.draft,
    sections: [RoutineSection(id: 'section', name: 'Seção', sortOrder: 0, fields: fields)],
    expectedVersion: 1,
    institutionId: 'institution-1',
  );

  test('public contract separates model application and launch', () {
    expect(<Type>[RoutineModel, RoutineApplication, RoutineLaunch], hasLength(3));
    expect(RoutineEntryKind.values.map((kind) => kind.name), ['model', 'application', 'launch']);
  });

  test('model scope is institution-owned by default and never platform-wide', () {
    final scoped = RoutineModel(
      id: 'model',
      name: 'Modelo',
      description: '',
      version: 1,
      status: RoutineModelStatus.draft,
      sections: const [],
      expectedVersion: 0,
      institutionId: 'institution-1',
    );

    expect(scoped.originScope, RoutineModelOriginScope.institution);
    expect(RoutineModelOriginScope.values.map((scope) => scope.name), ['institution', 'unit']);
    expect(scoped.validate, returnsNormally);
  });

  test('institution-owned model rejects a missing institution', () {
    final unscoped = RoutineModel(
      id: 'model',
      name: 'Modelo',
      description: '',
      version: 1,
      status: RoutineModelStatus.draft,
      sections: const [],
      expectedVersion: 0,
    );

    expect(unscoped.validate, throwsFormatException);
  });
  test('field options preserve stable identity label and order', () {
    const options = [
      RoutineFieldOption(id: 'yes', label: 'Sim', sortOrder: 0),
      RoutineFieldOption(id: 'no', label: 'Não', sortOrder: 1),
    ];
    final choice = field(
      id: 'choice',
      kind: RoutineFieldKind.singleChoice,
      initialValue: 'yes',
      options: options,
    );

    expect(choice.options.map((option) => option.id), ['yes', 'no']);
    expect(choice.validate, returnsNormally);
  });

  test('number initial value is typed and constrained by minimum and maximum', () {
    expect(
      field(
        id: 'temperature',
        kind: RoutineFieldKind.number,
        initialValue: 36.5,
        minimumValue: 35,
        maximumValue: 42,
      ).validate,
      returnsNormally,
    );
    expect(
      field(
        id: 'temperature',
        kind: RoutineFieldKind.number,
        initialValue: '36.5',
        minimumValue: 35,
        maximumValue: 42,
      ).validate,
      throwsFormatException,
    );
    expect(
      field(
        id: 'temperature',
        kind: RoutineFieldKind.number,
        minimumValue: 42,
        maximumValue: 35,
      ).validate,
      throwsFormatException,
    );
  });

  test('condition graph accepts four levels', () {
    final fields = [for (var index = 0; index < 5; index++) field(id: 'f$index')];
    for (var depth = 1; depth <= 4; depth++) {
      fields[depth] = field(
        id: 'f$depth',
        conditions: [
          RoutineCondition(
            id: 'c$depth',
            parentFieldId: 'f${depth - 1}',
            targetFieldId: 'f$depth',
            booleanValue: true,
            depth: depth,
          ),
        ],
      );
    }

    expect(model(fields).validate, returnsNormally);
  });

  test('condition graph rejects level five', () {
    final fields = [for (var index = 0; index < 6; index++) field(id: 'f$index')];
    for (var depth = 1; depth <= 5; depth++) {
      fields[depth] = field(
        id: 'f$depth',
        conditions: [
          RoutineCondition(
            id: 'c$depth',
            parentFieldId: 'f${depth - 1}',
            targetFieldId: 'f$depth',
            booleanValue: true,
            depth: depth,
          ),
        ],
      );
    }

    expect(model(fields).validate, throwsFormatException);
  });

  test('condition graph rejects a cycle', () {
    final fields = [
      field(
        id: 'a',
        conditions: const [
          RoutineCondition(
            id: 'a-to-b',
            parentFieldId: 'a',
            targetFieldId: 'b',
            booleanValue: true,
            depth: 1,
          ),
        ],
      ),
      field(
        id: 'b',
        conditions: const [
          RoutineCondition(
            id: 'b-to-a',
            parentFieldId: 'b',
            targetFieldId: 'a',
            booleanValue: true,
            depth: 2,
          ),
        ],
      ),
    ];

    expect(model(fields).validate, throwsFormatException);
  });

  test('directory state contract is fail closed for non-data statuses', () {
    expect(RoutineDirectoryStatus.values.map((status) => status.name), [
      'loading',
      'data',
      'empty',
      'noResults',
      'failure',
      'unauthorized',
      'notFound',
      'conflict',
    ]);
    expect(
      RoutineDirectoryStatus.values.where((status) => status != RoutineDirectoryStatus.data),
      everyElement(isNot(RoutineDirectoryStatus.data)),
    );
  });
}
