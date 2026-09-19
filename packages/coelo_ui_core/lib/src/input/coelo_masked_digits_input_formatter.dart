import 'package:flutter/services.dart';

/// Máscara de dígitos: `0` na máscara é um dígito; o resto é literal.
/// Descarta o que não é dígito e o que passa da máscara.
abstract base class CoeloMaskedDigitsInputFormatter extends TextInputFormatter {
  const CoeloMaskedDigitsInputFormatter(this.mask);

  final String mask;

  static final RegExp _nonDigits = RegExp(r'\D');

  /// Só os dígitos do texto, já cortados no tamanho da máscara.
  static String digitsOf(String value, String mask) {
    final max = mask.replaceAll(RegExp('[^0]'), '').length;
    final digits = value.replaceAll(_nonDigits, '');
    return digits.length > max ? digits.substring(0, max) : digits;
  }

  static String formatWith(String value, String mask) {
    final digits = digitsOf(value, mask);
    final buffer = StringBuffer();
    var digitIndex = 0;
    for (final char in mask.split('')) {
      if (digitIndex >= digits.length) break;
      if (char == '0') {
        buffer.write(digits[digitIndex++]);
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final formatted = formatWith(newValue.text, mask);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Formata CEP como `00000-000` enquanto o usuário digita.
final class CoeloCepInputFormatter extends CoeloMaskedDigitsInputFormatter {
  const CoeloCepInputFormatter() : super(_mask);

  static const String _mask = '00000-000';

  static String format(String value) => CoeloMaskedDigitsInputFormatter.formatWith(value, _mask);

  /// Só os dígitos (até 8), para payload e validação.
  static String digits(String value) => CoeloMaskedDigitsInputFormatter.digitsOf(value, _mask);
}

/// Formata CNPJ como `00.000.000/0000-00` enquanto o usuário digita.
final class CoeloCnpjInputFormatter extends CoeloMaskedDigitsInputFormatter {
  const CoeloCnpjInputFormatter() : super(_mask);

  static const String _mask = '00.000.000/0000-00';

  static String format(String value) => CoeloMaskedDigitsInputFormatter.formatWith(value, _mask);

  /// Só os dígitos (até 14), para payload e validação.
  static String digits(String value) => CoeloMaskedDigitsInputFormatter.digitsOf(value, _mask);
}
