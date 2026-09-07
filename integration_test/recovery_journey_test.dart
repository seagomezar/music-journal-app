import 'dart:io';
import 'dart:typed_data';

import 'package:flute/models/exercise.dart';
import 'package:flute/models/piece.dart';
import 'package:flute/models/routine.dart';
import 'package:flute/models/session_recording.dart';
import 'package:flute/providers/practice_provider.dart';
import 'package:flute/services/audio_service.dart';
import 'package:flute/services/database_service.dart';
import 'package:flute/services/file_storage_service.dart';
import 'package:flute/services/full_backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdf_document/pdf_document.dart' as pdf;

/// This journey erases app data. Run only on a dedicated test device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native relaunch recovery and full media restore', (
    tester,
  ) async {
    final db = DatabaseService();
    await db.init();
    await db.clearAllUserData();
    final exercise = Exercise(
      id: 'recovery-exercise',
      name: 'Long tones',
      targetBpm: 80,
      articulation: 'Legato',
    );
    final practice = PracticeProvider(persistDraft: db.writeSessionDraft);
    practice.startSession(
      Routine(
        id: 'recovery-routine',
        title: 'Recovery',
        description: '',
        exercises: [exercise],
      ),
    );
    practice.startExercise(exercise.id, 90);
    practice.notesController.text = 'Keep this unfinished practice';
    await practice.checkpointSession();
    practice.dispose();
    // Drain the serialized dispose checkpoint before closing the store.
    await practice.checkpointSession();
    await Hive.close();
    await db.init();
    final recovered = PracticeProvider(
      persistDraft: db.writeSessionDraft,
      recoveredDraft: db.readSessionDraft(),
    );
    expect(recovered.hasRecoveredSession, true);
    expect(recovered.isPaused, true);
    expect(recovered.isPitchListening, false);
    expect(recovered.notesController.text, 'Keep this unfinished practice');
    final record = (await recovered.prepareSessionRecord([]))!;
    await db.saveSession(record);
    recovered.completeSession();
    await recovered.checkpointSession();
    recovered.dispose();

    final directory = await Directory.systemTemp.createTemp(
      'flute_restore_journey_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final source = File('${directory.path}/score.pdf');
    await source.writeAsBytes(pdf.PdfBlankDocument.create(pageCount: 1));
    final storage = FileStorageService();
    final path = await storage.importPdf(source.path);
    await db.savePiece(
      Piece(
        id: 'score',
        title: 'Restore score',
        composer: '',
        targetBpm: 80,
        pdfPath: path,
      ),
    );
    final audioPath = await storage.createRecordingPath();
    final audioBytes = _silentWave();
    await File(audioPath).writeAsBytes(audioBytes, flush: true);
    await db.saveSession(
      record.copyWith(
        recordings: [
          SessionRecording(
            id: 'take',
            name: 'Silent playback fixture',
            createdAt: DateTime.now(),
            storagePath: audioPath,
          ),
        ],
      ),
    );
    final backups = FullBackupService();
    final backup = backups.parse(await backups.create(db));
    await db.clearAllUserData();
    await backups.restore(db, backup);
    final restored = db.getSessions().single;
    expect(restored.id, record.id);
    expect(restored.notes, record.notes);
    expect(
      await File(db.getPieces().single.pdfPath!).readAsBytes(),
      await source.readAsBytes(),
    );
    expect(
      await File(restored.recordings.single.storagePath).readAsBytes(),
      audioBytes,
    );
    // Exercise the real player, including its handling of a portable restored
    // attachment. No microphone permission or audible test tone is required.
    final player = AudioService();
    try {
      await player.startPlayback(restored.recordings.single.storagePath);
      expect(player.isPlaying, true);
      await player.stopPlayback();
    } finally {
      await player.dispose();
    }
    await db.clearAllUserData();
  });
}

Uint8List _silentWave() {
  const sampleRate = 16000;
  const dataSize = sampleRate * 2 * 2;
  final bytes = ByteData(44 + dataSize);
  void text(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  text(0, 'RIFF');
  bytes.setUint32(4, 36 + dataSize, Endian.little);
  text(8, 'WAVEfmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, sampleRate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  text(36, 'data');
  bytes.setUint32(40, dataSize, Endian.little);
  return bytes.buffer.asUint8List();
}
