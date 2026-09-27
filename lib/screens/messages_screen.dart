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
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
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
              'No messages yet.\nOpen a shelter on the map and tap '
              '"Message shelter manager" to start a conversation.',
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
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.seafoam,
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.deepEstuary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '$shelterName · ${fromMe ? 'You: ' : ''}${c.lastMessage.message}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              timeAgo(c.lastMessage.createdAt),
              style: Theme.of(context).textTheme.bodySmall,
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
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
