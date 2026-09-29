import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../auth/phone_login_screen.dart';
import '../team/team_create_screen.dart';
import '../team/team_detail_screen.dart';

class PlayerProfileScreen extends StatefulWidget {
  final int? playerId;
  const PlayerProfileScreen({super.key, this.playerId});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String _selectedFormat = 'T20';

  @override
  void initState() {
    super.initState();
    _fetchPlayerProfile();
  }

  Future<void> _fetchPlayerProfile() async {
    try {
      final query = widget.playerId != null ? '?player_id=${widget.playerId}' : '';
      final res = await _apiService.dio.get('/player_profile_get.php$query');
      if (mounted) {
        setState(() {
          _profileData = res.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }

    final player = _profileData?['player'] ?? {};
    final batting = _profileData?['batting_stats'] ?? {};
    final bowling = _profileData?['bowling_stats'] ?? {};
    final recentForm = _profileData?['recent_form'] as List? ?? [];

    if (player.isEmpty && widget.playerId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Player Profile 🏏',
            style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.background,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.person_outline, size: 56, color: AppTheme.primaryGold),
                ),
                const SizedBox(height: 24),
                Text(
                  'Guest Mode',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Log in with your mobile number to view your cricket profile, batting & bowling stats, and tournament history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('LOGIN / REGISTER'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }


    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Player Profile 🏏',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPlayerProfile,
        color: AppTheme.primaryGold,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 Player Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                      backgroundImage: player['profile_pic'] != null
                          ? NetworkImage('https://sbastro.com/tournament/${player['profile_pic']}')
                          : null,
                      child: player['profile_pic'] == null
                          ? Text(
                              ((player['name'] as String?) ?? 'P')[0].toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      player['name'] ?? 'Cricketer',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${player['city']} • ${player['role']}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildChip(player['batting_style'] ?? 'Right-hand bat'),
                        const SizedBox(width: 8),
                        _buildChip(player['bowling_style'] ?? 'Right-arm medium'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Format Filter Tabs
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['All', 'T20', 'T10', 'Test'].map((format) {
                  final isSelected = _selectedFormat == format;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedFormat = format),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryGold : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSelected ? AppTheme.primaryGold : AppTheme.cardBorder),
                      ),
                      child: Text(
                        format,
                        style: GoogleFonts.outfit(
                          color: isSelected ? const Color(0xFF070710) : AppTheme.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 🏏 Batting Career Stats
              _sectionTitle('BATTING CAREER'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  children: [
                    _statCell('Innings', '${batting['innings'] ?? 0}'),
                    _statCell('Runs', '${batting['runs'] ?? 0}', isHighlight: true),
                    _statCell('Average', '${batting['average'] ?? '0.00'}'),
                    _statCell('Strike Rate', '${batting['strike_rate'] ?? '0.00'}'),
                    _statCell('4s', '${batting['fours'] ?? 0}'),
                    _statCell('6s', '${batting['sixes'] ?? 0}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🎯 Bowling Career Stats
              _sectionTitle('BOWLING CAREER'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  children: [
                    _statCell('Overs', '${bowling['overs'] ?? '0.0'}'),
                    _statCell('Wickets', '${bowling['wickets'] ?? 0}', isHighlight: true),
                    _statCell('Economy', '${bowling['economy'] ?? '0.00'}'),
                    _statCell('Average', '${bowling['average'] ?? '0.00'}'),
                    _statCell('Runs Given', '${bowling['runs'] ?? 0}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 🛡️ My Teams Section
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _sectionTitle('MY TEAMS & SQUADS 🛡️'),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold),
                    icon: const Icon(Icons.add_circle, size: 18),
                    label: const Text('Create Team', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      final created = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TeamCreateScreen()),
                      );
                      if (created == true) {
                        _fetchPlayerProfile();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FutureBuilder<Map<String, dynamic>>(
                future: _apiService.getMyTeams(
                  ownerId: player['user_id'] != null ? int.tryParse(player['user_id'].toString()) : null,
                  playerId: widget.playerId ?? (player['id'] != null ? int.tryParse(player['id'].toString()) : null),
                  mobile: player['mobile']?.toString() ?? player['phone']?.toString(),
                  playerName: player['name']?.toString(),
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppTheme.primaryGold)));
                  }
                  final teams = snapshot.data?['teams'] as List? ?? [];
                  if (teams.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.white38, size: 36),
                          const SizedBox(height: 8),
                          const Text('No teams created yet.', style: TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('CREATE YOUR TEAM NOW'),
                            onPressed: () async {
                              final created = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TeamCreateScreen()),
                              );
                              if (created == true) setState(() {});
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final t = teams[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                        ),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: t['id'])),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                            child: const Icon(Icons.shield, color: AppTheme.primaryGold),
                          ),
                          title: Text(
                            t['name'] ?? 'Team',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${t['short_name'] ?? 'TEAM'} • ${t['city'] ?? 'Tamil Nadu'} • ${t['player_count'] ?? 0} Players',
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryGold),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              // 🔥 Recent Form (Last 5 Matches)
              if (recentForm.isNotEmpty) ...[
                _sectionTitle('RECENT FORM'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: recentForm.length,
                    itemBuilder: (context, index) {
                      final runs = recentForm[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: runs >= 50 ? AppTheme.primaryGold.withValues(alpha: 0.2) : const Color(0xFF131326),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: runs >= 50 ? AppTheme.primaryGold : AppTheme.cardBorder),
                        ),
                        child: Center(
                          child: Text(
                            '$runs runs',
                            style: GoogleFonts.outfit(
                              color: runs >= 50 ? AppTheme.primaryGold : AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryGold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131326),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
    );
  }

  Widget _statCell(String label, String value, {bool isHighlight = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.primaryGold : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }
}
