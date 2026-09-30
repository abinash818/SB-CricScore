import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import 'playing_xi_selector_screen.dart';

class QrMatchScannerScreen extends StatefulWidget {
  final int? preselectedTeamId;
  const QrMatchScannerScreen({super.key, this.preselectedTeamId});

  @override
  State<QrMatchScannerScreen> createState() => _QrMatchScannerScreenState();
}

class _QrMatchScannerScreenState extends State<QrMatchScannerScreen> {
  final ApiService _apiService = ApiService();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final TextEditingController _pinController = TextEditingController();
  List<dynamic> _myTeams = [];
  int? _selectedTeamId;
  bool _isLoadingTeams = true;
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _selectedTeamId = widget.preselectedTeamId;
    _fetchUserTeams();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserTeams() async {
    try {
      final myRes = await _apiService.getMyTeams();
      final allRes = await _apiService.dio.get('/team_ops.php', queryParameters: {'action': 'list'});

      if (mounted) {
        setState(() {
          final myTeams = myRes['teams'] as List? ?? [];
          final allTeams = allRes.data['teams'] as List? ?? [];

          final Map<int, dynamic> teamMap = {};
          for (var t in myTeams) {
            teamMap[int.parse(t['id'].toString())] = {...t, 'is_my_team': true};
          }
          for (var t in allTeams) {
            final id = int.parse(t['id'].toString());
            if (!teamMap.containsKey(id)) {
              teamMap[id] = {...t, 'is_my_team': false};
            }
          }

          _myTeams = teamMap.values.toList();
          if (_selectedTeamId == null && _myTeams.isNotEmpty) {
            _selectedTeamId = int.parse(_myTeams.first['id'].toString());
          }
          _isLoadingTeams = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTeams = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        _handleScannedPayload(rawValue);
        break;
      }
    }
  }

  void _handleScannedPayload(String raw) async {
    final payload = raw.trim();

    // 1. Tournament Registration QR
    if (payload.startsWith('sbcric_tourn:') || payload.contains('tour_id=')) {
      String tidStr = '';
      if (payload.startsWith('sbcric_tourn:')) {
        tidStr = payload.replaceFirst('sbcric_tourn:', '');
      } else {
        final uri = Uri.tryParse(payload);
        tidStr = uri?.queryParameters['tour_id'] ?? '';
      }
      final tid = int.tryParse(tidStr);
      if (tid != null && tid > 0) {
        _handleTournamentQr(tid);
        return;
      }
    }

    // 2. Match Invite QR / Code
    String code = payload;
    if (code.startsWith('sbcric_match:')) {
      code = code.replaceFirst('sbcric_match:', '');
    } else if (code.contains('code=')) {
      final uri = Uri.tryParse(code);
      if (uri != null && uri.queryParameters.containsKey('code')) {
        code = uri.queryParameters['code']!;
      }
    }
    code = code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toUpperCase();
    if (code.isNotEmpty) {
      _fetchAndShowMatchInvite(code);
    }
  }

  Future<void> _fetchAndShowMatchInvite(String matchCode) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      final res = await _apiService.dio.get('/match_join_qr.php', queryParameters: {
        'action': 'get_invite',
        'match_code': matchCode,
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        if (res.data['success'] == true) {
          _showMatchInviteBottomSheet(res.data, matchCode);
        } else {
          _scannerController.start();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data['message'] ?? 'Invalid Match QR'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _scannerController.start();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading match invite. Please try again.'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _showMatchInviteBottomSheet(Map<String, dynamic> invite, String matchCode) {
    int? chosenTeamId = _selectedTeamId;
    final hostTeam = invite['host_team_name'] ?? 'Host Team';
    final venue = invite['venue_name'] ?? 'Cricket Ground';
    final overs = invite['overs_limit'] ?? 10;
    final ballType = invite['ball_type_label'] ?? '🎾 Tennis Ball';
    final isScheduled = invite['is_scheduled'] == true;
    final matchDate = invite['match_date'];
    final matchTime = invite['match_time'];
    final matchId = invite['match_id'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.handshake, color: Color(0xFF00E676), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MATCH INVITATION 🏏',
                            style: GoogleFonts.outfit(color: const Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Text(
                            'Invited by $hostTeam',
                            style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _scannerController.start();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Match Specs Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131326),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(venue, style: const TextStyle(fontWeight: FontWeight.w600))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.sports_cricket, color: AppTheme.primaryGold, size: 16),
                          const SizedBox(width: 8),
                          Text('$overs Overs  •  $ballType', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                        ],
                      ),
                      if (isScheduled && (matchDate != null || matchTime != null)) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFF00E676), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              '📅 ${matchDate ?? ''} at ${matchTime ?? ''}',
                              style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Select Opponent Team
                Text(
                  'Select Your Team to Join:',
                  style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131326),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: chosenTeamId,
                      isExpanded: true,
                      dropdownColor: AppTheme.cardBg,
                      hint: const Text('Select Your Team', style: TextStyle(color: AppTheme.textMuted)),
                      items: _myTeams.map<DropdownMenuItem<int>>((t) {
                        final id = int.parse(t['id'].toString());
                        final isMine = t['is_my_team'] == true;
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(
                            "${t['name']} ${isMine ? '(My Team)' : ''}",
                            style: TextStyle(
                              color: isMine ? AppTheme.primaryGold : AppTheme.textPrimary,
                              fontWeight: isMine ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() => chosenTeamId = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Accept & Set Playing XI Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: const Color(0xFF070710),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.groups, color: Color(0xFF070710), size: 20),
                    label: Text(
                      'Accept & Set Playing XI (11+3)',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () async {
                      if (chosenTeamId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select your team first')),
                        );
                        return;
                      }

                      Navigator.pop(ctx); // Close sheet

                      // 1. Join Match on backend
                      final joinRes = await _apiService.joinMatchQR(
                        teamId: chosenTeamId!,
                        matchCode: matchCode,
                      );

                      if (joinRes['success'] == true) {
                        // 2. Open Playing XI Selector for Team B
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlayingXiSelectorScreen(
                                matchId: matchId,
                                teamId: chosenTeamId!,
                                teamName: joinRes['team_b_name'] ?? 'My Team',
                                openTossOnSave: true,
                              ),
                            ),
                          );
                        }
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(joinRes['message'] ?? 'Failed to connect'), backgroundColor: AppTheme.errorRed),
                          );
                          _scannerController.start();
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleTournamentQr(int tournamentId) async {
    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      final res = await _apiService.getTournamentHub(tournamentId);
      if (mounted) {
        setState(() => _isProcessing = false);
        if (res['success'] == true) {
          _showTournamentRegisterBottomSheet(res['tournament'], tournamentId);
        } else {
          _scannerController.start();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tournament not found'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _scannerController.start();
      }
    }
  }

  void _showTournamentRegisterBottomSheet(Map<String, dynamic> tourn, int tournamentId) {
    int? regTeamId = _selectedTeamId;
    final tName = tourn['name'] ?? 'Tournament';
    final overs = tourn['default_overs'] ?? 20;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events, color: AppTheme.primaryGold, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOURNAMENT REGISTRATION 🏆', style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(tName, style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppTheme.textMuted),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _scannerController.start();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Format: $overs Overs  •  Round Robin / Knockout', style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                const SizedBox(height: 16),
                Text('Select Your Team to Register:', style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131326),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: regTeamId,
                      isExpanded: true,
                      dropdownColor: AppTheme.cardBg,
                      hint: const Text('Select Team', style: TextStyle(color: AppTheme.textMuted)),
                      items: _myTeams.map<DropdownMenuItem<int>>((t) {
                        final id = int.parse(t['id'].toString());
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(t['name']),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => regTeamId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: const Color(0xFF070710),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      if (regTeamId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select team')));
                        return;
                      }
                      Navigator.pop(ctx);
                      try {
                        final regRes = await _apiService.dio.post('/tournament_ops.php?action=register_team', data: {
                          'tournament_id': tournamentId,
                          'team_id': regTeamId,
                        });
                        if (mounted) {
                          if (regRes.data['success'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(regRes.data['message'] ?? 'Team Registered!'), backgroundColor: AppTheme.successGreen),
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(regRes.data['message'] ?? 'Failed to register'), backgroundColor: AppTheme.errorRed),
                            );
                            _scannerController.start();
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Network error registering team'), backgroundColor: AppTheme.errorRed),
                          );
                          _scannerController.start();
                        }
                      }
                    },
                    child: Text('Confirm & Register Team 🏆', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showManualPinSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Enter Match PIN 🔢',
                    style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _pinController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '6-Digit Match PIN / Code',
                  hintText: 'e.g. SB8921',
                  prefixIcon: Icon(Icons.pin, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: const Color(0xFF070710),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    final code = _pinController.text.trim();
                    if (code.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter Match PIN')),
                      );
                      return;
                    }
                    Navigator.pop(ctx);
                    _handleScannedPayload(code);
                  },
                  child: Text(
                    'Search & Join Match 🚀',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'SCAN MATCH & TOURNAMENT QR',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: AppTheme.primaryGold),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _scannerController.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_android, color: AppTheme.primaryGold),
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Select Team Top Bar ──
          Container(
            color: AppTheme.cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _isLoadingTeams
                ? const Center(child: LinearProgressIndicator(color: AppTheme.primaryGold))
                : Row(
                    children: [
                      const Icon(Icons.shield, color: AppTheme.primaryGold, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedTeamId,
                            isExpanded: true,
                            dropdownColor: AppTheme.cardBg,
                            hint: const Text('Select Your Default Team', style: TextStyle(color: AppTheme.textMuted)),
                            items: _myTeams.map<DropdownMenuItem<int>>((t) {
                              final id = int.parse(t['id'].toString());
                              final isMine = t['is_my_team'] == true;
                              return DropdownMenuItem<int>(
                                value: id,
                                child: Text(
                                  "${t['name']} ${isMine ? '(My Team)' : ''}",
                                  style: TextStyle(
                                    color: isMine ? AppTheme.primaryGold : AppTheme.textPrimary,
                                    fontWeight: isMine ? FontWeight.bold : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() => _selectedTeamId = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Scanner Camera View ──
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),

                // Scanner Targeting Reticle
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.primaryGold, width: 2.5),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryGold.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Top Instruction Badge
                Positioned(
                  top: 30,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Scan Match QR / Tournament QR Code',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),

                // Loading Spinner when processing
                if (_isProcessing)
                  Container(
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: AppTheme.primaryGold),
                          const SizedBox(height: 16),
                          Text(
                            'Loading Details...',
                            style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Bottom Manual PIN Option ──
          Container(
            color: AppTheme.cardBg,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Have a 6-digit Match PIN?',
                        style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Tap here to enter PIN directly',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: const Color(0xFF070710),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.keyboard, size: 18, color: Color(0xFF070710)),
                  label: const Text('Enter PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showManualPinSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
