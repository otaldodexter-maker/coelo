import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_superadmin/features/health_care/presentation/health_care_responsive_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seis telas de Saude e Cuidado passam por [HealthCareResponsiveSurface] e
/// nenhuma prova cobria a condicao composta que ela avalia: claro E estreito.
/// A condicao tem duas variaveis, entao tem quatro combinacoes, e so uma delas
/// deve alterar o tema. Sem esta prova, apagar metade da condicao continuaria
/// verde.
///
/// O que a superficie muda de fato foi medido, nao suposto. Sob o tema do app,
/// `scaffoldBackgroundColor` ja e `colorScheme.surface` e o `surfaceTintColor`
/// da AppBar ja e transparente, entao essas duas linhas do `copyWith` sao
/// redundantes. As que atuam sao `canvasColor` e o fundo da AppBar, que saem
/// de #F7F8F8 para o branco da superficie. Por isso as afirmacoes abaixo
/// olham para essas duas, e nao para o fundo do Scaffold: afirmar o
/// redundante passaria mesmo com a superficie removida.
void main() {
  ThemeData appTheme(Brightness brightness) {
    final base = brightness == Brightness.light ? CoeloTheme.light : CoeloTheme.dark;
    return base.copyWith(scaffoldBackgroundColor: base.colorScheme.surface);
  }

  Future<ThemeData> pumpSurface(
    WidgetTester tester, {
    required Brightness brightness,
    required double width,
  }) async {
    late ThemeData inner;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(brightness),
        home: HealthCareResponsiveSurface(
          child: Builder(
            builder: (context) {
              inner = Theme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return inner;
  }

  // 839 e o ultimo pixel abaixo de expanded; 840 e o primeiro dentro dele.
  // A borda importa porque a comparacao e estrita.
  testWidgets('clean surface applies in light below the expanded breakpoint', (tester) async {
    final theme = await pumpSurface(tester, brightness: Brightness.light, width: 839);
    final surface = theme.colorScheme.surface;
    expect(theme.canvasColor, surface);
    expect(theme.appBarTheme.backgroundColor, surface);
    // A afirmacao so tem valor se o tema de origem fosse diferente.
    expect(appTheme(Brightness.light).canvasColor, isNot(surface));
  });

  testWidgets('expanded width keeps the authored light theme untouched', (tester) async {
    final theme = await pumpSurface(tester, brightness: Brightness.light, width: 840);
    final base = appTheme(Brightness.light);
    expect(theme.canvasColor, base.canvasColor);
    expect(theme.appBarTheme.backgroundColor, base.appBarTheme.backgroundColor);
  });

  testWidgets('dark never gets the clean surface, however narrow', (tester) async {
    final theme = await pumpSurface(tester, brightness: Brightness.dark, width: 320);
    final base = appTheme(Brightness.dark);
    expect(theme.canvasColor, base.canvasColor);
    expect(theme.appBarTheme.backgroundColor, base.appBarTheme.backgroundColor);
  });

  testWidgets('dark and expanded is untouched as well', (tester) async {
    final theme = await pumpSurface(tester, brightness: Brightness.dark, width: 1280);
    final base = appTheme(Brightness.dark);
    expect(theme.canvasColor, base.canvasColor);
    expect(theme.appBarTheme.backgroundColor, base.appBarTheme.backgroundColor);
  });

  testWidgets('the extension composes the same surface as the widget', (tester) async {
    late ThemeData inner;
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            inner = Theme.of(context);
            return const SizedBox();
          },
        ).withHealthCareResponsiveSurface(),
      ),
    );
    expect(inner.canvasColor, inner.colorScheme.surface);
  });
}
