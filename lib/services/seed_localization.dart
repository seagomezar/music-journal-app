import '../models/routine.dart';
import '../models/piece.dart';

const _seedSpanish = <String, String>{
  'Daily Warmup': 'Calentamiento diario',
  'Breathing exercises, long tones, and basic scales.':
      'Ejercicios de respiración, notas largas y escalas básicas.',
  'Long Tones (Low Register)': 'Notas largas (registro grave)',
  'Chromatic Scale (Full Range)': 'Escala cromática (registro completo)',
  'Major Scales (C, G, D, F)': 'Escalas mayores (Do, Sol, Re, Fa)',
  'Articulation drills': 'Ejercicios de articulación',
  'Focused routine on double and triple tonguing speed and clarity.':
      'Rutina centrada en la velocidad y claridad del doble y triple picado.',
  'Double Tonguing T-K Drill': 'Ejercicio de doble picado T-K',
  'Triple Tonguing T-T-K Arpeggios': 'Arpegios de triple picado T-T-K',
  'Double Tonguing': 'Doble picado',
  'Triple Tonguing': 'Triple picado',
};

Piece localizeSeedPiece(Piece piece, String locale) {
  if (piece.id != 'piece_default') return piece;
  const english =
      'Focus on the breath marks and key fluidity in the opening theme. Maintain deep tone quality on the low C/C# notes.';
  const spanish =
      'Concéntrate en las respiraciones y la fluidez de los dedos en el tema inicial. Mantén un sonido profundo en las notas Do y Do sostenido graves.';
  if (piece.notes != english && piece.notes != spanish) return piece;
  return piece.copyWith(notes: locale == 'es' ? spanish : english);
}

Routine localizeSeedRoutine(Routine routine, String locale) {
  if (!const {'warmup_default', 'tonguing_default'}.contains(routine.id)) {
    return routine;
  }
  final dictionary = locale == 'es'
      ? _seedSpanish
      : {for (final entry in _seedSpanish.entries) entry.value: entry.key};
  String translate(String value) => dictionary[value] ?? value;
  return routine.copyWith(
    title: translate(routine.title),
    description: translate(routine.description),
    exercises: routine.exercises
        .map(
          (exercise) => exercise.copyWith(
            name: translate(exercise.name),
            articulation: translate(exercise.articulation),
          ),
        )
        .toList(),
  );
}
