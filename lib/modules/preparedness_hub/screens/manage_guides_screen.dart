import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../models/zone.dart';
import '../models/preparedness_guide.dart';
import '../providers/preparedness_provider.dart';

class ManageGuidesScreen extends StatelessWidget {
  const ManageGuidesScreen({super.key, required this.zones});
  final List<Zone> zones;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreparednessProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage guides')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editGuide(context),
        icon: const Icon(Icons.add),
        label: const Text('New guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: provider.guides.map((guide) => Card(
          child: ListTile(
            title: Text(guide.title),
            subtitle: Text('${guide.category.name}  -  ${guide.isArchived ? 'Archived' : 'Published'}'),
            leading: Icon(guide.isArchived ? Icons.inventory_2_outlined : Icons.menu_book_outlined),
            onTap: () => _editGuide(context, guide),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') await _editGuide(context, guide);
                if (value == 'archive') {
                  await provider.archiveGuide(guide.id);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (!guide.isArchived)
                  const PopupMenuItem(value: 'archive', child: Text('Archive')),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Future<void> _editGuide(BuildContext context, [PreparednessGuide? guide]) async {
    final provider = context.read<PreparednessProvider>();
    final saved = await showModalBottomSheet<PreparednessGuide>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GuideEditor(guide: guide, zones: zones),
    );
    if (!context.mounted || saved == null) return;
    await provider.saveGuide(saved);
  }
}

class _GuideEditor extends StatefulWidget {
  const _GuideEditor({required this.guide, required this.zones});
  final PreparednessGuide? guide;
  final List<Zone> zones;

  @override
  State<_GuideEditor> createState() => _GuideEditorState();
}

class _GuideEditorState extends State<_GuideEditor> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _image;
  late GuideCategory _category;
  late Set<String> _zoneTags;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final guide = widget.guide;
    _title = TextEditingController(text: guide?.title);
    _body = TextEditingController(text: guide?.bodyContent);
    _image = TextEditingController(text: guide?.coverImageUrl);
    _category = guide?.category ?? GuideCategory.general;
    _zoneTags = {...?guide?.zoneTags};
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.guide == null ? 'Create guide' : 'Edit guide',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<GuideCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: GuideCategory.values.map((value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.name[0].toUpperCase() + value.name.substring(1)),
                )).toList(),
                onChanged: (value) => setState(() => _category = value ?? _category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _image,
                decoration: InputDecoration(
                  labelText: 'Cover image URL or local path',
                  suffixIcon: IconButton(
                    tooltip: 'Choose image',
                    icon: const Icon(Icons.photo_library_outlined),
                    onPressed: () async {
                      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (image != null) setState(() => _image.text = image.path);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _selectZones,
                icon: const Icon(Icons.location_on_outlined),
                label: Text(_zoneTags.isEmpty ? 'All zones' : '${_zoneTags.length} zones selected'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _body,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Guide content (Markdown)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving || _title.text.trim().isEmpty ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save guide'),
                ),
              ),
            ],
          ),
        ),
      );

  Future<void> _selectZones() async {
    final selected = Set<String>.from(_zoneTags);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Show guide in zones'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: [
                CheckboxListTile(
                  value: selected.isEmpty,
                  title: const Text('All zones'),
                  onChanged: (_) => setDialogState(() => selected.clear()),
                ),
                ...widget.zones.map((zone) => CheckboxListTile(
                  value: selected.contains(zone.id),
                  title: Text(zone.name),
                  onChanged: (value) => setDialogState(() {
                    if (value == true) {
                      selected.add(zone.id);
                    } else {
                      selected.remove(zone.id);
                    }
                  }),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Done')),
          ],
        ),
      ),
    );
    if (result != null) setState(() => _zoneTags = result);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final now = DateTime.now();
    final original = widget.guide;
    Navigator.pop(
      context,
      PreparednessGuide(
        id: original?.id ?? 'guide-${now.microsecondsSinceEpoch}',
        title: _title.text.trim(),
        category: _category,
        bodyContent: _body.text.trim(),
        coverImageUrl: _image.text.trim(),
        zoneTags: _zoneTags.toList(),
        createdBy: original?.createdBy ?? 'Local Authority',
        createdAt: original?.createdAt ?? now,
        updatedAt: now,
        isArchived: original?.isArchived ?? false,
      ),
    );
  }
}