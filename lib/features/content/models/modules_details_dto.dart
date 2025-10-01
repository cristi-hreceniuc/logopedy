class ModuleDetailsDto {
  final int id;
  final String title;
  final String? introText;
  final int position;
  final bool isPremium;
  final List<SubmoduleLite> submodules; // ← public

  ModuleDetailsDto({
    required this.id,
    required this.title,
    this.introText,
    required this.position,
    required this.isPremium,
    required this.submodules,
  });

  factory ModuleDetailsDto.fromJson(Map<String, dynamic> j) => ModuleDetailsDto(
    id: j['id'],
    title: j['title'],
    introText: j['introText'],
    position: j['position'],
    isPremium: j['isPremium'] ?? false,
    submodules: (j['submodules'] as List? ?? [])
        .map((e) => SubmoduleLite.fromJson(e)) // ← public
        .toList()
        .cast<SubmoduleLite>(),
  );
}

class SubmoduleLite { // ← public
  final int id;
  final String title;
  final String? introText;
  final int position;

  SubmoduleLite({
    required this.id,
    required this.title,
    this.introText,
    required this.position,
  });

  factory SubmoduleLite.fromJson(Map<String, dynamic> j) => SubmoduleLite(
    id: j['id'],
    title: j['title'],
    introText: j['introText'],
    position: j['position'],
  );
}
