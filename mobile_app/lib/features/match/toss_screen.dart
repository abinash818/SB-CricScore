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

  // Scorer Selection (Batting Team Squad)
  List<dynamic> _battingSquad = [];
  bool _isLoadingSquad = false;
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

    _loadBattingSquad(_getBattingTeamId());
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

  String _getBattingTeamName() {
    final batId = _getBattingTeamId();
    return (batId == widget.teamAId) ? widget.teamAName : widget.teamBName;
  }

  Future<void> _loadBattingSquad(int teamId) async {
    setState(() => _isLoadingSquad = true);
    try {
      final res = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': teamId,
      });
      if (mounted) {
        final squad = res.data['squad'] as List? ?? [];
        setState(() {
          _battingSquad = squad;
          _isLoadingSquad = false;
          if (squad.isNotEmpty) {
            // Default to captain or first player
            final capt = squad.firstWhere(
              (p) => p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader',
              orElse: () => squad.first,
            );
            _selectedScorerPlayerId = int.tryParse(capt['id'].toString());
            _selectedScorerName = capt['name']?.toString() ?? 'Player';
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

      _loadBattingSquad(_getBattingTeamId());
    });
  }

  void _onTossDecisionChanged(String decision) {
    setState(() {
      _tossDecision = decision;
    });
    _loadBattingSquad(_getBattingTeamId());
  }

  void _handleStartMatch() async {
    if (_tossWinnerId == null) return;

    setState(() => _isStarting = true);

    try {
      final batFirstId = _getBattingTeamId();
      final bowlFirstId = (batFirstId == widget.teamAId) ? widget.teamBId : widget.teamAId;

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
          final String bowlingTeamName = (batFirstId == widget.teamAId) ? widget.teamBName : widget.teamAName;

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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Match Toss & Scorer Setup 🪙',
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

            Text('Calling Choice:', style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w600)),
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
            const SizedBox(height: 24),

            // ── 2. 3D ANIMATED COIN FLIP ──
            Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _coinAnimation,
                    builder: (ctx, child) {
                      final angle = _coinAnimation.value * pi * 8; // 4 full 360 spins
                      final bool isHeadsFace = (cos(angle) >= 0);
                      final String displayFace = _coinResult != null ? _coinResult! : (isHeadsFace ? 'heads' : 'tails');

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateY(angle),
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: displayFace == 'heads'
                                ? const RadialGradient(colors: [Color(0xFFFFF2A3), Color(0xFFD4AF37), Color(0xFF8C6B1C)])
                                : const RadialGradient(colors: [Color(0xFFE0E0E0), Color(0xFF9E9E9E), Color(0xFF616161)]),
                            boxShadow: [
                              BoxShadow(
                                color: (displayFace == 'heads' ? AppTheme.primaryGold : Colors.white).withValues(alpha: 0.4),
                                blurRadius: 20,
                                spreadRadius: 3,
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
                                  style: const TextStyle(fontSize: 32),
                                ),
                                Text(
                                  displayFace.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black87,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: const Color(0xFF070710),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    icon: const Icon(Icons.casino, size: 20),
                    label: Text(
                      _isFlipping ? 'FLIPPING COIN... 🪙' : 'FLIP COIN 🪙',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _isFlipping ? null : _flipCoin,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── TOSS RESULT BANNER ──
            if (_coinResult != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text(
                      '🎉 IT\'S ${_coinResult!.toUpperCase()}!',
                      style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$winnerName won the toss!',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                          const Icon(Icons.sports_cricket, size: 30, color: AppTheme.primaryGold),
                          const SizedBox(height: 6),
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
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                          const Icon(Icons.sports_baseball, size: 30, color: AppTheme.primaryGold),
                          const SizedBox(height: 6),
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

            // ── 4. DESIGNATED SCORER SELECTION (Batting Team Squad) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '3. Innings 1 Scorer ✍️ ($battingTeamName)',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Batting team scores their own innings. Scorer will handover to the other team in 2nd Innings.',
              style: TextStyle(color: Colors.white60, fontSize: 11),
            ),
            const SizedBox(height: 10),

            if (_isLoadingSquad)
              const Center(child: Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: AppTheme.primaryGold)))
            else if (_battingSquad.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10)),
                child: const Text('Captain will act as primary scorekeeper.', style: TextStyle(color: Colors.white70, fontSize: 12)),
              )
            else
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _selectedScorerPlayerId,
                dropdownColor: const Color(0xFF131326),
                decoration: const InputDecoration(
                  labelText: 'Select Scorekeeper for Innings 1',
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
            const SizedBox(height: 32),

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
