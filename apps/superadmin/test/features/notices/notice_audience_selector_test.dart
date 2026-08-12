import 'package:coelo_superadmin/features/notices/presentation/notice_audience_selector.dart';
import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects all filtered results and supports exclusions', (tester) async {
    var selection = const NoticeAudiencePickerSelection.explicit();
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) => NoticeAudienceSelector(
            options: const [
              NoticeAudienceOption(
                id: 'institution-1',
                label: 'Aurora',
                groupLabel: 'Instituições',
              ),
              NoticeAudienceOption(id: 'unit-1', label: 'Unidade Centro', groupLabel: 'Unidades'),
            ],
            totalMatchingCount: 24,
            selection: selection,
            onChanged: (value) => setState(() => selection = value),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('notice-audience-select-all')));
    await tester.pump();
    expect(selection.allMatching, isTrue);
    expect(find.text('Todos os 24 resultados filtrados'), findsOneWidget);

    await tester.tap(find.byKey(const Key('notice-audience-option-unit-1')));
    await tester.pump();
    expect(selection.allMatching, isTrue);
    expect(selection.excludedIds, contains('unit-1'));
  });

  testWidgets('reports search and renders loading empty and failure states', (tester) async {
    var query = '';
    await tester.pumpWidget(
      _app(
        NoticeAudienceSelector(
          options: const [],
          selection: const NoticeAudiencePickerSelection.explicit(),
          onChanged: (_) {},
          onQueryChanged: (value) => query = value,
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('notice-audience-search')), 'aurora');
    expect(query, 'aurora');
    expect(find.text('Nenhum público encontrado.'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        const NoticeAudienceSelector(
          options: [],
          selection: NoticeAudiencePickerSelection.explicit(),
          isLoading: true,
        ),
      ),
    );
    expect(find.byKey(const Key('notice-audience-loading')), findsOneWidget);

    await tester.pumpWidget(
      _app(
        const NoticeAudienceSelector(
          options: [],
          selection: NoticeAudiencePickerSelection.explicit(),
          errorMessage: 'Não foi possível carregar o público.',
        ),
      ),
    );
    expect(find.text('Não foi possível carregar o público.'), findsOneWidget);
  });

  testWidgets('requests the next cursor page without changing explicit selection', (tester) async {
    var loadMoreCalls = 0;
    const selection = NoticeAudiencePickerSelection.explicit({'institution-1'});
    await tester.pumpWidget(
      _app(
        NoticeAudienceSelector(
          options: const [
            NoticeAudienceOption(id: 'institution-1', label: 'Aurora', groupLabel: 'Instituições'),
          ],
          selection: selection,
          hasMore: true,
          onLoadMore: () => loadMoreCalls += 1,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('notice-audience-load-more')));

    expect(loadMoreCalls, 1);
    expect(selection.selectedIds, {'institution-1'});
  });
}

Widget _app(Widget child) => MaterialApp(
  theme: CoeloTheme.light,
  home: Scaffold(body: child),
);
