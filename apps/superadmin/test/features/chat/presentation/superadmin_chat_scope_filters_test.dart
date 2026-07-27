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

  test('concept filters conversations by their final recipient level', () {
    expect(
      superadminChatScopeOptionLabel(SuperadminChatScopeKind.concept, 'institutions-units'),
      'Instituições e unidades',
    );
  });
}
