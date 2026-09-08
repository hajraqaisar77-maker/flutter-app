/// Aladhan API calculation method IDs, wrapped in a friendly enum so the UI
/// never deals with raw magic numbers.
enum CalculationMethod {
  karachi(1, 'Karachi — Univ. of Islamic Sciences'),
  isna(2, 'ISNA — North America'),
  mwl(3, 'Muslim World League'),
  ummAlQura(4, 'Umm al-Qura — Saudi Arabia'),
  egyptian(5, 'Egyptian General Authority'),
  diyanet(13, 'Diyanet — Turkey'),
  moonsightingCommittee(15, 'Moonsighting Committee Worldwide');

  final int id;
  final String label;

  const CalculationMethod(this.id, this.label);

  static CalculationMethod fromId(int id) =>
      CalculationMethod.values.firstWhere((m) => m.id == id, orElse: () => CalculationMethod.mwl);

  /// Best-effort default method for a given country name, so a first-time
  /// user in any country gets a sensible result before ever opening
  /// settings.
  static CalculationMethod defaultForCountry(String? country) {
    final key = (country ?? '').trim().toLowerCase();
    const map = <String, CalculationMethod>{
      'pakistan': CalculationMethod.karachi,
      'india': CalculationMethod.karachi,
      'bangladesh': CalculationMethod.karachi,
      'afghanistan': CalculationMethod.karachi,
      'sri lanka': CalculationMethod.karachi,
      'united kingdom': CalculationMethod.moonsightingCommittee,
      'uk': CalculationMethod.moonsightingCommittee,
      'ireland': CalculationMethod.moonsightingCommittee,
      'france': CalculationMethod.moonsightingCommittee,
      'germany': CalculationMethod.moonsightingCommittee,
      'united states': CalculationMethod.isna,
      'usa': CalculationMethod.isna,
      'canada': CalculationMethod.isna,
      'saudi arabia': CalculationMethod.ummAlQura,
      'egypt': CalculationMethod.egyptian,
      'turkey': CalculationMethod.diyanet,
    };
    return map[key] ?? CalculationMethod.mwl;
  }
}

enum Madhab {
  standard(0, 'Standard (Shafi, Maliki, Hanbali)'),
  hanafi(1, 'Hanafi');

  final int id;
  final String label;

  const Madhab(this.id, this.label);

  static Madhab fromId(int id) => Madhab.values.firstWhere((m) => m.id == id, orElse: () => Madhab.standard);
}

enum AppThemeMode { light, dark, system }

enum AppLanguage {
  english('en', 'English'),
  urdu('ur', 'اردو'),
  arabic('ar', 'العربية');

  final String code;
  final String label;

  const AppLanguage(this.code, this.label);

  static AppLanguage fromCode(String code) =>
      AppLanguage.values.firstWhere((l) => l.code == code, orElse: () => AppLanguage.english);
}

enum TimeFormatPref { h12, h24 }
