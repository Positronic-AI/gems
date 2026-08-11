import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gem.dart';

/// Gem palettes — the unlock ladder's delivery vehicle (docs/
/// streaks-and-unlocks.md). Rules: cosmetic only; the ladder is fully
/// visible; unlocks key off BEST-EVER streak (never re-lock);
/// accessibility is never gated — the colorblind palette is free.
class GemPalette {
  final String id;
  final String name;
  final int unlockStreak; // 0 = free
  final Map<GemType, Color> colors;
  final Map<GemType, Color> glows;
  final Map<GemType, IconData>? icons; // null = classic shapes

  const GemPalette({
    required this.id,
    required this.name,
    required this.unlockStreak,
    required this.colors,
    required this.glows,
    this.icons,
  });

  Color colorOf(GemType t) => colors[t]!;
  Color glowOf(GemType t) => glows[t]!;
}

/// Curated shape set for the Custom Studio — every icon vetted to stay
/// readable at board size. Stored by INDEX in prefs (stable across builds).
/// APPEND-ONLY: shapes persist by index — reordering or removing entries
/// would silently redesign every player's saved palette.
const List<IconData> studioShapes = [
  Icons.diamond,
  Icons.favorite,
  Icons.star,
  Icons.eco,
  Icons.local_fire_department,
  Icons.bolt,
  Icons.water_drop,
  Icons.circle,
  Icons.square,
  Icons.hexagon,
  Icons.spa,
  Icons.auto_awesome,
  Icons.pets,
  Icons.music_note,
  // v2 additions ↓
  Icons.ac_unit, // snowflake
  Icons.wb_sunny, // sun
  Icons.nightlight_round, // moon
  Icons.cloud,
  Icons.anchor,
  Icons.rocket_launch,
  Icons.emoji_events, // trophy
  Icons.celebration, // party popper
  Icons.extension, // puzzle piece
  Icons.casino, // die
  Icons.sports_esports, // gamepad
  Icons.smart_toy, // robot
  Icons.local_florist, // flower
  Icons.forest, // tree
  Icons.bug_report, // beetle
  Icons.cruelty_free, // bunny
  Icons.cake,
  Icons.icecream,
  Icons.key,
  Icons.shield,
  Icons.visibility, // eye
  Icons.mood, // smiley
  Icons.headphones,
  Icons.camera_alt,
];

/// Auto-derive a glow from a base color — the Studio asks 7 questions, not 14.
Color deriveGlow(Color c) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + 0.25).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
      .toColor();
}

/// Theme library (Custom Studio, one 14-day gate → unlimited themes).
/// Every theme is attributed: name + author, carried in GEMS2 envelopes.
/// Imports ADD to the library credited to their original creator.
class UserTheme {
  final String id;
  String name;
  String author;
  List<int> colors; // 7, by GemType index
  List<int> shapes; // 7, index into studioShapes, -1 = classic icon

  UserTheme({
    required this.id,
    required this.name,
    required this.author,
    required this.colors,
    required this.shapes,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'n': name, 'a': author, 'c': colors, 's': shapes};

  static UserTheme fromJson(Map<String, dynamic> j) => UserTheme(
        id: j['id'] as String,
        name: (j['n'] ?? 'Theme') as String,
        author: (j['a'] ?? '') as String,
        colors: (j['c'] as List).cast<int>(),
        shapes: (j['s'] as List).cast<int>(),
      );

  GemPalette toPalette() {
    final colorMap = <GemType, Color>{};
    final glowMap = <GemType, Color>{};
    final iconMap = <GemType, IconData>{};
    for (var i = 0; i < GemType.values.length; i++) {
      final t = GemType.values[i];
      final c = Color(colors[i]);
      colorMap[t] = c;
      glowMap[t] = deriveGlow(c);
      iconMap[t] = (shapes[i] >= 0 && shapes[i] < studioShapes.length)
          ? studioShapes[shapes[i]]
          : t.classicIcon;
    }
    return GemPalette(
      id: 'user_$id',
      name: name,
      unlockStreak: ThemeLibrary.unlockStreak,
      colors: colorMap,
      glows: glowMap,
      icons: iconMap,
    );
  }
}

class ThemeLibrary {
  static const unlockStreak = 14;

  static Future<List<UserTheme>> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _migrateLegacy(prefs);
    final raw = prefs.getString('themes_v1');
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => UserTheme.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _migrateLegacy(SharedPreferences prefs) async {
    if (prefs.getInt('custom_color_red') == null) return;
    final colors = <int>[];
    final shapes = <int>[];
    for (final t in GemType.values) {
      colors.add(prefs.getInt('custom_color_${t.name}') ??
          _classic.colorOf(t).value);
      shapes.add(prefs.getInt('custom_shape_${t.name}') ?? -1);
      await prefs.remove('custom_color_${t.name}');
      await prefs.remove('custom_shape_${t.name}');
    }
    final list = [
      UserTheme(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'My Palette',
        author: prefs.getString('theme_author') ?? '',
        colors: colors,
        shapes: shapes,
      )
    ];
    await prefs.setString(
        'themes_v1', jsonEncode(list.map((t) => t.toJson()).toList()));
  }

  static Future<void> saveAll(List<UserTheme> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'themes_v1', jsonEncode(themes.map((t) => t.toJson()).toList()));
  }

  static Future<UserTheme> create({String? name}) async {
    final themes = await load();
    final author = await getAuthor();
    final t = UserTheme(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? 'Theme ${themes.length + 1}',
      author: author,
      colors: [for (final t in GemType.values) _classic.colorOf(t).value],
      shapes: List.filled(GemType.values.length, -1),
    );
    themes.add(t);
    await saveAll(themes);
    return t;
  }

  static Future<void> update(UserTheme theme) async {
    final themes = await load();
    final i = themes.indexWhere((t) => t.id == theme.id);
    if (i >= 0) themes[i] = theme;
    await saveAll(themes);
  }

  static Future<void> delete(String id) async {
    final themes = await load();
    themes.removeWhere((t) => t.id == id);
    await saveAll(themes);
  }

  static Future<String> getAuthor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('theme_author') ?? '';
  }

  static Future<void> setAuthor(String author) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_author', author.trim());
  }

  /// GEMS2 envelope: version, name, author, colors, shapes.
  static String exportCode(UserTheme t) {
    final payload = jsonEncode(
        {'v': 2, 'n': t.name, 'a': t.author, 'c': t.colors, 's': t.shapes});
    return 'GEMS2.${base64UrlEncode(utf8.encode(payload))}';
  }

  /// Import GEMS2 (attributed) or legacy GEMS1 codes from anywhere in the
  /// pasted text. Adds a NEW library entry. Returns error or null.
  static Future<String?> importCode(String text) async {
    try {
      final m = RegExp(r'GEMS[12]\.[A-Za-z0-9_\-=]+').firstMatch(text);
      if (m == null) return 'No Gems theme code found (looks like GEMS2.…)';
      final code = m.group(0)!;
      final payload = utf8.decode(
          base64Url.decode(base64Url.normalize(code.substring(6))));
      final j = jsonDecode(payload) as Map<String, dynamic>;
      final c = (j['c'] as List).cast<int>();
      final sh = (j['s'] as List).cast<int>();
      if (c.length != GemType.values.length ||
          sh.length != GemType.values.length) {
        return 'Theme code is from a different game version';
      }
      final themes = await load();
      themes.add(UserTheme(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: (j['n'] ?? 'Imported theme') as String,
        author: (j['a'] ?? '') as String,
        colors: c,
        shapes: [
          for (final v in sh)
            (v >= 0 && v < studioShapes.length) ? v : -1
        ],
      ));
      await saveAll(themes);
      return null;
    } catch (_) {
      return 'Could not read that code — was it pasted completely?';
    }
  }
}

const _classic = GemPalette(
  id: 'classic',
  name: 'Classic',
  unlockStreak: 0,
  colors: {
    GemType.red: Color(0xFFE53935),
    GemType.orange: Color(0xFFFF9800),
    GemType.yellow: Color(0xFFFFEB3B),
    GemType.green: Color(0xFF4CAF50),
    GemType.blue: Color(0xFF2196F3),
    GemType.purple: Color(0xFF9C27B0),
    GemType.white: Color(0xFFE0E0E0),
  },
  glows: {
    GemType.red: Color(0xFFFF5252),
    GemType.orange: Color(0xFFFFB74D),
    GemType.yellow: Color(0xFFFFF176),
    GemType.green: Color(0xFF81C784),
    GemType.blue: Color(0xFF64B5F6),
    GemType.purple: Color(0xFFBA68C8),
    GemType.white: Color(0xFFFFFFFF),
  },
);

/// Okabe-Ito inspired — every pair distinguishable with deuteranopia/
/// protanopia. Free for everyone, always (gem shapes already differ too).
const _highContrast = GemPalette(
  id: 'colorblind',
  name: 'High Contrast',
  unlockStreak: 0,
  colors: {
    GemType.red: Color(0xFFD55E00), // vermillion
    GemType.orange: Color(0xFFE69F00), // orange
    GemType.yellow: Color(0xFFF0E442), // yellow
    GemType.green: Color(0xFF009E73), // bluish green
    GemType.blue: Color(0xFF0072B2), // deep blue
    GemType.purple: Color(0xFFCC79A7), // reddish purple
    GemType.white: Color(0xFFF5F5F5),
  },
  glows: {
    GemType.red: Color(0xFFFF8A50),
    GemType.orange: Color(0xFFFFC94D),
    GemType.yellow: Color(0xFFFFF9A6),
    GemType.green: Color(0xFF4DD0AC),
    GemType.blue: Color(0xFF4DA3E0),
    GemType.purple: Color(0xFFE8A8CC),
    GemType.white: Color(0xFFFFFFFF),
  },
);

const _ocean = GemPalette(
  id: 'ocean',
  name: 'Ocean',
  unlockStreak: 3,
  colors: {
    GemType.red: Color(0xFFFF6B6B), // coral
    GemType.orange: Color(0xFFFFA96B), // sandy
    GemType.yellow: Color(0xFFFFE66D), // sunlight
    GemType.green: Color(0xFF2EC4B6), // teal
    GemType.blue: Color(0xFF1B7FD4), // deep sea
    GemType.purple: Color(0xFF6A6FC9), // twilight
    GemType.white: Color(0xFFE8F6F8), // foam
  },
  glows: {
    GemType.red: Color(0xFFFF9E9E),
    GemType.orange: Color(0xFFFFC79E),
    GemType.yellow: Color(0xFFFFF0A0),
    GemType.green: Color(0xFF6BDDD2),
    GemType.blue: Color(0xFF62AEE8),
    GemType.purple: Color(0xFF9CA0E0),
    GemType.white: Color(0xFFFFFFFF),
  },
);

const _aurora = GemPalette(
  id: 'aurora',
  name: 'Aurora',
  unlockStreak: 7,
  colors: {
    GemType.red: Color(0xFFFF4D8F), // magenta
    GemType.orange: Color(0xFFFF8FA3), // rose
    GemType.yellow: Color(0xFFCFFF6B), // electric lime
    GemType.green: Color(0xFF3DFFB4), // polar green
    GemType.blue: Color(0xFF41D4FF), // ice blue
    GemType.purple: Color(0xFF9D5CFF), // violet
    GemType.white: Color(0xFFEDEBFF), // moonlight
  },
  glows: {
    GemType.red: Color(0xFFFF85B3),
    GemType.orange: Color(0xFFFFB3C1),
    GemType.yellow: Color(0xFFE2FF9E),
    GemType.green: Color(0xFF7DFFCC),
    GemType.blue: Color(0xFF7FE1FF),
    GemType.purple: Color(0xFFBE93FF),
    GemType.white: Color(0xFFFFFFFF),
  },
);

const _golden = GemPalette(
  id: 'golden',
  name: 'Golden',
  unlockStreak: 30,
  colors: {
    GemType.red: Color(0xFFB0263A), // garnet
    GemType.orange: Color(0xFFCC7722), // amber
    GemType.yellow: Color(0xFFE6B800), // gold
    GemType.green: Color(0xFF0B6E4F), // emerald
    GemType.blue: Color(0xFF1F4E9C), // sapphire
    GemType.purple: Color(0xFF6A2C91), // amethyst
    GemType.white: Color(0xFFF3E9D2), // pearl
  },
  glows: {
    GemType.red: Color(0xFFFFD700),
    GemType.orange: Color(0xFFFFD700),
    GemType.yellow: Color(0xFFFFE34D),
    GemType.green: Color(0xFFFFD700),
    GemType.blue: Color(0xFFFFD700),
    GemType.purple: Color(0xFFFFD700),
    GemType.white: Color(0xFFFFD700),
  },
);

const List<GemPalette> builtinPalettes = [
  _classic,
  _highContrast,
  _ocean,
  _aurora,
  _golden,
];

/// Process-wide active palette. Loaded at startup, swapped from Settings.
class ActivePalette {
  static GemPalette current = _classic;

  /// Built-ins + every library theme, in ladder order.
  static Future<List<GemPalette>> all() async {
    final themes = await ThemeLibrary.load();
    return [...builtinPalettes, ...themes.map((t) => t.toPalette())];
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('palette') ?? 'classic';
    final palettes = await all();
    current = palettes.firstWhere((p) => p.id == id, orElse: () => _classic);
  }

  static Future<void> select(GemPalette p) async {
    current = p;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('palette', p.id);
  }

  /// After Studio edits: if the active palette is a user theme, hot-reload
  /// it (or fall back to Classic if it was deleted).
  static Future<void> refreshIfCustom() async {
    if (current.id.startsWith('user_')) {
      final palettes = await all();
      current = palettes.firstWhere((p) => p.id == current.id,
          orElse: () => builtinPalettes.first);
    }
  }
}
