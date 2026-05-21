class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final int weeklyPracticeGoalMinutes;

  UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.weeklyPracticeGoalMinutes = 120,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'photoUrl': photoUrl,
        'weeklyPracticeGoalMinutes': weeklyPracticeGoalMinutes,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        photoUrl: json['photoUrl'] as String?,
        weeklyPracticeGoalMinutes: json['weeklyPracticeGoalMinutes'] as int? ?? 120,
      );

  UserProfile copyWith({
    String? name,
    String? email,
    String? photoUrl,
    int? weeklyPracticeGoalMinutes,
  }) {
    return UserProfile(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      weeklyPracticeGoalMinutes: weeklyPracticeGoalMinutes ?? this.weeklyPracticeGoalMinutes,
    );
  }
}
