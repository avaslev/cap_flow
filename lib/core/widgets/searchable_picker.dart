import 'package:flutter/material.dart';

/// Результат выбора в [showSearchablePicker].
///
/// [value] == null — выбрана опция «все» ([allLabel]); иначе — конкретное
/// значение из списка.
class SearchPick {
  final String? value;

  const SearchPick(this.value);
}

/// Модальный выбор значения из списка с поиском по части названия.
///
/// Возвращает [SearchPick] или null, если лист закрыт без выбора.
/// Первым пунктом всегда идёт [allLabel] (сброс фильтра).
Future<SearchPick?> showSearchablePicker(
  BuildContext context, {
  required List<String> items,
  required String allLabel,
  String? selected,
  String searchHint = 'Поиск',
  double heightFactor = 0.6,
}) {
  return showModalBottomSheet<SearchPick>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => _SearchablePickerSheet(
      items: items,
      allLabel: allLabel,
      selected: selected,
      searchHint: searchHint,
      heightFactor: heightFactor,
    ),
  );
}

class _SearchablePickerSheet extends StatefulWidget {
  final List<String> items;
  final String allLabel;
  final String? selected;
  final String searchHint;
  final double heightFactor;

  const _SearchablePickerSheet({
    required this.items,
    required this.allLabel,
    required this.selected,
    required this.searchHint,
    required this.heightFactor,
  });

  @override
  State<_SearchablePickerSheet> createState() => _SearchablePickerSheetState();
}

class _SearchablePickerSheetState extends State<_SearchablePickerSheet> {
  String _search = '';
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get _filtered {
    if (_search.isEmpty) return widget.items;
    final String query = _search.toLowerCase();
    return widget.items
        .where((String item) => item.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final List<String> filtered = _filtered;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * widget.heightFactor,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: widget.searchHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  isDense: true,
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _search = '');
                          },
                        ),
                ),
                onChanged: (String value) => setState(() => _search = value),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: Text(widget.allLabel),
              selected: widget.selected == null,
              onTap: () =>
                  Navigator.pop(context, const SearchPick(null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Ничего не найдено',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: filtered.length,
                      itemBuilder: (BuildContext context, int index) {
                        final String item = filtered[index];
                        return ListTile(
                          leading: const Icon(Icons.label_outline),
                          title: Text(
                            item,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: widget.selected == item,
                          onTap: () =>
                              Navigator.pop(context, SearchPick(item)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
