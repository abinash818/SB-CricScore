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

  String _cleanMatchCode(String raw) {
    var code = raw.trim();
    if (code.startsWith('sbcric_match:')) {
      code = code.replaceFirst('sbcric_match:', '');
    } else if (code.contains('code=')) {
      final uri = Uri.tryParse(code);
      if (uri != null && uri.queryParameters.containsKey('code')) {
        code = uri.queryParameters['code']!;
      }
    } else if (code.contains('match_id=')) {
      final uri = Uri.tryParse(code);
      if (uri != null && uri.queryParameters.containsKey('match_id')) {
        code = uri.queryParameters['match_id']!;
      }
    }
    return code.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '').toUpperCase();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        final code = _cleanMatchCode(rawValue);
        if (code.isNotEmpty) {
          _joinMatch(code);
          break;
        }
      }
    }
  }

  Future<void> _joinMatch(String matchCode) async {
    if (_isProcessing) return;

    if (_selectedTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your team first before scanning')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    _scannerController.stop();

    try {
      final res = await _apiService.joinMatchQR(
        teamId: _selectedTeamId!,
        matchCode: matchCode,
      );

      if (mounted) {
        if (res['success'] == true) {
          final matchId = res['match_id'] as int? ?? 0;
          final teamAName = res['team_a_name'] ?? 'Team A';
          final teamBName = res['team_b_name'] ?? 'Team B';

          _showJoinSuccessDialog(
            matchId: matchId,
            matchCode: matchCode,
            teamAName: teamAName,
            teamBName: teamBName,
            teamBId: _selectedTeamId!,
          );
        } else {
          setState(() => _isProcessing = false);
          _scannerController.start();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to connect match'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _scannerController.start();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error connecting to match. Check match code and try again.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _showJoinSuccessDialog({
    required int matchId,
    required String matchCode,
    required String teamAName,
    required String teamBName,
    required int teamBId,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 26),
            const SizedBox(width: 8),
            Text(
              'Connected to Match! 🎉',
              style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$teamAName vs $teamBName',
              style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Match PIN: $matchCode',
              style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            const Text(
              'You have successfully joined as Opponent Team! What would you like to do next?',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Back to Home', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGold,
              foregroundColor: const Color(0xFF070710),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PlayingXiSelectorScreen(
                    matchId: matchId,
                    teamId: teamBId,
                    teamName: teamBName,
                  ),
                ),
              );
            },
            child: const Text('Select Playing XI (11+3)', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
                    _joinMatch(code);
                  },
                  child: Text(
                    'Join Match 🚀',
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
          'SCAN MATCH QR',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
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
                            hint: const Text('Select Your Opponent Team', style: TextStyle(color: AppTheme.textMuted)),
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
                        color: AppTheme.primaryGold.withOpacity(0.2),
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
                      color: Colors.black.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5)),
                    ),
                    child: Text(
                      'Point camera at Opponent Match QR Code',
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
                            'Connecting to Match...',
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
                        'Cannot scan QR code?',
                        style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Type 6-digit Match PIN directly',
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
