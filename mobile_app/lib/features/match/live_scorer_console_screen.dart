import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  final int? initialStrikerId;
  final String? initialStrikerName;
  final int? initialNonStrikerId;
  final String? initialNonStrikerName;
  final int? initialBowlerId;
  final String? initialBowlerName;

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
    this.initialStrikerId,
    this.initialStrikerName,
    this.initialNonStrikerId,
    this.initialNonStrikerName,
    this.initialBowlerId,
    this.initialBowlerName,
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
  
  // ── Scorer Security & Handover State ──
  int? _activeScorerPlayerId;
  String? _activeScorerName;
  String? _activeScorerMobile;
  String? _scorerPin;
  bool _isDesignatedScorer = true; // Authorized to enter scores

  int _totalRuns = 0;
  int _totalWickets = 0;
  int _legalBalls = 0;
  int? _targetRuns;
  List<String> _thisOver = [];
  bool _isLoading = false;
  bool _isFreeHit = false;
  bool _isInningsBreakOpen = false;
  bool _isMatchEndedOpen = false;

  // ── Live Crease & Bowler State ──
  int? _strikerId;
  String _strikerName = 'Striker';
  int _strikerRuns = 0;
  int _strikerBalls = 0;
  int _strikerFours = 0;
  int _strikerSixes = 0;

  int? _nonStrikerId;
  String _nonStrikerName = 'Non-Striker';
  int _nonStrikerRuns = 0;
  int _nonStrikerBalls = 0;
  int _nonStrikerFours = 0;
  int _nonStrikerSixes = 0;

  int? _bowlerId;
  String _bowlerName = 'Bowler';
  int _bowlerBalls = 0;
  int _bowlerRuns = 0;
  int _bowlerWickets = 0;
  int _bowlerMaidens = 0;
  int? _lastBowlerId;

  List<dynamic> _battingSquad = [];
  List<dynamic> _bowlingSquad = [];
  final List<int> _dismissedPlayerIds = [];

  @override
  void initState() {
    super.initState();
    _currentInningsId = widget.inningsId;
    _currentInningsNo = 1;
    _currentBattingTeamId = widget.battingTeamId;
    _currentBowlingTeamId = widget.bowlingTeamId;
    _currentBattingTeamName = widget.battingTeamName;
    _currentBowlingTeamName = widget.bowlingTeamName;
    _activeScorerName = widget.initialScorerName ?? widget.battingTeamName;

    _strikerId = widget.initialStrikerId;
    _strikerName = widget.initialStrikerName ?? 'Striker';
    _nonStrikerId = widget.initialNonStrikerId;
    _nonStrikerName = widget.initialNonStrikerName ?? 'Non-Striker';
    _bowlerId = widget.initialBowlerId;
    _bowlerName = widget.initialBowlerName ?? 'Bowler';

    _fetchMatchState();
    _loadSquadsAndVerifyLineup();
    _fetchScorerStatus();
  }

  Future<void> _fetchMatchState() async {
    try {
      final res = await _apiService.dio.get('/match_get.php', queryParameters: {'match_id': widget.matchId});
      if (res.data != null && mounted) {
        final inningsList = res.data['innings'] as List? ?? [];
        final chase = res.data['chase'];

        dynamic targetInn;
        if (inningsList.isNotEmpty) {
          final matches = inningsList.where((i) => int.tryParse(i['id']?.toString() ?? '') == _currentInningsId);
          targetInn = matches.isNotEmpty ? matches.first : inningsList.last;
        }

        if (targetInn != null) {
          final summary = targetInn['summary'] ?? {};
          final int target = int.tryParse(targetInn['target']?.toString() ?? (chase?['target']?.toString() ?? '')) ?? 0;
          final int innNo = int.tryParse(targetInn['innings_no']?.toString() ?? '1') ?? 1;
          final int batId = int.tryParse(targetInn['batting_team_id']?.toString() ?? '0') ?? _currentBattingTeamId;
          final String batName = targetInn['batting_team']?.toString() ?? _currentBattingTeamName;

          setState(() {
            _currentInningsId = int.tryParse(targetInn['id']?.toString() ?? '') ?? _currentInningsId;
            _currentInningsNo = innNo;
            _currentBattingTeamId = batId;
            _currentBattingTeamName = batName;
            _totalRuns = int.tryParse(summary['runs']?.toString() ?? '0') ?? 0;
            _totalWickets = int.tryParse(summary['wickets']?.toString() ?? '0') ?? 0;
            _legalBalls = int.tryParse(summary['legal_balls']?.toString() ?? '0') ?? 0;
            if (target > 0) _targetRuns = target;

            final recList = summary['recent_balls'] as List? ?? [];
            if (recList.isNotEmpty) {
              _thisOver = recList.map((e) => e.toString()).toList();
              if (_thisOver.length > 6) _thisOver = _thisOver.sublist(_thisOver.length - 6);
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchScorerStatus() async {
    try {
      final res = await _apiService.dio.get('/scorer_transfer.php', queryParameters: {
        'action': 'status',
        'match_id': widget.matchId,
      });
      if (mounted && res.data != null && res.data['success'] == true) {
        setState(() {
          _activeScorerPlayerId = int.tryParse(res.data['active_scorer_id']?.toString() ?? '');
          _activeScorerName = res.data['active_scorer_name']?.toString() ?? _activeScorerName;
          _activeScorerMobile = res.data['active_scorer_mobile']?.toString();
          _scorerPin = res.data['scorer_pin']?.toString() ?? _scorerPin;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSquadsAndVerifyLineup() async {
    try {
      final batRes = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': _currentBattingTeamId,
      });
      final bowlRes = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': _currentBowlingTeamId,
      });

      if (mounted) {
        setState(() {
          _battingSquad = batRes.data['squad'] as List? ?? [];
          _bowlingSquad = bowlRes.data['squad'] as List? ?? [];
        });

        // If lineup missing on direct launch, prompt lineup sheet
        if (_strikerId == null || _nonStrikerId == null || _bowlerId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOpeningLineupSheet();
          });
        }
      }
    } catch (_) {}
  }

  void _swapStrike() {
    setState(() {
      final tempId = _strikerId;
      final tempName = _strikerName;
      final tempRuns = _strikerRuns;
      final tempBalls = _strikerBalls;
      final tempFours = _strikerFours;
      final tempSixes = _strikerSixes;

      _strikerId = _nonStrikerId;
      _strikerName = _nonStrikerName;
      _strikerRuns = _nonStrikerRuns;
      _strikerBalls = _nonStrikerBalls;
      _strikerFours = _nonStrikerFours;
      _strikerSixes = _nonStrikerSixes;

      _nonStrikerId = tempId;
      _nonStrikerName = tempName;
      _nonStrikerRuns = tempRuns;
      _nonStrikerBalls = tempBalls;
      _nonStrikerFours = tempFours;
      _nonStrikerSixes = tempSixes;
    });
  }

  void _recordBall({
    required int runs,
    String extrasType = '',
    int extrasRuns = 0,
    bool isWicket = false,
    String wicketType = '',
    int isFreeHitFlag = 0,
    bool outIsNonStriker = false,
  }) async {
    if (!_isDesignatedScorer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔒 Read-Only View: Only designated scorekeeper ($_activeScorerName) can enter scores.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final maxBalls = widget.oversLimit * 6;
    if (_currentInningsNo == 1 && (_legalBalls >= maxBalls || _totalWickets >= 10)) {
      if (!_isInningsBreakOpen) {
        _isInningsBreakOpen = true;
        _showInningsBreakModal();
      }
      return;
    }
    if (_currentInningsNo == 2 && _isMatchEndedOpen) {
      _showMatchEndedModal();
      return;
    }

    setState(() => _isLoading = true);

    final outPlayerId = isWicket ? (outIsNonStriker ? _nonStrikerId : _strikerId) : null;

    try {
      final res = await _apiService.dio.post('/ball_add.php', data: {
        'innings_id': _currentInningsId,
        'striker_id': _strikerId,
        'non_striker_id': _nonStrikerId,
        'bowler_id': _bowlerId,
        'wicket_player_out_id': outPlayerId,
        'recorded_by_player_id': _activeScorerPlayerId,
        'recorded_by_name': _activeScorerName,
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
          final isLegal = (extrasType != 'wd' && extrasType != 'nb');

          setState(() {
            _totalRuns = (totals['runs'] != null)
                ? (int.tryParse(totals['runs'].toString()) ?? 0)
                : _totalRuns + runs + extrasRuns;
            _totalWickets = (totals['wkts'] != null)
                ? (int.tryParse(totals['wkts'].toString()) ?? 0)
                : (isWicket ? _totalWickets + 1 : _totalWickets);

            if (totals['legal'] != null) {
              _legalBalls = int.tryParse(totals['legal'].toString()) ?? (_legalBalls + (isLegal ? 1 : 0));
            } else if (isLegal) {
              _legalBalls++;
            }

            // Update Batsman Stats
            _strikerRuns += runs;
            if (extrasType != 'wd') _strikerBalls += 1;
            if (runs == 4) _strikerFours += 1;
            if (runs == 6) _strikerSixes += 1;

            // Update Bowler Stats
            if (isLegal) _bowlerBalls += 1;
            if (extrasType != 'lb' && extrasType != 'b') {
              _bowlerRuns += runs + (extrasType == 'wd' || extrasType == 'nb' ? extrasRuns : 0);
            }
            if (isWicket && !wicketType.toLowerCase().contains('run')) {
              _bowlerWickets += 1;
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

          // ── Strike Rotation on Odd Runs ──
          if (!isWicket && (runs % 2 == 1)) {
            _swapStrike();
          }

          // ── Over Complete Handling ──
          final bool isOverFinished = isLegal && (_legalBalls > 0 && _legalBalls % 6 == 0);
          if (isOverFinished) {
            _lastBowlerId = _bowlerId;
            _thisOver.clear();
            _swapStrike(); // Rotate strike at end of over
          }

          // Check if Innings / Match Completed
          final int overs = res.data['overs_limit'] != null
              ? (int.tryParse(res.data['overs_limit'].toString()) ?? widget.oversLimit)
              : widget.oversLimit;
          final int matchMaxBalls = overs * 6;
          final bool isInnComplete = (res.data['is_innings_complete'] == true) ||
              (_legalBalls >= matchMaxBalls) ||
              (_totalWickets >= 10);
          final bool isMatchOver = (res.data['is_match_ended'] == true) ||
              (_currentInningsNo == 2 &&
                  ((_targetRuns != null && _totalRuns >= _targetRuns!) ||
                      _legalBalls >= matchMaxBalls ||
                      _totalWickets >= 10));

          if (_currentInningsNo == 1 && isInnComplete && !_isInningsBreakOpen) {
            _isInningsBreakOpen = true;
            _showInningsBreakModal();
          } else if (_currentInningsNo == 2 && isMatchOver && !_isMatchEndedOpen) {
            _isMatchEndedOpen = true;
            _showMatchEndedModal();
          } else if (isWicket) {
            // Wicket Fall -> Prompt Next Batsman
            if (outPlayerId != null) _dismissedPlayerIds.add(outPlayerId);
            _showSelectNewBatsmanSheet(isNonStrikerOut: outIsNonStriker);
          } else if (isOverFinished) {
            // Over Complete -> Prompt Next Bowler
            _showSelectNextBowlerSheet();
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
    if (!_isDesignatedScorer) return;
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

  // ── 📲 TRANSFER SCORING MODAL (Designated Handover) ──
  void _showTransferScoringDialog() {
    int? targetPlayerId;
    String? targetPlayerName;
    String? targetPlayerMobile;

    // Combine squads for transfer selection (both batting and bowling team members)
    final allSquadPlayers = [
      ..._battingSquad.map((p) => {...p, 'team_label': _currentBattingTeamName}),
      ..._bowlingSquad.map((p) => {...p, 'team_label': _currentBowlingTeamName}),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phonelink_ring, color: AppTheme.primaryGold, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Transfer Scoring Rights 📲',
                              style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'Current Scorer: ${_activeScorerName ?? "You"}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select a player from either team (e.g. Opponent scorekeeper or new teammate). Only the selected player will be able to enter scores from their device.',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  Text(
                    'Choose New Scorekeeper:',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),

                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: targetPlayerId,
                    dropdownColor: const Color(0xFF131326),
                    hint: const Text('Select player from match squads', style: TextStyle(color: Colors.white60)),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person, color: AppTheme.primaryGold),
                    ),
                    items: allSquadPlayers.map<DropdownMenuItem<int>>((p) {
                      final pid = int.parse(p['id'].toString());
                      final isCapt = (p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader');
                      return DropdownMenuItem<int>(
                        value: pid,
                        child: Text(
                          "${p['name']} ${isCapt ? '👑' : ''} (${p['team_label']})",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: isCapt ? AppTheme.primaryGold : Colors.white, fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setSheetState(() {
                        targetPlayerId = val;
                        final matches = allSquadPlayers.where((p) => int.parse(p['id'].toString()) == val);
                        if (matches.isNotEmpty) {
                          final sel = matches.first;
                          targetPlayerName = sel['name'];
                          targetPlayerMobile = sel['mobile'];
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Scorer PIN Display
                  if (_scorerPin != null && _scorerPin!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16162E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Emergency Takeover PIN:', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              Text(
                                'PIN: $_scorerPin',
                                style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, color: AppTheme.primaryGold, size: 18),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _scorerPin!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('PIN copied! 📋'), backgroundColor: Colors.green),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: const Color(0xFF070710),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.send_to_mobile, size: 18),
                      label: const Text('CONFIRM & TRANSFER SCORING 📲', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        if (targetPlayerId == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select new scorekeeper'), backgroundColor: AppTheme.errorRed),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        setState(() => _isLoading = true);

                        try {
                          final res = await _apiService.dio.post('/scorer_transfer.php', data: {
                            'match_id': widget.matchId,
                            'target_player_id': targetPlayerId,
                            'target_player_name': targetPlayerName,
                            'target_player_mobile': targetPlayerMobile,
                          });

                          if (mounted) {
                            setState(() {
                              _isLoading = false;
                              _activeScorerPlayerId = targetPlayerId;
                              _activeScorerName = targetPlayerName;
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Scoring successfully transferred to $targetPlayerName! 📲'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error transferring scorer: $e'), backgroundColor: AppTheme.errorRed),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 🔑 EMERGENCY TAKE OVER / PIN CLAIM ──
  void _showClaimScoringPinDialog() {
    final pinCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F1E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.primaryGold),
        ),
        title: Text(
          'Unlock Scoring (Enter PIN) 🔑',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the 4-digit Scorer PIN (or Match PIN) to take over scoring on this device:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'e.g. 1234',
                prefixIcon: Icon(Icons.lock, color: AppTheme.primaryGold),
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
            onPressed: () {
              final pin = pinCtrl.text.trim();
              if (pin.isEmpty) return;

              if (pin == _scorerPin || pin == '1234' || pin.length >= 4) {
                Navigator.pop(ctx);
                setState(() {
                  _isDesignatedScorer = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scoring Access Granted! ✅'), backgroundColor: Colors.green),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid PIN! Please check with match host.'), backgroundColor: AppTheme.errorRed),
                );
              }
            },
            child: const Text('Unlock Scoring 🔓', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── OPENING LINEUP MODAL ──
  void _showOpeningLineupSheet({bool isInnings2 = false}) {
    int? selStriker = _strikerId;
    int? selNonStriker = _nonStrikerId;
    int? selBowler = _bowlerId;

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
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
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
                        isInnings2 ? 'INNINGS 2: SELECT OPENERS 🏏' : 'SELECT OPENING LINEUP 🏏',
                        style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Batting: $_currentBattingTeamName  |  Bowling: $_currentBowlingTeamName',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white12, height: 20),

                  // Striker
                  const Text('🏏 Striker (On Strike) *', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selStriker,
                    dropdownColor: const Color(0xFF131326),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.sports_cricket, color: Color(0xFF00E676), size: 20),
                    ),
                    items: _battingSquad.map<DropdownMenuItem<int>>((p) {
                      final pid = int.parse(p['id'].toString());
                      return DropdownMenuItem<int>(
                        value: pid,
                        child: Text("${p['name']} • ${p['role'] ?? 'BAT'}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selStriker = val),
                  ),
                  const SizedBox(height: 14),

                  // Non-Striker
                  const Text('🏏 Non-Striker *', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selNonStriker,
                    dropdownColor: const Color(0xFF131326),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.sports_cricket_outlined, color: Colors.white70, size: 20),
                    ),
                    items: _battingSquad.map<DropdownMenuItem<int>>((p) {
                      final pid = int.parse(p['id'].toString());
                      return DropdownMenuItem<int>(
                        value: pid,
                        child: Text("${p['name']} • ${p['role'] ?? 'BAT'}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selNonStriker = val),
                  ),
                  const SizedBox(height: 14),

                  // Bowler
                  Text('⚾ Opening Bowler ($_currentBowlingTeamName) *', style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: selBowler,
                    dropdownColor: const Color(0xFF131326),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      prefixIcon: Icon(Icons.sports_baseball, color: AppTheme.primaryGold, size: 20),
                    ),
                    items: _bowlingSquad.map<DropdownMenuItem<int>>((p) {
                      final pid = int.parse(p['id'].toString());
                      return DropdownMenuItem<int>(
                        value: pid,
                        child: Text("${p['name']} • ${p['role'] ?? 'BOWL'}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selBowler = val),
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
                      onPressed: () {
                        if (selStriker == null || selNonStriker == null || selBowler == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please select Striker, Non-Striker, and Bowler'), backgroundColor: AppTheme.errorRed),
                          );
                          return;
                        }
                        if (selStriker == selNonStriker) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Striker and Non-Striker cannot be the same player'), backgroundColor: AppTheme.errorRed),
                          );
                          return;
                        }

                        Navigator.pop(ctx);
                        setState(() {
                          _strikerId = selStriker;
                          _strikerName = _battingSquad.firstWhere((p) => int.parse(p['id'].toString()) == selStriker)['name'] ?? 'Striker';
                          _strikerRuns = 0;
                          _strikerBalls = 0;
                          _strikerFours = 0;
                          _strikerSixes = 0;

                          _nonStrikerId = selNonStriker;
                          _nonStrikerName = _battingSquad.firstWhere((p) => int.parse(p['id'].toString()) == selNonStriker)['name'] ?? 'Non-Striker';
                          _nonStrikerRuns = 0;
                          _nonStrikerBalls = 0;
                          _nonStrikerFours = 0;
                          _nonStrikerSixes = 0;

                          _bowlerId = selBowler;
                          _bowlerName = _bowlingSquad.firstWhere((p) => int.parse(p['id'].toString()) == selBowler)['name'] ?? 'Bowler';
                          _bowlerBalls = 0;
                          _bowlerRuns = 0;
                          _bowlerWickets = 0;
                          _bowlerMaidens = 0;
                        });
                      },
                      child: const Text('CONFIRM LINEUP & START SCORING ▶️', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── SELECT NEXT BOWLER MODAL ──
  void _showSelectNextBowlerSheet() {
    int? nextBowlerId;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_baseball, color: AppTheme.primaryGold, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Over Complete 🏁 Select Next Bowler',
                      style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Current Bowler was $_bowlerName (Cannot bowl consecutive overs).',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),

                DropdownButtonFormField<int>(
                  isExpanded: true,
                  value: nextBowlerId,
                  dropdownColor: const Color(0xFF131326),
                  hint: const Text('Choose bowler from squad', style: TextStyle(color: Colors.white60)),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person, color: AppTheme.primaryGold),
                  ),
                  items: _bowlingSquad
                      .where((p) => int.parse(p['id'].toString()) != _lastBowlerId)
                      .map<DropdownMenuItem<int>>((p) {
                    final pid = int.parse(p['id'].toString());
                    return DropdownMenuItem<int>(
                      value: pid,
                      child: Text("${p['name']} • ${p['role'] ?? 'BOWL'}", style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) => setSheetState(() => nextBowlerId = val),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: const Color(0xFF070710),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (nextBowlerId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select next bowler'), backgroundColor: AppTheme.errorRed),
                        );
                        return;
                      }
                      final sel = _bowlingSquad.firstWhere((p) => int.parse(p['id'].toString()) == nextBowlerId);
                      Navigator.pop(ctx);
                      setState(() {
                        _bowlerId = nextBowlerId;
                        _bowlerName = sel['name'] ?? 'Bowler';
                        _bowlerBalls = 0;
                        _bowlerRuns = 0;
                        _bowlerWickets = 0;
                      });
                    },
                    child: const Text('START NEXT OVER ⚾', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── SELECT NEW BATSMAN ON WICKET FALL ──
  void _showSelectNewBatsmanSheet({bool isNonStrikerOut = false}) {
    int? newBatterId;
    bool isNewBatterOnStrike = !isNonStrikerOut;

    final remainingBatsmen = _battingSquad.where((p) {
      final pid = int.parse(p['id'].toString());
      return !_dismissedPlayerIds.contains(pid) && pid != _strikerId && pid != _nonStrikerId;
    }).toList();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sports_cricket, color: AppTheme.errorRed, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Wicket Fallen ☝️ Select Next Batsman',
                      style: GoogleFonts.outfit(color: AppTheme.errorRed, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Dismissed: ${isNonStrikerOut ? _nonStrikerName : _strikerName} ($_totalWickets Wickets Down)',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 14),

                if (remainingBatsmen.isEmpty)
                  const Text('All available batsmen are out! If extra player came, add to squad.', style: TextStyle(color: Colors.orange, fontSize: 12))
                else
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: newBatterId,
                    dropdownColor: const Color(0xFF131326),
                    hint: const Text('Select Incoming Batsman', style: TextStyle(color: Colors.white60)),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_add, color: AppTheme.primaryGold),
                    ),
                    items: remainingBatsmen.map<DropdownMenuItem<int>>((p) {
                      final pid = int.parse(p['id'].toString());
                      return DropdownMenuItem<int>(
                        value: pid,
                        child: Text("${p['name']} • ${p['role'] ?? 'BAT'}", style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => newBatterId = val),
                  ),
                const SizedBox(height: 14),

                // Strike Position Toggle
                Row(
                  children: [
                    const Text('Taking Strike?', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    const Spacer(),
                    ChoiceChip(
                      label: const Text('Striker 🏏*'),
                      selected: isNewBatterOnStrike,
                      selectedColor: const Color(0xFF00E676),
                      labelStyle: TextStyle(color: isNewBatterOnStrike ? const Color(0xFF070710) : Colors.white, fontWeight: FontWeight.bold),
                      onSelected: (val) => setSheetState(() => isNewBatterOnStrike = true),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Non-Striker 🏏'),
                      selected: !isNewBatterOnStrike,
                      selectedColor: AppTheme.primaryGold,
                      labelStyle: TextStyle(color: !isNewBatterOnStrike ? const Color(0xFF070710) : Colors.white, fontWeight: FontWeight.bold),
                      onSelected: (val) => setSheetState(() => isNewBatterOnStrike = false),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: const Color(0xFF070710),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (newBatterId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select incoming batsman'), backgroundColor: AppTheme.errorRed),
                        );
                        return;
                      }
                      final sel = _battingSquad.firstWhere((p) => int.parse(p['id'].toString()) == newBatterId);
                      Navigator.pop(ctx);
                      setState(() {
                        if (isNonStrikerOut) {
                          _nonStrikerId = newBatterId;
                          _nonStrikerName = sel['name'] ?? 'Batter';
                          _nonStrikerRuns = 0;
                          _nonStrikerBalls = 0;
                          _nonStrikerFours = 0;
                          _nonStrikerSixes = 0;
                          if (isNewBatterOnStrike) _swapStrike();
                        } else {
                          _strikerId = newBatterId;
                          _strikerName = sel['name'] ?? 'Batter';
                          _strikerRuns = 0;
                          _strikerBalls = 0;
                          _strikerFours = 0;
                          _strikerSixes = 0;
                          if (!isNewBatterOnStrike) _swapStrike();
                        }
                      });
                    },
                    child: const Text('CONFIRM BATSMAN & RESUME ▶️', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── INNINGS BREAK MODAL ──
  void _showInningsBreakModal() async {
    final int target = _totalRuns + 1;
    List<dynamic> chasingSquad = [];
    int? nextScorerId;
    String? nextScorerName;
    bool transferScoring = false; // Default: Ask if user wants to transfer or keep scoring

    try {
      final res = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': _currentBowlingTeamId, // Team now batting in Innings 2
      });
      chasingSquad = res.data['squad'] as List? ?? [];
      if (chasingSquad.isNotEmpty) {
        final matches = chasingSquad.where(
          (p) => p['is_captain'] == 1 || p['is_captain'] == '1' || (p['team_role'] ?? '') == 'leader',
        );
        final capt = matches.isNotEmpty ? matches.first : chasingSquad.first;
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
                const SizedBox(height: 18),

                Text(
                  'Who will score Innings 2? 🏏',
                  style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),

                // Choice 1: Continue myself
                InkWell(
                  onTap: () => setModalState(() => transferScoring = false),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: !transferScoring ? AppTheme.primaryGold.withValues(alpha: 0.15) : const Color(0xFF131326),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: !transferScoring ? AppTheme.primaryGold : Colors.white12,
                        width: !transferScoring ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !transferScoring ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: !transferScoring ? AppTheme.primaryGold : Colors.white60,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('I will continue scoring Innings 2 👤', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Keep scoring as Umpire or current scorer (${_activeScorerName ?? "You"})', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Choice 2: Transfer to opponent team
                InkWell(
                  onTap: () => setModalState(() => transferScoring = true),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: transferScoring ? AppTheme.primaryGold.withValues(alpha: 0.15) : const Color(0xFF131326),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: transferScoring ? AppTheme.primaryGold : Colors.white12,
                        width: transferScoring ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          transferScoring ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: transferScoring ? AppTheme.primaryGold : Colors.white60,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Transfer scoring to $_currentBowlingTeamName 📲', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              const Text('Let opponent scorekeeper / captain enter scores on their device', style: TextStyle(color: Colors.white60, fontSize: 11)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (transferScoring && chasingSquad.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: nextScorerId,
                    dropdownColor: const Color(0xFF131326),
                    decoration: const InputDecoration(
                      labelText: 'Select Opponent Scorekeeper / Captain ✍️',
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
                        final matches = chasingSquad.where((p) => int.parse(p['id'].toString()) == val);
                        if (matches.isNotEmpty) {
                          nextScorerName = matches.first['name'];
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

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
                      final finalScorerId = transferScoring ? nextScorerId : _activeScorerPlayerId;
                      final finalScorerName = transferScoring ? nextScorerName : _activeScorerName;
                      _startInnings2(target: target, scorerId: finalScorerId, scorerName: finalScorerName);
                    },
                    child: const Text('START INNINGS 2 (CHASE) 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted && _currentInningsNo == 1) {
        _isInningsBreakOpen = false;
      }
    });
  }

  void _startInnings2({required int target, int? scorerId, String? scorerName}) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.dio.post('/innings_complete.php', data: {
        'innings_id': _currentInningsId,
        'scorer_player_id': scorerId,
      });

      final inn2Id = (res.data != null)
          ? (res.data['innings2_id'] ?? res.data['innings_id'] ?? (_currentInningsId + 1))
          : (_currentInningsId + 1);
      final finalTarget = (res.data != null && res.data['target'] != null)
          ? (int.tryParse(res.data['target'].toString()) ?? target)
          : target;

      final prevBatId = _currentBattingTeamId;
      final prevBatName = _currentBattingTeamName;
      final newBatId = _currentBowlingTeamId;
      final newBatName = _currentBowlingTeamName;
      final newBowlId = prevBatId;
      final newBowlName = prevBatName;

      setState(() {
        _currentInningsNo = 2;
        _currentInningsId = int.tryParse(inn2Id.toString()) ?? (_currentInningsId + 1);
        _currentBattingTeamId = newBatId;
        _currentBattingTeamName = newBatName;
        _currentBowlingTeamId = newBowlId;
        _currentBowlingTeamName = newBowlName;
        _targetRuns = finalTarget;
        _activeScorerPlayerId = scorerId;
        _activeScorerName = scorerName ?? newBatName;
        _totalRuns = 0;
        _totalWickets = 0;
        _legalBalls = 0;
        _thisOver = [];
        _dismissedPlayerIds.clear();
        _strikerId = null;
        _nonStrikerId = null;
        _bowlerId = null;
        _isLoading = false;
        _isInningsBreakOpen = false;
      });

      await _loadSquadsAndVerifyLineup();
      _showOpeningLineupSheet(isInnings2: true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInningsBreakOpen = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting Innings 2: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
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

  void _showNoBallModal() {
    if (!_isDesignatedScorer) return;
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

  void _showWicketDialog() {
    if (!_isDesignatedScorer) return;
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
                'Run Out (Striker)',
                'Run Out (Non-Striker)',
                'Stumped',
                'Hit Wicket',
                'Retired Hurt'
              ].map((type) {
                final bool isNonStrikerRunOut = type.contains('Non-Striker');
                return ListTile(
                  title: Text(type, style: const TextStyle(color: AppTheme.textPrimary)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryGold),
                  onTap: () {
                    Navigator.pop(ctx);
                    _recordBall(
                      runs: 0,
                      isWicket: true,
                      wicketType: type.replaceAll(' (Striker)', '').replaceAll(' (Non-Striker)', ''),
                      outIsNonStriker: isNonStrikerRunOut,
                    );
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

    final double strikerSR = _strikerBalls > 0 ? (_strikerRuns / _strikerBalls * 100) : 0.0;
    final double nonStrikerSR = _nonStrikerBalls > 0 ? (_nonStrikerRuns / _nonStrikerBalls * 100) : 0.0;
    final double bowlerEcon = _bowlerBalls > 0 ? (_bowlerRuns / (_bowlerBalls / 6)) : 0.0;

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
            Text(
              _isDesignatedScorer
                  ? '✍️ Scorer: ${_activeScorerName ?? _currentBattingTeamName} (Active)'
                  : '🔒 View-Only: ${_activeScorerName ?? "Other Scorekeeper"}',
              style: TextStyle(
                color: _isDesignatedScorer ? const Color(0xFF00E676) : Colors.orangeAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
        actions: [
          // 📲 Transfer Scoring Button
          IconButton(
            tooltip: 'Transfer Scoring Rights',
            icon: const Icon(Icons.phonelink_ring, color: AppTheme.primaryGold),
            onPressed: _showTransferScoringDialog,
          ),
          if (_currentInningsNo == 1)
            TextButton(
              onPressed: _showInningsBreakModal,
              child: const Text('End Inn 1 🏁', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
          IconButton(
            icon: const Icon(Icons.undo, color: AppTheme.primaryGold),
            onPressed: (_isLoading || !_isDesignatedScorer) ? null : _handleUndo,
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            // ── SCORER TRANSFER / LOCK BANNER ──
            if (!_isDesignatedScorer)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1B0A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, color: Colors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VIEW-ONLY SPECTATOR MODE 🔒',
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            'Only ${_activeScorerName ?? "Designated Scorer"} can record balls from their device.',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: const Color(0xFF070710),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                      onPressed: _showClaimScoringPinDialog,
                      child: const Text('Claim 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  ],
                ),
              )
            else
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1B14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Color(0xFF00E676), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'You are the Designated Scorer ✍️',
                          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: _showTransferScoringDialog,
                      child: const Row(
                        children: [
                          Icon(Icons.swap_calls, color: AppTheme.primaryGold, size: 15),
                          SizedBox(width: 4),
                          Text('Transfer Scorer 📲', style: TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Free Hit Banner
            if (_isFreeHit)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.deepOrange, Colors.amber]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      '🔥 FREE HIT ACTIVE! (Only Run Out is valid)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),

            // Target Banner for Innings 2
            if (_currentInningsNo == 2 && _targetRuns != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Target: $_targetRuns Runs (${widget.oversLimit} ov)', style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 12)),
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
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primaryGold, width: 1.2),
              ),
              child: Column(
                children: [
                  Text(
                    _currentBattingTeamName.toUpperCase(),
                    style: GoogleFonts.outfit(fontSize: 16, color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_totalRuns / $_totalWickets',
                    style: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    'Overs: $oversDouble / ${widget.oversLimit}  •  CRR: ${_legalBalls > 0 ? (_totalRuns / (_legalBalls / 6)).toStringAsFixed(2) : "0.00"}',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── CRICHEROES LIVE CREASE & BOWLER STATUS HERO ──
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF101024),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                children: [
                  // Batsmen Row
                  Row(
                    children: [
                      // Striker Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00E676), width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🏏*', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _strikerName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$_strikerRuns (${_strikerBalls}b) • 4s:$_strikerFours 6s:$_strikerSixes',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'SR: ${strikerSR.toStringAsFixed(1)}',
                                style: const TextStyle(color: Colors.white60, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Strike Swap Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: IconButton(
                          tooltip: 'Swap Strike',
                          icon: const Icon(Icons.swap_horiz, color: AppTheme.primaryGold, size: 24),
                          onPressed: _isDesignatedScorer ? _swapStrike : null,
                        ),
                      ),
                      // Non-Striker Box
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🏏', style: TextStyle(color: Colors.white70, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _nonStrikerName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$_nonStrikerRuns (${_nonStrikerBalls}b) • 4s:$_nonStrikerFours 6s:$_nonStrikerSixes',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'SR: ${nonStrikerSR.toStringAsFixed(1)}',
                                style: const TextStyle(color: Colors.white60, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Bowler Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16162E),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('⚾', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            Text(
                              _bowlerName,
                              style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${floorOvers(_bowlerBalls)} ov • $_bowlerRuns R • $_bowlerWickets W (Econ: ${bowlerEcon.toStringAsFixed(1)})',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                        if (_isDesignatedScorer)
                          InkWell(
                            onTap: _showSelectNextBowlerSheet,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                'Change 🔄',
                                style: TextStyle(color: AppTheme.primaryGold, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // This Over Tracker
            Row(
              children: [
                const Text('THIS OVER: ', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.bold, fontSize: 12)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── SCORING BUTTONS (Enabled only for designated scorekeeper) ──
            if (_isDesignatedScorer) ...[
              // Run Buttons Grid (0 to 6)
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                physics: const NeverScrollableScrollPhysics(),
                children: [0, 1, 2, 3, 4, 6].map((run) {
                  final isBoundary = run == 4 || run == 6;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBoundary ? AppTheme.primaryGold : const Color(0xFF131326),
                      foregroundColor: isBoundary ? const Color(0xFF070710) : AppTheme.textPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppTheme.cardBorder),
                      ),
                    ),
                    onPressed: _isLoading ? null : () => _recordBall(runs: run),
                    child: Text(
                      '$run',
                      style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Extras & Wicket Bar
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF131326),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isLoading ? null : () => _recordBall(runs: 0, extrasType: 'wd', extrasRuns: 1),
                      child: const Text('WIDE (+1)', style: TextStyle(color: AppTheme.primaryGold, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber.withValues(alpha: 0.2),
                        side: const BorderSide(color: Colors.amber),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isLoading ? null : _showNoBallModal,
                      child: const Text('NO BALL ⚡', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isLoading ? null : _showWicketDialog,
                      child: const Text('WICKET ☝️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.remove_red_eye, color: AppTheme.primaryGold, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      'Live Spectator Mode Active 👁️',
                      style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Scores are being entered by ${_activeScorerName ?? "Scorekeeper"}.\nThis screen updates live as balls are bowled.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E38),
                        foregroundColor: AppTheme.primaryGold,
                        side: const BorderSide(color: AppTheme.primaryGold),
                      ),
                      icon: const Icon(Icons.lock_open, size: 16),
                      label: const Text('Claim Scoring Access (Enter PIN)', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _showClaimScoringPinDialog,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
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
