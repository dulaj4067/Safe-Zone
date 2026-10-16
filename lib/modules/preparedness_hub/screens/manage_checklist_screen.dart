import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_user.dart';
import '../models/checklist_item.dart';
import '../providers/preparedness_provider.dart';
import '../../../l10n/ui_text.dart';

class ManageChecklistItemsScreen extends StatelessWidget {
  const ManageChecklistItemsScreen({super.key, required this.currentUser});

  final AppUser? currentUser;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreparednessProvider>();
    if (currentUser?.role.isAuthority != true) {
      return const _AccessDeniedView();
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Manage checklist items'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add_task),
        label: Text(context.tr('New checklist item')),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : provider.masterChecklistItems.isEmpty
          ? Center(
              child: Text(context.tr('No checklist items yet. Add one to get started.')),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: provider.masterChecklistItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = provider.masterChecklistItems[index];
                return Card(
                  child: ListTile(
                    title: Text(item.title),
                    subtitle: Text(item.description),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') await _edit(context, item);
                        if (value == 'delete')
                          await provider.deleteChecklistItem(item.id);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(value: 'edit', child: Text(context.tr('Edit'))),
                        PopupMenuItem(value: 'delete', child: Text(context.tr('Delete'))),
                      ],
                    ),
                    onTap: () => _edit(context, item),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _edit(BuildContext context, [ChecklistItem? item]) async {
    final provider = context.read<PreparednessProvider>();
    final result = await showModalBottomSheet<ChecklistItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ChecklistEditor(item: item),
    );
    if (!context.mounted || result == null) return;
    await provider.saveChecklistItem(result);
  }
}

class _ChecklistEditor extends StatefulWidget {
  const _ChecklistEditor({this.item});

  final ChecklistItem? item;

  @override
  State<_ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<_ChecklistEditor> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late Set<String> _tags;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.item?.title);
    _description = TextEditingController(text: widget.item?.description);
    _tags = {...?widget.item?.riskFactorTags};
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tags = <String>{
      'riverside',
      'low-lying',
      'hillside',
      'urban',
      'small-household',
      'medium-household',
      'elderly-household',
      'disabled-household',
      'no-vehicle',
      'large-household',
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.item == null
                  ? 'Create checklist item'
                  : 'Edit checklist item',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              decoration: InputDecoration(labelText: context.tr('Title')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.tr('Description'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(context.tr('Applies to these household risks')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                final selected = _tags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: selected,
                  onSelected: (_) => setState(() {
                    if (selected) {
                      _tags.remove(tag);
                    } else {
                      _tags.add(tag);
                    }
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _title.text.trim().isEmpty
                    ? null
                    : () {
                        final now = DateTime.now();
                        Navigator.pop(
                          context,
                          ChecklistItem(
                            id:
                                widget.item?.id ??
                                'checklist-${now.microsecondsSinceEpoch}',
                            title: _title.text.trim(),
                            description: _description.text.trim(),
                            riskFactorTags: _tags.toList(),
                            isDone: widget.item?.isDone ?? false,
                          ),
                        );
                      },
                child: Text(context.tr('Save item')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessDeniedView extends StatelessWidget {
  const _AccessDeniedView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Access denied'))),
    body: Center(
      child: Text(context.tr('Only authority accounts can manage checklist items.')),
    ),
  );
}
