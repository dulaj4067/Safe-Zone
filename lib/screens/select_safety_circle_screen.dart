import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/safety_provider.dart';
import '../models/risk_zone.dart';
import 'live_eta_sharing_screen.dart';

Future<void> _showAddContactSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _AddContactSheet(),
  );
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _relationship = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _relationship.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<SafetyProvider>().addContact(
            name: _name.text.trim(),
            phoneNumber: _phone.text.trim(),
            relationship:
                _relationship.text.trim().isEmpty ? 'Contact' : _relationship.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Couldn\'t add contact: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add to safety circle',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'If their phone number matches a registered SafeZone account, '
              'their live location will show up once they share it.',
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: 'e.g. +94 77 123 4567',
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a phone number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _relationship,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Relationship (optional)',
                hintText: 'e.g. Mother, Partner, Roommate',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectSafetyCircleScreen extends StatefulWidget {
  final RiskZone? currentRiskZone;

  const SelectSafetyCircleScreen({super.key, this.currentRiskZone});

  @override
  State<SelectSafetyCircleScreen> createState() => _SelectSafetyCircleScreenState();
}

class _SelectSafetyCircleScreenState extends State<SelectSafetyCircleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SafetyProvider>().loadSafetyCircle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();
    final selectedCount = safety.selectedContacts.length;
    final zone = widget.currentRiskZone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Live Location'),
        actions: [
          IconButton(
            tooltip: 'Add contact',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _showAddContactSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (zone != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: zone.fillColor,
                border: Border.all(color: zone.borderColor),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: zone.borderColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${zone.name} - ${zone.label}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: zone.borderColor),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose who should see your live location and ETA while '
                'you travel through this risk zone.',
                style: TextStyle(fontSize: 15, color: Colors.black87),
              ),
            ),
          ),
          if (safety.isLoading) const LinearProgressIndicator(),
          if (safety.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(safety.errorMessage!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: safety.circle.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final contact = safety.circle[index];
                return Dismissible(
                  key: ValueKey(contact.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red.shade600,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) =>
                      context.read<SafetyProvider>().removeContact(contact.id),
                  child: CheckboxListTile(
                    value: contact.isSelected,
                    onChanged: (checked) => context
                        .read<SafetyProvider>()
                        .toggleContactSelection(contact.id, checked ?? false),
                    secondary: CircleAvatar(child: Text(contact.initials)),
                    title: Text(contact.name),
                    subtitle: Text('${contact.relationship} - ${contact.phoneNumber}'),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.share_location),
                  label: Text(
                    selectedCount == 0
                        ? 'Select at least one contact'
                        : 'Start sharing with $selectedCount contact${selectedCount == 1 ? '' : 's'}',
                  ),
                  onPressed: selectedCount == 0
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LiveEtaSharingScreen(currentRiskZone: zone),
                            ),
                          ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
