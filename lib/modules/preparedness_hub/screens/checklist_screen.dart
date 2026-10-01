import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/app_user.dart';
import '../models/checklist_item.dart';
import '../providers/preparedness_provider.dart';

class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({super.key, required this.currentUser});

  final AppUser? currentUser;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final Map<String, dynamic> _profile = {
    'locationType': 'low-lying',
    'householdSize': '3-4',
    'hasElderlyMember': false,
    'hasDisabledMember': false,
    'hasVehicle': true,
  };

  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChecklist());
  }

  Future<void> _loadChecklist() async {
    final provider = context.read<PreparednessProvider>();
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final userId = widget.currentUser?.id ?? 'guest';
      final existingProfile = await provider.getRiskProfile(userId);
      if (existingProfile.isNotEmpty) {
        _profile.clear();
        _profile.addAll(existingProfile);
      }
      await provider.loadUserChecklist(userId, profile: _profile);
    } catch (error) {
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfileAndRefresh() async {
    final provider = context.read<PreparednessProvider>();
    final userId = widget.currentUser?.id ?? 'guest';
    try {
      setState(() => _errorMessage = null);
      await provider.saveRiskProfile(userId, _profile);
      await provider.loadUserChecklist(userId, profile: _profile);
    } catch (error) {
      if (mounted) setState(() => _errorMessage = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreparednessProvider>();
    final checklist = provider.personalChecklist;
    final completed = checklist.where((item) => item.isDone).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Preparedness checklist')),
      body: RefreshIndicator(
        onRefresh: () => _loadChecklist(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Household risk profile',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _profile['locationType'] as String?,
                      decoration: const InputDecoration(
                        labelText: 'Location type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'low-lying',
                          child: Text('Low-lying / flood prone'),
                        ),
                        DropdownMenuItem(
                          value: 'riverside',
                          child: Text('Riverside / flood plain'),
                        ),
                        DropdownMenuItem(
                          value: 'hillside',
                          child: Text('Hillside / wildfire prone'),
                        ),
                        DropdownMenuItem(
                          value: 'urban',
                          child: Text('Urban / general'),
                        ),
                      ],
                      onChanged: (value) => setState(
                        () => _profile['locationType'] = value ?? 'urban',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _profile['householdSize'] as String?,
                      decoration: const InputDecoration(
                        labelText: 'Household size',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: '1-2',
                          child: Text('1-2 people'),
                        ),
                        DropdownMenuItem(
                          value: '3-4',
                          child: Text('3-4 people'),
                        ),
                        DropdownMenuItem(value: '5+', child: Text('5+ people')),
                      ],
                      onChanged: (value) => setState(
                        () => _profile['householdSize'] = value ?? '3-4',
                      ),
                    ),
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      value: _profile['hasElderlyMember'] as bool? ?? false,
                      title: const Text('Household has elderly members'),
                      onChanged: (value) => setState(
                        () => _profile['hasElderlyMember'] = value ?? false,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: _profile['hasDisabledMember'] as bool? ?? false,
                      title: const Text('Household has disabled members'),
                      onChanged: (value) => setState(
                        () => _profile['hasDisabledMember'] = value ?? false,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: _profile['hasVehicle'] as bool? ?? true,
                      title: const Text('Household has a vehicle'),
                      onChanged: (value) => setState(
                        () => _profile['hasVehicle'] = value ?? true,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saveProfileAndRefresh,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Generate checklist'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Could not load your checklist. Please try again.\n$_errorMessage',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else if (checklist.isEmpty)
              const Center(
                child: Text(
                  'No checklist items match your household profile yet.',
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your plan',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$completed/${checklist.length} completed',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: checklist.isEmpty ? 0 : completed / checklist.length,
              ),
              const SizedBox(height: 16),
              ...checklist.map(
                (item) => _ChecklistTile(
                  item: item,
                  onToggle: () async {
                    final userId = widget.currentUser?.id ?? 'guest';
                    await provider.toggleChecklistItem(
                      userId,
                      item.id,
                      !item.isDone,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.item, required this.onToggle});

  final ChecklistItem item;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: CheckboxListTile(
        value: item.isDone,
        onChanged: (_) => onToggle(),
        title: Text(
          item.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            decoration: item.isDone ? TextDecoration.lineThrough : null,
            fontWeight: item.isDone ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        subtitle: item.description.isEmpty
            ? null
            : Text(item.description, style: theme.textTheme.bodyMedium),
        secondary: const Icon(Icons.checklist_outlined),
      ),
    );
  }
}
