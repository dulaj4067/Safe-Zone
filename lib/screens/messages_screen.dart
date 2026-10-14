import 'package:flutter/material.dart';

import '../models/coordination_message.dart';
import '../models/shelter.dart';
import '../services/coordination_service.dart';
import '../services/profile_service.dart';
import '../services/shelter_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'message_thread_screen.dart';

/// Inbox of every shelter conversation the signed-in user is part of —
/// citizens see threads they started with shelter managers; managers see
/// every citizen who has messaged about their shelters.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final CoordinationService _service = CoordinationService();
  List<ConversationSummary>? _conversations;
  Map<String, String> _names = {};
  Map<String, String> _shelterNames = {};
  List<MessageContact> _contacts = [];
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final conversations = await _service.fetchConversations();
      final results = await Future.wait([
        ProfileService.fetchNames(conversations.map((c) => c.otherUserId)),
        ShelterService().fetchShelters(),
      ]);
      if (!mounted) return;
      final shelters = results[1] as List<Shelter>;
      setState(() {
        _conversations = conversations;
        _names = results[0] as Map<String, String>;
        _shelterNames = {for (final s in shelters) s.id: s.name};
        _failed = false;
      });
      _loadContacts();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// Volunteers a shelter manager could message first. Quietly empty for
  /// anyone who doesn't manage a shelter, which hides the button.
  Future<void> _loadContacts() async {
    try {
      final contacts = await _service.fetchStartableContacts();
      final names = await ProfileService.fetchNames(contacts.map((c) => c.userId));
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _names = {..._names, ...names};
      });
    } catch (_) {
      // Leave the button hidden.
    }
  }

  Future<void> _openThread(String shelterId, String shelterName, String userId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageThreadScreen(
          shelterId: shelterId,
          shelterName: shelterName,
          otherUserId: userId,
          otherUserLabel: _names[userId] ?? 'SafeZone user',
        ),
      ),
    );
    _load();
  }

  /// Picker for a manager starting a new conversation.
  Future<void> _startConversation() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Message a volunteer',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final c in _contacts)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.tintSoft,
                  child: Text(
                    (_names[c.userId] ?? '?')[0].toUpperCase(),
                    style: TextStyle(color: context.brandInk, fontWeight: FontWeight.w700),
                  ),
                ),
                title: Text(_names[c.userId] ?? 'SafeZone user'),
                subtitle: Text('Volunteering at ${c.shelterName}'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openThread(c.shelterId, c.shelterName, c.userId);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = _conversations;
    final me = SupabaseService.currentUserId;

    Widget body;
    if (_failed) {
      body = const Center(child: Text('Couldn\'t load your messages.'));
    } else if (conversations == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (conversations.isEmpty) {
      body = ListView(
        children: const [
          SizedBox(height: 120),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'No messages yet.\nOpen a shelter and tap "Message" next to its '
              'manager to start a conversation. Shelter managers can also '
              'message their volunteers with the button below.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      body = ListView.separated(
        itemCount: conversations.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final c = conversations[i];
          final name = _names[c.otherUserId] ?? 'SafeZone user';
          final shelterName = _shelterNames[c.shelterId] ?? 'Shelter';
          final fromMe = c.lastMessage.senderId == me;
          final unread = c.unreadCount > 0;
          return ListTile(
            // The count is a number as well as a colour, so it is readable
            // without colour vision.
            selected: unread,
            leading: CircleAvatar(
              backgroundColor: context.tintSoft,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: context.brandInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(
              name,
              style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600),
            ),
            subtitle: Text(
              '$shelterName · ${fromMe ? 'You: ' : ''}${c.lastMessage.message}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeAgo(c.lastMessage.createdAt), style: Theme.of(context).textTheme.bodySmall),
                if (unread)
                  Semantics(
                    label: '${c.unreadCount} unread',
                    child: Badge(label: Text('${c.unreadCount}')),
                  ),
              ],
            ),
            onTap: c.shelterId == null
                ? null
                : () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MessageThreadScreen(
                          shelterId: c.shelterId!,
                          shelterName: shelterName,
                          otherUserId: c.otherUserId,
                          otherUserLabel: name,
                        ),
                      ),
                    );
                    _load();
                  },
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      floatingActionButton: _contacts.isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('new_message_button'),
              onPressed: _startConversation,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New message'),
            ),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
