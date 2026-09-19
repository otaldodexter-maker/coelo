import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata CEP parcial e completo e corta o excedente', () {
    expect(CoeloCepInputFormatter.format('013'), '013');
    expect(CoeloCepInputFormatter.format('013101'), '01310-1');
    expect(CoeloCepInputFormatter.format('01310100'), '01310-100');
    expect(CoeloCepInputFormatter.format('01310-100999'), '01310-100');
    expect(CoeloCepInputFormatter.format('abc'), '');
  });

  test('digits devolve só os dígitos, no máximo 8', () {
    expect(CoeloCepInputFormatter.digits('01310-100'), '01310100');
    expect(CoeloCepInputFormatter.digits('01310-100999'), '01310100');
    expect(CoeloCepInputFormatter.digits(''), '');
  });

  test('formatEditUpdate aplica a máscara e deixa o cursor no fim', () {
    const formatter = CoeloCepInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '01310100'),
    );
    expect(result.text, '01310-100');
    expect(result.selection.baseOffset, 9);
  });
}
