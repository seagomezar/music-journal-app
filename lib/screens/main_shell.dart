import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/practice_provider.dart';
import '../providers/localization_provider.dart';
import 'dashboard_view.dart';
import 'routine_config_view.dart';
import 'repertoire_view.dart';
import 'calendar_history_view.dart';
import 'active_practice_view.dart';
import '../theme/app_theme.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _views = [
    const DashboardView(),
    const RoutineConfigView(),
    const RepertoireView(),
    const CalendarHistoryView(),
  ];

  @override
  Widget build(BuildContext context) {
    final practiceProv = Provider.of<PracticeProvider>(context);
    final localizationProv = context.watch<LocalizationProvider>();
    final width = MediaQuery.sizeOf(context).width;
    final useDesktopNavigation = width >= 900;
    final extendDesktopNavigation = width >= 1180;
    final content = _buildContent(
      context,
      practiceProv,
      activeSessionBottom: useDesktopNavigation
          ? 20
          : kBottomNavigationBarHeight + 20,
    );

    if (useDesktopNavigation) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: extendDesktopNavigation,
              minExtendedWidth: 220,
              backgroundColor: AppTheme.surfaceColor(context),
              selectedIndex: _currentIndex,
              labelType: extendDesktopNavigation
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Tooltip(
                  message: context.translate('app_title'),
                  child: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor(context),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: Icon(Icons.music_note_rounded),
                  ),
                ),
              ),
              onDestinationSelected: _selectDestination,
              destinations: [
                NavigationRailDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded),
                  label: Text(localizationProv.translate('dashboard_nav')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.playlist_add_check_circle_outlined),
                  selectedIcon: const Icon(Icons.playlist_add_check_circle),
                  label: Text(localizationProv.translate('routines')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.library_music_outlined),
                  selectedIcon: const Icon(Icons.library_music),
                  label: Text(localizationProv.translate('repertoire')),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month),
                  label: Text(localizationProv.translate('history')),
                ),
              ],
            ),
            VerticalDivider(width: 1, color: AppTheme.borderColor(context)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = constraints.maxWidth > 1100
                      ? 1100.0
                      : constraints.maxWidth;
                  return Center(
                    child: SizedBox(
                      width: contentWidth,
                      height: constraints.maxHeight,
                      child: content,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.borderColor(context), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _selectDestination,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard_rounded),
              label: localizationProv.translate('dashboard_nav'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              activeIcon: const Icon(Icons.playlist_add_check_circle),
              label: localizationProv.translate('routines'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.library_music_outlined),
              activeIcon: const Icon(Icons.library_music),
              label: localizationProv.translate('repertoire'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: localizationProv.translate('history'),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildContent(
    BuildContext context,
    PracticeProvider practiceProv, {
    required double activeSessionBottom,
  }) {
    return Stack(
      children: [
        IndexedStack(index: _currentIndex, children: _views),
        if (practiceProv.isActive)
          Positioned(
            bottom: activeSessionBottom,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const ActivePracticeView(),
                  ),
                );
              },
              child: AppTheme.glassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                customColor: AppTheme.primaryColor(
                  context,
                ).withValues(alpha: 0.95),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onPrimary.withValues(alpha: 0.24),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.translate('active_practice_session'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          Text(
                            practiceProv.activeRoutine != null
                                ? context.translate('routine_label', [
                                    practiceProv.activeRoutine!.title,
                                  ])
                                : context.translate('free_study_piece'),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDuration(practiceProv.secondsElapsed),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
