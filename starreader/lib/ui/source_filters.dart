import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/extensions.dart';
import '../main.dart' show message;

Future<void> editSourceFilters(
  BuildContext context,
  ExtensionMangaSource source,
) async {
  try {
    final filters = source.appliedFilters.isEmpty
        ? await source.filters()
        : (jsonDecode(jsonEncode(source.appliedFilters)) as List)
              .map((f) => Map<String, dynamic>.from(f))
              .toList();
    if (!context.mounted) return;
    final result = await showModalBottomSheet<List<Map<String, dynamic>>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(filters: filters, source: source),
    );
    if (result != null) source.appliedFilters = result;
  } catch (e) {
    if (context.mounted) message(context, e);
  }
}

class _FilterSheet extends StatefulWidget {
  final List<Map<String, dynamic>> filters;
  final ExtensionMangaSource source;
  const _FilterSheet({required this.filters, required this.source});
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late List<Map<String, dynamic>> filters = widget.filters;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .85,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Find your kind of story',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Close filters',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (filters.isEmpty)
                const Text(
                  'This source does not provide extra search filters.',
                ),
              ...fields(filters),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () async {
                    try {
                      final defaults = await widget.source.filters();
                      if (mounted) setState(() => filters = defaults);
                    } catch (e) {
                      if (context.mounted) message(context, e);
                    }
                  },
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, filters),
                    child: const Text('Apply filters'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  List<Widget> fields(List<dynamic> entries) => entries.map<Widget>((raw) {
    final f = raw as Map;
    final name = f['name']?.toString() ?? '';
    Widget field;
    switch (f['type']) {
      case 'header':
        field = Text(name, style: Theme.of(context).textTheme.titleSmall);
      case 'separator':
        field = const Divider();
      case 'check':
        field = SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(name),
          value: f['value'] == true,
          onChanged: (v) => setState(() => f['value'] = v),
        );
      case 'tri':
        field = DropdownButtonFormField<int>(
          key: ValueKey('$name-${f['value']}'),
          initialValue: f['value'] as int? ?? 0,
          decoration: InputDecoration(labelText: name),
          items: const [
            DropdownMenuItem(value: 0, child: Text('Any')),
            DropdownMenuItem(value: 1, child: Text('Include')),
            DropdownMenuItem(value: 2, child: Text('Exclude')),
          ],
          onChanged: (v) => setState(() => f['value'] = v),
        );
      case 'select':
      case 'sort':
        final values = (f['values'] as List? ?? [])
            .map((v) => v.toString())
            .toList();
        field = Column(
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey('$name-${f['value']}'),
              isExpanded: true,
              initialValue: values.isEmpty
                  ? null
                  : (f['value'] as int? ?? 0).clamp(0, values.length - 1),
              decoration: InputDecoration(labelText: name),
              items: [
                for (var i = 0; i < values.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text(values[i], overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => f['value'] = v),
            ),
            if (f['type'] == 'sort')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ascending order'),
                value: f['ascending'] != false,
                onChanged: (v) => setState(() => f['ascending'] = v),
              ),
          ],
        );
      case 'text':
        field = TextFormField(
          key: ValueKey('$name-${identityHashCode(f)}'),
          initialValue: f['value']?.toString() ?? '',
          decoration: InputDecoration(labelText: name),
          onChanged: (v) => f['value'] = v,
        );
      case 'group':
        field = ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(name),
          children: fields(f['children'] as List? ?? []),
        );
      default:
        field = Text('$name · not supported by this host');
    }
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: field);
  }).toList();
}
