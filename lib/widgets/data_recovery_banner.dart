import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/localization_provider.dart';
import '../providers/practice_provider.dart';
import '../services/database_service.dart';

class DataRecoveryBanner extends StatelessWidget {
  const DataRecoveryBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final recovered = context.select<PracticeProvider, bool>(
      (p) => p.hasRecoveredSession,
    );
    final draftError = context.select<PracticeProvider, bool>(
      (p) => p.hasDraftSaveError,
    );
    return ValueListenableBuilder<Set<String>>(
      valueListenable: DatabaseService().damagedRecords,
      builder: (context, damaged, _) {
        if (damaged.isEmpty && !recovered && !draftError) {
          return const SizedBox.shrink();
        }
        return Material(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                context.translate(
                  damaged.isNotEmpty
                      ? 'damaged_records'
                      : draftError
                      ? 'draft_save_error'
                      : 'session_recovered',
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
