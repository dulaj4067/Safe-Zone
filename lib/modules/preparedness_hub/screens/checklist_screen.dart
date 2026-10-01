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
  final Map<String, dynamic> _profile = {};

  bool _loading = true;
  String? _errorMessage;

  bool get _canGenerateChecklist =>
      _profile['locationType'] is String &&
      _profile['householdSize'] is String &&
      _profile['hasVehicle'] is bool &&
      _profile['hasElderlyMember'] is String &&
      _profile['hasDisabledMember'] is String;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChecklist());
  }

  Future<void> _loadChecklist() async {
    final provider = context.read<PreparednessProvider>();
    final userId = widget.currentUser?.id;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    if (userId == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Sign in to save your preparedness checklist.';
        });
      }
      return;
    }

    try {
      final existingProfile = await provider.getRiskProfile(userId);
      if (existingProfile.isNotEmpty) {
        _profile.clear();
        _profile
          ..addAll(existingProfile)
          ..['hasElderlyMember'] = existingProfile['hasElderlyMember'] == true
              ? 'yes'
              : 'no'
          ..['hasDisabledMember'] = existingProfile['hasDisabledMember'] == true
              ? 'yes'
              : 'no';
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
    final userId = widget.currentUser?.id;
    if (userId == null) return;
    try {
      setState(() => _errorMessage = null);
      final profile = {
        ..._profile,
        'hasElderlyMember': _profile['hasElderlyMember'] == 'yes',
        'hasDisabledMember': _profile['hasDisabledMember'] == 'yes',
      };
      await provider.saveRiskProfile(userId, profile);
      await provider.loadUserChecklist(userId, profile: profile);
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
                      initialValue: _profile['locationType'] as String?,
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
                      initialValue: _profile['householdSize'] as String?,
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
                    DropdownButtonFormField<String>(
                      initialValue: _profile['hasElderlyMember'] as String?,
                      decoration: const InputDecoration(
                        labelText: 'Household has elderly members',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'yes', child: Text('Yes')),
                        DropdownMenuItem(value: 'no', child: Text('No')),
                      ],
                      onChanged: (value) =>
                          setState(() => _profile['hasElderlyMember'] = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _profile['hasDisabledMember'] as String?,
                      decoration: const InputDecoration(
                        labelText: 'Household has disabled members',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'yes', child: Text('Yes')),
                        DropdownMenuItem(value: 'no', child: Text('No')),
                      ],
                      onChanged: (value) =>
                          setState(() => _profile['hasDisabledMember'] = value),
                    ),
                    DropdownButtonFormField<bool>(
                      initialValue: _profile['hasVehicle'] as bool?,
                      decoration: const InputDecoration(
                        labelText: 'Household has access to a vehicle',
                      ),
                      items: const [
                        DropdownMenuItem(value: true, child: Text('Yes')),
                        DropdownMenuItem(value: false, child: Text('No')),
                      ],
                      onChanged: (value) =>
                          setState(() => _profile['hasVehicle'] = value),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _canGenerateChecklist
                            ? _saveProfileAndRefresh
                            : null,
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
                    final userId = widget.currentUser?.id;
                    if (userId == null) return;
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
