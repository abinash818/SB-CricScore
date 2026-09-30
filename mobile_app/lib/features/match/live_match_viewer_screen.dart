import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import 'full_scorecard_screen.dart';
import 'match_analytics_screen.dart';
import 'toss_screen.dart';
import 'live_scorer_console_screen.dart';

class LiveMatchViewerScreen extends StatefulWidget {
  final int matchId;
  const LiveMatchViewerScreen({super.key, required this.matchId});

  @override
  State<LiveMatchViewerScreen> createState() => _LiveMatchViewerScreenState();
}

class _LiveMatchViewerScreenState extends State<LiveMatchViewerScreen> {
  final ApiService _apiService = ApiService();
  Timer? _pollingTimer;

  bool _isLoading = true;
  Map<String, dynamic>? _matchData;

  @override
  void initState() {
    super.initState();
    _fetchLiveMatch();
    // 5-second polling for live spectator updates
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchLiveMatch());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchLiveMatch() async {
    try {
      final res = await _apiService.dio.get('/live_match_viewer.php?match_id=${widget.matchId}');
      if (mounted) {
        setState(() {
          _matchData = res.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchStream(String urlStr) async {
    if (urlStr.trim().isEmpty) return;
    Uri? uri = Uri.tryParse(urlStr.trim());
    if (uri != null) {
      if (!uri.hasScheme) {
        uri = Uri.tryParse('https://${urlStr.trim()}');
      }
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open YouTube link. Please check the URL.')),
      );
    }
  }

  void _showStreamUrlDialog(String currentUrl) {
    final controller = TextEditingController(text: currentUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppTheme.primaryGold)),
        title: Row(
          children: [
            const Icon(Icons.live_tv, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text('YouTube Live Stream', style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the YouTube Live Stream URL or Video ID for this match:',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/live/...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF131326),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.primaryGold)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
            onPressed: () async {
              final newUrl = controller.text.trim();
              Navigator.pop(ctx);
              try {
                final res = await _apiService.updateMatchStream(widget.matchId, newUrl);
                if (res['success'] == true) {
                  _fetchLiveMatch();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('YouTube Stream URL updated! 🔴')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to update URL: $e')),
                  );
                }
              }
            },
            child: const Text('Save URL', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _openScorerConsoleOrToss() {
    final status = _matchData?['status']?.toString() ?? 'scheduled';
    final teamA = _matchData?['team_a'] ?? {};
    final teamB = _matchData?['team_b'] ?? {};
    final int teamAId = int.tryParse(teamA['id']?.toString() ?? '0') ?? 0;
    final int teamBId = int.tryParse(teamB['id']?.toString() ?? '0') ?? 0;
    final String teamAName = teamA['name']?.toString() ?? 'Team A';
    final String teamBName = teamB['name']?.toString() ?? 'Team B';
    final int oversLimit = int.tryParse(_matchData?['overs_limit']?.toString() ?? '10') ?? 10;

    if (status == 'scheduled' || status == 'pending_toss') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TossScreen(
            matchId: widget.matchId,
            teamAId: teamAId,
            teamBId: teamBId,
            teamAName: teamAName,
            teamBName: teamBName,
            oversLimit: oversLimit,
          ),
        ),
      ).then((_) => _fetchLiveMatch());
    } else {
      final int innId = int.tryParse(_matchData?['active_innings_id']?.toString() ?? '1') ?? 1;
      final int batTeamId = int.tryParse(_matchData?['batting_team_id']?.toString() ?? '0') ?? teamAId;
      final int bowlTeamId = int.tryParse(_matchData?['bowling_team_id']?.toString() ?? '0') ?? teamBId;
      final String batTeamName = _matchData?['batting_team']?.toString() ?? ((batTeamId == teamAId) ? teamAName : teamBName);
      final String bowlTeamName = (batTeamId == teamAId) ? teamBName : teamAName;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveScorerConsoleScreen(
            matchId: widget.matchId,
            inningsId: innId,
            battingTeamId: batTeamId,
            bowlingTeamId: bowlTeamId,
            battingTeamName: batTeamName,
            bowlingTeamName: bowlTeamName,
            oversLimit: oversLimit,
            initialScorerName: _matchData?['active_scorer_name']?.toString(),
          ),
        ),
      ).then((_) => _fetchLiveMatch());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }

    final teamA = _matchData?['team_a'] ?? {};
    final teamB = _matchData?['team_b'] ?? {};
    final battingTeam = _matchData?['batting_team'] ?? 'Batting';
    final runs = _matchData?['runs'] ?? 0;
    final wickets = _matchData?['wickets'] ?? 0;
    final overs = _matchData?['overs'] ?? '0.0';
    final oversLimit = _matchData?['overs_limit'] ?? 20;
    final crr = _matchData?['crr'] ?? '0.00';
    final rrr = _matchData?['rrr'] ?? '0.00';
    final reqRuns = _matchData?['runs_required'] ?? 0;
    final remBalls = _matchData?['balls_remaining'] ?? 0;
    final youtubeUrl = (_matchData?['youtube_url'] ?? '').toString();
    final commentary = _matchData?['commentary'] as List? ?? [];
    final matchStatus = _matchData?['status']?.toString() ?? 'scheduled';

    final isCurrentUserScorer = (_matchData?['is_current_user_scorer'] == true);
    final activeScorerName = _matchData?['active_scorer_name']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Match Center Live 🔴',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          if (matchStatus != 'completed')
            IconButton(
              icon: Icon(
                Icons.sports_cricket,
                color: isCurrentUserScorer ? AppTheme.primaryGold : Colors.white60,
              ),
              tooltip: isCurrentUserScorer ? 'Scorekeeper Console ✍️' : 'Live Score Console (View) 👁️',
              onPressed: _openScorerConsoleOrToss,
            ),
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primaryGold),
            tooltip: 'Share Live Scorecard',
            onPressed: () async {
              try {
                final res = await _apiService.getMatchShareSummary(widget.matchId);
                if (res['success'] == true && res['share_text'] != null) {
                  Share.share(res['share_text']);
                }
              } catch (_) {}
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: AppTheme.primaryGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MatchAnalyticsScreen(matchId: widget.matchId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long, color: AppTheme.primaryGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScorecardScreen(matchId: widget.matchId),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchLiveMatch,
        color: AppTheme.primaryGold,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scorer / Spectator Quick Access Banner
              if (matchStatus != 'completed')
                GestureDetector(
                  onTap: _openScorerConsoleOrToss,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCurrentUserScorer
                            ? [AppTheme.primaryGold.withValues(alpha: 0.25), const Color(0xFF1E1E38)]
                            : [const Color(0xFF16162E), const Color(0xFF0F0F1E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrentUserScorer
                            ? AppTheme.primaryGold.withValues(alpha: 0.6)
                            : Colors.white12,
                        width: isCurrentUserScorer ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isCurrentUserScorer ? AppTheme.primaryGold : const Color(0xFF1E1E38),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isCurrentUserScorer ? Icons.sports_cricket : Icons.remove_red_eye,
                            color: isCurrentUserScorer ? const Color(0xFF070710) : AppTheme.primaryGold,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCurrentUserScorer
                                    ? ((matchStatus == 'scheduled' || matchStatus == 'pending_toss')
                                        ? 'Start Match Toss 🪙'
                                        : 'You are the Active Scorer ✍️')
                                    : 'Live Match Center 🔴 (Spectator)',
                                style: GoogleFonts.outfit(
                                  color: isCurrentUserScorer ? AppTheme.primaryGold : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                isCurrentUserScorer
                                    ? 'Tap to record runs, extras & wickets'
                                    : (activeScorerName != null
                                        ? 'Scoring by $activeScorerName • Tap to view live console'
                                        : 'Updates real-time ball-by-ball'),
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: isCurrentUserScorer ? AppTheme.primaryGold : Colors.white38,
                          size: 13,
                        ),
                      ],
                    ),
                  ),
                ),

              // Live Stream Banner (If URL available or option to add)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B0000), Color(0xFF131326)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.2),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'YOUTUBE LIVE STREAM',
                                style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            youtubeUrl.isNotEmpty
                                ? 'Watch live video coverage'
                                : 'No live stream link added yet',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (youtubeUrl.isNotEmpty) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _launchStream(youtubeUrl),
                        icon: const Icon(Icons.tv, size: 16),
                        label: const Text('WATCH LIVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      icon: Icon(youtubeUrl.isNotEmpty ? Icons.edit : Icons.add_link, color: AppTheme.primaryGold),
                      tooltip: 'Set/Edit Stream Link',
                      onPressed: () => _showStreamUrlDialog(youtubeUrl),
                    ),
                  ],
                ),
              ),

              // Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryGold, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGold.withValues(alpha: 0.1),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      '${teamA['name']} vs ${teamB['name']}',
                      style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$battingTeam: $runs/$wickets',
                      style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                    ),
                    Text(
                      'Overs: $overs / $oversLimit',
                      style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('CRR: $crr', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        if (reqRuns > 0) ...[
                          const SizedBox(width: 16),
                          Text('RRR: $rrr', style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ],
                    ),
                    if (reqRuns > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Need $reqRuns runs in $remBalls balls',
                          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LIVE COMMENTARY',
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => FullScorecardScreen(matchId: widget.matchId)),
                      );
                    },
                    icon: const Icon(Icons.table_chart, size: 16, color: AppTheme.primaryGold),
                    label: const Text('SCORECARD', style: TextStyle(color: AppTheme.primaryGold, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: commentary.length,
                itemBuilder: (context, index) {
                  final c = commentary[index];
                  final isWkt = c['is_wicket'] == true;
                  final runs = c['runs'] ?? 0;
                  final isBoundary = runs == 4 || runs == 6;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isWkt
                                ? AppTheme.errorRed
                                : (isBoundary ? AppTheme.primaryGold : const Color(0xFF131326)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c['over_ball'] ?? '0.0',
                            style: TextStyle(
                              color: isBoundary ? const Color(0xFF070710) : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${c['bowler']} to ${c['striker']}',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c['event'] ?? '',
                                style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (isCurrentUserScorer && matchStatus != 'completed')
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: const Color(0xFF070710),
              elevation: 6,
              icon: const Icon(Icons.sports_cricket, size: 22),
              label: Text(
                (matchStatus == 'scheduled' || matchStatus == 'pending_toss')
                    ? '🪙 START MATCH TOSS'
                    : '✍️ ENTER LIVE SCORES',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
              ),
              onPressed: _openScorerConsoleOrToss,
            )
          : null,
    );
  }
}

