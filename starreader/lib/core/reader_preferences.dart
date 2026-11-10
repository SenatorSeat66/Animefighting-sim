/// Persistent reader preferences. Missing fields retain safe defaults so older
/// StarReader backups remain readable when the preference schema grows.
class ReaderPreferences {
  final String mode, fit, background, tapZones;
  final bool rtl, spread, autoHide;
  final double margin, doubleTapScale;
  const ReaderPreferences({
    this.mode = 'paged',
    this.fit = 'contain',
    this.background = 'black',
    this.tapZones = 'standard',
    this.rtl = false,
    this.spread = false,
    this.autoHide = true,
    this.margin = 0,
    this.doubleTapScale = 2.5,
  });
  static const modes = ['paged', 'vertical', 'webtoon'];
  static const fits = ['contain', 'width', 'height', 'original'];
  static const backgrounds = ['black', 'charcoal', 'paper', 'white'];
  static const zones = ['standard', 'wideCenter', 'disabled'];
  factory ReaderPreferences.fromJson(Map<String, dynamic> json) =>
      ReaderPreferences(
        mode: modes.contains(json['mode']) ? json['mode'] : 'paged',
        fit: fits.contains(json['fit']) ? json['fit'] : 'contain',
        background: backgrounds.contains(json['background'])
            ? json['background']
            : 'black',
        tapZones: zones.contains(json['tapZones'])
            ? json['tapZones']
            : 'standard',
        rtl: json['rtl'] == true,
        spread: json['spread'] == true && json['mode'] != 'webtoon',
        autoHide: json['autoHide'] != false,
        margin: json['margin'] is num
            ? (json['margin'] as num).toDouble().clamp(0, 40)
            : 0,
        doubleTapScale: json['doubleTapScale'] is num
            ? (json['doubleTapScale'] as num).toDouble().clamp(1.5, 4)
            : 2.5,
      );
  Map<String, dynamic> toJson() => {
    'mode': mode,
    'fit': fit,
    'background': background,
    'tapZones': tapZones,
    'rtl': rtl,
    'spread': spread,
    'autoHide': autoHide,
    'margin': margin,
    'doubleTapScale': doubleTapScale,
  };
  ReaderPreferences copyWith({
    String? mode,
    String? fit,
    String? background,
    String? tapZones,
    bool? rtl,
    bool? spread,
    bool? autoHide,
    double? margin,
    double? doubleTapScale,
  }) => ReaderPreferences.fromJson({
    ...toJson(),
    'mode': ?mode,
    'fit': ?fit,
    'background': ?background,
    'tapZones': ?tapZones,
    'rtl': ?rtl,
    'spread': ?spread,
    'autoHide': ?autoHide,
    'margin': ?margin,
    'doubleTapScale': ?doubleTapScale,
  });
  static bool isValid(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return false;
    }
    for (final e in value.entries) {
      final valid = switch (e.key) {
        'mode' => modes.contains(e.value),
        'fit' => fits.contains(e.value),
        'background' => backgrounds.contains(e.value),
        'tapZones' => zones.contains(e.value),
        'rtl' || 'spread' || 'autoHide' => e.value is bool,
        'margin' =>
          e.value is num &&
              (e.value as num).isFinite &&
              e.value >= 0 &&
              e.value <= 40,
        'doubleTapScale' =>
          e.value is num &&
              (e.value as num).isFinite &&
              e.value >= 1.5 &&
              e.value <= 4,
        _ => false,
      };
      if (!valid) {
        return false;
      }
    }
    return true;
  }
}
