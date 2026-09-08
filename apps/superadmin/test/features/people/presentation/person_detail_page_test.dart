import 'dart:async';
import 'package:coelo_superadmin/features/auth/domain/logout_action.dart';
import 'package:coelo_superadmin/features/people/domain/person_directory.dart';
import 'package:coelo_superadmin/features/people/domain/person_detail_reader.dart';
import 'package:coelo_superadmin/features/people/presentation/person_detail_page.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = '10000000-0000-4000-8000-000000000001';
const _b = '10000000-0000-4000-8000-000000000002';

void main() {
  for (final type in PersonType.values) {
    testWidgets('minimal ${type.name} detail has no command or invented fields', (tester) async {
      await _size(tester, 1440);
      final reader = _Reader();
      await tester.pumpWidget(_app(reader));
      reader.calls.single.complete(_person(_a, type));
      await tester.pumpAndSettle();
      expect(find.text('Synthetic person'), findsOneWidget);
      expect(find.text(type.label), findsOneWidget);
      expect(find.text('Suspensa'), findsOneWidget);
      expect(find.text('Vinculado'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Salvar'), findsNothing);
      expect(find.text('Suspender'), findsNothing);
      expect(find.text('LEGACY PRIVATE CONTACT'), findsNothing);
      expect(find.text('LEGACY ACTIVITY'), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('person-detail-content')),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reload clears identity and denial is non-enumerating; retry and back work', (
    tester,
  ) async {
    await _size(tester, 1440);
    final reader = _Reader();
    var back = 0;
    await tester.pumpWidget(_app(reader, onBack: () => back++));
    expect(find.text('Não foi possível carregar os detalhes'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Carregando detalhes',
      ),
      findsOneWidget,
    );
    reader.calls.single.complete(_person(_a, PersonType.adult));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('person-detail-reload')));
    await tester.pump();
    expect(find.text('Synthetic person'), findsNothing);
    expect(find.text('Não foi possível carregar os detalhes'), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.label == 'Carregando detalhes',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<OutlinedButton>(find.byKey(const Key('person-detail-reload'))).onPressed,
      isNull,
    );
    reader.calls.last.completeError(const PersonDirectoryUnauthorizedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-detail-denied')), findsOneWidget);
    expect(find.text('Synthetic person'), findsNothing);
    await tester.tap(find.byKey(const Key('person-detail-reload')));
    reader.calls.last.completeError(StateError('PRIVATE ERROR'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-detail-unavailable')), findsOneWidget);
    expect(find.text('PRIVATE ERROR'), findsNothing);
    await tester.tap(find.byKey(const Key('person-detail-back')));
    expect(back, 1);
  });

  testWidgets('new id and reader ignore pending response from replaced page input', (tester) async {
    await _size(tester, 1440);
    final old = _Reader();
    final next = _Reader();
    await tester.pumpWidget(_app(old));
    await tester.pumpWidget(_app(next, id: _b));
    old.calls.single.complete(_person(_a, PersonType.adult));
    await tester.pump();
    expect(find.text('Synthetic person'), findsNothing);
    expect(find.byKey(const Key('person-detail-loading')), findsOneWidget);
    next.calls.single.completeError(const PersonDirectoryUnauthorizedException());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('person-detail-denied')), findsOneWidget);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    for (final dark in [false, true]) {
      testWidgets('detail $width dark=$dark text200 remains usable', (tester) async {
        await _size(tester, width);
        final reader = _Reader();
        await tester.pumpWidget(_app(reader, dark: dark, text200: true));
        reader.calls.single.complete(_person(_a, PersonType.child));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final key in ['person-detail-reload', 'person-detail-back']) {
          expect(find.byKey(Key(key)).hitTestable(), findsOneWidget);
          expect(tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(48));
        }
      });
    }
  }
  for (final child in [false, true]) {
    for (final empty in [false, true]) {
      testWidgets('authorized context child=$child empty=$empty is represented honestly', (
        tester,
      ) async {
        await _size(tester, 1440);
        final reader = _Reader();
        await tester.pumpWidget(_app(reader));
        final person = _person(_a, child ? PersonType.child : PersonType.adult);
        reader.calls.single.complete(
          empty ? person.copyWith(memberships: [], childContexts: []) : person,
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byKey(const Key('person-detail-content')), const Offset(0, -700));
        await tester.pumpAndSettle();
        if (empty) {
          expect(
            find.text(child ? 'Nenhum contexto retornado.' : 'Nenhum vínculo retornado.'),
            findsOneWidget,
          );
        } else {
          expect(find.text('Institution A'), findsOneWidget);
          expect(find.text(child ? 'Unit A' : 'guardian'), findsOneWidget);
          if (child) expect(find.text('Group A'), findsOneWidget);
        }
        expect(find.text('LEGACY ACTIVITY'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}

Future<void> _size(WidgetTester tester, double width) async {
  await tester.binding.setSurfaceSize(Size(width, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Widget _app(
  PersonDetailReader reader, {
  String id = _a,
  bool dark = false,
  bool text200 = false,
  VoidCallback? onBack,
}) => MaterialApp(
  theme: dark ? CoeloTheme.dark : CoeloTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(text200 ? 2 : 1)),
    child: child!,
  ),
  home: PersonDetailPage(
    reader: reader,
    id: id,
    logout: () async => const LogoutResult.success(),
    onBack: onBack ?? () {},
  ),
);

class _Reader implements PersonDetailReader {
  final calls = <Completer<PersonDirectoryItem>>[];
  @override
  Future<PersonDirectoryItem> fetchDetail(String id) {
    final call = Completer<PersonDirectoryItem>();
    calls.add(call);
    return call.future;
  }
}

PersonDirectoryItem _person(String id, PersonType type) => PersonDirectoryItem(
  id: id,
  displayName: 'Synthetic person',
  type: type,
  status: PersonStatus.suspended,
  authLink: AuthLinkStatus.linked,
  maskedContact: 'LEGACY PRIVATE CONTACT',
  memberships: type == PersonType.adult
      ? [
          const PersonMembership(
            id: 'assignment',
            institutionId: 'institution',
            institutionName: 'Institution A',
            role: 'guardian',
            activityName: 'LEGACY ACTIVITY',
          ),
        ]
      : [],
  childContexts: type == PersonType.child
      ? [
          const PersonChildContext(
            id: 'context',
            institutionId: 'institution',
            institutionName: 'Institution A',
            unitName: 'Unit A',
            groupName: 'Group A',
          ),
        ]
      : [],
  updatedAt: DateTime.utc(2026, 9, 7),
);
