import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../main_navigation_screen.dart';

class LiveScorerConsoleScreen extends StatefulWidget {
  final int matchId;
  final int inningsId;
  final int battingTeamId;
  final int bowlingTeamId;
  final String battingTeamName;
  final String bowlingTeamName;
  final int oversLimit;
  final String? initialScorerName;

  const LiveScorerConsoleScreen({
    super.key,
    required this.matchId,
    required this.inningsId,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.battingTeamName,
    required this.bowlingTeamName,
    required this.oversLimit,
    this.initialScorerName,
  });

  @override
  State<LiveScorerConsoleScreen> createState() => _LiveScorerConsoleScreenState();
}

class _LiveScorerConsoleScreenState extends State<LiveScorerConsoleScreen> {
  final ApiService _apiService = ApiService();

  late int _currentInningsId;
  late int _currentInningsNo;
  late int _currentBattingTeamId;
  late int _currentBowlingTeamId;
  late String _currentBattingTeamName;
  late String _currentBowlingTeamName;
  String? _activeScorerName;

  int _totalRuns = 0;
  int _totalWickets = 0;
  int _legalBalls = 0;
  int? _targetRuns;
  List<String> _thisOver = [];
  bool _isLoading = false;
  bool _isFreeHit = false;

  @override
  void initState() {
    super.initState();
    _currentInningsId = widget.inningsId;
    _currentInningsNo = 1;
    _currentBattingTeamId = widget.battingTeamId;
    _currentBowlingTeamId = widget.bowlingTeamId;
    _currentBattingTeamName = widget.battingTeamName;
    _currentBowlingTeamName = widget.bowlingTeamName;
    _activeScorerName = widget.initialScorerName;
  }

  void _recordBall({
    required int runs,
    String extrasType = '',
    int extrasRuns = 0,
    bool isWicket = false,
    String wicketType = '',
    int isFreeHitFlag = 0,
  }) async {
    setState(() => _isLoading = true);

    try {
      final res = await _apiService.dio.post('/ball_add.php', data: {
        'innings_id': _currentInningsId,
        'runs_bat': runs,
        'extras_type': extrasType,
        'extras_runs': extrasRuns,
        'is_wicket': isWicket ? 1 : 0,
        'wicket_type': wicketType,
        'is_free_hit': _isFreeHit ? 1 : isFreeHitFlag,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        if (res.data != null && (res.data['success'] == true || res.data['ok'] == true)) {
          final totals = res.data['totals'] ?? {};
          setState(() {
            _totalRuns = (totals['runs'] != null)
                ? (int.tryParse(totals['runs'].toString()) ?? 0)
                : _totalRuns + runs + extrasRuns;
            _totalWickets = (totals['wkts'] != null)
                ? (int.tryParse(totals['wkts'].toString()) ?? 0)
                : (isWicket ? _totalWickets + 1 : _totalWickets);

            final isLegal = (extrasType != 'wd' && extrasType != 'nb');
            if (isLegal) {
              _legalBalls++;
            }

            // Next ball Free Hit check
            _isFreeHit = (res.data['is_next_free_hit'] == true);

            String ballText = '$runs';
            if (extrasType == 'wd') ballText = '${extrasRuns}Wd';
            if (extrasType == 'nb') ballText = '${runs > 0 ? "$runs+" : ""}NB';
            if (extrasType == 'lb') ballText = '${extrasRuns}LB';
            if (extrasType == 'b') ballText = '${extrasRuns}B';
            if (isWicket) ballText = 'W';

            _thisOver.add(ballText);
            if (_thisOver.length > 6) {
              _thisOver.removeAt(0);
            }
          });

          // Check if Innings 1 is completed (Overs limit reached or 10 wickets)
          final maxBalls = widget.oversLimit * 6;
          if (_currentInningsNo == 1 && (_legalBalls >= maxBalls || _totalWickets >= 10)) {
            _showInningsBreakModal();
          } else if (_currentInningsNo == 2 && _targetRuns != null && (_totalRuns >= _targetRuns! || _legalBalls >= maxBalls || _totalWickets >= 10)) {
            _showMatchEndedModal();
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scoring error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _handleUndo() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.dio.post('/ball_undo.php', data: {
        'innings_id': _currentInningsId,
      });
      if (mounted) {
        setState(() => _isLoading = false);
        if (res.data['success'] == true || res.data['ok'] == true) {
          if (_thisOver.isNotEmpty) {
            setState(() => _thisOver.removeLast());
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Last ball undone!'), backgroundColor: AppTheme.successGreen),
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Innings 1 Break & Scorer Handover Modal ──
  void _showInningsBreakModal() async {
    final int target = _totalRuns + 1;
    List<dynamic> chasingSquad = [];
    int? nextScorerId;
    String? nextScorerName;

    try {
      final res = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': _currentBowlingTeamId, // Team now batting in Innings 2
      });
      chasingSquad = res.data['squad'] as List? ?? [];
      if (chasingSquad.isNotEmpty) {
        final capt = chasingSquad.firstWhere(
          (p) => p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader',
          orElse: () => chasingSquad.first,
        );
        nextScorerId = int.tryParse(capt['id'].toString());
        nextScorerName = capt['name']?.toString() ?? 'Player';
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'INNINGS 1 COMPLETE 🏁',
                      style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '$_currentBattingTeamName scored $_totalRuns/$_totalWickets in ${floorOvers(_legalBalls)} overs.',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131326),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target for $_currentBowlingTeamName:', style: const TextStyle(color: Colors.white70)),
                      Text(
                        '$target Runs',
                        style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Innings 2 Scorer Handover ──
                Text(
                  '🔄 Handover Scoring to $_currentBowlingTeamName:',
                  style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Batting team now scores their own chase. Select scorekeeper from their squad:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 10),

                if (chasingSquad.isNotEmpty)
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: nextScorerId,
                    dropdownColor: const Color(0xFF131326),
                    decoration: const InputDecoration(
                      labelText: 'Innings 2 Scorekeeper ✍️',
                      prefixIcon: Icon(Icons.person, color: AppTheme.primaryGold),
                    ),
                    items: chasingSquad.map<DropdownMenuItem<int>>((p) {
                      final pid = int.parse(p['id'].toString());
                      final isCapt = (p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader');
                      return DropdownMenuItem<int>(
                        value: pid,
                        child: Text(
                          "${p['name']} ${isCapt ? '👑 (Captain)' : ''}",
                          style: TextStyle(color: isCapt ? AppTheme.primaryGold : Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setModalState(() {
                        nextScorerId = val;
                        final sel = chasingSquad.firstWhere((p) => int.parse(p['id'].toString()) == val, orElse: () => null);
                        if (sel != null) nextScorerName = sel['name'];
                      });
                    },
                  ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: const Color(0xFF070710),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _startInnings2(target: target, scorerName: nextScorerName);
                    },
                    child: const Text('START INNINGS 2 (CHASE) 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _startInnings2({required int target, String? scorerName}) async {
    setState(() => _isLoading = true);
    try {
      await _apiService.dio.post('/innings_complete.php', data: {
        'innings_id': _currentInningsId,
      });

      setState(() {
        _currentInningsNo = 2;
        _currentInningsId = _currentInningsId + 1;
        final prevBatId = _currentBattingTeamId;
        final prevBatName = _currentBattingTeamName;
        _currentBattingTeamId = _currentBowlingTeamId;
        _currentBattingTeamName = _currentBowlingTeamName;
        _currentBowlingTeamId = prevBatId;
        _currentBowlingTeamName = prevBatName;
        _targetRuns = target;
        _activeScorerName = scorerName;
        _totalRuns = 0;
        _totalWickets = 0;
        _legalBalls = 0;
        _thisOver = [];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Innings 2 Started! Target: $target Runs. Scorekeeper: ${_activeScorerName ?? _currentBattingTeamName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMatchEndedModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final bool isWonByChasing = (_targetRuns != null && _totalRuns >= _targetRuns!);
        final String winnerTeam = isWonByChasing ? _currentBattingTeamName : _currentBowlingTeamName;

        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text('MATCH FINISHED! 🏆', textAlign: TextAlign.center, style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '🎉 $winnerTeam WON THE MATCH!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Final Score: $_currentBattingTeamName $_totalRuns/$_totalWickets (${floorOvers(_legalBalls)} ov)',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: const Color(0xFF070710)),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                  (route) => false,
                );
              },
              child: const Text('Back to Home 🏠', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ── CricHeroes-Style No Ball Popup ──
  void _showNoBallModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('NO BALL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  const Text('Select Runs scored off the bat:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [0, 1, 2, 3, 4, 6].map((batRuns) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E38),
                      foregroundColor: AppTheme.primaryGold,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _recordBall(runs: batRuns, extrasType: 'nb', extrasRuns: 1);
                    },
                    child: Text('NB + $batRuns Run${batRuns == 1 ? "" : "s"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.warning, size: 18),
                label: const Text('Run Out on No Ball'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _recordBall(runs: 0, extrasType: 'nb', extrasRuns: 1, isWicket: true, wicketType: 'run out');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Wicket Dialog ──
  void _showWicketDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.cardBg,
          title: Text('Wicket Fallen ☝️', style: GoogleFonts.outfit(color: AppTheme.primaryGold)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                'Bowled',
                'Caught',
                'LBW',
                'Run Out',
                'Stumped',
                'Hit Wicket',
                'Retired Hurt'
              ].map((type) {
                return ListTile(
                  title: Text(type, style: const TextStyle(color: AppTheme.textPrimary)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryGold),
                  onTap: () {
                    Navigator.pop(ctx);
                    _recordBall(runs: 0, isWicket: true, wicketType: type);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final oversDouble = floorOvers(_legalBalls);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Innings $_currentInningsNo Console 🏏',
              style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            if (_activeScorerName != null)
              Text(
                '✍️ Scorer: $_activeScorerName ($_currentBattingTeamName)',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
          ],
        ),
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
        actions: [
          if (_currentInningsNo == 1)
            TextButton(
              onPressed: _showInningsBreakModal,
              child: const Text('End Innings 1 🏁', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.undo, color: AppTheme.primaryGold),
            onPressed: _isLoading ? null : _handleUndo,
          ),
          IconButton(
            icon: const Icon(Icons.home, color: AppTheme.primaryGold),
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Free Hit Banner
            if (_isFreeHit)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.deepOrange, Colors.amber]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      '🔥 FREE HIT ACTIVE! (Only Run Out is valid)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),

            // Target Banner for Innings 2
            if (_currentInningsNo == 2 && _targetRuns != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Target: $_targetRuns Runs (${widget.oversLimit} ov)', style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
                    Text(
                      'Need ${_targetRuns! - _totalRuns > 0 ? _targetRuns! - _totalRuns : 0} runs to win',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Score Display Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryGold, width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    _currentBattingTeamName.toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 18, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_totalRuns / $_totalWickets',
                    style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Overs: $oversDouble / ${widget.oversLimit}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // This Over Tracker
            Row(
              children: [
                const Text('THIS OVER: ', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _thisOver.map((b) {
                        final isW = b == 'W';
                        final is46 = b == '4' || b == '6';
                        final isNB = b.contains('NB');
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isW
                                ? AppTheme.errorRed
                                : (is46
                                    ? AppTheme.primaryGold
                                    : (isNB ? Colors.deepOrange : const Color(0xFF131326))),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b,
                            style: TextStyle(
                              color: is46 ? const Color(0xFF070710) : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Run Buttons Grid (0 to 6)
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [0, 1, 2, 3, 4, 6].map((run) {
                final isBoundary = run == 4 || run == 6;
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBoundary ? AppTheme.primaryGold : const Color(0xFF131326),
                    foregroundColor: isBoundary ? const Color(0xFF070710) : AppTheme.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppTheme.cardBorder),
                    ),
                  ),
                  onPressed: _isLoading ? null : () => _recordBall(runs: run),
                  child: Text(
                    '$run',
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Extras & Wicket Bar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF131326)),
                    onPressed: _isLoading ? null : () => _recordBall(runs: 0, extrasType: 'wd', extrasRuns: 1),
                    child: const Text('WIDE (+1)', style: TextStyle(color: AppTheme.primaryGold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withValues(alpha: 0.2),
                      side: const BorderSide(color: Colors.amber),
                    ),
                    onPressed: _isLoading ? null : _showNoBallModal,
                    child: const Text('NO BALL ⚡', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
                    onPressed: _isLoading ? null : _showWicketDialog,
                    child: const Text('WICKET ☝️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String floorOvers(int legal) {
    final ov = legal ~/ 6;
    final rem = legal % 6;
    return '$ov.$rem';
  }
}
