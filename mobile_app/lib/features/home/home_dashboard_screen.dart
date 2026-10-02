import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';
import '../location/location_picker_dialog.dart';
import '../match/live_match_viewer_screen.dart';
import '../match/match_create_screen.dart';
import '../match/qr_match_scanner_screen.dart';
import '../search/global_search_screen.dart';
import '../notifications/notification_list_screen.dart';
import '../tournament/tournament_detail_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locService = LocationService();
  
  bool _isLoading = true;
  String _activeFilter = 'my_matches'; // 'my_matches', 'district', 'all'
  Map<String, dynamic>? _dashboardData;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _locService.currentDistrict.addListener(_onDistrictChanged);
  }

  @override
  void dispose() {
    _locService.currentDistrict.removeListener(_onDistrictChanged);
    super.dispose();
  }

  void _onDistrictChanged() {
    if (mounted) {
      _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.dio.get('/home_dashboard.php', queryParameters: {
        'filter': _activeFilter,
        'district': _locService.currentDistrict.value,
        'state': _locService.currentState.value,
      });
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

  void _setFilter(String filter) {
    if (_activeFilter != filter) {
      setState(() {
        _activeFilter = filter;
      });
      _loadDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveMatches = _dashboardData?['live_matches'] as List? ?? [];
    final fallbackLive = _dashboardData?['district_live_fallback'] as List? ?? [];
    final upcomingMatches = _dashboardData?['upcoming_matches'] as List? ?? [];
    final recentResults = _dashboardData?['recent_results'] as List? ?? [];
    final tournaments = _dashboardData?['tournaments'] as List? ?? [];
    final banners = _dashboardData?['banners'] as List? ?? [];
    final currentDist = _locService.currentDistrict.value;

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
          ).then((_) => _loadDashboard());
        },
      ),
      appBar: AppBar(
        titleSpacing: 16,
        title: GestureDetector(
          onTap: () => LocationPickerDialog.show(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF131326),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 16),
                const SizedBox(width: 4),
                ValueListenableBuilder<String>(
                  valueListenable: _locService.currentDistrict,
                  builder: (_, dist, __) => Text(
                    dist,
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryGold,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.arrow_drop_down, color: AppTheme.primaryGold, size: 18),
              ],
            ),
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
              ).then((_) => _loadDashboard());
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
          padding: const EdgeInsets.symmetric(vertical: 14),
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
                          ).then((_) => _loadDashboard());
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
                          ).then((_) => _loadDashboard());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E38),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryGold, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Join via QR',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const Text(
                                      'Scan & Accept',
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
              const SizedBox(height: 18),

              // ── Segmented Match Filter Tabs ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121224),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      _buildFilterTab('my_matches', '🏏 My Matches'),
                      _buildFilterTab('district', '📍 In $currentDist'),
                      _buildFilterTab('all', '🌐 Explore All'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: AppTheme.primaryGold),
                  ),
                )
              else ...[
                // 🔴 Live Matches Section
                if (liveMatches.isNotEmpty) ...[
                  _sectionTitle('🔴 LIVE MATCHES (${liveMatches.length})'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 185,
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
                ] else if (_activeFilter == 'my_matches') ...[
                  // Friendly Prompt when User has no Live Matches
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131326),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.sports_cricket, color: Colors.white38, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'No live matches for your squad right now',
                            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Matches you host or join via QR will appear here automatically.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 12),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold),
                                icon: const Icon(Icons.location_on, size: 16),
                                label: Text('View $currentDist Matches'),
                                onPressed: () => _setFilter('district'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryGold,
                                  foregroundColor: const Color(0xFF070710),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const MatchCreateScreen()),
                                  ).then((_) => _loadDashboard());
                                },
                                child: const Text('Start Match ➕', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Fallback: If Coimbatore has other live matches, suggest them
                  if (fallbackLive.isNotEmpty) ...[
                    _sectionTitle('📍 LIVE IN $currentDist (${fallbackLive.length})'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 185,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: fallbackLive.length,
                        itemBuilder: (context, index) {
                          return _buildLiveMatchCard(fallbackLive[index]);
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],

                // 📅 Upcoming Matches
                if (upcomingMatches.isNotEmpty) ...[
                  _sectionTitle('📅 UPCOMING MATCHES (${upcomingMatches.length})'),
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

                // 🏆 Active Tournaments in District
                _sectionTitle('🏆 TOURNAMENTS (${tournaments.length})'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: tournaments.length,
                    itemBuilder: (context, index) {
                      final t = tournaments[index];
                      final dist = t['district'] ?? 'Tamil Nadu';

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TournamentDetailScreen(tournamentId: int.parse(t['id'].toString())),
                            ),
                          );
                        },
                        child: Container(
                          width: 220,
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
                                  const Icon(Icons.emoji_events, color: AppTheme.primaryGold, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      t['name'] ?? 'Tournament',
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.white38, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    dist,
                                    style: const TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${t['total_teams'] ?? 0} Teams • ${t['type'] ?? 'League'}',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                              ),
                            ],
                          ),
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
                  const SizedBox(height: 24),
                ],

                // 📢 Promotional Banners
                if (banners.isNotEmpty) ...[
                  SizedBox(
                    height: 110,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: banners.length,
                      itemBuilder: (context, index) {
                        return _buildBannerCard(banners[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String title) {
    final isSelected = (_activeFilter == key);
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFilter(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGold : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: isSelected ? const Color(0xFF070710) : Colors.white70,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 12,
            ),
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
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryGold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildLiveMatchCard(Map<String, dynamic> match) {
    final teamA = match['team_a'] ?? {};
    final teamB = match['team_b'] ?? {};
    final scores = match['scores'] as List? ?? [];
    final locationText = match['district'] ?? match['venue_name'] ?? 'Turf';

    final int teamAId = int.tryParse(teamA['id']?.toString() ?? '') ?? 0;
    final int teamBId = int.tryParse(teamB['id']?.toString() ?? '') ?? 0;

    String scoreTextA = match['score_team_a']?.toString() ?? '';
    String scoreTextB = match['score_team_b']?.toString() ?? '';

    if (scoreTextA.isEmpty || scoreTextB.isEmpty) {
      for (var s in scores) {
        final int batId = int.tryParse(s['batting_team_id']?.toString() ?? '') ?? 0;
        final String formatted = "${s['runs'] ?? 0}/${s['wickets'] ?? 0} (${s['overs'] ?? '0.0'} ov)";
        if (batId == teamAId && scoreTextA.isEmpty) {
          scoreTextA = formatted;
        } else if (batId == teamBId && scoreTextB.isEmpty) {
          scoreTextB = formatted;
        }
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveMatchViewerScreen(matchId: match['id']),
          ),
        ).then((_) => _loadDashboard());
      },
      child: Container(
        width: 285,
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
                Expanded(
                  child: Text(
                    match['tournament_name'] ?? 'Match',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                Expanded(
                  child: Text(
                    teamA['name'] ?? 'Team A',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  scoreTextA.isNotEmpty ? scoreTextA : '-',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    teamB['name'] ?? 'Team B',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  scoreTextB.isNotEmpty ? scoreTextB : '-',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${match['overs_limit']} Overs Match',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      locationText,
                      style: const TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> match, {required bool isUpcoming}) {
    final teamA = match['team_a'] ?? {};
    final teamB = match['team_b'] ?? {};
    final locationText = match['district'] ?? match['venue_name'] ?? 'Turf';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LiveMatchViewerScreen(matchId: match['id']),
          ),
        ).then((_) => _loadDashboard());
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
                  Row(
                    children: [
                      Text(
                        match['tournament_name'] ?? 'Friendly Match',
                        style: const TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.location_on, color: Colors.white38, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        locationText,
                        style: const TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "${teamA['name']} vs ${teamB['name']}",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  if (match['winner_name'] != null)
                    Text(
                      '🏆 Won by ${match['winner_name']}',
                      style: const TextStyle(color: AppTheme.successGreen, fontSize: 12, fontWeight: FontWeight.w600),
                    )
                  else
                    Text(
                      '${match['overs_limit']} Overs Match',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isUpcoming ? Colors.blue.withValues(alpha: 0.15) : AppTheme.primaryGold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isUpcoming ? 'UPCOMING' : 'FINISHED',
                style: TextStyle(
                  color: isUpcoming ? Colors.blueAccent : AppTheme.primaryGold,
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

  Widget _buildBannerCard(Map<String, dynamic> banner) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryGold.withValues(alpha: 0.15),
            const Color(0xFF131326),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  banner['title'] ?? '',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryGold,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  banner['subtitle'] ?? '',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryGold),
        ],
      ),
    );
  }
}
