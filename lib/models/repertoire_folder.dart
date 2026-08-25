class RepertoireFolder {
  const RepertoireFolder({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory RepertoireFolder.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final name = json['name'] as String;
    if (id.isEmpty || name.trim().isEmpty || name.length > 100) {
      throw const FormatException('Invalid repertoire folder.');
    }
    return RepertoireFolder(id: id, name: name.trim());
  }

  RepertoireFolder copyWith({String? name}) {
    return RepertoireFolder(id: id, name: name ?? this.name);
  }
}
