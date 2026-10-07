class TwitchAutomodSettings {
  static const categories = <String, String>{
    'disability': '身心障礙歧視',
    'aggression': '敵意與攻擊',
    'sexuality_sex_or_gender': '性向與性別歧視',
    'misogyny': '厭女歧視',
    'bullying': '辱罵與霸凌',
    'swearing': '髒話',
    'race_ethnicity_or_religion': '種族與宗教歧視',
    'sex_based_terms': '性相關內容',
  };
  final int? overallLevel;
  final Map<String, int> levels;
  TwitchAutomodSettings({
    required this.overallLevel,
    required Map<String, int> levels,
  }) : levels = Map.unmodifiable(levels);

  static bool validLevel(Object? value) =>
      value is int && value >= 0 && value <= 4;
  static bool validChanges(Map<String, int> changes) {
    if (changes.length == 1 && changes.containsKey('overall_level')) {
      return validLevel(changes['overall_level']);
    }
    // PUT overwrites omitted categories; never permit partial custom writes.
    return changes.length == categories.length &&
        categories.keys.every((key) => validLevel(changes[key]));
  }

  static TwitchAutomodSettings? parse(Map row) {
    if (!row.containsKey('overall_level') ||
        (row['overall_level'] != null && !validLevel(row['overall_level'])) ||
        !categories.keys.every((key) => validLevel(row[key]))) {
      return null;
    }
    return TwitchAutomodSettings(
      overallLevel: row['overall_level'] as int?,
      levels: {for (final key in categories.keys) key: row[key] as int},
    );
  }

  bool sameAs(TwitchAutomodSettings other) =>
      overallLevel == other.overallLevel &&
      categories.keys.every((key) => levels[key] == other.levels[key]);
}
