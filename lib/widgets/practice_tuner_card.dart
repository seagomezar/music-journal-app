import 'package:flutter/material.dart';

import '../providers/localization_provider.dart';
import '../providers/practice_provider.dart';
import '../theme/app_theme.dart';

class PracticeTunerCard extends StatelessWidget {
  const PracticeTunerCard({super.key, required this.practiceProvider});

  final PracticeProvider practiceProvider;

  Future<void> _start(BuildContext context, {required bool track}) async {
    final started = await practiceProvider.startPitchCapture(
      trackExercise: track,
    );
    if (!started && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.translate('tuner_mic_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!practiceProvider.isTunerVisible) {
      return OutlinedButton.icon(
        key: const ValueKey('show_tuner'),
        onPressed: () => practiceProvider.setTunerVisible(true),
        icon: const Icon(Icons.tune_rounded),
        label: Text(context.translate('show_tuner')),
      );
    }

    final reading = practiceProvider.pitchReading;
    final summary = practiceProvider.livePitchSummary;
    final hasExercise = practiceProvider.activeExerciseId != null;
    final isListening = practiceProvider.isPitchListening;
    final isTracking = practiceProvider.isTrackingPitch;
    final controlsEnabled = !isListening && !practiceProvider.isPaused;
    final cents = reading?.cents ?? 0;
    final indicatorColor = reading == null || !reading.isStable
        ? AppTheme.textSecondary
        : reading.isOnPitch
        ? Colors.greenAccent.shade400
        : Colors.orangeAccent;

    return AppTheme.glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.graphic_eq_rounded,
                color: AppTheme.primaryAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.translate('tuner'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      context.translate('tuner_subtitle'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isListening)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.mic_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                ),
              IconButton(
                key: const ValueKey('hide_tuner'),
                tooltip: context.translate('hide_tuner'),
                onPressed: () => practiceProvider.setTunerVisible(false),
                icon: const Icon(Icons.visibility_off_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                key: const ValueKey('decrease_tuner_reference'),
                tooltip: context.translate('decrease_tuner_reference'),
                onPressed:
                    controlsEnabled && practiceProvider.tunerReferenceHz > 420
                    ? () => practiceProvider.setTunerReferenceHz(
                        practiceProvider.tunerReferenceHz - 1,
                      )
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 150,
                child: Text(
                  'A4 = ${practiceProvider.tunerReferenceHz} Hz',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton.filledTonal(
                key: const ValueKey('increase_tuner_reference'),
                tooltip: context.translate('increase_tuner_reference'),
                onPressed:
                    controlsEnabled && practiceProvider.tunerReferenceHz < 460
                    ? () => practiceProvider.setTunerReferenceHz(
                        practiceProvider.tunerReferenceHz + 1,
                      )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                context.translate('pitch_tolerance'),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              for (final tolerance in const [5, 10, 20])
                ChoiceChip(
                  label: Text('±$tolerance¢'),
                  selected: practiceProvider.tunerToleranceCents == tolerance,
                  onSelected: controlsEnabled
                      ? (_) =>
                            practiceProvider.setTunerToleranceCents(tolerance)
                      : null,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            label: reading == null
                ? context.translate('play_a_note')
                : '${reading.displayNote}, ${reading.cents.toStringAsFixed(1)} cents',
            child: Column(
              children: [
                Text(
                  reading?.displayNote ?? '—',
                  style: TextStyle(
                    fontSize: 52,
                    height: 1,
                    fontWeight: FontWeight.w300,
                    color: indicatorColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reading == null
                      ? context.translate('play_a_note')
                      : '${reading.frequencyHz.toStringAsFixed(1)} Hz  •  ${reading.cents >= 0 ? '+' : ''}${reading.cents.toStringAsFixed(1)}¢',
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                _PitchMeter(cents: cents, color: indicatorColor),
              ],
            ),
          ),
          if (isTracking) ...[
            const SizedBox(height: 12),
            Text(
              summary == null || summary.analyzedMilliseconds == 0
                  ? context.translate('waiting_for_stable_pitch')
                  : context.translate('on_pitch_live', [
                      summary.onPitchPercentage.round().toString(),
                      _formatDuration(summary.analyzedMilliseconds),
                    ]),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.primaryAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (isListening)
            ElevatedButton.icon(
              key: const ValueKey('stop_pitch_capture'),
              onPressed: practiceProvider.stopPitchCapture,
              icon: const Icon(Icons.stop_rounded),
              label: Text(
                context.translate(
                  isTracking ? 'stop_pitch_tracking' : 'stop_listening',
                ),
              ),
            )
          else
            ElevatedButton.icon(
              key: const ValueKey('start_pitch_capture'),
              onPressed:
                  practiceProvider.isPaused ||
                      practiceProvider.isRecording ||
                      practiceProvider.isPlayingPlayback
                  ? null
                  : () => _start(context, track: hasExercise),
              icon: const Icon(Icons.mic_rounded),
              label: Text(
                context.translate(hasExercise ? 'track_my_pitch' : 'tune_now'),
              ),
            ),
          if (practiceProvider.metronomeOn &&
              practiceProvider.metronomeSoundEnabled) ...[
            const SizedBox(height: 8),
            Text(
              context.translate('tuner_headphones_hint'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDuration(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    return '$minutes:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _PitchMeter extends StatelessWidget {
  const _PitchMeter({required this.cents, required this.color});

  final double cents;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 28,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = constraints.maxWidth / 2;
              final position =
                  center + cents.clamp(-50.0, 50.0) / 50 * (center - 8);
              return Stack(
                alignment: Alignment.center,
                children: [
                  Container(height: 3, color: AppTheme.border),
                  Positioned(
                    left: center - 1,
                    child: Container(width: 2, height: 18, color: Colors.green),
                  ),
                  Positioned(
                    left: position - 5,
                    child: Container(
                      width: 10,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text('♭  −50¢', style: TextStyle(fontSize: 10)),
            Text('0', style: TextStyle(fontSize: 10)),
            Text('+50¢  ♯', style: TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
