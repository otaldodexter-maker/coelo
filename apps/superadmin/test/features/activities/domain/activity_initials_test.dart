import 'package:coelo_superadmin/features/activities/domain/activity_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sigla digitada vence; vazia nasce do nome; sem nome cai em AT', () {
    expect(activityInitialsFor(typed: ' rb ', name: 'Natação'), 'rb');
    expect(activityInitialsFor(typed: '', name: 'Prova Atividade'), 'PA');
    expect(activityInitialsFor(typed: '', name: 'Capoeira'), 'C');
    expect(activityInitialsFor(typed: '', name: '  '), 'AT');
  });
}
