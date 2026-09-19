import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata CNPJ parcial e completo e corta o excedente', () {
    expect(CoeloCnpjInputFormatter.format('12'), '12');
    expect(CoeloCnpjInputFormatter.format('12345'), '12.345');
    expect(CoeloCnpjInputFormatter.format('123456780001'), '12.345.678/0001');
    expect(CoeloCnpjInputFormatter.format('12345678000195'), '12.345.678/0001-95');
    expect(CoeloCnpjInputFormatter.format('12.345.678/0001-95999'), '12.345.678/0001-95');
    expect(CoeloCnpjInputFormatter.format('abc'), '');
  });

  test('digits devolve só os dígitos, no máximo 14', () {
    expect(CoeloCnpjInputFormatter.digits('12.345.678/0001-95'), '12345678000195');
    expect(CoeloCnpjInputFormatter.digits('12.345.678/0001-95999'), '12345678000195');
  });

  test('formatEditUpdate aplica a máscara e deixa o cursor no fim', () {
    const formatter = CoeloCnpjInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '12345678000195'),
    );
    expect(result.text, '12.345.678/0001-95');
    expect(result.selection.baseOffset, 18);
  });
}
