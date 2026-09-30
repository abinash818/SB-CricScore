import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../match/live_match_viewer_screen.dart';
import '../match/match_create_screen.dart';
import '../match/qr_match_scanner_screen.dart';
import '../search/global_search_screen.dart';
import '../notifications/notification_list_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    try {
      final res = await _apiService.dio.get('/home_dashboard.php');
      if (mounted) {
        setState(() {
          _dashboardData = res.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primaryGold),
        ),
      );
    }

    final liveMatches = _dashboardData?['live_matches'] as List? ?? [];
    final upcomingMatches = _dashboardData?['upcoming_matches'] as List? ?? [];
    final recentResults = _dashboardData?['recent_results'] as List? ?? [];
    final tournaments = _dashboardData?['tournaments'] as List? ?? [];

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: const Color(0xFF070710),
        icon: const Icon(Icons.add),
        label: Text(
          'START MATCH',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MatchCreateScreen()),
          );
        },
      ),
      appBar: AppBar(
        title: Text(
          'SB CRICSCORE',
          style: GoogleFonts.outfit(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Scan Match QR Code',
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrMatchScannerScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search, color: AppTheme.primaryGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppTheme.primaryGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationListScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        color: AppTheme.primaryGold,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Quick Match Actions Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Start New Match Card
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MatchCreateScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.primaryGold.withValues(alpha: 0.2),
                                AppTheme.cardBg,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryGold,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.sports_cricket, color: Color(0xFF070710), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Start Match',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.primaryGold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Text(
                                      'Create & Get QR',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Scan Match QR Card
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QrMatchScannerScreen()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00E676).withValues(alpha: 0.15),
                                AppTheme.cardBg,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00E676),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.qr_code_scanner, color: Color(0xFF070710), size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Scan Match QR',
                                      style: GoogleFonts.outfit(
                                        color: const Color(0xFF00E676),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Text(
                                      'Join as Opponent',
                                      style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 🔴 Live Matches Section
              if (liveMatches.isNotEmpty) ...[
                _sectionTitle('🔴 LIVE MATCHES'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: liveMatches.length,
                    itemBuilder: (context, index) {
                      return _buildLiveMatchCard(liveMatches[index]);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 📅 Upcoming Matches
              if (upcomingMatches.isNotEmpty) ...[
                _sectionTitle('📅 UPCOMING MATCHES'),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: upcomingMatches.length,
                  itemBuilder: (context, index) {
                    return _buildMatchTile(upcomingMatches[index], isUpcoming: true);
                  },
                ),
                const SizedBox(height: 24),
              ],

              // 🏆 Active Tournaments
              _sectionTitle('🏆 TOURNAMENTS'),
              const SizedBox(height: 12),
              SizedBox(
                height: 140,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) {
                    final t = tournaments[index];
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.emoji_events, color: AppTheme.primaryGold, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  t['name'] ?? 'Tournament',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '${t['total_teams'] ?? 0} Teams • ${t['type'] ?? 'League'}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'VIEW HUB',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppTheme.primaryGold,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // 📊 Recent Results
              if (recentResults.isNotEmpty) ...[
                _sectionTitle('📊 RECENT RESULTS'),
                const SizedBox(height: 12),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: recentResults.length,
                  itemBuilder: (context, index) {
                    return _buildMatchTile(recentResults[index], isUpcoming: false);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryGold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildLiveMatchCard(Map<String, dynamic> match) {
    final teamA = match['team_a'] ?? {};
    final teamB = match['team_b'] ?? {};
    final scores = match['scores'] as List? ?? [];

    String scoreTextA = 'Yet to bat';
    String scoreTextB = 'Yet to bat';

    for (var s in scores) {
      if (s['batting_team_id'] == teamA['id']) {
        scoreTextA = '${s['runs']}/${s['wickets']} (${s['overs']} ov)';
      } else if (s['batting_team_id'] == teamB['id']) {
        scoreTextB = '${s['runs']}/${s['wickets']} (${s['overs']} ov)';
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveMatchViewerScreen(matchId: match['id']),
          ),
        );
      },
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGold.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  match['tournament_name'] ?? 'Match',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(color: AppTheme.errorRed, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  teamA['name'] ?? 'Team A',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  scoreTextA,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  teamB['name'] ?? 'Team B',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  scoreTextB,
                  style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '${match['overs_limit']} Overs Match',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> match, {required bool isUpcoming}) {
    final teamA = match['team_a'] ?? {};
    final teamB = match['team_b'] ?? {};

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveMatchViewerScreen(matchId: match['id']),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${teamA['name']} vs ${teamB['name']}',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    match['tournament_name'] ?? 'Tournament',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isUpcoming ? AppTheme.primaryGold.withValues(alpha: 0.15) : Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isUpcoming ? 'UPCOMING' : (match['winner_name'] != null ? '${match['winner_name']} Won' : 'FINISHED'),
                style: TextStyle(
                  color: isUpcoming ? AppTheme.primaryGold : AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
