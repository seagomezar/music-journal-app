import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/history_provider.dart';
import '../providers/practice_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';
import 'active_practice_view.dart';
import 'settings_screen.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final TextEditingController _goalController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RoutineProvider>(context, listen: false).loadRoutines();
      Provider.of<HistoryProvider>(context, listen: false).loadSessions();
    });
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  void _showEditGoalDialog(BuildContext context, int currentGoal) {
    _goalController.text = currentGoal.toString();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.translate('update_goal_title')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.translate('update_goal_desc'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.translate('target_minutes'),
                  suffixText: 'mins',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.translate('cancel'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              onPressed: () {
                final mins = int.tryParse(_goalController.text);
                if (mins != null && mins > 0 && mins <= 10080) {
                  Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).updateWeeklyGoal(mins);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.translate('invalid_weekly_goal')),
                    ),
                  );
                }
              },
              child: Text(context.translate('save')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final historyProv = Provider.of<HistoryProvider>(context);
    final routineProv = Provider.of<RoutineProvider>(context);
    final practiceProv = Provider.of<PracticeProvider>(context, listen: false);
    final localizationProv = context.watch<LocalizationProvider>();

    final user = authProv.user;
    final weeklyGoal = user?.weeklyPracticeGoalMinutes ?? 120;
    final weeklyMins = historyProv.thisWeekMinutesPracticed;
    final weeklyProgress = weeklyGoal > 0
        ? (weeklyMins / weeklyGoal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await historyProv.loadSessions();
            await routineProv.loadRoutines();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Profile bar
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      backgroundImage: user?.photoUrl != null
                          ? NetworkImage(user!.photoUrl!)
                          : null,
                      child: user?.photoUrl == null
                          ? Text(
                              (user?.name.isNotEmpty == true)
                                  ? user!.name[0].toUpperCase()
                                  : 'F',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.translate('welcome_back'),
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                          ),
                          Text(
                            user?.name ?? 'Flutist',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: localizationProv.isSpanish
                          ? 'English'
                          : 'Español',
                      icon: Icon(
                        Icons.language_rounded,
                        color: AppTheme.accentColor(context),
                      ),
                      onPressed: () {
                        localizationProv.setLocale(
                          localizationProv.isSpanish ? 'en' : 'es',
                        );
                      },
                    ),
                    IconButton(
                      tooltip: context.translate('settings'),
                      icon: Icon(
                        Icons.settings_outlined,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Weekly Goal Progress Card
                AppTheme.glassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.translate('weekly_progress'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: AppTheme.accentColor(context),
                            ),
                            tooltip: context.translate('update_goal_title'),
                            onPressed: () =>
                                _showEditGoalDialog(context, weeklyGoal),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$weeklyMins',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accentColor(context),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ $weeklyGoal ${context.translate('minutes')}',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: weeklyProgress,
                          minHeight: 10,
                          backgroundColor: AppTheme.borderColor(
                            context,
                          ).withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.accentColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('weekly_goal_target', [
                          (weeklyProgress * 100).toStringAsFixed(0),
                        ]),
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Grid Statistics Dashboard
                LayoutBuilder(
                  builder: (context, constraints) {
                    final useFourColumns = constraints.maxWidth >= 760;
                    return GridView.count(
                      crossAxisCount: useFourColumns ? 4 : 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 112,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Streak Card
                        _buildStatCard(
                          context,
                          title: context.translate('current_streak_title'),
                          value:
                              '${historyProv.currentStreak} ${context.translate('days')}',
                          icon: Icons.local_fire_department_rounded,
                          iconColor: Colors.orangeAccent,
                        ),
                        // Total Sessions
                        _buildStatCard(
                          context,
                          title: context.translate('total_sessions_title'),
                          value: '${historyProv.totalSessionsCount}',
                          icon: Icons.history_toggle_off_rounded,
                          iconColor: Colors.tealAccent,
                        ),
                        // Exercises Finished
                        _buildStatCard(
                          context,
                          title: context.translate('exercises_done_title'),
                          value: '${historyProv.totalExercisesCompleted}',
                          icon: Icons.checklist_rtl_rounded,
                          iconColor: Colors.lightBlueAccent,
                        ),
                        // Total Practice Hours
                        _buildStatCard(
                          context,
                          title: context.translate('total_study_time_title'),
                          value: '${historyProv.totalMinutesPracticed}m',
                          icon: Icons.timer_outlined,
                          iconColor: Colors.purpleAccent,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                // Quick Start Practice Header
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.translate('quick_start'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15),
                        foregroundColor: AppTheme.accentColor(context),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 0.5,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        context.translate('free_study'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: () {
                        practiceProv.startSession(null);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ActivePracticeView(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Routines List inside Dashboard
                if (routineProv.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (routineProv.routines.isEmpty)
                  AppTheme.glassCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          context.translate('no_routines_configured'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: routineProv.routines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final routine = routineProv.routines[index];
                      return GestureDetector(
                        onTap: () {
                          practiceProv.startSession(routine);
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ActivePracticeView(),
                            ),
                          );
                        },
                        child: AppTheme.glassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.playlist_play_rounded,
                                  color: AppTheme.accentColor(context),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      routine.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.translate(
                                        'technical_exercises_count',
                                        [routine.exercises.length.toString()],
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.play_circle_fill_rounded,
                                size: 36,
                                color: AppTheme.accentColor(context),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return AppTheme.glassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 28,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
