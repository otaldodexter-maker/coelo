import 'package:coelo_ui_core/coelo_ui_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const formatter = CoeloBrazilianPhoneInputFormatter();

  test('formats Brazilian landline and mobile numbers', () {
    expect(_format(formatter, '1133334444').text, '+55 (11) 3333-4444');
    expect(_format(formatter, '11999994444').text, '+55 (11) 99999-4444');
  });

  test('accepts pasted country code and limits the national number', () {
    expect(_format(formatter, '+55 11 99999-4444').text, '+55 (11) 99999-4444');
    expect(_format(formatter, '551199999444499').text, '+55 (11) 99999-4444');
  });

  test('keeps a predictable caret while editing in the middle', () {
    const oldValue = TextEditingValue(
      text: '+55 (11) 99999-4444',
      selection: TextSelection.collapsed(offset: 10),
    );
    const newValue = TextEditingValue(
      text: '+55 (11) 899999-4444',
      selection: TextSelection.collapsed(offset: 10),
    );

    final formatted = formatter.formatEditUpdate(oldValue, newValue);

    expect(formatted.text, '+55 (11) 89999-9444');
    expect(formatted.selection.baseOffset, 10);
  });

  test('normalizes formatted values to E.164', () {
    expect(CoeloBrazilianPhoneInputFormatter.toE164('+55 (11) 3333-4444'), '+551133334444');
    expect(CoeloBrazilianPhoneInputFormatter.toE164('(11) 99999-4444'), '+5511999994444');
    expect(CoeloBrazilianPhoneInputFormatter.toE164(''), '');
  });
}

TextEditingValue _format(CoeloBrazilianPhoneInputFormatter formatter, String value) {
  return formatter.formatEditUpdate(
    TextEditingValue.empty,
    TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    ),
  );
}
