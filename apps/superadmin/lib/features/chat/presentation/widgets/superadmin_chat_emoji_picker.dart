import 'package:coelo_tokens/coelo_tokens.dart';
import 'package:flutter/material.dart';

final class SuperadminChatEmojiPicker extends StatefulWidget {
  const SuperadminChatEmojiPicker({required this.onSelected, super.key});

  final ValueChanged<String> onSelected;

  @override
  State<SuperadminChatEmojiPicker> createState() => _SuperadminChatEmojiPickerState();
}

final class _SuperadminChatEmojiPickerState extends State<SuperadminChatEmojiPicker> {
  static final _recent = <String>[];
  static const _entries = <_EmojiEntry>[
    _EmojiEntry('\u{1F60A}', 'Rostos', 'sorriso feliz'),
    _EmojiEntry('\u{1F602}', 'Rostos', 'risada alegria'),
    _EmojiEntry('\u{1F622}', 'Rostos', 'triste choro'),
    _EmojiEntry('\u{1F609}', 'Rostos', 'piscada'),
    _EmojiEntry('\u{1F60D}', 'Rostos', 'amor coracao olhos'),
    _EmojiEntry('\u{1F914}', 'Rostos', 'pensando duvida'),
    _EmojiEntry('\u{2764}\u{FE0F}', 'Gestos', 'coracao amor'),
    _EmojiEntry('\u{1F44D}', 'Gestos', 'curtir positivo'),
    _EmojiEntry('\u{1F44F}', 'Gestos', 'palmas parabens'),
    _EmojiEntry('\u{1F64F}', 'Gestos', 'agradecimento'),
    _EmojiEntry('\u{1F389}', 'Atividades', 'festa parabens'),
    _EmojiEntry('\u{2728}', 'Atividades', 'brilho destaque'),
    _EmojiEntry('\u{1F4CC}', 'Objetos', 'alfinete importante'),
    _EmojiEntry('\u{1F4F7}', 'Objetos', 'foto camera'),
    _EmojiEntry('\u{1F4DA}', 'Objetos', 'livros estudo'),
  ];

  final _search = TextEditingController();
  var _category = 'Rostos';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(String emoji) {
    _recent
      ..remove(emoji)
      ..insert(0, emoji);
    if (_recent.length > 12) _recent.removeLast();
    widget.onSelected(emoji);
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final categories = <String>[
      'Recentes',
      ...{for (final item in _entries) item.category},
    ];
    final entries = query.isNotEmpty
        ? _entries
              .where((item) => item.keywords.contains(query) || item.value.contains(query))
              .toList()
        : _category == 'Recentes'
        ? _recent.map((value) => _entries.firstWhere((item) => item.value == value)).toList()
        : _entries.where((item) => item.category == _category).toList();
    final colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('superadmin-chat-emoji-picker'),
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(CoeloRadius.xl)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(CoeloSpacing.space3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Buscar emoji',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              SizedBox(
                height: CoeloSize.touchMin,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: CoeloSpacing.space1),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final selected = category == _category && query.isEmpty;
                    return TextButton(
                      onPressed: () {
                        _search.clear();
                        setState(() => _category = category);
                      },
                      style: TextButton.styleFrom(
                        minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin),
                        foregroundColor: selected ? colors.onPrimary : colors.primary,
                        backgroundColor: selected ? colors.primary : colors.primaryContainer,
                      ),
                      child: Text(category),
                    );
                  },
                ),
              ),
              const SizedBox(height: CoeloSpacing.space2),
              Wrap(
                spacing: CoeloSpacing.space1,
                children: [
                  _EmoticonShortcut(label: ':)', emoji: '\u{1F60A}', onSelected: _select),
                  _EmoticonShortcut(label: ';)', emoji: '\u{1F609}', onSelected: _select),
                  _EmoticonShortcut(label: '<3', emoji: '\u{2764}\u{FE0F}', onSelected: _select),
                ],
              ),
              const SizedBox(height: CoeloSpacing.space2),
              SizedBox(
                height: CoeloSize.touchMin * 2,
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty ? 'Nenhum emoji recente' : 'Nenhum emoji encontrado',
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          mainAxisExtent: CoeloSize.touchMin,
                        ),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final emoji = entries[index];
                          return Tooltip(
                            message: 'Inserir ${emoji.keywords}',
                            child: TextButton(
                              onPressed: () => _select(emoji.value),
                              style: TextButton.styleFrom(
                                minimumSize: const Size.square(CoeloSize.touchMin),
                                padding: EdgeInsets.zero,
                                foregroundColor: colors.onSurface,
                              ),
                              child: Text(emoji.value, style: const TextStyle(fontSize: 24)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _EmojiEntry {
  const _EmojiEntry(this.value, this.category, this.keywords);

  final String value;
  final String category;
  final String keywords;
}

final class _EmoticonShortcut extends StatelessWidget {
  const _EmoticonShortcut({required this.label, required this.emoji, required this.onSelected});
  final String label;
  final String emoji;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: 'Inserir ',
    child: TextButton(
      onPressed: () => onSelected(emoji),
      style: TextButton.styleFrom(minimumSize: const Size(CoeloSize.touchMin, CoeloSize.touchMin)),
      child: Text(label),
    ),
  );
}
