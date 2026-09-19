import 'package:flutter/services.dart';

/// Formata CPF como `000.000.000-00` enquanto o usuário digita.
final class CoeloCpfInputFormatter extends TextInputFormatter {
  const CoeloCpfInputFormatter();

  static final RegExp _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = format(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Aplica a máscara a qualquer texto, descartando o que não é dígito e o
  /// que passa de 11 dígitos.
  static String format(String value) {
    final digits = value.replaceAll(_nonDigits, '');
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length && index < 11; index++) {
      if (index == 3 || index == 6) buffer.write('.');
      if (index == 9) buffer.write('-');
      buffer.write(digits[index]);
    }
    return buffer.toString();
  }
}
