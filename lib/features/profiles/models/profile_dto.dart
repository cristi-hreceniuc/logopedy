class ProfileDto {
  final int id;
  final String name;
  final String? avatarUrl;
  final bool isPremium;
  final int completedLessons;
  final int totalLessons;

  ProfileDto({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.isPremium,
    this.completedLessons = 0,
    this.totalLessons = 0,
  });

  factory ProfileDto.fromJson(Map<String, dynamic> j) => ProfileDto(
    id: j['id'],
    name: j['name'] ?? '',
    avatarUrl: j['avatarUrl'],
    isPremium: (j['isPremium'] ?? false) as bool,
    completedLessons: j['completedLessons'] ?? 0,
    totalLessons: j['totalLessons'] ?? 0,
  );
}
