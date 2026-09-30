import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import 'live_scorer_console_screen.dart';

class TossScreen extends StatefulWidget {
  final int matchId;
  final int teamAId;
  final int teamBId;
  final String teamAName;
  final String teamBName;
  final int oversLimit;

  const TossScreen({
    super.key,
    required this.matchId,
    required this.teamAId,
    required this.teamBId,
    required this.teamAName,
    required this.teamBName,
    required this.oversLimit,
  });

  @override
  State<TossScreen> createState() => _TossScreenState();
}

class _TossScreenState extends State<TossScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();

  late AnimationController _coinController;
  late Animation<double> _coinAnimation;

  // Toss State
  late int _callingTeamId;
  String _calledSide = 'heads'; // 'heads' or 'tails'
  bool _isFlipping = false;
  String? _coinResult; // 'heads' or 'tails'
  int? _tossWinnerId;
  String _tossDecision = 'bat'; // 'bat' or 'bowl'
  bool _isStarting = false;

  // Squads
  List<dynamic> _battingSquad = [];
  List<dynamic> _bowlingSquad = [];
  bool _isLoadingSquad = false;

  // Opening Lineup Selection
  int? _strikerId;
  String? _strikerName;
  int? _nonStrikerId;
  String? _nonStrikerName;
  int? _bowlerId;
  String? _bowlerName;

  // Scorer Selection (Batting Team Squad)
  int? _selectedScorerPlayerId;
  String? _selectedScorerName;

  @override
  void initState() {
    super.initState();
    _callingTeamId = widget.teamAId;
    _tossWinnerId = widget.teamAId;

    _coinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _coinAnimation = CurvedAnimation(
      parent: _coinController,
      curve: Curves.easeOutBack,
    );

    _loadSquads();
  }

  @override
  void dispose() {
    _coinController.dispose();
    super.dispose();
  }

  int _getBattingTeamId() {
    final winner = _tossWinnerId ?? widget.teamAId;
    if (_tossDecision == 'bat') {
      return winner;
    } else {
      return (winner == widget.teamAId) ? widget.teamBId : widget.teamAId;
    }
  }

  int _getBowlingTeamId() {
    final batId = _getBattingTeamId();
    return (batId == widget.teamAId) ? widget.teamBId : widget.teamAId;
  }

  String _getBattingTeamName() {
    final batId = _getBattingTeamId();
    return (batId == widget.teamAId) ? widget.teamAName : widget.teamBName;
  }

  String _getBowlingTeamName() {
    final bowlId = _getBowlingTeamId();
    return (bowlId == widget.teamAId) ? widget.teamAName : widget.teamBName;
  }

  Future<void> _loadSquads() async {
    final batId = _getBattingTeamId();
    final bowlId = _getBowlingTeamId();
    setState(() => _isLoadingSquad = true);
    try {
      final batRes = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': batId,
      });
      final bowlRes = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': bowlId,
      });

      if (mounted) {
        final batSquad = batRes.data['squad'] as List? ?? [];
        final bowlSquad = bowlRes.data['squad'] as List? ?? [];

        setState(() {
          _battingSquad = batSquad;
          _bowlingSquad = bowlSquad;
          _isLoadingSquad = false;

          // Auto-select Scorer (Captain or first player)
          if (batSquad.isNotEmpty) {
            final capt = batSquad.firstWhere(
              (p) => p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader',
              orElse: () => batSquad.first,
            );
            _selectedScorerPlayerId = int.tryParse(capt['id'].toString());
            _selectedScorerName = capt['name']?.toString() ?? 'Player';

            // Auto-select Striker & Non-Striker
            final p1 = batSquad[0];
            _strikerId = int.tryParse(p1['id'].toString());
            _strikerName = p1['name']?.toString() ?? 'Batter 1';

            if (batSquad.length > 1) {
              final p2 = batSquad[1];
              _nonStrikerId = int.tryParse(p2['id'].toString());
              _nonStrikerName = p2['name']?.toString() ?? 'Batter 2';
            } else {
              _nonStrikerId = null;
              _nonStrikerName = null;
            }
          }

          // Auto-select Bowler
          if (bowlSquad.isNotEmpty) {
            final b1 = bowlSquad.firstWhere(
              (p) => (p['role'] ?? '').toString().toUpperCase().contains('BOWL') || (p['role'] ?? '').toString().toUpperCase().contains('ALL'),
              orElse: () => bowlSquad.first,
            );
            _bowlerId = int.tryParse(b1['id'].toString());
            _bowlerName = b1['name']?.toString() ?? 'Bowler 1';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSquad = false);
    }
  }

  void _flipCoin() {
    if (_isFlipping) return;
    setState(() {
      _isFlipping = true;
      _coinResult = null;
    });

    _coinController.reset();
    _coinController.forward().then((_) {
      // 50-50 Random Toss Result
      final isHeads = Random().nextBool();
      final result = isHeads ? 'heads' : 'tails';

      int winner;
      if (_calledSide == result) {
        winner = _callingTeamId;
      } else {
        winner = (_callingTeamId == widget.teamAId) ? widget.teamBId : widget.teamAId;
      }

      setState(() {
        _isFlipping = false;
        _coinResult = result;
        _tossWinnerId = winner;
      });

      _loadSquads();
    });
  }

  void _onTossDecisionChanged(String decision) {
    setState(() {
      _tossDecision = decision;
    });
    _loadSquads();
  }

  Future<void> _showQuickAddPlayerDialog(bool isBattingTeam) async {
    final teamId = isBattingTeam ? _getBattingTeamId() : _getBowlingTeamId();
    final teamName = isBattingTeam ? _getBattingTeamName() : _getBowlingTeamName();
    final nameCtrl = TextEditingController();
    String selectedRole = isBattingTeam ? 'BAT' : 'BOWL';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.primaryGold),
        ),
        title: Text(
          'Add Player to $teamName',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Player Name *',
                hintText: 'e.g. Ramesh, Karthik',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: const Color(0xFF070710),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final res = await _apiService.dio.post(
                  '/team_ops.php',
                  queryParameters: {'action': 'add_player'},
                  data: {
                    'team_id': teamId,
                    'name': name,
                    'role': selectedRole,
                  },
                );
                if (res.data['success'] == true) {
                  await _loadSquads();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Player $name added to $teamName! ✅'), backgroundColor: Colors.green),
                    );
                  }
                }
              } catch (_) {}
            },
            child: const Text('Add Player ✅', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _handleStartMatch() async {
    if (_tossWinnerId == null) return;

    // Validation
    if (_strikerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Striker Batsman (On Strike) 🏏'), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    if (_nonStrikerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Non-Striker Batsman 🏏'), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    if (_strikerId == _nonStrikerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Striker and Non-Striker cannot be the same player!'), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    if (_bowlerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Opening Bowler ⚾'), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    setState(() => _isStarting = true);

    try {
      final batFirstId = _getBattingTeamId();
      final bowlFirstId = _getBowlingTeamId();

      final res = await _apiService.dio.post('/match_start.php', data: {
        'match_id': widget.matchId,
        'toss_winner_team_id': _tossWinnerId,
        'toss_decision': _tossDecision,
        'toss_caller_team_id': _callingTeamId,
        'toss_call': _calledSide,
        'toss_result': _coinResult ?? 'heads',
        'batting_first_team_id': batFirstId,
        'scorer_player_id': _selectedScorerPlayerId,
      });

      if (mounted) {
        setState(() => _isStarting = false);
        if (res.data != null && (res.data['success'] == true || res.data['ok'] == true)) {
          final int inningsId = int.tryParse(res.data['innings_id']?.toString() ?? '1') ?? 1;
          final String battingTeamName = _getBattingTeamName();
          final String bowlingTeamName = _getBowlingTeamName();

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LiveScorerConsoleScreen(
                matchId: widget.matchId,
                inningsId: inningsId,
                battingTeamId: batFirstId,
                bowlingTeamId: bowlFirstId,
                battingTeamName: battingTeamName,
                bowlingTeamName: bowlingTeamName,
                oversLimit: widget.oversLimit,
                initialScorerName: _selectedScorerName,
                initialStrikerId: _strikerId,
                initialStrikerName: _strikerName,
                initialNonStrikerId: _nonStrikerId,
                initialNonStrikerName: _nonStrikerName,
                initialBowlerId: _bowlerId,
                initialBowlerName: _bowlerName,
              ),
            ),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data?['message']?.toString() ?? 'Failed to start match'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isStarting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String winnerName = (_tossWinnerId == widget.teamAId) ? widget.teamAName : widget.teamBName;
    final String battingTeamName = _getBattingTeamName();
    final String bowlingTeamName = _getBowlingTeamName();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Match Toss & Setup 🪙',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── MATCH HEADER ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      widget.teamAName,
                      textAlign: TextAlign.right,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('VS', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Flexible(
                    child: Text(
                      widget.teamBName,
                      textAlign: TextAlign.left,
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 1. CALLING TEAM & CHOICE ──
            Text('1. Who is Calling the Toss?', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(widget.teamAName, overflow: TextOverflow.ellipsis)),
                    selected: _callingTeamId == widget.teamAId,
                    selectedColor: AppTheme.primaryGold,
                    labelStyle: TextStyle(
                      color: _callingTeamId == widget.teamAId ? const Color(0xFF070710) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: AppTheme.cardBg,
                    onSelected: (val) {
                      if (val) setState(() => _callingTeamId = widget.teamAId);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ChoiceChip(
                    label: Center(child: Text(widget.teamBName, overflow: TextOverflow.ellipsis)),
                    selected: _callingTeamId == widget.teamBId,
                    selectedColor: AppTheme.primaryGold,
                    labelStyle: TextStyle(
                      color: _callingTeamId == widget.teamBId ? const Color(0xFF070710) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    backgroundColor: AppTheme.cardBg,
                    onSelected: (val) {
                      if (val) setState(() => _callingTeamId = widget.teamBId);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            const Text('Calling Choice:', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _calledSide = 'heads'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _calledSide == 'heads' ? AppTheme.primaryGold.withValues(alpha: 0.2) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _calledSide == 'heads' ? AppTheme.primaryGold : Colors.white10,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            'HEADS (ஹெட்)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _calledSide == 'heads' ? AppTheme.primaryGold : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _calledSide = 'tails'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _calledSide == 'tails' ? AppTheme.primaryGold.withValues(alpha: 0.2) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _calledSide == 'tails' ? AppTheme.primaryGold : Colors.white10,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🦅', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 8),
                          Text(
                            'TAILS (டெய்ல்)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _calledSide == 'tails' ? AppTheme.primaryGold : Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── 2. 3D ANIMATED COIN FLIP ──
            Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _coinAnimation,
                    builder: (ctx, child) {
                      final angle = _coinAnimation.value * pi * 8; // 4 full spins
                      final bool isHeadsFace = (cos(angle) >= 0);
                      final String displayFace = _coinResult != null ? _coinResult! : (isHeadsFace ? 'heads' : 'tails');

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(angle),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: displayFace == 'heads'
                                ? const RadialGradient(colors: [Color(0xFFFFF2A3), Color(0xFFD4AF37), Color(0xFF8C6B1C)])
                                : const RadialGradient(colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E), Color(0xFF616161)]),
                            boxShadow: [
                              BoxShadow(
                                color: (displayFace == 'heads' ? AppTheme.primaryGold : Colors.white).withValues(alpha: 0.4),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayFace == 'heads' ? '👑' : '🦅',
                                  style: const TextStyle(fontSize: 28),
                                ),
                                Text(
                                  displayFace.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.black87,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: const Color(0xFF070710),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.casino, size: 18),
                    label: Text(
                      _isFlipping ? 'FLIPPING COIN... 🪙' : 'FLIP COIN 🪙',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: _isFlipping ? null : _flipCoin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── TOSS RESULT BANNER ──
            if (_coinResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      '🎉 IT\'S ${_coinResult!.toUpperCase()}!',
                      style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$winnerName won the toss!',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],

            // ── 3. TOSS WINNER DECISION ──
            Text('2. Toss Decision ($winnerName Elected to)', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _onTossDecisionChanged('bat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _tossDecision == 'bat' ? AppTheme.primaryGold.withValues(alpha: 0.2) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _tossDecision == 'bat' ? AppTheme.primaryGold : Colors.white10,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.sports_cricket, size: 26, color: AppTheme.primaryGold),
                          const SizedBox(height: 4),
                          Text(
                            'ELECTED TO BAT',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: _tossDecision == 'bat' ? AppTheme.primaryGold : AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _onTossDecisionChanged('bowl'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _tossDecision == 'bowl' ? AppTheme.primaryGold.withValues(alpha: 0.2) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _tossDecision == 'bowl' ? AppTheme.primaryGold : Colors.white10,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.sports_baseball, size: 26, color: AppTheme.primaryGold),
                          const SizedBox(height: 4),
                          Text(
                            'ELECTED TO BOWL',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: _tossDecision == 'bowl' ? AppTheme.primaryGold : AppTheme.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 4. CRICHEROES STYLE OPENING LINEUP SELECTION ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF101024),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '3. Opening Lineup 🏏',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                      ),
                      if (_isLoadingSquad)
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Batting: $battingTeamName  |  Bowling: $bowlingTeamName',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Divider(color: Colors.white12, height: 20),

                  // ── STRIKER BATSMAN ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('🏏 Striker (On Strike) *', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                      InkWell(
                        onTap: () => _showQuickAddPlayerDialog(true),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text('+ Add Batter', style: TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_battingSquad.isEmpty)
                    const Text('No players in batting squad. Tap "+ Add Batter" above.', style: TextStyle(color: AppTheme.errorRed, fontSize: 12))
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _strikerId,
                      dropdownColor: const Color(0xFF131326),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: Icon(Icons.sports_cricket, color: Color(0xFF00E676), size: 20),
                      ),
                      items: _battingSquad.map<DropdownMenuItem<int>>((p) {
                        final pid = int.parse(p['id'].toString());
                        final isCapt = (p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader');
                        return DropdownMenuItem<int>(
                          value: pid,
                          child: Text(
                            "${p['name']} ${isCapt ? '👑 (C)' : ''} • ${p['role'] ?? 'BAT'}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _strikerId = val;
                          final sel = _battingSquad.firstWhere((p) => int.parse(p['id'].toString()) == val, orElse: () => null);
                          if (sel != null) _strikerName = sel['name'];
                        });
                      },
                    ),
                  const SizedBox(height: 14),

                  // ── NON-STRIKER BATSMAN ──
                  const Text('🏏 Non-Striker *', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (_battingSquad.length < 2)
                    const Text('Need at least 2 batsmen. Tap "+ Add Batter" above.', style: TextStyle(color: Colors.orange, fontSize: 12))
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _nonStrikerId,
                      dropdownColor: const Color(0xFF131326),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: Icon(Icons.sports_cricket_outlined, color: Colors.white70, size: 20),
                      ),
                      items: _battingSquad.map<DropdownMenuItem<int>>((p) {
                        final pid = int.parse(p['id'].toString());
                        final isCapt = (p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader');
                        return DropdownMenuItem<int>(
                          value: pid,
                          child: Text(
                            "${p['name']} ${isCapt ? '👑 (C)' : ''} • ${p['role'] ?? 'BAT'}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _nonStrikerId = val;
                          final sel = _battingSquad.firstWhere((p) => int.parse(p['id'].toString()) == val, orElse: () => null);
                          if (sel != null) _nonStrikerName = sel['name'];
                        });
                      },
                    ),
                  const SizedBox(height: 14),

                  // ── OPENING BOWLER ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('⚾ Opening Bowler ($bowlingTeamName) *', style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13)),
                      InkWell(
                        onTap: () => _showQuickAddPlayerDialog(false),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Text('+ Add Bowler', style: TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_bowlingSquad.isEmpty)
                    const Text('No players in bowling squad. Tap "+ Add Bowler" above.', style: TextStyle(color: AppTheme.errorRed, fontSize: 12))
                  else
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _bowlerId,
                      dropdownColor: const Color(0xFF131326),
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        prefixIcon: Icon(Icons.sports_baseball, color: AppTheme.primaryGold, size: 20),
                      ),
                      items: _bowlingSquad.map<DropdownMenuItem<int>>((p) {
                        final pid = int.parse(p['id'].toString());
                        final isCapt = (p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader');
                        return DropdownMenuItem<int>(
                          value: pid,
                          child: Text(
                            "${p['name']} ${isCapt ? '👑 (C)' : ''} • ${p['role'] ?? 'BOWL'}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _bowlerId = val;
                          final sel = _bowlingSquad.firstWhere((p) => int.parse(p['id'].toString()) == val, orElse: () => null);
                          if (sel != null) _bowlerName = sel['name'];
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 5. DESIGNATED SCORER SELECTION ──
            Text('4. Innings 1 Scorer ✍️ ($battingTeamName)', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
            const SizedBox(height: 4),
            const Text(
              'Scorekeeper will record balls for Innings 1 and handover in Innings 2.',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 8),

            if (_battingSquad.isNotEmpty)
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _selectedScorerPlayerId,
                dropdownColor: const Color(0xFF131326),
                decoration: const InputDecoration(
                  labelText: 'Scorekeeper for Innings 1',
                  prefixIcon: Icon(Icons.edit_note, color: AppTheme.primaryGold),
                ),
                items: _battingSquad.map<DropdownMenuItem<int>>((p) {
                  final pid = int.parse(p['id'].toString());
                  final isCapt = (p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader');
                  return DropdownMenuItem<int>(
                    value: pid,
                    child: Text(
                      "${p['name']} ${isCapt ? '👑 (Captain)' : ''}",
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isCapt ? FontWeight.bold : FontWeight.normal,
                        color: isCapt ? AppTheme.primaryGold : Colors.white,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedScorerPlayerId = val;
                    final sel = _battingSquad.firstWhere((p) => int.parse(p['id'].toString()) == val, orElse: () => null);
                    if (sel != null) _selectedScorerName = sel['name'];
                  });
                },
              ),
            const SizedBox(height: 28),

            // ── START MATCH & OPEN SCORER ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: const Color(0xFF070710),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isStarting ? null : _handleStartMatch,
                child: _isStarting
                    ? const CircularProgressIndicator(color: Color(0xFF070710))
                    : Text(
                        'START MATCH & OPEN SCORER 🏏',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
