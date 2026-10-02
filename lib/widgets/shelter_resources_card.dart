import 'package:flutter/material.dart';

import '../models/shelter.dart';
import '../models/shelter_resource.dart';
import '../services/shelter_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

/// "Supplies" section of the Shelter page, backed by
/// `shelter_resources`. Everyone sees current stock; the shelter's manager
/// (or an authority) also gets edit / add / remove controls.
class ShelterResourcesCard extends StatefulWidget {
  final Shelter shelter;

  const ShelterResourcesCard({super.key, required this.shelter});

  @override
  State<ShelterResourcesCard> createState() => _ShelterResourcesCardState();
}

class _ShelterResourcesCardState extends State<ShelterResourcesCard> {
  final ShelterService _service = ShelterService();
  List<ShelterResource>? _resources;
  bool _canManage = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _service.fetchResources(widget.shelter.id),
        _service.canManageShelter(widget.shelter),
      ]);
      if (!mounted) return;
      setState(() {
        _resources = results[0] as List<ShelterResource>;
        _canManage = results[1] as bool;
        _failed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  static IconData _iconFor(ResourceType type) => switch (type) {
        ResourceType.water => Icons.water_drop_outlined,
        ResourceType.food => Icons.restaurant_outlined,
        ResourceType.medicine => Icons.medical_services_outlined,
        ResourceType.bedding => Icons.bed_outlined,
        ResourceType.other => Icons.inventory_2_outlined,
      };

  Future<void> _showEditor({ShelterResource? existing}) async {
    final missingTypes = ResourceType.values
        .where((t) => !(_resources ?? []).any((r) => r.type == t))
        .toList();
    var type = existing?.type ?? missingTypes.first;
    final qtyCtrl = TextEditingController(text: existing?.quantityText ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? type.defaultUnit);
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add supply' : 'Update ${existing.type.label}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (existing == null)
                  DropdownButtonFormField<ResourceType>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Supply'),
                    items: [
                      for (final t in missingTypes)
                        DropdownMenuItem(value: t, child: Text(t.label)),
                    ],
                    onChanged: (t) {
                      if (t == null) return;
                      setDialogState(() {
                        type = t;
                        unitCtrl.text = t.defaultUnit;
                      });
                    },
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: qtyCtrl,
                  autofocus: existing != null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Quantity on hand'),
                  validator: (v) {
                    final q = double.tryParse((v ?? '').trim());
                    if (q == null) return 'Enter a number';
                    if (q < 0) return 'Can\'t be negative';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'Unit (liters, meals, kits…)'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Enter a unit' : null,
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: AppColors.severityRed),
                onPressed: () async {
                  try {
                    await _service.deleteResource(existing.id);
                    if (ctx.mounted) Navigator.pop(ctx, true);
                  } catch (e) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(e is StateError ? e.message : 'Couldn\'t remove: $e')),
                      );
                    }
                  }
                },
                child: const Text('Remove'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                final qty = double.parse(qtyCtrl.text.trim());
                final unit = unitCtrl.text.trim();
                try {
                  if (existing == null) {
                    await _service.addResource(
                      shelterId: widget.shelter.id,
                      type: type,
                      quantity: qty,
                      unit: unit,
                    );
                  } else {
                    await _service.updateResource(existing.id, quantity: qty, unit: unit);
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e is StateError ? e.message : 'Couldn\'t save: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final resources = _resources;
    final divider = Divider(height: 1, color: Theme.of(context).dividerTheme.color);

    Widget body;
    if (_failed) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Text('Supply levels are unavailable right now.'),
      );
    } else if (resources == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (resources.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text('No supply levels reported yet.', style: textTheme.bodySmall),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < resources.length; i++) ...[
            if (i > 0) divider,
            InkWell(
              onTap: _canManage ? () => _showEditor(existing: resources[i]) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(_iconFor(resources[i].type), size: 20, color: AppColors.riverTeal),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(resources[i].type.label, style: textTheme.bodyMedium),
                          if (resources[i].updatedAt != null)
                            Text(
                              'Updated ${timeAgo(resources[i].updatedAt!)}',
                              style: textTheme.bodySmall?.copyWith(fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      resources[i].quantityLabel,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: resources[i].quantity == 0 ? AppColors.severityRed : null,
                      ),
                    ),
                    if (_canManage) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.edit_outlined, size: 16, color: textTheme.bodySmall?.color),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    }

    final canAdd = _canManage &&
        resources != null &&
        resources.length < ResourceType.values.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Supplies', style: textTheme.titleMedium),
                const Spacer(),
                if (canAdd)
                  TextButton.icon(
                    onPressed: () => _showEditor(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                  ),
              ],
            ),
            body,
          ],
        ),
      ),
    );
  }
}
