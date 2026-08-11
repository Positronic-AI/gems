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

/// The player's own palette (Custom Studio, 14-day unlock). Persisted as
/// color values + shape indices in prefs; defaults to Classic's look.
class CustomPalette {
  static const unlockStreak = 14;

  static Future<GemPalette> load() async {
    final prefs = await SharedPreferences.getInstance();
    final colors = <GemType, Color>{};
    final glows = <GemType, Color>{};
    final icons = <GemType, IconData>{};
    for (final t in GemType.values) {
      final v = prefs.getInt('custom_color_${t.name}');
      final c = v != null ? Color(v) : _classic.colorOf(t);
      colors[t] = c;
      glows[t] = deriveGlow(c);
      final si = prefs.getInt('custom_shape_${t.name}');
      icons[t] = (si != null && si >= 0 && si < studioShapes.length)
          ? studioShapes[si]
          : t.classicIcon;
    }
    return GemPalette(
      id: 'custom',
      name: 'My Palette',
      unlockStreak: unlockStreak,
      colors: colors,
      glows: glows,
      icons: icons,
    );
  }

  static Future<void> setColor(GemType t, Color c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_color_${t.name}', c.value);
  }

  static Future<void> setShape(GemType t, int shapeIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('custom_shape_${t.name}', shapeIndex);
  }

  /// Shareable theme code: GEMS1. + base64url of {"c":[7 colors],"s":[7
  /// shape indices]}. Versioned so future payloads (drawn shapes) can ride
  /// the same envelope. Sharing travels the OS share sheet — no network.
  static Future<String> exportCode() async {
    final prefs = await SharedPreferences.getInstance();
    final c = <int>[];
    final sh = <int>[];
    for (final t in GemType.values) {
      c.add(prefs.getInt('custom_color_${t.name}') ??
          _classic.colorOf(t).value);
      sh.add(prefs.getInt('custom_shape_${t.name}') ?? -1);
    }
    final payload = jsonEncode({'c': c, 's': sh});
    return 'GEMS1.${base64UrlEncode(utf8.encode(payload))}';
  }

  /// Returns null on success, or a human-readable error.
  static Future<String?> importCode(String code) async {
    try {
      final trimmed = code.trim();
      if (!trimmed.startsWith('GEMS1.')) {
        return 'Not a Gems theme code (should start with GEMS1.)';
      }
      final payload = utf8.decode(
          base64Url.decode(base64Url.normalize(trimmed.substring(6))));
      final j = jsonDecode(payload) as Map<String, dynamic>;
      final c = (j['c'] as List).cast<int>();
      final sh = (j['s'] as List).cast<int>();
      if (c.length != GemType.values.length ||
          sh.length != GemType.values.length) {
        return 'Theme code is for a different game version';
      }
      final prefs = await SharedPreferences.getInstance();
      for (var i = 0; i < GemType.values.length; i++) {
        final t = GemType.values[i];
        await prefs.setInt('custom_color_${t.name}', c[i]);
        if (sh[i] >= 0 && sh[i] < studioShapes.length) {
          await prefs.setInt('custom_shape_${t.name}', sh[i]);
        } else {
          await prefs.remove('custom_shape_${t.name}');
        }
      }
      return null;
    } catch (_) {
      return 'Could not read that code — was it pasted completely?';
    }
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    for (final t in GemType.values) {
      await prefs.remove('custom_color_${t.name}');
      await prefs.remove('custom_shape_${t.name}');
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

  /// Built-ins + the player's custom palette, in ladder order.
  static Future<List<GemPalette>> all() async {
    final custom = await CustomPalette.load();
    return [...builtinPalettes, custom];
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

  /// After Studio edits: if the custom palette is active, hot-reload it.
  static Future<void> refreshIfCustom() async {
    if (current.id == 'custom') {
      current = await CustomPalette.load();
    }
  }
}
