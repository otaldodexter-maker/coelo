import 'package:coelo_superadmin/features/account/domain/account_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sigla projetada com digito vira letras do nome (pessoa de servico da ponte)', () {
    expect(AccountAvatar.lettersOnlyInitials('O4', 'Operador interno', '41462594'), 'O');
    expect(AccountAvatar.lettersOnlyInitials('OC', 'Owner', 'Coelo'), 'OC');
    expect(AccountAvatar.lettersOnlyInitials('12', '', ''), 'EQ');
    expect(AccountAvatar.lettersOnlyInitials('1a', '', ''), 'A');
    expect(
      AccountAvatar.validateInitials(
        AccountAvatar.lettersOnlyInitials('O4', 'Operador', '41462594'),
      ),
      isNull,
    );
  });
}
