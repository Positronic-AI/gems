import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gem.dart';
import '../models/palette.dart';
import '../widgets/starfield_background.dart';

/// The Custom Studio (14-day streak unlock): design your own gem set.
/// Seven rows, each a live gem preview — tap the swatch for a color picker,
/// tap the shape for the curated icon set. Glows derive automatically.
/// Everything saves as you go; Reset returns to Classic.
class PaletteEditorScreen extends StatefulWidget {
  const PaletteEditorScreen({super.key});

  @override
  State<PaletteEditorScreen> createState() => _PaletteEditorScreenState();
}

class _PaletteEditorScreenState extends State<PaletteEditorScreen> {
  GemPalette? _palette;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final p = await CustomPalette.load();
    if (mounted) setState(() => _palette = p);
  }

  Future<void> _pickColor(GemType t) async {
    var c = _palette!.colorOf(t);
    final applied = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Gem color', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: c,
            onColorChanged: (v) => c = v,
            enableAlpha: false,
            labelTypes: const [],
            pickerAreaBorderRadius: BorderRadius.circular(12),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (applied == true) {
      await CustomPalette.setColor(t, c);
      await ActivePalette.refreshIfCustom();
      await _reload();
    }
  }

  Future<void> _pickShape(GemType t) async {
    final idx = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Gem shape', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: 280,
          height: 340,
          child: GridView.count(
            crossAxisCount: 4,
            children: [
              for (var i = 0; i < studioShapes.length; i++)
                IconButton(
                  iconSize: 34,
                  icon: Icon(studioShapes[i],
                      color: _palette!.colorOf(t)),
                  onPressed: () => Navigator.pop(ctx, i),
                ),
            ],
          ),
        ),
      ),
    );
    if (idx != null) {
      await CustomPalette.setShape(t, idx);
      await ActivePalette.refreshIfCustom();
      await _reload();
    }
  }

  Future<void> _importDialog() async {
    final ctrl = TextEditingController();
    String? error;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Import theme',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                maxLines: 3,
                style: const TextStyle(
                    color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'Paste a GEMS1. code',
                  hintStyle: TextStyle(color: Colors.white38),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final err = await CustomPalette.importCode(ctrl.text);
                if (err != null) {
                  setDlg(() => error = err);
                  return;
                }
                await ActivePalette.refreshIfCustom();
                await _reload();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Studio'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share theme',
            onPressed: () async {
              final code = await CustomPalette.exportCode();
              await Share.share(
                  'My Gems theme — paste this in Custom Studio → Import:\n$code');
            },
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import theme',
            onPressed: _importDialog,
          ),
          TextButton(
            onPressed: () async {
              await CustomPalette.reset();
              await ActivePalette.refreshIfCustom();
              await _reload();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: StarfieldBackground(
        child: SafeArea(
          child: p == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Text(
                      'Tap a gem\'s color or shape to change it. Your palette '
                      'saves as you go and applies everywhere.',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    for (final t in GemType.values)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Row(
                          children: [
                            // Live preview: shape in color with derived glow
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: p.colorOf(t).withOpacity(0.18),
                                boxShadow: [
                                  BoxShadow(
                                    color: p.glowOf(t).withOpacity(0.55),
                                    blurRadius: 14,
                                  ),
                                ],
                              ),
                              child: Icon(p.icons![t],
                                  color: p.colorOf(t), size: 30),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                t.name[0].toUpperCase() + t.name.substring(1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () => _pickColor(t),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: p.colorOf(t),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _pickShape(t),
                              child: Icon(p.icons![t],
                                  size: 20, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
