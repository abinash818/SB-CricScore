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

  const LiveScorerConsoleScreen({
    super.key,
    required this.matchId,
    required this.inningsId,
    required this.battingTeamId,
    required this.bowlingTeamId,
    required this.battingTeamName,
    required this.bowlingTeamName,
    required this.oversLimit,
  });

  @override
  State<LiveScorerConsoleScreen> createState() => _LiveScorerConsoleScreenState();
}

class _LiveScorerConsoleScreenState extends State<LiveScorerConsoleScreen> {
  final ApiService _apiService = ApiService();

  int _totalRuns = 0;
  int _totalWickets = 0;
  int _legalBalls = 0;
  List<String> _thisOver = [];
  bool _isLoading = false;
  bool _isFreeHit = false;

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
        'innings_id': widget.inningsId,
        'runs_bat': runs,
        'extras_type': extrasType,
        'extras_runs': extrasRuns,
        'is_wicket': isWicket ? 1 : 0,
        'wicket_type': wicketType,
        'is_free_hit': _isFreeHit ? 1 : isFreeHitFlag,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        if (res.data['success'] == true || res.data['ok'] == true) {
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
        'innings_id': widget.inningsId,
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
                    child: const Text('NO BALL', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'What happened on this ball?',
                    style: GoogleFonts.outfit(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Text('1. Runs from Bat:', style: GoogleFonts.outfit(color: AppTheme.gold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [0, 1, 2, 3, 4, 6].map((run) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: (run == 4 || run == 6) ? AppTheme.gold : const Color(0xFF1E1E38),
                      foregroundColor: (run == 4 || run == 6) ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _recordBall(runs: run, extrasType: 'nb', extrasRuns: 1);
                    },
                    child: Text(run == 0 ? '0 (1 NB)' : '+$run Bat ($run+1)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Text('2. Byes / Leg-Byes on No Ball:', style: GoogleFonts.outfit(color: AppTheme.gold, fontSize: 14)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [1, 2, 3, 4].map((extra) {
                  return OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.cyanAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _recordBall(runs: 0, extrasType: 'nb', extrasRuns: 1 + extra);
                    },
                    child: Text('+$extra Bye (Total ${1 + extra})', style: const TextStyle(color: Colors.cyanAccent)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              Text('3. Wicket on No Ball (Run Out only):', style: GoogleFonts.outfit(color: Colors.redAccent, fontSize: 14)),
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
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
          title: Text('Wicket Fallen ☝️', style: GoogleFonts.outfit(color: AppTheme.gold)),
          content: Column(
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
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.gold),
                onTap: () {
                  Navigator.pop(ctx);
                  _recordBall(runs: 0, isWicket: true, wicketType: type);
                },
              );
            }).toList(),
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
        title: Text(
          'Live Scorer Console',
          style: GoogleFonts.outfit(color: AppTheme.gold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.undo, color: AppTheme.gold),
            onPressed: _isLoading ? null : _handleUndo,
          ),
          IconButton(
            icon: const Icon(Icons.home, color: AppTheme.gold),
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
            // Free Hit Banner if active
            if (_isFreeHit)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.deepOrange, Colors.amber]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      '🔥 FREE HIT ACTIVE! (Only Run Out is valid)',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),

            // Score Display Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.gold, width: 1.5),
              ),
              child: Column(
                children: [
                  Text(
                    widget.battingTeamName.toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 18, color: AppTheme.gold, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
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
            const SizedBox(height: 16),

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
                                    ? AppTheme.gold
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
                    backgroundColor: isBoundary ? AppTheme.gold : const Color(0xFF131326),
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

            // Extras & Wicket Bar (CricHeroes No-Ball Trigger)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF131326)),
                    onPressed: _isLoading ? null : () => _recordBall(runs: 0, extrasType: 'wd', extrasRuns: 1),
                    child: const Text('WIDE (+1)', style: TextStyle(color: AppTheme.gold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.withOpacity(0.2),
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
