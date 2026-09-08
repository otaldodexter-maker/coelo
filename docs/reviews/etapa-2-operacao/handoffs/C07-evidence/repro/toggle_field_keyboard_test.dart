import 'package:coelo_superadmin/features/principal_shared/presentation/principal_publication_frame.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:coelo_ui_admin/coelo_ui_admin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contrato medido para a linha booleana administrativa:
///
/// 1. focar por Tab e pressionar Enter (ou Espaco) alterna o valor;
/// 2. o campo expoe uma unica parada de Tab;
/// 3. toda parada de Tab dentro do campo responde a Enter;
/// 4. o no semantico publica rotulo, estado toggled, estado habilitado e tap.
///
/// O caso do pacote (`CoeloAdminToggleField`) e o caso de controle do
/// Superadmin (`PrincipalPublicationToggleField`) recebem o mesmo roteiro,
/// para servirem de A/B.
const String _packageLabel = 'Publicar no Happens';
const String _twinLabel = 'Salvar automaticamente';

void main() {
  group('CoeloAdminToggleField (pacote coelo_ui_admin)', () {
    Widget field(bool value, ValueChanged<bool> onChanged) =>
        CoeloAdminToggleField(label: _packageLabel, value: value, onChanged: onChanged);

    testWidgets('Enter alterna o valor quando o campo recebe foco por Tab', (tester) async {
      await _expectKeyActivates(
        tester,
        key: LogicalKeyboardKey.enter,
        host: CoeloAdminToggleField,
        field: field,
        tag: 'pacote/Enter',
      );
    });

    testWidgets('Espaco alterna o valor quando o campo recebe foco por Tab', (tester) async {
      await _expectKeyActivates(
        tester,
        key: LogicalKeyboardKey.space,
        host: CoeloAdminToggleField,
        field: field,
        tag: 'pacote/Espaco',
      );
    });

    testWidgets('expoe uma unica parada de Tab', (tester) async {
      await _expectSingleTabStop(
        tester,
        host: CoeloAdminToggleField,
        field: field,
        tag: 'pacote/paradas',
      );
    });

    testWidgets('toda parada de Tab do campo responde a Enter', (tester) async {
      await _expectEveryStopActivates(
        tester,
        host: CoeloAdminToggleField,
        field: field,
        tag: 'pacote/ativacao',
      );
    });

    testWidgets('publica rotulo, acao de tap e estado toggled', (tester) async {
      await _expectSemantics(
        tester,
        label: _packageLabel,
        field: field,
        tag: 'pacote/semantica',
      );
    });
  });

  group('PrincipalPublicationToggleField (controle A/B do Superadmin)', () {
    Widget field(bool value, ValueChanged<bool> onChanged) =>
        PrincipalPublicationToggleField(label: _twinLabel, value: value, onChanged: onChanged);

    testWidgets('Enter alterna o valor quando o campo recebe foco por Tab', (tester) async {
      await _expectKeyActivates(
        tester,
        key: LogicalKeyboardKey.enter,
        host: PrincipalPublicationToggleField,
        field: field,
        tag: 'gemeo/Enter',
      );
    });

    testWidgets('Espaco alterna o valor quando o campo recebe foco por Tab', (tester) async {
      await _expectKeyActivates(
        tester,
        key: LogicalKeyboardKey.space,
        host: PrincipalPublicationToggleField,
        field: field,
        tag: 'gemeo/Espaco',
      );
    });

    testWidgets('expoe uma unica parada de Tab', (tester) async {
      await _expectSingleTabStop(
        tester,
        host: PrincipalPublicationToggleField,
        field: field,
        tag: 'gemeo/paradas',
      );
    });

    testWidgets('toda parada de Tab do campo responde a Enter', (tester) async {
      await _expectEveryStopActivates(
        tester,
        host: PrincipalPublicationToggleField,
        field: field,
        tag: 'gemeo/ativacao',
      );
    });

    testWidgets('publica rotulo, acao de tap e estado toggled', (tester) async {
      await _expectSemantics(
        tester,
        label: _twinLabel,
        field: field,
        tag: 'gemeo/semantica',
      );
    });
  });
}

typedef _FieldBuilder = Widget Function(bool value, ValueChanged<bool> onChanged);

/// Contrato 1: a primeira parada de Tab dentro do campo alterna o valor.
Future<void> _expectKeyActivates(
  WidgetTester tester, {
  required LogicalKeyboardKey key,
  required Type host,
  required _FieldBuilder field,
  required String tag,
}) async {
  final calls = <bool>[];
  final before = FocusNode(debugLabel: 'antes');
  addTearDown(before.dispose);

  await tester.pumpWidget(_ToggleHarness(calls: calls, before: before, builder: field));
  await tester.pumpAndSettle();

  final stop = await _focusStop(tester, start: before, host: host);
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();

  final rendered = tester.widget<Switch>(find.byType(Switch)).value;
  debugPrint('[medicao] $tag parada="$stop" chamadas=$calls switchRenderizado=$rendered');
  expect(
    calls,
    <bool>[true],
    reason:
        '$tag: na parada "$stop" a tecla produziu onChanged=$calls (esperado [true]); '
        'Switch renderizado=$rendered',
  );
}

/// Contrato 2: o campo expoe uma unica parada de Tab.
Future<void> _expectSingleTabStop(
  WidgetTester tester, {
  required Type host,
  required _FieldBuilder field,
  required String tag,
}) async {
  final before = FocusNode(debugLabel: 'antes');
  final after = FocusNode(debugLabel: 'depois');
  addTearDown(before.dispose);
  addTearDown(after.dispose);

  await tester.pumpWidget(
    _ToggleHarness(calls: <bool>[], before: before, after: after, builder: field),
  );
  await tester.pumpAndSettle();

  final stops = await _tabStops(tester, start: before, host: host);
  debugPrint('[medicao] $tag total=${stops.length} -> $stops');
  expect(
    stops,
    hasLength(1),
    reason: '$tag: paradas de Tab medidas dentro do campo: ${stops.length} -> $stops',
  );
}

/// Contrato 3: cada parada de Tab dentro do campo responde a Enter. Remonta o
/// ambiente por parada para que uma ativacao nao contamine a medicao seguinte.
Future<void> _expectEveryStopActivates(
  WidgetTester tester, {
  required Type host,
  required _FieldBuilder field,
  required String tag,
  int probedStops = 2,
}) async {
  final before = FocusNode(debugLabel: 'antes');
  final after = FocusNode(debugLabel: 'depois');
  addTearDown(before.dispose);
  addTearDown(after.dispose);

  final map = <String>[];
  final activations = <bool>[];

  for (var target = 0; target < probedStops; target++) {
    final calls = <bool>[];
    await tester.pumpWidget(
      _ToggleHarness(calls: calls, before: before, after: after, builder: field),
    );
    await tester.pumpAndSettle();

    final stop = await _focusStop(tester, start: before, host: host, skip: target);
    if (stop == null) {
      break;
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    activations.add(calls.isNotEmpty);
    map.add('#$target $stop -> onChanged=$calls');
  }

  debugPrint('[medicao] $tag $map');
  expect(
    activations,
    everyElement(isTrue),
    reason: '$tag: mapa de ativacao por parada de Tab: $map',
  );
}

/// Contrato 4: o no semantico publica rotulo, estado e acao de tap.
Future<void> _expectSemantics(
  WidgetTester tester, {
  required String label,
  required _FieldBuilder field,
  required String tag,
}) async {
  final handle = tester.ensureSemantics();

  await tester.pumpWidget(
    _ToggleHarness(calls: <bool>[], initialValue: true, builder: field),
  );
  await tester.pumpAndSettle();

  final node = tester.getSemantics(find.bySemanticsLabel(label));
  final data = node.getSemanticsData();
  final measured =
      'label="${node.label}" flags=${node.flagsCollection.toStrings()} '
      'tap=${data.hasAction(SemanticsAction.tap)}';
  debugPrint('[medicao] $tag $measured');
  try {
    expect(
      node,
      isSemantics(
        label: label,
        hasEnabledState: true,
        isEnabled: true,
        hasToggledState: true,
        isToggled: true,
        hasTapAction: true,
      ),
      reason: '$tag: semantica medida: $measured',
    );
  } finally {
    handle.dispose();
  }
}

/// Ambiente minimo: um alvo focavel antes do campo, o campo e, opcionalmente,
/// um alvo focavel depois, para delimitar a travessia de Tab.
class _ToggleHarness extends StatefulWidget {
  const _ToggleHarness({
    required this.builder,
    required this.calls,
    this.initialValue = false,
    this.before,
    this.after,
  });

  final _FieldBuilder builder;
  final List<bool> calls;
  final bool initialValue;
  final FocusNode? before;
  final FocusNode? after;

  @override
  State<_ToggleHarness> createState() => _ToggleHarnessState();
}

class _ToggleHarnessState extends State<_ToggleHarness> {
  late bool _value = widget.initialValue;

  @override
  void didUpdateWidget(_ToggleHarness oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.calls, widget.calls)) {
      _value = widget.initialValue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: CoeloTheme.light,
      home: Scaffold(
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.before case final node?)
              TextButton(focusNode: node, onPressed: () {}, child: const Text('antes')),
            widget.builder(_value, (next) {
              widget.calls.add(next);
              setState(() => _value = next);
            }),
            if (widget.after case final node?)
              TextButton(focusNode: node, onPressed: () {}, child: const Text('depois')),
          ],
        ),
      ),
    );
  }
}

/// Indica se o no de foco esta dentro da subarvore do widget [type].
bool _isWithin(FocusNode node, Type type) {
  final context = node.context;
  if (context == null) {
    return false;
  }
  if (context.widget.runtimeType == type) {
    return true;
  }
  var found = false;
  context.visitAncestorElements((element) {
    if (element.widget.runtimeType == type) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

/// Rotulo legivel da parada de foco.
String _describeStop(FocusNode? node) {
  if (node == null) {
    return 'nenhum';
  }
  if (_isWithin(node, Switch)) {
    return 'Switch';
  }
  if (_isWithin(node, FocusableActionDetector)) {
    return 'FocusableActionDetector';
  }
  return node.context?.widget.runtimeType.toString() ?? 'sem contexto';
}

/// Pressiona Tab a partir de [start] ate alcancar a parada de indice [skip]
/// dentro do campo e devolve o rotulo dessa parada, ou `null` se ela nao
/// existir.
Future<String?> _focusStop(
  WidgetTester tester, {
  required FocusNode start,
  required Type host,
  int skip = 0,
  int maxTabs = 8,
}) async {
  start.requestFocus();
  await tester.pumpAndSettle();
  var reached = 0;
  for (var index = 0; index < maxTabs; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final node = FocusManager.instance.primaryFocus;
    if (node == null || !_isWithin(node, host)) {
      continue;
    }
    if (reached == skip) {
      return _describeStop(node);
    }
    reached++;
  }
  return null;
}

/// Percorre a travessia de Tab a partir de [start] e devolve os rotulos de
/// todas as paradas de foco que caem dentro da subarvore de [host].
Future<List<String>> _tabStops(
  WidgetTester tester, {
  required FocusNode start,
  required Type host,
  int maxTabs = 10,
}) async {
  start.requestFocus();
  await tester.pumpAndSettle();
  final stops = <String>[];
  for (var index = 0; index < maxTabs; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node == start) {
      break;
    }
    if (_isWithin(node, host)) {
      stops.add(_describeStop(node));
    } else if (stops.isNotEmpty) {
      break;
    }
  }
  return stops;
}
