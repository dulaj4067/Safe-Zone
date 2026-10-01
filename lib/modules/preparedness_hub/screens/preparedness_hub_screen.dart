import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
        const SnackBar(
          content: Text('Only authority accounts can manage this area.'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preparedness hub'),
        actions: [
          if (isAuthority)
            IconButton(
              tooltip: 'Manage evacuation routes',
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
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.cloud_off_outlined),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ready when it matters.',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Practical guidance for your community.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HubAction(
                          icon: Icons.map_outlined,
                          label: 'Evacuation map',
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
                          label: 'Checklist',
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
                          label: 'Volunteer',
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
                          label: 'Disaster history',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DisasterHistoryScreen(
                                zoneId: widget.currentUser?.zoneId ?? '',
                              ),
                            ),
                          ),
                        ),
                        if (isAuthority)
                          _HubAction(
                            icon: Icons.edit_note,
                            label: 'Manage guides',
                            onTap: () => _openAuthorityRoute(
                              context,
                              ManageGuidesScreen(
                                zones: widget.zones,
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                        if (isAuthority)
                          _HubAction(
                            icon: Icons.fact_check_outlined,
                            label: 'Checklist items',
                            onTap: () => _openAuthorityRoute(
                              context,
                              ManageChecklistItemsScreen(
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                        if (isAuthority)
                          _HubAction(
                            icon: Icons.notifications_active_outlined,
                            label: 'Reminders',
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
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _CategoryChip(
                            label: 'All',
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
                    if (upcomingReminders.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(
                        'Upcoming reminders',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...upcomingReminders
                          .take(3)
                          .map(
                            (reminder) => Card(
                              child: ListTile(
                                leading: const Icon(
                                  Icons.notifications_active_outlined,
                                ),
                                title: Text(reminder.title),
                                subtitle: Text(
                                  '${MaterialLocalizations.of(context).formatShortDate(reminder.scheduledDate)} • ${reminder.message}',
                                ),
                              ),
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            if (provider.isLoading && provider.guides.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (guides.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('No guides in this category yet.')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: guides.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
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
  GuideCategory.flood => 'Flood',
  GuideCategory.fire => 'Fire',
  GuideCategory.earthquake => 'Earthquake',
  GuideCategory.general => 'General',
};

class _HubAction extends StatelessWidget {
  const _HubAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
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
      onSelected: (_) => onTap(),
    ),
  );
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.guide, required this.onTap});
  final PreparednessGuide guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (guide.coverImageUrl.isNotEmpty)
            SizedBox(
              height: 156,
              width: double.infinity,
              child: guide.coverImageUrl.startsWith('http')
                  ? Image.network(
                      guide.coverImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _GuidePlaceholder(),
                    )
                  : Image.file(
                      File(guide.coverImageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _GuidePlaceholder(),
                    ),
            )
          else
            const _GuidePlaceholder(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _categoryName(guide.category).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  guide.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  guide.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _GuidePlaceholder extends StatelessWidget {
  const _GuidePlaceholder();

  @override
  Widget build(BuildContext context) => Container(
    height: 156,
    width: double.infinity,
    color: Theme.of(context).colorScheme.primaryContainer,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Icon(
      Icons.health_and_safety_outlined,
      size: 48,
      color: Theme.of(context).colorScheme.primary,
    ),
  );
}

class GuideDetailScreen extends StatelessWidget {
  const GuideDetailScreen({super.key, required this.guide});
  final PreparednessGuide guide;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_categoryName(guide.category))),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          guide.title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Updated ${MaterialLocalizations.of(context).formatShortDate(guide.updatedAt)}',
        ),
        const SizedBox(height: 16),
        if (guide.coverImageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: guide.coverImageUrl.startsWith('http')
                ? Image.network(
                    guide.coverImageUrl,
                    height: 210,
                    fit: BoxFit.cover,
                  )
                : Image.file(
                    File(guide.coverImageUrl),
                    height: 210,
                    fit: BoxFit.cover,
                  ),
          ),
        const SizedBox(height: 16),
        GuideMarkdown(content: guide.bodyContent),
      ],
    ),
  );
}
