import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import 'playing_xi_selector_screen.dart';
import 'toss_screen.dart';
import 'qr_match_scanner_screen.dart';

class MatchCreateScreen extends StatefulWidget {
  final int? tournamentId;
  const MatchCreateScreen({super.key, this.tournamentId});

  @override
  State<MatchCreateScreen> createState() => _MatchCreateScreenState();
}

class _MatchCreateScreenState extends State<MatchCreateScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _venueController = TextEditingController(text: 'Marina Cricket Ground');
  final TextEditingController _oversController = TextEditingController(text: '10');
  final TextEditingController _wicketsController = TextEditingController(text: '10');

  List<dynamic> _teams = [];
  bool _isLoading = true;
  bool _isCreating = false;

  int? _selectedTeamA;
  int? _selectedTeamB;
  String _ballType = 'tennis_light';

  final Map<String, String> _ballTypes = {
    'tennis_light': '🎾 Tennis (Light)',
    'tennis_heavy': '🎾 Tennis (Heavy)',
    'leather': '🏏 Leather Ball',
    'rubber': '⚪ Rubber Ball',
  };

  List<dynamic> _myTeams = [];

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final myRes = await _apiService.getMyTeams();
      final allRes = await _apiService.dio.get('/team_ops.php', queryParameters: {'action': 'list'});

      if (mounted) {
        setState(() {
          _myTeams = myRes['teams'] as List? ?? [];
          final allTeams = allRes.data['teams'] as List? ?? [];

          // Merge uniquely: My Teams first, followed by other teams
          final Map<int, dynamic> teamMap = {};
          for (var t in _myTeams) {
            teamMap[int.parse(t['id'].toString())] = {...t, 'is_my_team': true};
          }
          for (var t in allTeams) {
            final id = int.parse(t['id'].toString());
            if (!teamMap.containsKey(id)) {
              teamMap[id] = {...t, 'is_my_team': false};
            }
          }

          _teams = teamMap.values.toList();

          // Auto-select user's own team for Team A if available
          if (_myTeams.isNotEmpty && _selectedTeamA == null) {
            _selectedTeamA = int.parse(_myTeams.first['id'].toString());
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMatchCreatedDialog({
    required int matchId,
    required String matchCode,
    required String shareLink,
    required String teamAName,
    required String teamBName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F0F1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.gold, width: 1.5),
          ),
          title: Text(
            'Match Created Successfully! 🎉',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: AppTheme.gold, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$teamAName vs $teamBName',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Match PIN: $matchCode',
                  style: GoogleFonts.outfit(color: AppTheme.gold, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: QrImageView(
                    data: 'sbcric_match:$matchCode',
                    version: QrVersions.auto,
                    size: 160.0,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Ask Opponent Captain to scan this QR code or use Match PIN.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),

                // WhatsApp Share Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share Match Link on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Share.share(
                      '🏏 Join our Cricket Match!\nMatch Code: $matchCode\nLive Link: $shareLink',
                      subject: 'SB CricScore Match Invite',
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog

                // 1. Open Lineup Selector for Team A first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PlayingXiSelectorScreen(
                      matchId: matchId,
                      teamId: _selectedTeamA!,
                      teamName: teamAName,
                      onSaved: () {
                        // After Team A saves Lineup, proceed to Toss
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TossScreen(
                              matchId: matchId,
                              teamAId: _selectedTeamA!,
                              teamBId: _selectedTeamB!,
                              teamAName: teamAName,
                              teamBName: teamBName,
                              oversLimit: int.tryParse(_oversController.text) ?? 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
              child: Text(
                'Set Playing XI (11+3) ➔',
                style: GoogleFonts.outfit(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  void _handleCreateMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeamA == null || _selectedTeamB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Team A and Team B'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }
    if (_selectedTeamA == _selectedTeamB) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team A and Team B cannot be the same team'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final res = await _apiService.dio.post('/match_create.php', data: {
        'tournament_id': widget.tournamentId,
        'team_a_id': _selectedTeamA,
        'team_b_id': _selectedTeamB,
        'overs_limit': int.tryParse(_oversController.text) ?? 10,
        'wickets_limit': int.tryParse(_wicketsController.text) ?? 10,
        'venue_name': _venueController.text.trim(),
        'ball_type': _ballType,
      });

      if (mounted) {
        setState(() => _isCreating = false);
        if (res.data['success'] == true || res.data['ok'] == true) {
          final matchId = res.data['match_id'];
          final matchCode = res.data['match_code'] ?? 'SB1234';
          final shareLink = res.data['share_link'] ?? '';
          final teamAName = _teams.firstWhere((t) => t['id'] == _selectedTeamA)['name'];
          final teamBName = _teams.firstWhere((t) => t['id'] == _selectedTeamB)['name'];

          _showMatchCreatedDialog(
            matchId: matchId,
            matchCode: matchCode,
            shareLink: shareLink,
            teamAName: teamAName,
            teamBName: teamBName,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data['message'] ?? 'Failed to create match'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Create Match',
          style: GoogleFonts.outfit(color: AppTheme.gold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Scan Match QR Code',
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.gold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrMatchScannerScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Opponent QR Scan Banner ──
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QrMatchScannerScreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00E676),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.qr_code_scanner, color: Color(0xFF070710), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Opponent Team Captain? 📷',
                                    style: GoogleFonts.outfit(
                                      color: const Color(0xFF00E676),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Text(
                                    'Tap here to scan Host QR or enter PIN to join',
                                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Color(0xFF00E676), size: 14),
                          ],
                        ),
                      ),
                    ),

                    // Teams Selector
                    Text('Select Teams', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedTeamA,
                      decoration: const InputDecoration(
                        labelText: 'Host Team (Team A) *',
                        prefixIcon: Icon(Icons.shield_outlined, color: AppTheme.gold),
                      ),
                      items: _teams.map<DropdownMenuItem<int>>((t) {
                        final bool isMyTeam = t['is_my_team'] == true;
                        return DropdownMenuItem<int>(
                          value: int.parse(t['id'].toString()),
                          child: Row(
                            children: [
                              if (isMyTeam) ...[
                                const Text('⭐ ', style: TextStyle(fontSize: 14)),
                              ],
                              Text(
                                t['name'] ?? 'Team',
                                style: TextStyle(
                                  fontWeight: isMyTeam ? FontWeight.bold : FontWeight.normal,
                                  color: isMyTeam ? AppTheme.gold : Colors.white,
                                ),
                              ),
                              if (isMyTeam) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('My Team', style: TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedTeamA = val),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: _selectedTeamB,
                      decoration: const InputDecoration(
                        labelText: 'Opponent Team (Team B) *',
                        prefixIcon: Icon(Icons.shield, color: AppTheme.gold),
                      ),
                      items: _teams.map<DropdownMenuItem<int>>((t) {
                        final bool isMyTeam = t['is_my_team'] == true;
                        return DropdownMenuItem<int>(
                          value: int.parse(t['id'].toString()),
                          child: Row(
                            children: [
                              if (isMyTeam) ...[
                                const Text('⭐ ', style: TextStyle(fontSize: 14)),
                              ],
                              Text(
                                t['name'] ?? 'Team',
                                style: TextStyle(
                                  fontWeight: isMyTeam ? FontWeight.bold : FontWeight.normal,
                                  color: isMyTeam ? AppTheme.gold : Colors.white,
                                ),
                              ),
                              if (isMyTeam) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.gold.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('My Team', style: TextStyle(color: AppTheme.gold, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedTeamB = val),
                    ),
                    const SizedBox(height: 20),

                    // Ground & Ball Type
                    Text('Match Details', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _venueController,
                      decoration: const InputDecoration(
                        labelText: 'Ground / Venue Name *',
                        prefixIcon: Icon(Icons.location_on, color: AppTheme.gold),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Venue name required' : null,
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: _ballType,
                      decoration: const InputDecoration(
                        labelText: 'Ball Type *',
                        prefixIcon: Icon(Icons.sports_baseball, color: AppTheme.gold),
                      ),
                      items: _ballTypes.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _ballType = val ?? 'tennis_light'),
                    ),
                    const SizedBox(height: 20),

                    // Overs & Wickets
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _oversController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Overs Limit *',
                              prefixIcon: Icon(Icons.timer, color: AppTheme.gold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _wicketsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Wickets *',
                              prefixIcon: Icon(Icons.sports_cricket, color: AppTheme.gold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: const Color(0xFF070710),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isCreating ? null : _handleCreateMatch,
                        child: _isCreating
                            ? const CircularProgressIndicator(color: Colors.black)
                            : Text(
                                'Generate Match & QR 🚀',
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
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
