import 'exercise.dart';

class Routine {
  final String id;
  final String title;
  final String description;
  final List<Exercise> exercises;

  Routine({
    required this.id,
    required this.title,
    required this.description,
    required this.exercises,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        exercises: (json['exercises'] as List<dynamic>?)
                ?.map((e) => Exercise.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );

  Routine copyWith({
    String? title,
    String? description,
    List<Exercise>? exercises,
  }) {
    return Routine(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
    );
  }
}
