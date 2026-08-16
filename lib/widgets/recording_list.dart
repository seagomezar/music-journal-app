import 'package:flutter/material.dart';

import '../models/session_recording.dart';
import '../providers/localization_provider.dart';
import '../theme/app_theme.dart';

Future<String?> promptRecordingRename(
  BuildContext context,
  SessionRecording recording,
) async {
  final controller = TextEditingController(text: recording.name);
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(dialogContext.translate('rename_recording_title')),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(
          labelText: dialogContext.translate('recording_name_label'),
        ),
        onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.translate('cancel')),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(dialogContext).pop(controller.text.trim()),
          child: Text(dialogContext.translate('save')),
        ),
      ],
    ),
  );
  controller.dispose();
  return result?.isEmpty == true ? null : result;
}

class RecordingList extends StatelessWidget {
  const RecordingList({
    super.key,
    required this.recordings,
    required this.playingPath,
    required this.isPlaying,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
    this.compact = false,
  });

  final List<SessionRecording> recordings;
  final String? playingPath;
  final bool isPlaying;
  final Future<void> Function(SessionRecording recording) onPlay;
  final Future<void> Function(SessionRecording recording) onRename;
  final Future<void> Function(SessionRecording recording) onDelete;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (recordings.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: recordings.map((recording) {
        final selected = playingPath == recording.storagePath && isPlaying;
        return Padding(
          padding: EdgeInsets.only(bottom: compact ? 4 : 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppTheme.borderColor(context).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ListTile(
              dense: compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
              leading: IconButton.filledTonal(
                tooltip: context.translate(
                  selected ? 'stop_playback_btn' : 'play_recording_btn',
                ),
                icon: Icon(
                  selected ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                onPressed: () => onPlay(recording),
              ),
              title: Text(
                recording.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(recording.createdAt.toLocal()))} · ${context.translate('recording_take_number', [(recordings.indexOf(recording) + 1).toString()])}',
              ),
              trailing: PopupMenuButton<String>(
                tooltip: context.translate('recording_actions'),
                onSelected: (action) async {
                  if (action == 'rename') {
                    final name = await promptRecordingRename(
                      context,
                      recording,
                    );
                    if (name != null) {
                      await onRename(recording.copyWith(name: name));
                    }
                  } else if (action == 'delete') {
                    final confirmed = await _confirmDelete(context, recording);
                    if (confirmed) {
                      await onDelete(recording);
                    }
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(context.translate('rename_recording')),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(context.translate('delete_recording')),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<bool> _confirmDelete(
    BuildContext context,
    SessionRecording recording,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(dialogContext.translate('delete_recording_title')),
            content: Text(
              dialogContext.translate('delete_recording_confirm', [
                recording.name,
              ]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(dialogContext.translate('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(dialogContext.translate('delete_btn')),
              ),
            ],
          ),
        ) ??
        false;
  }
}
