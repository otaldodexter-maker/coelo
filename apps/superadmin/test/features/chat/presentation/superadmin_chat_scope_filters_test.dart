import 'package:coelo_superadmin/features/chat/presentation/widgets/superadmin_chat_scope_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('changing an institution clears incompatible descendants', () {
    final updated = updatedSuperadminChatScope(
      {
        SuperadminChatScopeKind.institution: 'Centro Horizonte',
        SuperadminChatScopeKind.unit: 'Unidade Cambuí',
        SuperadminChatScopeKind.group: 'Turma Girassol',
        SuperadminChatScopeKind.child: 'Lia',
      },
      SuperadminChatScopeKind.institution,
      'Instituto Aurora',
    );

    expect(updated, {SuperadminChatScopeKind.institution: 'Instituto Aurora'});
    expect(superadminChatScopeOptions(SuperadminChatScopeKind.unit, updated), ['Unidade Jardins']);
  });

  test('changing a state clears its contextual descendants', () {
    final updated = updatedSuperadminChatScope(
      {
        SuperadminChatScopeKind.institution: 'Centro Horizonte',
        SuperadminChatScopeKind.unit: 'Unidade Cambu\u00ed',
        SuperadminChatScopeKind.group: 'Turma Girassol',
        SuperadminChatScopeKind.child: 'Lia',
      },
      SuperadminChatScopeKind.state,
      'CE',
    );

    expect(updated, {SuperadminChatScopeKind.state: 'CE'});
  });

  test('person role options group every supported relationship', () {
    expect(
      superadminChatScopeOptions(SuperadminChatScopeKind.personRole, const {}),
      containsAll(['Respons\u00e1veis', 'Crian\u00e7as', 'Professores', 'Outros']),
    );
  });

  test('concept filters conversations by their final recipient level', () {
    expect(
      superadminChatScopeOptionLabel(SuperadminChatScopeKind.concept, 'institutions-units'),
      'Instituições e unidades',
    );
  });
}
