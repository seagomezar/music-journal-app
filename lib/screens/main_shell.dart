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

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: _views,
          ),
          
          // Floating active session card
          if (practiceProv.isActive)
            Positioned(
              bottom: kBottomNavigationBarHeight + 20,
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  customColor: AppTheme.primary.withOpacity(0.95),
                  child: Row(
                     children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.music_note, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.translate('active_practice_session'),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              practiceProv.activeRoutine != null 
                                  ? context.translate('routine_label', [practiceProv.activeRoutine!.title])
                                  : context.translate('free_study_piece'),
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDuration(practiceProv.secondsElapsed),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard_rounded),
              label: context.translate('dashboard_nav'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              activeIcon: const Icon(Icons.playlist_add_check_circle),
              label: context.translate('routines'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.library_music_outlined),
              activeIcon: const Icon(Icons.library_music),
              label: context.translate('repertoire'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_outlined),
              activeIcon: const Icon(Icons.calendar_month),
              label: context.translate('history'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
