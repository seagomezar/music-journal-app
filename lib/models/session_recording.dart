class SessionRecording {
  const SessionRecording({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.storagePath,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  final String storagePath;

  SessionRecording copyWith({String? name}) => SessionRecording(
    id: id,
    name: name ?? this.name,
    createdAt: createdAt,
    storagePath: storagePath,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'storagePath': storagePath,
  };

  factory SessionRecording.fromJson(Map<String, dynamic> json) {
    return SessionRecording(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Recording',
      createdAt: DateTime.parse(json['createdAt'] as String),
      storagePath: json['storagePath'] as String,
    );
  }
}
