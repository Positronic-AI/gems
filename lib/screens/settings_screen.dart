import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/game_mode.dart';
import '../services/leaderboard_service.dart';
import '../services/daily_gem.dart';
import '../models/gem.dart';
import '../models/palette.dart';
import '../models/tile_style.dart';
import 'palette_editor_screen.dart';
import '../widgets/starfield_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = 'Loading...';
  final LeaderboardService _leaderboardService = LeaderboardService();
  Map<GameModeType, List<LeaderboardEntry>> _leaderboards = {};
  int _bestStreak = 0;
  int _versionTaps = 0;
  bool _showDebug = false;
  int _curStreak = 0;
  int _passes = 0;
  String _selectedPalette = ActivePalette.current.id;
  TileStyle _tileStyle = ActiveTileStyle.current;
  List<GemPalette> _palettes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadAppInfo();
    await _loadLeaderboards();
    _bestStreak = await DailyGem.bestStreak();
    _curStreak = await DailyGem.currentStreak();
    _passes = await DailyGem.freePasses();
    _palettes = await ActivePalette.all();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
      });
    }
  }

  Future<void> _loadLeaderboards() async {
    for (final mode in GameModeType.values) {
      _leaderboards[mode] = await _leaderboardService.getLeaderboard(mode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StarfieldBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  children: [
                    const SizedBox(height: 32),

                    // App title
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.deepPurple.shade800,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.diamond,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Gem Game',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _versionTaps++;
                              if (_versionTaps >= 7 && !_showDebug) {
                                setState(() => _showDebug = true);
                              }
                            },
                            child: Text(
                              'Version $_appVersion',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    if (_showDebug) ...[
                      _buildSectionHeader('🛠 Time Machine (debug)'),
                      _buildDebugCard(),
                      const SizedBox(height: 24),
                    ],

                    // Palettes + the visible unlock ladder
                    _buildSectionHeader('Tile Style'),
                    ..._buildTileStyleCards(),
                    const SizedBox(height: 24),

                    _buildSectionHeader('Gem Palettes'),
                    ..._buildPaletteCards(),
                    _buildStudioRow(),
                    const SizedBox(height: 24),

                    // Leaderboards
                    _buildSectionHeader('Leaderboards'),
                    ..._buildLeaderboardCards(),

                    const SizedBox(height: 16),

                    // How to play
                    _buildSectionHeader('How to Play'),
                    _buildInfoTile(
                      Icons.swipe,
                      'Swipe to Swap',
                      'Swipe gems to swap them with adjacent gems',
                    ),
                    _buildInfoTile(
                      Icons.view_comfy_alt,
                      'Match 3+',
                      'Match 3 or more gems of the same color',
                    ),
                    _buildInfoTile(
                      Icons.auto_awesome,
                      'Chain Combos',
                      'Create chain reactions for bonus points',
                    ),

                    const SizedBox(height: 16),

                    // Scoring
                    _buildSectionHeader('Scoring'),
                    _buildInfoTile(
                      Icons.star,
                      'Basic Match',
                      '50 points per gem matched',
                    ),
                    _buildInfoTile(
                      Icons.add_circle,
                      'Long Match',
                      '+100 bonus for each gem beyond 3',
                    ),
                    _buildInfoTile(
                      Icons.whatshot,
                      'Combos',
                      '50% bonus per combo level',
                    ),

                    const SizedBox(height: 16),

                    // About
                    _buildSectionHeader('About'),
                    _buildTappableInfoTile(
                      Icons.code,
                      'Open Source',
                      'View source code on GitHub',
                      () => _launchUrl('https://github.com/Positronic-AI/gems'),
                    ),
                    _buildInfoTile(
                      Icons.favorite,
                      'Made with Flutter',
                      'Built with love using Flutter',
                    ),
                    _buildInfoTile(
                      Icons.block,
                      'No Ads, No Tracking',
                      'Your privacy is respected',
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
        ),
      ),
    );
  }

  List<Widget> _buildLeaderboardCards() {
    final cards = <Widget>[];

    for (final mode in GameModeType.values) {
      final entries = _leaderboards[mode] ?? [];
      cards.add(_buildLeaderboardCard(mode, entries));
    }

    return cards;
  }

  Widget _buildLeaderboardCard(GameModeType mode, List<LeaderboardEntry> entries) {
    final colors = {
      GameModeType.timed: Colors.orange,
      GameModeType.moves: Colors.blue,
      GameModeType.target: Colors.green,
      GameModeType.zen: Colors.purple,
    };

    final color = colors[mode] ?? Colors.purple;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Text(mode.icon, style: const TextStyle(fontSize: 24)),
          title: Text(
            '${mode.displayName} Mode',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Text(
            entries.isEmpty
                ? 'No scores yet'
                : 'Best: ${entries.first.score}',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
          iconColor: Colors.white,
          collapsedIconColor: Colors.white.withOpacity(0.6),
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Play ${mode.displayName} mode to set a high score!',
                  style: TextStyle(color: Colors.white.withOpacity(0.5)),
                ),
              )
            else
              ...entries.asMap().entries.map((entry) {
                final index = entry.key;
                final score = entry.value;
                final medals = ['🥇', '🥈', '🥉', '4.', '5.'];

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          medals[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          score.name,
                          style: TextStyle(
                            color: Colors.amber.withOpacity(0.9),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '${score.score}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        score.seed != null
                            ? '${score.gridSize}x${score.gridSize} · s${score.seed}'
                            : '${score.gridSize}x${score.gridSize}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(score.date),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  Widget _buildDebugCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simulated today: ${DailyGem.dateKey()} (offset ${DailyGem.debugDayOffset >= 0 ? '+' : ''}${DailyGem.debugDayOffset}d)\n'
            'Streak: $_curStreak · Best: $_bestStreak · Free Passes: $_passes\n'
            'Seed today: ${DailyGem.seedFor()}',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _debugBtn('+1 day', () async {
                await DailyGem.setDebugOffset(DailyGem.debugDayOffset + 1);
                await _reloadDebug();
              }),
              const SizedBox(width: 8),
              _debugBtn('+2 days', () async {
                await DailyGem.setDebugOffset(DailyGem.debugDayOffset + 2);
                await _reloadDebug();
              }),
              const SizedBox(width: 8),
              _debugBtn('Real time', () async {
                await DailyGem.setDebugOffset(0);
                await _reloadDebug();
              }),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: [
            _debugBtn('Best +7', () async {
              await DailyGem.debugSetBestStreak(_bestStreak + 7);
              await _reloadDebug();
              _palettes = await ActivePalette.all();
              if (mounted) setState(() {});
            }),
          ]),
          const SizedBox(height: 8),
          _debugBtn('💣 Reset ALL daily data (fresh player)', () async {
            await DailyGem.resetAll();
            await _reloadDebug();
          }),
        ],
      ),
    );
  }

  Future<void> _reloadDebug() async {
    _bestStreak = await DailyGem.bestStreak();
    _curStreak = await DailyGem.currentStreak();
    _passes = await DailyGem.freePasses();
    _palettes = await ActivePalette.all();
    if (mounted) setState(() {});
  }

  Widget _debugBtn(String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.redAccent,
        side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Future<void> _openStudio() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PaletteEditorScreen()),
    );
    await ActivePalette.refreshIfCustom();
    _palettes = await ActivePalette.all();
    if (mounted) setState(() {});
  }

  List<Widget> _buildTileStyleCards() {
    return TileStyle.values.map((st) {
      final selected = st == _tileStyle;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.amber : Colors.white.withOpacity(0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          onTap: () async {
            await ActiveTileStyle.select(st);
            setState(() => _tileStyle = st);
          },
          title: Text(st.displayName,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(st.description,
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          trailing: selected
              ? const Icon(Icons.check_circle, color: Colors.amber)
              : null,
        ),
      );
    }).toList();
  }

  Widget _buildStudioRow() {
    final unlocked = ThemeLibrary.unlockStreak <= _bestStreak;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(unlocked ? 0.5 : 0.15)),
      ),
      child: ListTile(
        enabled: unlocked,
        onTap: unlocked ? _openStudio : null,
        leading: Icon(Icons.palette,
            color: unlocked ? Colors.amber : Colors.white24),
        title: Text('Custom Studio',
            style: TextStyle(
                color: unlocked ? Colors.white : Colors.white38,
                fontWeight: FontWeight.bold)),
        subtitle: Text(
          unlocked
              ? 'Design unlimited themes · share them with GEMS codes'
              : '🔒 Design your own gems · unlocks at ${ThemeLibrary.unlockStreak}-day streak',
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: unlocked
            ? const Icon(Icons.chevron_right, color: Colors.amber)
            : const Icon(Icons.lock, color: Colors.white24, size: 18),
      ),
    );
  }

  List<Widget> _buildPaletteCards() {
    return _palettes.map((p) {
      final unlocked = p.unlockStreak <= _bestStreak;
      final selected = p.id == _selectedPalette;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.amber
                : Colors.white.withOpacity(0.15),
            width: selected ? 2 : 1,
          ),
        ),
        child: ListTile(
          enabled: unlocked,
          onTap: unlocked
              ? () async {
                  await ActivePalette.select(p);
                  setState(() => _selectedPalette = p.id);
                }
              : null,
          title: Row(
            children: [
              Text(
                p.name,
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              // Swatch strip — the ladder preview IS the reward preview
              ...GemType.values.take(6).map((t) => Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: unlocked
                          ? p.colorOf(t)
                          : p.colorOf(t).withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                  )),
            ],
          ),
          subtitle: !unlocked
              ? Text(
                  '🔒 Unlocks at ${p.unlockStreak}-day streak',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                )
              : (p.id.startsWith('user_')
                  ? const Text('Custom theme · edit in the Studio',
                      style: TextStyle(color: Colors.white54, fontSize: 12))
                  : p.id == 'colorblind'
                      ? const Text('Colorblind-friendly · free for everyone',
                          style: TextStyle(color: Colors.white54, fontSize: 12))
                      : null),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected)
                const Icon(Icons.check_circle, color: Colors.amber)
              else if (!unlocked)
                const Icon(Icons.lock, color: Colors.white24, size: 18),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.purple.shade300,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.purple.shade300),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildTappableInfoTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.purple.shade300),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade400),
      ),
      trailing: Icon(
        Icons.open_in_new,
        color: Colors.grey.shade500,
        size: 18,
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Silently fail if unable to launch
    }
  }
}
