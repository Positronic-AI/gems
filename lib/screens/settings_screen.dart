import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models/game_mode.dart';
import '../services/leaderboard_service.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await _loadAppInfo();
    await _loadLeaderboards();
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
                          Text(
                            'Version $_appVersion',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

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
                    _buildInfoTile(
                      Icons.code,
                      'Open Source',
                      'Free and open source - no ads, no tracking',
                    ),
                    _buildInfoTile(
                      Icons.favorite,
                      'Made with Flutter',
                      'Built with love using Flutter',
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
                        '${score.gridSize}x${score.gridSize}',
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
}
