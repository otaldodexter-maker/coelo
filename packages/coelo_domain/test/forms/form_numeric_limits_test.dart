import 'package:coelo_domain/coelo_domain.dart';
import 'package:test/test.dart';

void main() {
  group('money travels in minor units', () {
    test('civil notation parses into minor units', () {
      expect(FormNumericLimits.parse(FormItemKind.money, '10,50'), 1050);
      expect(FormNumericLimits.parse(FormItemKind.money, '10.50'), 1050);
      expect(FormNumericLimits.parse(FormItemKind.money, '1000'), 100000);
      expect(FormNumericLimits.parse(FormItemKind.money, '0,05'), 5);
      expect(FormNumericLimits.parse(FormItemKind.money, '-3,20'), -320);
    });

    test('minor units format back into civil notation', () {
      expect(FormNumericLimits.format(FormItemKind.money, 1050), '10,50');
      expect(FormNumericLimits.format(FormItemKind.money, 100), '1,00');
      expect(FormNumericLimits.format(FormItemKind.money, 5), '0,05');
      expect(FormNumericLimits.format(FormItemKind.money, -320), '-3,20');
    });

    test('the round trip is stable', () {
      for (final raw in ['0,00', '10,50', '1,00', '999,99']) {
        final parsed = FormNumericLimits.parse(FormItemKind.money, raw)!;
        expect(FormNumericLimits.format(FormItemKind.money, parsed), raw);
      }
    });
  });

  group('other numeric kinds keep their plain unit', () {
    test('integer refuses a fractional value', () {
      expect(FormNumericLimits.parse(FormItemKind.integer, '11'), 11);
      expect(FormNumericLimits.parse(FormItemKind.integer, '10,5'), isNull);
    });

    test('decimal accepts both separators', () {
      expect(FormNumericLimits.parse(FormItemKind.decimal, '10,5'), 10.5);
      expect(FormNumericLimits.parse(FormItemKind.decimal, '10.5'), 10.5);
    });

    test('non-finite and empty input has no value', () {
      for (final raw in ['', '  ', '-', 'NaN', 'Infinity', 'abc']) {
        expect(FormNumericLimits.parse(FormItemKind.decimal, raw), isNull, reason: raw);
        expect(FormNumericLimits.parse(FormItemKind.money, raw), isNull, reason: raw);
      }
    });
  });

  group('violation compares in the declared unit', () {
    test('the boundary itself is allowed', () {
      const config = FormItemConfig(minValue: 1, maxValue: 10);
      expect(FormNumericLimits.violation(FormItemKind.integer, config, 1), isNull);
      expect(FormNumericLimits.violation(FormItemKind.integer, config, 10), isNull);
    });

    test('outside the range names the declared bound', () {
      const config = FormItemConfig(minValue: 1, maxValue: 10);
      expect(FormNumericLimits.violation(FormItemKind.integer, config, 11), contains('10'));
      expect(FormNumericLimits.violation(FormItemKind.integer, config, 0), contains('1'));
    });

    test('money reports the bound in civil notation', () {
      const config = FormItemConfig(maxValue: 1000);
      expect(FormNumericLimits.violation(FormItemKind.money, config, 1050), contains('10,00'));
      expect(FormNumericLimits.violation(FormItemKind.money, config, 1000), isNull);
    });

    test('an absent bound never refuses', () {
      const config = FormItemConfig();
      expect(FormNumericLimits.violation(FormItemKind.decimal, config, -99999), isNull);
      expect(FormNumericLimits.violation(FormItemKind.decimal, config, 99999), isNull);
    });
  });

  group('text length', () {
    test('the declared maximum is inclusive', () {
      const config = FormItemConfig(maxLength: 5);
      expect(FormNumericLimits.textViolation(config, 'abcde'), isNull);
      expect(FormNumericLimits.textViolation(config, 'abcdef'), contains('5'));
    });

    test('an absent maximum never refuses', () {
      expect(FormNumericLimits.textViolation(const FormItemConfig(), 'a' * 5000), isNull);
    });
  });

  test('isNumeric selects exactly the three numeric kinds', () {
    expect(
      FormItemKind.values.where(FormNumericLimits.isNumeric),
      [FormItemKind.integer, FormItemKind.decimal, FormItemKind.money],
    );
  });
}
