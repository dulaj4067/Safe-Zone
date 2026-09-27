import 'package:flutter/material.dart';

import '../services/feedback_service.dart';
import '../theme/app_colors.dart';

/// Citizen feedback form (`feedback_forms`): a 1–5 rating of how well
/// they're being supported, plus anything they still need. Tagged with the
/// citizen's zone so authorities can see where needs cluster.
Future<void> showFeedbackSheet(BuildContext context, {String? zoneId}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _FeedbackSheet(zoneId: zoneId),
  );
}

class _FeedbackSheet extends StatefulWidget {
  final String? zoneId;

  const _FeedbackSheet({this.zoneId});

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _needs = TextEditingController();
  int _rating = 0;
  bool _saving = false;
  String? _error;

  static const _ratingLabels = ['', 'Very poor', 'Poor', 'Okay', 'Good', 'Very good'];

  @override
  void dispose() {
    _needs.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Tap a star to rate first.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await FeedbackService().submit(
        rating: _rating,
        needs: _needs.text,
        zoneId: widget.zoneId,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your feedback was sent to local authorities.')),
      );
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Couldn\'t send feedback: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Send feedback', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('How well are you being supported during this emergency?', style: textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var star = 1; star <= 5; star++)
                IconButton(
                  iconSize: 36,
                  tooltip: _ratingLabels[star],
                  onPressed: () => setState(() {
                    _rating = star;
                    _error = null;
                  }),
                  icon: Icon(
                    star <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: star <= _rating ? AppColors.severityYellow : textTheme.bodySmall?.color,
                  ),
                ),
            ],
          ),
          Center(
            child: Text(
              _ratingLabels[_rating],
              style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _needs,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'What do you still need? (optional)',
              hintText: 'e.g. drinking water, baby formula, transport to a shelter',
              alignLabelWithHint: true,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: AppColors.severityRed, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Send feedback'),
          ),
        ],
      ),
    );
  }
}
