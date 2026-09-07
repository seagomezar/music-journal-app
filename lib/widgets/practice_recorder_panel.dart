import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../providers/practice_provider.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';
import 'recording_list.dart';

class PracticeRecorderPanel extends StatelessWidget {
  const PracticeRecorderPanel({super.key, required this.practiceProv});
  final PracticeProvider practiceProv;

  Future<void> _handleAction(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      debugPrint('Recording save error: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('recording_save_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = practiceProv.recordings.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: AppTheme.glassCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.translate('self_recorder'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 3),
            Text(
              context.translate('self_recorder_subtitle'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 8),
              Text(
                context.translate('recording_web_session_only'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.accentColor(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (!practiceProv.isAudioRecorderActive)
              OutlinedButton.icon(
                onPressed: practiceProv.activateAudioRecorder,
                icon: const Icon(Icons.mic_none_rounded),
                label: Text(context.translate('open_self_recorder')),
              )
            else ...[
              if (practiceProv.isRecording)
                Text(
                  context.translate('recording_audio'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (practiceProv.isPlayingPlayback)
                Text(
                  context.translate('playing_back_audio'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.accentColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                )
              else if (hasRecording)
                Text(
                  context.translateRecordingCount(
                    practiceProv.recordings.length,
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  if (!practiceProv.isRecording)
                    IconButton.filled(
                      tooltip: context.translate('start_recording'),
                      onPressed: () async {
                        final success = await practiceProv.startRecording();
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.translate('mic_error')),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.fiber_manual_record),
                    ),
                  if (practiceProv.isRecording)
                    IconButton.filled(
                      tooltip: context.translate('stop_recording'),
                      onPressed: () =>
                          _handleAction(context, practiceProv.stopRecording),
                      icon: const Icon(Icons.stop_rounded),
                    ),
                ],
              ),
              if (hasRecording) ...[
                const SizedBox(height: 8),
                RecordingList(
                  recordings: practiceProv.recordings,
                  playingPath: practiceProv.playingRecordingPath,
                  isPlaying: practiceProv.isPlayingPlayback,
                  compact: true,
                  onPlay: (recording) => practiceProv.startPlayback(recording),
                  onRename: (recording) =>
                      practiceProv.renameRecording(recording, recording.name),
                  onDelete: (recording) =>
                      practiceProv.deleteRecording(recording),
                ),
              ],
              TextButton(
                onPressed: () =>
                    _handleAction(context, practiceProv.closeAudioRecorder),
                child: Text(context.translate('close_recorder')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
