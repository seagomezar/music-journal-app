import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/session_record.dart';
import '../models/session_recording.dart';
import '../providers/history_provider.dart';
import '../providers/localization_provider.dart';
import '../services/audio_service.dart';
import '../services/local_file_availability.dart';
import '../theme/app_theme.dart';
import '../widgets/recording_list.dart';

class RecordingLibraryScreen extends StatefulWidget {
  const RecordingLibraryScreen({super.key});

  @override
  State<RecordingLibraryScreen> createState() => _RecordingLibraryScreenState();
}

class _RecordingLibraryScreenState extends State<RecordingLibraryScreen> {
  late final AudioService _playbackService;
  String? _playingPath;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _playbackService = AudioService(
      onPlaybackChanged: (isPlaying) {
        if (!mounted) return;
        setState(() {
          _isPlaying = isPlaying;
          if (!isPlaying) _playingPath = null;
        });
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().loadSessions();
    });
  }

  @override
  void dispose() {
    unawaited(_playbackService.dispose());
    super.dispose();
  }

  Future<void> _play(SessionRecording recording) async {
    try {
      if (!await localFileExists(recording.storagePath)) {
        throw StateError('Recording file not found.');
      }
      if (_playingPath == recording.storagePath && _isPlaying) {
        await _playbackService.stopPlayback();
        return;
      }
      await _playbackService.stopPlayback();
      if (!mounted) return;
      setState(() => _playingPath = recording.storagePath);
      await _playbackService.startPlayback(recording.storagePath);
    } catch (error) {
      debugPrint('Recording library playback error: $error');
      if (!mounted) return;
      setState(() {
        _playingPath = null;
        _isPlaying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('audio_playback_error'))),
      );
    }
  }

  Future<void> _rename(
    HistoryProvider provider,
    SessionRecord session,
    SessionRecording recording,
  ) async {
    try {
      await provider.renameRecording(session.id, recording, recording.name);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('recording_rename_error'))),
      );
    }
  }

  Future<void> _delete(
    HistoryProvider provider,
    SessionRecord session,
    SessionRecording recording,
  ) async {
    try {
      if (_playingPath == recording.storagePath) {
        await _playbackService.stopPlayback();
      }
      await provider.deleteRecording(session.id, recording);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('recording_delete_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HistoryProvider>();
    final sessions = provider.sessions
        .where((session) => session.recordings.isNotEmpty)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(context.translate('recording_library'))),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : sessions.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.translate('recording_library_empty'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondaryColor(context)),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: sessions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final session = sessions[index];
                return AppTheme.glassCard(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _sessionTitle(context, session),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.translate('recording_count_format', [
                          session.recordings.length.toString(),
                        ]),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RecordingList(
                        recordings: session.recordings,
                        playingPath: _playingPath,
                        isPlaying: _isPlaying,
                        compact: true,
                        onPlay: _play,
                        onRename: (recording) =>
                            _rename(provider, session, recording),
                        onDelete: (recording) =>
                            _delete(provider, session, recording),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _sessionTitle(BuildContext context, SessionRecord session) {
    final local = session.localStartTime;
    return MaterialLocalizations.of(context).formatMediumDate(local);
  }
}
