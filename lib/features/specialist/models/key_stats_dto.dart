class KeyStatsDTO {
  final int total;
  final int used;

  KeyStatsDTO({
    required this.total,
    required this.used,
  });

  factory KeyStatsDTO.fromJson(Map<String, dynamic> json) {
    return KeyStatsDTO(
      total: json['total'] as int,
      used: json['used'] as int,
    );
  }

  int get available => total - used;
}

