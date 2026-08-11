import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:share_plus/share_plus.dart';

import '../models/gem.dart';
import '../models/palette.dart';
import '../widgets/starfield_background.dart';

/// The Custom Studio (one 14-day gate → unlimited attributed themes).
/// Library screen: your themes — create, edit, share (GEMS2 codes with
/// name + author), import (adds, credited to its creator), delete.
class PaletteEditorScreen extends StatefulWidget {
  const PaletteEditorScreen({super.key});

  @override
  State<PaletteEditorScreen> createState() => _PaletteEditorScreenState();
}

class _PaletteEditorScreenState extends State<PaletteEditorScreen> {
  List<UserTheme> _themes = [];
  String _author = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _themes = await ThemeLibrary.load();
    _author = await ThemeLibrary.getAuthor();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _ensureAuthor() async {
    if (_author.isNotEmpty) return;
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Sign your work',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLength: 24,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Your name or handle',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () async {
              await ThemeLibrary.setAuthor(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    _author = await ThemeLibrary.getAuthor();
  }

  Future<void> _create() async {
    await _ensureAuthor();
    final t = await ThemeLibrary.create();
    await _reload();
    if (mounted) _edit(t);
  }

  void _edit(UserTheme t) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ThemeEditor(theme: t)),
    ).then((_) async {
      await ActivePalette.refreshIfCustom();
      await _reload();
    });
  }

  Future<void> _share(UserTheme t) async {
    final code = ThemeLibrary.exportCode(t);
    final by = t.author.isNotEmpty ? ' by ${t.author}' : '';
    await Share.share(
        '💎 Gems theme "${t.name}"$by — paste in Custom Studio → Import:\n$code');
  }

  Future<void> _import() async {
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
                  hintText: 'Paste a GEMS code (the whole message is fine)',
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
                final err = await ThemeLibrary.importCode(ctrl.text);
                if (err != null) {
                  setDlg(() => error = err);
                  return;
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
    await _reload();
  }

  Future<void> _delete(UserTheme t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text('Delete "${t.name}"?',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ThemeLibrary.delete(t.id);
      await ActivePalette.refreshIfCustom();
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Studio'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Import theme',
            onPressed: _import,
          ),
        ],
      ),
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('New theme'),
      ),
      body: StarfieldBackground(
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _themes.isEmpty
                  ? Center(
                      child: Text(
                        'No themes yet.\nCreate one, or import a friend\'s code.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.white.withOpacity(0.6)),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      children: [
                        for (final t in _themes)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.12)),
                            ),
                            child: ListTile(
                              onTap: () => _edit(t),
                              title: Row(children: [
                                Expanded(
                                  child: Text(t.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)),
                                ),
                                ...List.generate(6, (i) {
                                  final gt = GemType.values[i];
                                  final pal = t.toPalette();
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 3),
                                    child: Icon(pal.icons![gt],
                                        size: 15, color: pal.colorOf(gt)),
                                  );
                                }),
                              ]),
                              subtitle: Text(
                                t.author.isNotEmpty
                                    ? 'by ${t.author}'
                                    : 'unsigned',
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                      icon: const Icon(Icons.ios_share,
                                          size: 19, color: Colors.white70),
                                      onPressed: () => _share(t)),
                                  IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 19, color: Colors.white38),
                                      onPressed: () => _delete(t)),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

/// Per-theme editor: rename inline, seven live-preview gem rows.
class _ThemeEditor extends StatefulWidget {
  final UserTheme theme;

  const _ThemeEditor({required this.theme});

  @override
  State<_ThemeEditor> createState() => _ThemeEditorState();
}

class _ThemeEditorState extends State<_ThemeEditor> {
  late UserTheme _t;
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _t = widget.theme;
    _nameCtrl = TextEditingController(text: _t.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _t.name = _nameCtrl.text.trim().isEmpty ? _t.name : _nameCtrl.text.trim();
    await ThemeLibrary.update(_t);
    await ActivePalette.refreshIfCustom();
  }

  Future<void> _pickColor(int i) async {
    var c = Color(_t.colors[i]);
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
      setState(() => _t.colors[i] = c.value);
      await _save();
    }
  }

  Future<void> _pickShape(int i) async {
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
              for (var si = 0; si < studioShapes.length; si++)
                IconButton(
                  iconSize: 34,
                  icon: Icon(studioShapes[si], color: Color(_t.colors[i])),
                  onPressed: () => Navigator.pop(ctx, si),
                ),
            ],
          ),
        ),
      ),
    );
    if (idx != null) {
      setState(() => _t.shapes[i] = idx);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pal = _t.toPalette();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TextField(
          controller: _nameCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: const InputDecoration(border: InputBorder.none),
          onSubmitted: (_) => _save(),
          onTapOutside: (_) => _save(),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: StarfieldBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                'Tap a color or shape. Saves as you go.',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 13),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < GemType.values.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: pal
                              .colorOf(GemType.values[i])
                              .withOpacity(0.18),
                          boxShadow: [
                            BoxShadow(
                              color: pal
                                  .glowOf(GemType.values[i])
                                  .withOpacity(0.55),
                              blurRadius: 14,
                            ),
                          ],
                        ),
                        child: Icon(pal.icons![GemType.values[i]],
                            color: pal.colorOf(GemType.values[i]), size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          GemType.values[i].name[0].toUpperCase() +
                              GemType.values[i].name.substring(1),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => _pickColor(i),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Color(_t.colors[i]),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _pickShape(i),
                        child: Icon(pal.icons![GemType.values[i]],
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
