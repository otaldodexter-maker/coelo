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

    test('counts characters the way the server does, not UTF-16 units', () {
      // char_length no Postgres conta code points. Contar unidades UTF-16
      // recusaria um texto que o servidor aceita, uma unidade a menos por emoji.
      const config = FormItemConfig(maxLength: 3);
      const three = '\u{1F600}\u{1F600}\u{1F600}';
      expect(FormNumericLimits.textViolation(config, three), isNull);
      expect(FormNumericLimits.textViolation(config, 'ção'), isNull);
      expect(FormNumericLimits.textViolation(config, '$three\u{1F600}'), contains('3'));
    });

    test('an absent maximum still honours the server default', () {
      // O servidor limita texto curto a 1000 caracteres quando a pergunta nao
      // declara maximo. Sem espelhar isso, a pessoa so descobre a recusa
      // quando o comando chega ao backend.
      const config = FormItemConfig();
      expect(FormNumericLimits.textViolation(config, 'a' * 1000), isNull);
      expect(FormNumericLimits.textViolation(config, 'a' * 1001), contains('1000'));
    });
  });

  test('decimal limits are written with the comma the author types', () {
    expect(FormNumericLimits.format(FormItemKind.decimal, 10.5), '10,5');
    expect(FormNumericLimits.format(FormItemKind.integer, 7), '7');
    expect(FormNumericLimits.parse(FormItemKind.decimal, '10,5'), 10.5);
  });

  test('isNumeric selects exactly the three numeric kinds', () {
    expect(
      FormItemKind.values.where(FormNumericLimits.isNumeric),
      [FormItemKind.integer, FormItemKind.decimal, FormItemKind.money],
    );
  });

  // A guarda de selecoes so tinha prova pela pagina de resposta. Ela e
  // compartilhada e espelha padroes do servidor, entao os padroes precisam de
  // afirmacao propria: um teste de widget nao diz QUAL numero esta espelhado.
  group('selection limits mirror the server defaults', () {
    test('an item without authored limits inherits coalesce(1, 50)', () {
      const config = FormItemConfig();
      expect(FormSelectionLimits.minimum(config), 1);
      expect(FormSelectionLimits.maximum(config), 50);
    });

    test('authored limits win over the defaults', () {
      const config = FormItemConfig(minSelections: 2, maxSelections: 3);
      expect(FormSelectionLimits.minimum(config), 2);
      expect(FormSelectionLimits.maximum(config), 3);
    });

    test('the hint stays silent when the author declared nothing', () {
      // Anunciar o teto de cinquenta numa pergunta sem limite seria ruido, e
      // nao e regra deste formulario, e do servidor.
      expect(FormSelectionLimits.hint(const FormItemConfig()), isNull);
    });

    test('the hint names only what the author declared', () {
      expect(
        FormSelectionLimits.hint(const FormItemConfig(maxSelections: 2)),
        'Escolha no m\u00e1ximo 2 op\u00e7\u00f5es.',
      );
      expect(
        FormSelectionLimits.hint(const FormItemConfig(minSelections: 2)),
        'Escolha ao menos 2 op\u00e7\u00f5es.',
      );
      final both = FormSelectionLimits.hint(
        const FormItemConfig(minSelections: 2, maxSelections: 3),
      );
      // As duas metades precisam aparecer: quem le a frase tem de conseguir
      // agir sobre qualquer um dos dois limites.
      expect(both, contains('ao menos 2'));
      expect(both, contains('m\u00e1ximo 3'));
    });

    test('a single option reads in the singular', () {
      expect(
        FormSelectionLimits.hint(const FormItemConfig(minSelections: 1)),
        'Escolha ao menos 1 op\u00e7\u00e3o.',
      );
    });

    test('an empty answer is never a selection violation', () {
      // Nao ter respondido e assunto de obrigatoriedade. Dizer "escolha ao
      // menos duas" numa pergunta que a pessoa pode pular estaria errado.
      expect(
        FormSelectionLimits.violation(const FormItemConfig(minSelections: 2), 0),
        isNull,
      );
    });

    test('counts inside the authored range pass', () {
      const config = FormItemConfig(minSelections: 2, maxSelections: 3);
      expect(FormSelectionLimits.violation(config, 2), isNull);
      expect(FormSelectionLimits.violation(config, 3), isNull);
    });

    test('counts outside the authored range say which side broke', () {
      const config = FormItemConfig(minSelections: 2, maxSelections: 3);
      expect(FormSelectionLimits.violation(config, 1), contains('ao menos 2'));
      expect(FormSelectionLimits.violation(config, 4), contains('m\u00e1ximo 3'));
    });

    test('the server ceiling still applies with nothing authored', () {
      // O servidor recusa acima de cinquenta mesmo sem limite autorado, entao
      // a guarda nao pode ser omissa ali so porque a frase de aviso e.
      expect(FormSelectionLimits.violation(const FormItemConfig(), 50), isNull);
      expect(
        FormSelectionLimits.violation(const FormItemConfig(), 51),
        contains('m\u00e1ximo 50'),
      );
    });
  });
}
