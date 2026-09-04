import 'package:flutter/material.dart';

import '../models/flute_dynamic.dart';
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
    final dynamicReading = practiceProvider.dynamicReading;
    final summary = practiceProvider.livePitchSummary;
    final hasExercise = practiceProvider.activeExerciseId != null;
    final isListening = practiceProvider.isPitchListening;
    final isTracking = practiceProvider.isTrackingPitch;
    final controlsEnabled = !isListening && !practiceProvider.isPaused;
    final cents = reading?.cents ?? 0;
    final indicatorColor = reading == null || !reading.isStable
        ? AppTheme.textSecondaryColor(context)
        : reading.isOnPitch
        ? Colors.greenAccent.shade400
        : Colors.orangeAccent;

    return AppTheme.glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                color: AppTheme.accentColor(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.translate('tuner'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      context.translate('tuner_subtitle'),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondaryColor(context),
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
                    controlsEnabled && practiceProvider.tunerReferenceHz > 410
                    ? () => practiceProvider.setTunerReferenceHz(
                        practiceProvider.tunerReferenceHz - 1,
                      )
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 140,
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
                    controlsEnabled && practiceProvider.tunerReferenceHz < 480
                    ? () => practiceProvider.setTunerReferenceHz(
                        practiceProvider.tunerReferenceHz + 1,
                      )
                    : null,
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                key: const ValueKey('toggle_sound_out'),
                tooltip: practiceProvider.isSoundOutPlaying
                    ? context.translate('stop_sound_out')
                    : context.translate('sound_out'),
                onPressed: practiceProvider.isPaused
                    ? null
                    : () => practiceProvider.toggleSoundOut(),
                style: practiceProvider.isSoundOutPlaying
                    ? IconButton.styleFrom(
                        backgroundColor: Colors.amberAccent.shade700,
                        foregroundColor: Colors.black,
                      )
                    : null,
                icon: Icon(
                  practiceProvider.isSoundOutPlaying
                      ? Icons.volume_up_rounded
                      : Icons.volume_up_outlined,
                ),
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
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondaryColor(context),
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
              FilterChip(
                key: const ValueKey('toggle_tuner_focus_mode'),
                avatar: Icon(
                  practiceProvider.isTunerFocusMode
                      ? Icons.center_focus_strong_rounded
                      : Icons.center_focus_weak_rounded,
                  size: 16,
                ),
                label: Text(
                  context.translate(
                    practiceProvider.isTunerFocusMode
                        ? 'focus_mode'
                        : 'normal_scale',
                  ),
                  style: const TextStyle(fontSize: 11),
                ),
                selected: practiceProvider.isTunerFocusMode,
                onSelected: (_) => practiceProvider.toggleTunerFocusMode(),
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
                  style: TextStyle(color: AppTheme.textSecondaryColor(context)),
                ),
                const SizedBox(height: 12),
                _PitchMeter(
                  cents: cents,
                  color: indicatorColor,
                  isFocusMode: practiceProvider.isTunerFocusMode,
                ),
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: AppTheme.borderColor(context).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                _DynamicMeter(
                  dynamicReading: dynamicReading,
                  isListening: isListening,
                ),
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
              style: TextStyle(
                color: AppTheme.accentColor(context),
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
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textSecondaryColor(context),
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
  const _PitchMeter({
    required this.cents,
    required this.color,
    this.isFocusMode = false,
  });

  final double cents;
  final Color color;
  final bool isFocusMode;

  @override
  Widget build(BuildContext context) {
    final maxCents = isFocusMode ? 25.0 : 50.0;

    return Column(
      children: [
        SizedBox(
          height: 32,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = constraints.maxWidth / 2;
              final span = center - 10;
              final position =
                  center + (cents.clamp(-maxCents, maxCents) / maxCents) * span;

              // Pure Major Third: -13.7 cents
              // Pure Minor Third: +15.6 cents
              final majorThirdX = center + (-13.7 / maxCents) * span;
              final minorThirdX = center + (15.6 / maxCents) * span;

              return Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Horizontal bar
                  Container(height: 3, color: AppTheme.borderColor(context)),
                  // Center tick (0 cents)
                  Positioned(
                    left: center - 1,
                    child: Container(width: 2, height: 18, color: Colors.green),
                  ),
                  // Pure Major Third marker (-13.7 cents)
                  Positioned(
                    left: majorThirdX - 5,
                    top: 2,
                    child: Tooltip(
                      message: '-13.7¢ (Pure M3)',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_drop_down,
                            size: 11,
                            color: Colors.lightBlueAccent.shade200,
                          ),
                          Container(
                            width: 1.5,
                            height: 6,
                            color: Colors.lightBlueAccent.shade200,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Pure Minor Third marker (+15.6 cents)
                  Positioned(
                    left: minorThirdX - 5,
                    top: 2,
                    child: Tooltip(
                      message: '+15.6¢ (Pure m3)',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_drop_down,
                            size: 11,
                            color: Colors.purpleAccent.shade100,
                          ),
                          Container(
                            width: 1.5,
                            height: 6,
                            color: Colors.purpleAccent.shade100,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Needle
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
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '♭  −${maxCents.toInt()}¢',
              style: const TextStyle(fontSize: 10),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '▼ M3 (-13.7¢)',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.lightBlueAccent.shade200,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '0',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text(
                  '▼ m3 (+15.6¢)',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.purpleAccent.shade100,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '+${maxCents.toInt()}¢  ♯',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
}

class _DynamicMeter extends StatelessWidget {
  const _DynamicMeter({
    required this.dynamicReading,
    required this.isListening,
  });

  final FluteDynamicReading? dynamicReading;
  final bool isListening;

  @override
  Widget build(BuildContext context) {
    final activeDynamic = isListening && dynamicReading != null
        ? dynamicReading!.dynamic
        : FluteDynamic.ambient;
    final decibels = isListening && dynamicReading != null
        ? dynamicReading!.smoothedDecibels
        : 0.0;
    final peakDecibels = isListening && dynamicReading != null
        ? dynamicReading!.peakDecibels
        : 0.0;
    final normalized = dynamicReading?.normalizedLevel ?? 0.0;
    final normalizedPeak = dynamicReading?.normalizedPeak ?? 0.0;

    final dynamicText = activeDynamic == FluteDynamic.ambient
        ? (isListening
              ? context.translate('dynamic_ambient')
              : context.translate('dynamic_meter'))
        : context.translate(activeDynamic.localizationKey);

    return Semantics(
      liveRegion: true,
      label: isListening && dynamicReading != null && dynamicReading!.isAudible
          ? '${activeDynamic.symbol}, ${decibels.toStringAsFixed(1)} dB'
          : context.translate('dynamic_meter'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: activeDynamic.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: activeDynamic.color.withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: Text(
                  activeDynamic.symbol,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: activeDynamic.color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  dynamicText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: activeDynamic == FluteDynamic.ambient
                        ? AppTheme.textSecondaryColor(context)
                        : activeDynamic.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    isListening && dynamicReading != null
                        ? '${decibels.toStringAsFixed(1)} dB SPL'
                        : '— dB SPL',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          isListening &&
                              dynamicReading != null &&
                              dynamicReading!.isAudible
                          ? activeDynamic.color
                          : AppTheme.textSecondaryColor(context),
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (isListening &&
                      dynamicReading != null &&
                      dynamicReading!.isAudible)
                    Text(
                      '${context.translate('dynamic_peak')}: ${peakDecibels.toStringAsFixed(1)} dB',
                      style: TextStyle(
                        fontSize: 9,
                        color: AppTheme.textSecondaryColor(context),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          // VU Meter Bar
          SizedBox(
            height: 12,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                final fillWidth = (barWidth * normalized).clamp(0.0, barWidth);
                final peakX = (barWidth * normalizedPeak).clamp(0.0, barWidth);

                return Stack(
                  children: [
                    // Background track
                    Container(
                      width: barWidth,
                      height: 12,
                      decoration: BoxDecoration(
                        color: AppTheme.borderColor(
                          context,
                        ).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    // Active gradient fill
                    if (fillWidth > 0)
                      Container(
                        width: fillWidth,
                        height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF5C9DED), // ppp
                              Color(0xFF2BB0D7), // pp
                              Color(0xFF2EB7A3), // p
                              Color(0xFF67B576), // mp
                              Color(0xFFE2B734), // mf
                              Color(0xFFE88A2E), // f
                              Color(0xFFE5583B), // ff
                              Color(0xFFC72C5B), // fff
                            ],
                          ),
                        ),
                      ),
                    // Peak indicator tick
                    if (isListening && peakX > 2)
                      Positioned(
                        left: peakX - 1.5,
                        top: 0,
                        child: Container(
                          width: 3,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          // Dynamic symbols row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final dyn in const [
                FluteDynamic.ppp,
                FluteDynamic.pp,
                FluteDynamic.p,
                FluteDynamic.mp,
                FluteDynamic.mf,
                FluteDynamic.f,
                FluteDynamic.ff,
                FluteDynamic.fff,
              ])
                Text(
                  dyn.symbol,
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontStyle: FontStyle.italic,
                    fontSize: 10,
                    fontWeight: activeDynamic == dyn
                        ? FontWeight.w900
                        : FontWeight.w500,
                    color: activeDynamic == dyn
                        ? dyn.color
                        : AppTheme.textSecondaryColor(
                            context,
                          ).withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
