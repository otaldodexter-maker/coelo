import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formata CPF parcial e completo e corta o excedente', () {
    expect(CoeloCpfInputFormatter.format('529'), '529');
    expect(CoeloCpfInputFormatter.format('5299822'), '529.982.2');
    expect(CoeloCpfInputFormatter.format('52998224725'), '529.982.247-25');
    expect(CoeloCpfInputFormatter.format('529.982.247-25999'), '529.982.247-25');
    expect(CoeloCpfInputFormatter.format('abc'), '');
  });

  test('formatEditUpdate aplica a máscara e deixa o cursor no fim', () {
    const formatter = CoeloCpfInputFormatter();
    final result = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '52998224725'),
    );
    expect(result.text, '529.982.247-25');
    expect(result.selection.baseOffset, 14);
  });
}
