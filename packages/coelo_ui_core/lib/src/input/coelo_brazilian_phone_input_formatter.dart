import 'package:flutter/services.dart';

/// Formats Brazilian landline and mobile numbers while preserving editable text.
final class CoeloBrazilianPhoneInputFormatter extends TextInputFormatter {
  const CoeloBrazilianPhoneInputFormatter();

  static final RegExp _nonDigits = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final nationalDigits = _nationalDigits(newValue.text);
    if (nationalDigits.isEmpty) {
      return TextEditingValue.empty;
    }

    final formatted = format(newValue.text);
    final localDigitsBeforeCaret = _localDigitsBeforeCaret(newValue);
    final caret = _caretAfterLocalDigits(formatted, localDigitsBeforeCaret);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caret),
    );
  }

  static String format(String value) {
    final digits = _nationalDigits(value);
    if (digits.isEmpty) return '';

    final buffer = StringBuffer('+55 (');
    final areaLength = digits.length.clamp(0, 2);
    buffer.write(digits.substring(0, areaLength));
    if (digits.length < 2) return buffer.toString();

    buffer.write(')');
    if (digits.length == 2) return buffer.toString();

    final subscriber = digits.substring(2);
    buffer.write(' ');
    final leadingLength = digits.length == 11 ? 5 : 4;
    if (subscriber.length <= leadingLength) {
      buffer.write(subscriber);
    } else {
      buffer
        ..write(subscriber.substring(0, leadingLength))
        ..write('-')
        ..write(subscriber.substring(leadingLength));
    }
    return buffer.toString();
  }

  static String toE164(String value) {
    final digits = _nationalDigits(value);
    return digits.isEmpty ? '' : '+55$digits';
  }

  static String _nationalDigits(String value) {
    var digits = value.replaceAll(_nonDigits, '');
    final explicitCountryCode = value.trimLeft().startsWith('+55');
    if ((explicitCountryCode || digits.length > 11) && digits.startsWith('55')) {
      digits = digits.substring(2);
    }
    return digits.length <= 11 ? digits : digits.substring(0, 11);
  }

  static int _localDigitsBeforeCaret(TextEditingValue value) {
    final offset = value.selection.extentOffset.clamp(0, value.text.length);
    var digits = value.text.substring(0, offset).replaceAll(_nonDigits, '');
    final allDigits = value.text.replaceAll(_nonDigits, '');
    final hasCountryCode =
        value.text.trimLeft().startsWith('+55') ||
        (allDigits.length > 11 && allDigits.startsWith('55'));
    if (hasCountryCode && digits.startsWith('55')) {
      digits = digits.substring(2);
    }
    return digits.length.clamp(0, 11);
  }

  static int _caretAfterLocalDigits(String formatted, int localDigitCount) {
    if (localDigitCount <= 0) return 0;
    var seenCountryDigits = 0;
    var seenLocalDigits = 0;
    for (var index = 0; index < formatted.length; index += 1) {
      final codeUnit = formatted.codeUnitAt(index);
      final isDigit = codeUnit >= 48 && codeUnit <= 57;
      if (!isDigit) continue;
      if (seenCountryDigits < 2) {
        seenCountryDigits += 1;
        continue;
      }
      seenLocalDigits += 1;
      if (seenLocalDigits == localDigitCount) return index + 1;
    }
    return formatted.length;
  }
}
