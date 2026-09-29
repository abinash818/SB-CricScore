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

class _TossScreenState extends State<TossScreen> {
  final ApiService _apiService = ApiService();

  int? _tossWinnerId;
  String _tossDecision = 'bat'; // 'bat' or 'bowl'
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _tossWinnerId = widget.teamAId;
  }

  void _handleStartMatch() async {
    if (_tossWinnerId == null) return;

    setState(() => _isStarting = true);

    try {
      final res = await _apiService.dio.post('/match_start.php', data: {
        'match_id': widget.matchId,
        'toss_winner_team_id': _tossWinnerId,
        'toss_decision': _tossDecision,
      });

      if (mounted) {
        setState(() => _isStarting = false);
        if (res.data['success'] == true || res.data['ok'] == true) {
          final inningsId = res.data['innings_id'];
          final battingTeamId = res.data['batting_team'];
          final bowlingTeamId = res.data['bowling_team'];

          final battingTeamName = (battingTeamId == widget.teamAId) ? widget.teamAName : widget.teamBName;
          final bowlingTeamName = (bowlingTeamId == widget.teamAId) ? widget.teamAName : widget.teamBName;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LiveScorerConsoleScreen(
                matchId: widget.matchId,
                inningsId: inningsId,
                battingTeamId: battingTeamId,
                bowlingTeamId: bowlingTeamId,
                battingTeamName: battingTeamName,
                bowlingTeamName: bowlingTeamName,
                oversLimit: widget.oversLimit,
              ),
            ),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.data['message'] ?? 'Failed to start match'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Match Toss 🪙',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Who Won the Toss?',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            RadioListTile<int>(
              value: widget.teamAId,
              groupValue: _tossWinnerId,
              title: Text(widget.teamAName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              activeColor: AppTheme.primaryGold,
              tileColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onChanged: (val) => setState(() => _tossWinnerId = val),
            ),
            const SizedBox(height: 12),
            RadioListTile<int>(
              value: widget.teamBId,
              groupValue: _tossWinnerId,
              title: Text(widget.teamBName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              activeColor: AppTheme.primaryGold,
              tileColor: AppTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onChanged: (val) => setState(() => _tossWinnerId = val),
            ),
            const SizedBox(height: 36),
            Text(
              'Toss Decision',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tossDecision = 'bat'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _tossDecision == 'bat' ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _tossDecision == 'bat' ? AppTheme.primaryGold : AppTheme.cardBorder,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.sports_cricket, size: 36, color: AppTheme.primaryGold),
                          const SizedBox(height: 8),
                          Text(
                            'ELECTED TO BAT',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: _tossDecision == 'bat' ? AppTheme.primaryGold : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _tossDecision = 'bowl'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: _tossDecision == 'bowl' ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _tossDecision == 'bowl' ? AppTheme.primaryGold : AppTheme.cardBorder,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.sports_baseball, size: 36, color: AppTheme.primaryGold),
                          const SizedBox(height: 8),
                          Text(
                            'ELECTED TO BOWL',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: _tossDecision == 'bowl' ? AppTheme.primaryGold : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isStarting ? null : _handleStartMatch,
                child: _isStarting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF070710)),
                      )
                    : const Text('START MATCH & OPEN SCORER 🏏'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
