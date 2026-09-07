import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../widgets/adaptive_layout.dart';

class PracticeInsightsScreen extends StatelessWidget {
  const PracticeInsightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final groups = context
        .watch<HistoryProvider>()
        .summary
        .exercises
        .values
        .where((rows) => rows.length >= 2)
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.translate('practice_insights'))),
      body: AdaptiveContent(
        maxWidth: 900,
        child: groups.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(context.translate('practice_insights_empty')),
                ),
              )
            : ListView.builder(
                itemCount: groups.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final rows = groups[index];
                  final latest = rows.first;
                  final earliest = rows.last;
                  final latestPitch = latest.pitchSummary;
                  final comparable = rows
                      .skip(1)
                      .where(
                        (row) =>
                            row.pitchSummary?.hasEnoughData == true &&
                            row.pitchSummary!.referenceHz ==
                                latestPitch?.referenceHz &&
                            row.pitchSummary!.toleranceCents ==
                                latestPitch?.toleranceCents,
                      )
                      .toList();
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            latest.exercise.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.translate('exercise_comparison', [
                              rows.length.toString(),
                              earliest.practicedBpm.toString(),
                              latest.practicedBpm.toString(),
                            ]),
                          ),
                          if (latestPitch?.hasEnoughData == true &&
                              comparable.isNotEmpty)
                            Text(
                              context.translate('intonation_comparison', [
                                comparable.last.pitchSummary!.onPitchPercentage
                                    .toStringAsFixed(0),
                                latestPitch!.onPitchPercentage.toStringAsFixed(
                                  0,
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
