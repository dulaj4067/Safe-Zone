import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/family_member.dart';
import '../models/risk_zone.dart';
import '../models/safety_circle_request.dart';
import '../providers/safety_provider.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'live_eta_sharing_screen.dart';

/// Google-family-style circle: everyone joins through a single-use invite
/// link and has to confirm (email + in-app) before anyone's location is
/// visible. Confirmed members see each other's location while sharing.
class FamilyCircleScreen extends StatefulWidget {
  /// Passed through to the live sharing screen; not shown here.
  final RiskZone? currentRiskZone;

  const FamilyCircleScreen({super.key, this.currentRiskZone});

  @override
  State<FamilyCircleScreen> createState() => _FamilyCircleScreenState();
}

class _FamilyCircleScreenState extends State<FamilyCircleScreen> {
  bool _creatingInvite = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SafetyProvider>().loadFamilyCircle();
    });
  }

  Future<void> _invite() async {
    setState(() => _creatingInvite = true);
    try {
      final link = await context.read<SafetyProvider>().createInvite();
      if (!mounted) return;
      await showInviteLinkSheet(context, link);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _creatingInvite = false);
    }
  }

  Future<void> _remove(FamilyMember member) async {
    final leaving = !member.invitedByMe;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          leaving ? 'Leave ${member.name}\'s circle?' : 'Remove ${member.name}?',
        ),
        content: Text(
          member.isPending
              ? 'Their invite will be cancelled.'
              : 'You will stop seeing each other\'s location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.severityRed,
              minimumSize: const Size(0, 40),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(leaving ? 'Leave' : 'Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<SafetyProvider>().removeFamilyMember(member.linkId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safety = context.watch<SafetyProvider>();
    final family = safety.family;
    final invites = safety.openInvites;
    final confirmedCount = safety.confirmedFamily.length;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family circle'),
        actions: [
          IconButton(
            tooltip: 'Join with a code',
            icon: const Icon(Icons.vpn_key_outlined),
            onPressed: () => showJoinWithCodeDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          if (safety.isLoading) const LinearProgressIndicator(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: safety.loadFamilyCircle,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                children: [
                  Text(
                    'Family members can see each other\'s location while '
                    'sharing. People join with an invite link and have to '
                    'confirm before anything is shared.',
                    style: textTheme.bodyMedium,
                  ),
                  if (safety.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      safety.errorMessage!,
                      style: const TextStyle(color: AppColors.severityRed),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (family.isEmpty && !safety.isLoading)
                    const _EmptyFamily()
                  else
                    for (final member in family)
                      _MemberTile(
                        member: member,
                        onRemove: () => _remove(member),
                      ),
                  if (invites.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Open invite links', style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    for (final invite in invites)
                      _InviteTile(
                        invite: invite,
                        onShare: () => showInviteLinkSheet(
                          context,
                          SafetyProvider.inviteLinkFor(invite.code),
                        ),
                        onRevoke: () => context
                            .read<SafetyProvider>()
                            .revokeInvite(invite.code),
                      ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _creatingInvite ? null : _invite,
                      icon: _creatingInvite
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1),
                      label: const Text('Invite family member'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share_location),
                      label: Text(
                        confirmedCount == 0
                            ? 'Invite someone to start sharing'
                            : 'Share my location with family ($confirmedCount)',
                      ),
                      onPressed: confirmedCount == 0
                          ? null
                          : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LiveEtaSharingScreen(
                                  currentRiskZone: widget.currentRiskZone,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFamily extends StatelessWidget {
  const _EmptyFamily();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.family_restroom, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text(
            'No one in your family circle yet',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Send an invite link to a family member to get started.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final FamilyMember member;
  final VoidCallback onRemove;

  const _MemberTile({required this.member, required this.onRemove});

  String get _status {
    if (member.isPending) return 'Waiting for them to confirm';
    if (member.isSharingNow) return 'Sharing their location now';
    if (member.lastSeenAt != null) return 'Last seen ${timeAgo(member.lastSeenAt!)}';
    return 'Hasn\'t shared a location yet';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            backgroundColor: member.isPending
                ? Colors.grey.shade300
                : AppColors.deepEstuary.withValues(alpha: 0.12),
            child: Text(member.initials),
          ),
          if (member.isSharingNow)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.severityGreen,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
        ],
      ),
      title: Text(member.name),
      subtitle: Text(
        _status,
        style: TextStyle(
          color: member.isPending ? AppColors.slateMuted : null,
          fontStyle: member.isPending ? FontStyle.italic : null,
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        onSelected: (_) => onRemove(),
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'remove',
            child: Text(
              member.invitedByMe
                  ? (member.isPending ? 'Cancel invite' : 'Remove from circle')
                  : 'Leave their circle',
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends StatelessWidget {
  final FamilyInvite invite;
  final VoidCallback onShare;
  final VoidCallback onRevoke;

  const _InviteTile({
    required this.invite,
    required this.onShare,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    // Round up, so a fresh 7-day invite reads "7 days", not "6 days".
    final days = (invite.expiresAt.difference(DateTime.now()).inHours / 24)
        .ceil();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(Icons.link, size: 20)),
      title: Text('Code ${invite.code}'),
      subtitle: Text(
        days >= 1
            ? 'Not used yet · expires in $days day${days == 1 ? '' : 's'}'
            : 'Not used yet · expires today',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Share link',
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
          ),
          IconButton(
            tooltip: 'Revoke link',
            icon: const Icon(Icons.link_off),
            onPressed: onRevoke,
          ),
        ],
      ),
    );
  }
}

/// Shows a fresh invite link with Copy / Share buttons.
Future<void> showInviteLinkSheet(BuildContext context, Uri link) {
  final code = link.queryParameters['code'] ?? '';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite to your family circle',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Send this link to one family member. When they open it, '
              'SafeZone emails them and asks them to confirm in the app. '
              'The link works once and expires in 7 days.',
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cloud,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.deepEstuary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    link.toString(),
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Or join with code: $code',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: link.toString()),
                      );
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Invite link copied')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                    onPressed: () => SharePlus.instance.share(
                      ShareParams(
                        subject: 'Join my SafeZone family circle',
                        text:
                            'Join my SafeZone family circle so we can see '
                            'each other\'s location in an emergency: $link\n\n'
                            'Or open SafeZone > Family circle > Join with a '
                            'code and enter $code',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Manual fallback for when a link doesn't open the app directly.
Future<void> showJoinWithCodeDialog(BuildContext context) async {
  final code = await showDialog<String>(
    context: context,
    builder: (_) => const _JoinWithCodeDialog(),
  );
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  await acceptFamilyInvite(context, code.trim());
}

/// Owns its text controller, so the controller is only disposed once the
/// dialog has finished animating out. Disposing it right after
/// `showDialog` returns crashes, because the closing dialog still uses it.
class _JoinWithCodeDialog extends StatefulWidget {
  const _JoinWithCodeDialog();

  @override
  State<_JoinWithCodeDialog> createState() => _JoinWithCodeDialogState();
}

class _JoinWithCodeDialogState extends State<_JoinWithCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Join a family circle'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Invite code',
          hintText: 'e.g. 3F9A1C7B20DE',
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Join'),
        ),
      ],
    );
  }
}

/// Accepts an invite (from a link or a typed code), then asks the user to
/// confirm right away. The email the server sends and the app-wide banner
/// cover the case where they close this without answering.
Future<void> acceptFamilyInvite(BuildContext context, String code) async {
  final safety = context.read<SafetyProvider>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    final request = await safety.acceptInvite(code);
    if (!context.mounted) return;
    await showFamilyRequestDialog(context, request);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// The in-app confirmation for joining someone's family circle.
Future<void> showFamilyRequestDialog(
  BuildContext context,
  SafetyCircleRequest request,
) async {
  final safety = context.read<SafetyProvider>();
  final accept = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.family_restroom,
        color: AppColors.deepEstuary,
        size: 36,
      ),
      title: Text('Join ${request.ownerName}\'s family circle?'),
      content: Text(
        'You and ${request.ownerName} will be able to see each other\'s '
        'location whenever either of you shares it. We\'ve also emailed you '
        'about this. Only confirm if you know them.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Decline'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.deepEstuary,
            minimumSize: const Size(0, 40),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
  // Dismissed without answering: leave it pending — the banner keeps asking.
  if (accept == null) return;
  await safety.respondToPendingRequest(request.id, accept);
  await safety.loadFamilyCircle();
}
