import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/app_user.dart';
import '../../../models/zone.dart';
import '../../../screens/volunteer_tasks_screen.dart';
import '../models/preparedness_guide.dart';
import '../providers/preparedness_provider.dart';
import '../widgets/guide_markdown.dart';
import 'checklist_screen.dart';
import 'disaster_history_screen.dart';
import 'evacuation_map_screen.dart';
import 'manage_checklist_screen.dart';
import 'manage_guides_screen.dart';
import 'manage_reminders_screen.dart';
import 'manage_routes_screen.dart';
import '../../../l10n/ui_text.dart';

class PreparednessHubScreen extends StatefulWidget {
  const PreparednessHubScreen({
    super.key,
    required this.currentUser,
    required this.zones,
  });

  final AppUser? currentUser;
  final List<Zone> zones;

  @override
  State<PreparednessHubScreen> createState() => _PreparednessHubScreenState();
}

class _PreparednessHubScreenState extends State<PreparednessHubScreen> {
  GuideCategory? _category;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PreparednessProvider>().load();
    });
  }

  void _openAuthorityRoute(BuildContext context, Widget page) {
    if (widget.currentUser?.role.isAuthority != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('Only authority accounts can manage this area.')),
        ),
      );
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PreparednessProvider>();
    final isAuthority = widget.currentUser?.role.isAuthority ?? false;
    final guides = provider
        .guidesForZone(widget.currentUser?.zoneId)
        .where((guide) => _category == null || guide.category == _category)
        .toList();
    final upcomingReminders = provider.upcomingRemindersForZone(
      widget.currentUser?.zoneId,
    );
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Preparedness hub')),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          if (isAuthority)
            IconButton(
              tooltip: context.tr('Manage evacuation routes'),
              icon: const Icon(Icons.alt_route),
              onPressed: () => _openAuthorityRoute(
                context,
                ManageRoutesScreen(
                  zones: widget.zones,
                  currentUser: widget.currentUser,
                ),
              ),
            ),
          if (provider.isOffline)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.cloud_off_outlined,
                semanticLabel: appStringsOf(context).t('offlineBanner'),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _HeroHeader(),
                    const SizedBox(height: 20),
                    const _SectionLabel('Quick access'),
                    const SizedBox(height: 10),
                    _ActionGrid(
                      children: [
                        _HubAction(
                          icon: Icons.map_outlined,
                          label: context.tr('Evacuation map'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EvacuationMapScreen(
                                zoneId: widget.currentUser?.zoneId ?? '',
                              ),
                            ),
                          ),
                        ),
                        _HubAction(
                          icon: Icons.checklist_rtl_outlined,
                          label: context.tr('Checklist'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChecklistScreen(
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                        ),
                        _HubAction(
                          icon: Icons.volunteer_activism_outlined,
                          label: context.tr('Volunteer'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VolunteerTasksScreen(zones: widget.zones),
                            ),
                          ),
                        ),
                        _HubAction(
                          icon: Icons.history,
                          label: context.tr('Disaster history'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DisasterHistoryScreen(
                                zoneId: widget.currentUser?.zoneId ?? '',
                                currentUser: widget.currentUser,
                                zones: widget.zones,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (isAuthority) ...[
                      const SizedBox(height: 22),
                      const _SectionLabel('Authority tools'),
                      const SizedBox(height: 10),
                      _ActionGrid(
                        children: [
                          _HubAction(
                            icon: Icons.edit_note,
                            label: 'Manage guides',
                            admin: true,
                            onTap: () => _openAuthorityRoute(
                              context,
                              ManageGuidesScreen(
                                zones: widget.zones,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                          _HubAction(
                            icon: Icons.fact_check_outlined,
                            label: 'Checklist items',
                            admin: true,
                            onTap: () => _openAuthorityRoute(
                              context,
                              ManageChecklistItemsScreen(
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                          _HubAction(
                            icon: Icons.notifications_active_outlined,
                            label: 'Reminders',
                            admin: true,
                            onTap: () => _openAuthorityRoute(
                              context,
                              ManageRemindersScreen(
                                currentUser: widget.currentUser,
                                zones: widget.zones,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (upcomingReminders.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _SectionLabel('Upcoming reminders'),
                      const SizedBox(height: 10),
                      ...upcomingReminders
                          .take(3)
                          .map(
                            (reminder) => _ReminderTile(
                              title: reminder.title,
                              date: MaterialLocalizations.of(
                                context,
                              ).formatShortDate(reminder.scheduledDate),
                              message: reminder.message,
                            ),
                          ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Guides',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (guides.isNotEmpty)
                          Text(
                            '${guides.length}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: context.tr('All'),
                            selected: _category == null,
                            onTap: () => setState(() => _category = null),
                          ),
                          ...GuideCategory.values.map(
                            (category) => _CategoryChip(
                              label: _categoryName(category),
                              selected: _category == category,
                              onTap: () => setState(() => _category = category),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
            if (provider.isLoading && provider.guides.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (guides.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 44,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No guides in this category yet.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverList.separated(
                  itemCount: guides.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) => _GuideCard(
                    guide: guides[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GuideDetailScreen(guide: guides[index]),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _categoryName(GuideCategory category) => switch (category) {
  _ => category.label,
};

// ───────────────────────── Shared pieces ─────────────────────────

class _HeroHeader extends StatelessWidget {
  const _HeroHeader();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.78)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ready when it matters.',
                  style: text.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimary,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Practical guidance for your community.',
                  style: text.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 30,
              color: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    ),
  );
}

/// Lays children out in a responsive two-column grid.
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final width = (constraints.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class _HubAction extends StatelessWidget {
  const _HubAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.admin = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = admin ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final fg = admin ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    return Material(
      color: bg.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                height: 38,
                width: 38,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: fg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    required this.title,
    required this.date,
    required this.message,
  });
  final String title;
  final String date;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              size: 20,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              date,
              style: text.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (_) => onTap(),
    ),
  );
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill(this.label, {this.onImage = false});
  final String label;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onImage
            ? scheme.surface.withValues(alpha: 0.92)
            : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: onImage ? scheme.primary : scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.url, required this.height});
  final String url;
  final double height;

  @override
  Widget build(BuildContext context) {
    final placeholder = _GuidePlaceholder(height: height);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: url.startsWith('http')
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : placeholder,
            )
          : Image.file(
              File(url),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.onTap});
  final PreparednessGuide guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (guide.coverImageUrl.isNotEmpty)
                  _CoverImage(url: guide.coverImageUrl, height: 164)
                else
                  const _GuidePlaceholder(height: 164),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _CategoryPill(
                    _categoryName(guide.category),
                    onImage: true,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guide.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guide.excerpt,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        'Read guide',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ],
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

class _GuidePlaceholder extends StatelessWidget {
  const _GuidePlaceholder({this.height = 156});
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.secondaryContainer.withValues(alpha: 0.8),
          ],
        ),
      ),
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.all(20),
      child: Icon(
        Icons.health_and_safety_outlined,
        size: 56,
        color: scheme.primary.withValues(alpha: 0.7),
      ),
    );
  }
}

// ───────────────────────── Detail screen ─────────────────────────

class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.guide});
  final PreparednessGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasCover = guide.coverImageUrl.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: hasCover ? 240 : null,
            title: Text(_categoryName(guide.category)),
            flexibleSpace: hasCover
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _CoverImage(url: guide.coverImageUrl, height: 240),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black38, Colors.transparent],
                              stops: [0, 0.45],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryPill(_categoryName(guide.category)),
                  const SizedBox(height: 12),
                  Text(
                    guide.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.update,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Updated ${MaterialLocalizations.of(context).formatShortDate(guide.updatedAt)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 12),
                  GuideMarkdown(content: guide.bodyContent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}