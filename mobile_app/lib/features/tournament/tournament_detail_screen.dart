import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_service.dart';
import '../match/match_create_screen.dart';
import '../match/live_match_viewer_screen.dart';
import '../match/full_scorecard_screen.dart';
import '../match/toss_screen.dart';
import '../team/team_create_screen.dart';
import '../team/team_detail_screen.dart';
import 'tournament_leaderboard_screen.dart';

class TournamentDetailScreen extends StatefulWidget {
  final int tournamentId;

  const TournamentDetailScreen({super.key, required this.tournamentId});

  @override
  State<TournamentDetailScreen> createState() => _TournamentDetailScreenState();
}

class _TournamentDetailScreenState extends State<TournamentDetailScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _tournament;
  List<dynamic> _teams = [];
  List<dynamic> _matches = [];
  List<dynamic> _pointsTable = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTournamentHub();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTournamentHub() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _apiService.getTournamentHub(widget.tournamentId);
      if (res['success'] == true) {
        setState(() {
          _tournament = res['tournament'];
          _teams = res['teams'] ?? [];
          _matches = res['matches'] ?? [];
          _pointsTable = res['points_table'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load tournament data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading hub: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateFixturesDialog() async {
    if (_teams.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 teams are required to generate fixtures.')),
      );
      return;
    }

    String selectedType = 'single';
    int overs = int.tryParse(_tournament?['default_overs']?.toString() ?? '20') ?? 20;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF121222),
        title: const Text('⚡ Auto-Generate Fixtures', style: TextStyle(color: Color(0xFFDFBA73))),
        content: StatefulBuilder(
          builder: (context, setDlgState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Generate match fixtures automatically for all participating teams.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedType,
                dropdownColor: const Color(0xFF121222),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Fixture Type',
                  labelStyle: TextStyle(color: Color(0xFFDFBA73)),
                ),
                items: const [
                  DropdownMenuItem(value: 'single', child: Text('Single Round Robin (All vs All 1x)')),
                  DropdownMenuItem(value: 'double', child: Text('Double Round Robin (Home & Away)')),
                  DropdownMenuItem(value: 'knockout', child: Text('Single Knockout Bracket')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => selectedType = val);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDFBA73)),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final res = await _apiService.generateFixtures(
                  tournamentId: widget.tournamentId,
                  type: selectedType,
                  oversLimit: overs,
                );
                if (res['success'] == true) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ ${res['message']}'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadTournamentHub();
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message'] ?? 'Failed to generate fixtures')),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error generating fixtures: $e')),
                  );
                }
              }
            },
            child: const Text('Generate', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTournamentQrDialog() {
    final tName = _tournament?['name'] ?? 'Tournament';
    final qrPayload = 'sbcric_tourn:${widget.tournamentId}';
    final shareLink = 'https://sbastro.com/tournament/pages/tournament.php?tour_id=${widget.tournamentId}&register=1';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121222),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFDFBA73), width: 1.5),
        ),
        title: Text(
          'Tournament QR & Registration 🏆',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDFBA73), fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: qrPayload,
                version: QrVersions.auto,
                size: 160.0,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Team Captains can scan this QR in SB CricScore App or use the WhatsApp link to register their team & squad directly!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Share Registration Link on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Share.share(
                  '🏆 Register your Cricket Team for $tName!\nScan QR in SB CricScore App or Register Online:\n$shareLink',
                  subject: 'Tournament Team Registration',
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF070710);
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    final String name = _tournament?['name'] ?? 'Tournament Hub';
    final String type = _tournament?['type'] ?? 'round_robin';

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code, color: goldColor),
            tooltip: 'Tournament Registration QR',
            onPressed: _showTournamentQrDialog,
          ),
          IconButton(
            icon: const Icon(Icons.emoji_events, color: goldColor),
            tooltip: 'Leaderboard',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TournamentLeaderboardScreen(tournamentId: widget.tournamentId),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: goldColor),
            onPressed: _loadTournamentHub,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadTournamentHub,
                        style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                        child: const Text('Retry', style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Header Banner & Action Buttons
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: goldColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: goldColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: goldColor.withOpacity(0.4)),
                                ),
                                child: Text(
                                  type == 'round_robin' ? '🔄 Round Robin' : '⚡ Knockout',
                                  style: const TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${_teams.length} Teams • ${_matches.length} Matches',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.bolt,
                                  label: 'Auto Fixtures',
                                  color: goldColor,
                                  onTap: _generateFixturesDialog,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.add,
                                  label: 'Create Match',
                                  color: Colors.greenAccent,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MatchCreateScreen(tournamentId: widget.tournamentId),
                                      ),
                                    );
                                    _loadTournamentHub();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildActionButton(
                                  icon: Icons.group_add,
                                  label: 'Add Team',
                                  color: Colors.blueAccent,
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TeamCreateScreen(tournamentId: widget.tournamentId),
                                      ),
                                    );
                                    _loadTournamentHub();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // TabBar
                    Container(
                      color: bgDark,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: goldColor,
                        labelColor: goldColor,
                        unselectedLabelColor: Colors.white54,
                        indicatorWeight: 3,
                        tabs: const [
                          Tab(text: '📅 Fixtures'),
                          Tab(text: '🛡️ Teams'),
                          Tab(text: '📊 Points Table'),
                        ],
                      ),
                    ),

                    // TabBarView Content
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildFixturesTab(),
                          _buildTeamsTab(),
                          _buildPointsTableTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. FIXTURES TAB ──────────────────────────────────────────────────────────
  Widget _buildFixturesTab() {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    if (_matches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text('No Fixtures Scheduled', style: TextStyle(color: Colors.white70, fontSize: 15)),
            const SizedBox(height: 8),
            const Text('Tap "Auto Fixtures" or "Create Match" above', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final m = _matches[index];
        final int matchId = int.tryParse(m['id'].toString()) ?? 0;
        final int teamAId = int.tryParse(m['team_a_id'].toString()) ?? 0;
        final int teamBId = int.tryParse(m['team_b_id'].toString()) ?? 0;
        final String teamA = m['team_a_short'] ?? m['team_a_name'] ?? 'Team A';
        final String teamB = m['team_b_short'] ?? m['team_b_name'] ?? 'Team B';
        final String teamANameFull = m['team_a_name'] ?? 'Team A';
        final String teamBNameFull = m['team_b_name'] ?? 'Team B';
        final int oversLimit = int.tryParse(m['overs_limit']?.toString() ?? '20') ?? 20;
        final String status = m['status'] ?? 'scheduled';
        final String winnerName = m['winner_name'] ?? '';

        Color statusColor = Colors.orangeAccent;
        String statusText = 'SCHEDULED';
        if (status == 'live') {
          statusColor = Colors.redAccent;
          statusText = 'LIVE 🔴';
        } else if (status == 'completed') {
          statusColor = Colors.greenAccent;
          statusText = 'COMPLETED';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: status == 'live' ? Colors.redAccent.withOpacity(0.5) : goldColor.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Match #$matchId', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(teamA, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                  const Text('VS', style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(teamB, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ),
                ],
              ),
              if (winnerName.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('🏆 $winnerName Won', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'scheduled' || status == 'live')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: goldColor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
                      onPressed: () {
                        if (status == 'scheduled') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TossScreen(
                                matchId: matchId,
                                teamAId: teamAId,
                                teamBId: teamBId,
                                teamAName: teamANameFull,
                                teamBName: teamBNameFull,
                                oversLimit: oversLimit,
                              ),
                            ),
                          ).then((_) => _loadTournamentHub());
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LiveMatchViewerScreen(matchId: matchId),
                            ),
                          ).then((_) => _loadTournamentHub());
                        }
                      },
                      child: Text(status == 'scheduled' ? 'Start Toss' : 'Live Viewer', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldColor,
                      side: const BorderSide(color: goldColor),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onPressed: () {
                      if (status == 'completed') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => FullScorecardScreen(matchId: matchId)),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LiveMatchViewerScreen(matchId: matchId)),
                        );
                      }
                    },
                    child: Text(status == 'completed' ? 'Scorecard' : 'Live Center', style: const TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 2. TEAMS TAB ─────────────────────────────────────────────────────────────
  Widget _buildTeamsTab() {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    if (_teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 12),
            const Text('No Teams Added Yet', style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teams.length,
      itemBuilder: (context, index) {
        final t = _teams[index];
        final int teamId = int.tryParse(t['id'].toString()) ?? 0;
        final String name = t['name'] ?? '';
        final String short = t['short_name'] ?? 'TM';
        final int players = int.tryParse(t['player_count']?.toString() ?? '0') ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: goldColor.withOpacity(0.2)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: goldColor.withOpacity(0.2),
              child: Text(short, style: const TextStyle(color: goldColor, fontWeight: FontWeight.bold)),
            ),
            title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Text('$players Squad Players', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            trailing: const Icon(Icons.arrow_forward_ios, color: goldColor, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TeamDetailScreen(teamId: teamId)),
              );
            },
          ),
        );
      },
    );
  }

  // ── 3. POINTS TABLE TAB ──────────────────────────────────────────────────────
  Widget _buildPointsTableTab() {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    if (_pointsTable.isEmpty) {
      return const Center(
        child: Text('No Points Table Data Available', style: TextStyle(color: Colors.white54)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: goldColor.withOpacity(0.2)),
        ),
        child: Table(
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(3.0),
            2: FlexColumnWidth(1.0),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(1.2),
          },
          children: [
            // Header
            TableRow(
              decoration: BoxDecoration(
                color: goldColor.withOpacity(0.15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              children: const [
                _TableCellHeader('#'),
                _TableCellHeader('Team'),
                _TableCellHeader('P'),
                _TableCellHeader('W'),
                _TableCellHeader('L'),
                _TableCellHeader('Pts'),
              ],
            ),
            // Rows
            ...List.generate(_pointsTable.length, (idx) {
              final row = _pointsTable[idx];
              final String name = row['short_name'] ?? row['team'] ?? '';
              final int p = row['P'] ?? 0;
              final int w = row['W'] ?? 0;
              final int l = row['L'] ?? 0;
              final int pts = row['Pts'] ?? 0;

              return TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                children: [
                  _TableCell('#${idx + 1}', isGold: idx < 2),
                  _TableCell(name, isBold: true, isGold: idx < 2),
                  _TableCell('$p'),
                  _TableCell('$w', color: Colors.greenAccent),
                  _TableCell('$l', color: Colors.redAccent),
                  _TableCell('$pts', isBold: true, isGold: true),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _TableCellHeader extends StatelessWidget {
  final String text;
  const _TableCellHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFDFBA73), fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isBold;
  final bool isGold;
  final Color? color;

  const _TableCell(this.text, {this.isBold = false, this.isGold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color ?? (isGold ? const Color(0xFFDFBA73) : Colors.white),
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }
}
