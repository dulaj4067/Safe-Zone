import 'package:flutter/material.dart';

import '../models/coordination_message.dart';
import '../services/coordination_service.dart';
import '../services/profile_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';

/// One conversation with one person about one shelter, updated live.
class MessageThreadScreen extends StatefulWidget {
  final String shelterId;
  final String shelterName;
  final String otherUserId;

  /// Shown until the other person's profile name loads.
  final String otherUserLabel;

  const MessageThreadScreen({
    super.key,
    required this.shelterId,
    required this.shelterName,
    required this.otherUserId,
    this.otherUserLabel = 'Shelter manager',
  });

  @override
  State<MessageThreadScreen> createState() => _MessageThreadScreenState();
}

class _MessageThreadScreenState extends State<MessageThreadScreen> {
  final CoordinationService _service = CoordinationService();
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final String? _me = SupabaseService.currentUserId;

  List<CoordinationMessage>? _messages;
  String? _otherName;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    ProfileService.fetchNames([widget.otherUserId]).then((names) {
      if (mounted) setState(() => _otherName = names[widget.otherUserId]);
    });
    _service.subscribeToShelter(widget.shelterId, _onLiveMessage);
  }

  @override
  void dispose() {
    _service.unsubscribe();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final messages = await _service.fetchThread(
        shelterId: widget.shelterId,
        otherUserId: widget.otherUserId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _error = null;
      });
      _scrollToEnd();
    } catch (e) {
      if (mounted) setState(() => _error = 'Couldn\'t load messages.');
    }
  }

  void _onLiveMessage(CoordinationMessage message) {
    final me = _me;
    if (me == null || !message.isBetween(me, widget.otherUserId)) return;
    final current = _messages ?? [];
    if (current.any((m) => m.id == message.id)) return;
    if (!mounted) return;
    setState(() => _messages = [...current, message]);
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await _service.send(
        shelterId: widget.shelterId,
        recipientId: widget.otherUserId,
        message: text,
      );
      _composer.clear();
      _onLiveMessage(sent);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Message not sent: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_otherName ?? widget.otherUserLabel,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(widget.shelterName,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : messages == null
                      ? const Center(child: CircularProgressIndicator())
                      : messages.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No messages yet. Ask about space, supplies, '
                                  'or how you can help.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.all(12),
                              itemCount: messages.length,
                              itemBuilder: (context, i) => _Bubble(
                                message: messages[i],
                                mine: messages[i].senderId == _me,
                              ),
                            ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Write a message'),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final CoordinationMessage message;
  final bool mine;

  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final bg = mine ? AppColors.deepEstuary : Theme.of(context).cardColor;
    final fg = mine ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: mine ? null : Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.message, style: TextStyle(color: fg, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              timeAgo(message.createdAt),
              style: TextStyle(color: fg?.withValues(alpha: 0.7), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
