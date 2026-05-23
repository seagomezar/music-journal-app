import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/history_provider.dart';
import '../providers/practice_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';
import 'active_practice_view.dart';

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
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
              child: Text(context.translate('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final mins = int.tryParse(_goalController.text);
                if (mins != null && mins > 0) {
                  Provider.of<AuthProvider>(context, listen: false).updateWeeklyGoal(mins);
                  Navigator.of(context).pop();
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

    final user = authProv.user;
    final weeklyGoal = user?.weeklyPracticeGoalMinutes ?? 120;
    final weeklyMins = historyProv.thisWeekMinutesPracticed;
    final weeklyProgress = weeklyGoal > 0 ? (weeklyMins / weeklyGoal).clamp(0.0, 1.0) : 0.0;

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
                      backgroundColor: AppTheme.primary,
                      backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                      child: user?.photoUrl == null
                          ? Text(
                              (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'F',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
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
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
                          ),
                          Text(
                            user?.name ?? 'Flutist',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Consumer<LocalizationProvider>(
                      builder: (context, locProv, _) {
                        return IconButton(
                          tooltip: locProv.isSpanish ? 'English' : 'Español',
                          icon: const Icon(Icons.language_rounded, color: AppTheme.primaryAccent),
                          onPressed: () {
                            locProv.setLocale(locProv.isSpanish ? 'en' : 'es');
                          },
                        );
                      },
                    ),
                    IconButton(
                      tooltip: context.translate('sign_out'),
                      icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
                      onPressed: () {
                        authProv.signOut();
                      },
                    )
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
                            icon: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.primaryAccent),
                            onPressed: () => _showEditGoalDialog(context, weeklyGoal),
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '$weeklyMins',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryAccent,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '/ $weeklyGoal ${context.translate('minutes')}',
                            style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: weeklyProgress,
                          minHeight: 10,
                          backgroundColor: AppTheme.border.withOpacity(0.5),
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryAccent),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        context.translate('weekly_goal_target', [(weeklyProgress * 100).toStringAsFixed(0)]),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Grid Statistics Dashboard
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Streak Card
                    _buildStatCard(
                      context,
                      title: context.translate('current_streak_title'),
                      value: '${historyProv.currentStreak} ${context.translate('days')}',
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
                ),
                
                const SizedBox(height: 32),
                
                // Quick Start Practice Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.translate('quick_start'),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary.withOpacity(0.15),
                        foregroundColor: AppTheme.primaryAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: const BorderSide(color: AppTheme.primary, width: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(context.translate('free_study'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () {
                        practiceProv.startSession(null);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const ActivePracticeView()),
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
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: routineProv.routines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final routine = routineProv.routines[index];
                      return GestureDetector(
                        onTap: () {
                          practiceProv.startSession(routine);
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ActivePracticeView()),
                          );
                        },
                        child: AppTheme.glassCard(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.playlist_play_rounded, color: AppTheme.primaryAccent),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      routine.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      context.translate('technical_exercises_count', [routine.exercises.length.toString()]),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.play_circle_fill_rounded, size: 36, color: AppTheme.primaryAccent),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
