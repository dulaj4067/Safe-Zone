import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/family_member.dart';
import '../models/risk_zone.dart';
import '../models/safety_circle_request.dart';
import '../providers/safety_provider.dart';
import '../theme/app_colors.dart';
import '../utils/format_utils.dart';
import 'live_eta_sharing_screen.dart';
import '../l10n/ui_text.dart';
import '../utils/error_messages.dart';
import '../utils/validators.dart';

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
      ).showSnackBar(SnackBar(content: Text(context.tr(friendlyError(e)))));
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
            child: Text(context.tr('Cancel')),
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
        title: Text(context.tr('Family circle')),
        actions: [
          IconButton(
            tooltip: context.tr('Join with a code'),
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
                  Text(context.tr('Family members can see each other\'s location while sharing. People join with an invite link and have to confirm before anything is shared.'),
                    style: textTheme.bodyMedium,
                  ),
                  if (safety.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      context.tr(safety.errorMessage!),
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
                    Text(context.tr('Open invite links'), style: textTheme.titleSmall),
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
                      label: Text(context.tr('Invite family member')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // One button, one place: it starts sharing right here and,
                  // while a share is running, ends it. There is no separate
                  // screen, because family locations are shown on the Home map.
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: safety.isSharing
                        ? ElevatedButton.icon(
                            key: const Key('stop_sharing_button'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.severityRed,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(Icons.stop_circle_outlined),
                            label: Text(appStringsOf(context).t('stopSharing')),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final text = appStringsOf(context, listen: false)
                                  .t('stoppedSharing');
                              await context.read<SafetyProvider>().stopSharing();
                              messenger.showSnackBar(SnackBar(content: Text(text)));
                            },
                          )
                        : ElevatedButton.icon(
                            key: const Key('start_sharing_button'),
                            icon: const Icon(Icons.share_location),
                            label: Text(appStringsOf(context).t('startSharing')),
                            onPressed: confirmedCount == 0
                                ? null
                                : () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    final provider = context.read<SafetyProvider>();
                                    final text = appStringsOf(context, listen: false)
                                        .t('sharingStarted');
                                    await provider.startSharingEta(
                                      currentRiskZone: widget.currentRiskZone,
                                    );
                                    // A failure shows its own message above.
                                    if (provider.errorMessage == null) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text(text)),
                                      );
                                    }
                                  },
                          ),
                  ),
                  if (!safety.isSharing && confirmedCount == 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        appStringsOf(context).t('addFamilyFirst'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
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
          Text(context.tr('No one in your family circle yet'),
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(context.tr('Send an invite link to a family member to get started.'),
            textAlign: TextAlign.center,
            style: TextStyle(color: context.inkMuted),
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
    final location = member.isSharingNow
        ? 'Sharing their location now'
        : member.lastSeenAt != null
        ? 'Last seen ${timeAgo(member.lastSeenAt!)}'
        : 'Hasn\'t shared a location yet';
    if (member.lastSafeAt == null) return location;
    return 'Marked safe ${timeAgo(member.lastSafeAt!)} · $location';
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
          color: member.isPending ? context.inkMuted : null,
          fontStyle: member.isPending ? FontStyle.italic : null,
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: context.tr('More'),
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
      title: Text(context.tr('Code {p0}', {'p0': invite.code})),
      subtitle: Text(
        days >= 1
            ? 'Not used yet · expires in $days day${days == 1 ? '' : 's'}'
            : 'Not used yet · expires today',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: context.tr('Share link'),
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
          ),
          IconButton(
            tooltip: context.tr('Revoke link'),
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
            Text(context.tr('Invite to your family circle'),
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(context.tr('Send this link to one family member. When they open it, SafeZone emails them and asks them to confirm in the app. The link works once and expires in 7 days.'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.brandInk.withValues(alpha: 0.15),
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
                  Text(context.tr('Or join with code: {code}', {'code': code}),
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
                    label: Text(context.tr('Copy')),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: link.toString()),
                      );
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          SnackBar(content: Text(context.tr('Invite link copied'))),
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
                    label: Text(context.tr('Share')),
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
  String? _error;

  /// Closes with the cleaned code, or explains what is wrong and stays open.
  void _submit() {
    final code = normalizeInviteCode(_controller.text);
    if (code == null) {
      setState(() => _error = context.tr('Enter the 12-character invite code'));
      return;
    }
    Navigator.pop(context, code);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('Join a family circle')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: InputDecoration(
          labelText: context.tr('Invite code'),
          hintText: context.tr('e.g. 3F9A1C7B20DE'),
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: _submit,
          child: Text(context.tr('Join')),
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
    messenger.showSnackBar(SnackBar(content: Text(context.tr(friendlyError(e)))));
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
      icon: Icon(
        Icons.family_restroom,
        color: context.brandInk,
        size: 36,
      ),
      title: Text(context.tr('Join {p0}\'s family circle?', {'p0': request.ownerName})),
      content: Text(context.tr('You and {p0} will be able to see each other\'s location whenever either of you shares it. We\'ve also emailed you about this. Only confirm if you know them.', {'p0': request.ownerName}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.tr('Decline')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.brandFill,
            minimumSize: const Size(0, 40),
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.tr('Confirm')),
        ),
      ],
    ),
  );
  // Dismissed without answering: leave it pending — the banner keeps asking.
  if (accept == null) return;
  await safety.respondToPendingRequest(request.id, accept);
  await safety.loadFamilyCircle();
}
