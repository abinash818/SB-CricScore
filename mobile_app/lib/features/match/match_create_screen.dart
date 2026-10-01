import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api_service.dart';
import '../../core/location_service.dart';
import '../../core/theme.dart';
import '../location/location_picker_dialog.dart';
import '../team/team_create_screen.dart';
import 'toss_screen.dart';
import 'qr_match_scanner_screen.dart';

class MatchCreateScreen extends StatefulWidget {
  final int? tournamentId;
  final int? initialTeamAId;
  final int? initialTeamBId;
  final String? initialTeamBName;

  const MatchCreateScreen({
    super.key,
    this.tournamentId,
    this.initialTeamAId,
    this.initialTeamBId,
    this.initialTeamBName,
  });

  @override
  State<MatchCreateScreen> createState() => _MatchCreateScreenState();
}

class _MatchCreateScreenState extends State<MatchCreateScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _venueController = TextEditingController(text: 'Marina Cricket Ground');
  final TextEditingController _cityAreaController = TextEditingController();
  final TextEditingController _oversController = TextEditingController(text: '10');
  final TextEditingController _wicketsController = TextEditingController(text: '10');

  String _selectedDistrict = LocationService().currentDistrict.value;
  String _selectedState = LocationService().currentState.value;

  List<dynamic> _teams = [];
  List<dynamic> _hostEligibleTeams = [];
  bool _isLoading = true;
  bool _isCreating = false;

  // Match Mode: Instant vs Scheduled
  bool _isScheduled = false;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  int? _selectedTeamA;
  int? _selectedTeamB; // Pre-selected opponent or null for open QR invite
  String? _selectedTeamBName;
  bool _useQrInviteMode = false;
  String _ballType = 'tennis_light';
  List<int> _hostPlayingXiIds = [];

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

          // Host can only be a team where user is Leader, Co-Leader, or Owner
          _hostEligibleTeams = _myTeams.where((t) {
            return t['can_host_match'] != false || t['is_leader'] == true || t['is_co_leader'] == true;
          }).toList();

          if (_hostEligibleTeams.isEmpty && _myTeams.isNotEmpty) {
            _hostEligibleTeams = _myTeams;
          }

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
          if (widget.initialTeamAId != null) {
            _selectedTeamA = widget.initialTeamAId;
          } else if (_hostEligibleTeams.isNotEmpty && _selectedTeamA == null) {
            _selectedTeamA = int.parse(_hostEligibleTeams.first['id'].toString());
          }

          if (widget.initialTeamBId != null) {
            _selectedTeamB = widget.initialTeamBId;
            _selectedTeamBName = widget.initialTeamBName;
            _useQrInviteMode = false;
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(data: AppTheme.darkTheme, child: child!),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (ctx, child) => Theme(data: AppTheme.darkTheme, child: child!),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _openHostSquadPicker() async {
    if (_selectedTeamA == null) return;
    try {
      final res = await _apiService.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': _selectedTeamA,
      });
      if (!mounted) return;
      final squad = res.data['squad'] as List? ?? [];
      if (squad.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No players found in this team squad. You can proceed directly.')),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: AppTheme.cardBg,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Host Playing XI (${_hostPlayingXiIds.length} Selected)',
                        style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: squad.length,
                      itemBuilder: (c, idx) {
                        final p = squad[idx];
                        final pid = int.parse(p['id'].toString());
                        final isSel = _hostPlayingXiIds.contains(pid);
                        return CheckboxListTile(
                          activeColor: AppTheme.primaryGold,
                          checkColor: const Color(0xFF070710),
                          title: Text(p['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${p['role'] ?? 'BAT'}  •  ${p['batting_style'] ?? 'RHB'}", style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                          value: isSel,
                          onChanged: (val) {
                            setSheetState(() {
                              if (val == true) {
                                if (!_hostPlayingXiIds.contains(pid)) _hostPlayingXiIds.add(pid);
                              } else {
                                _hostPlayingXiIds.remove(pid);
                              }
                            });
                            setState(() {});
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGold,
                        foregroundColor: const Color(0xFF070710),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Confirm Playing XI', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    } catch (_) {}
  }

  void _showMatchCreatedDialog({
    required int matchId,
    required String matchCode,
    required String shareLink,
    required String teamAName,
    required String teamBName,
    required bool isScheduled,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppTheme.primaryGold, width: 1.5),
          ),
          child: Container(
            width: 360,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isScheduled ? 'Match Scheduled! 📅' : 'Match Created! 🎉',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    teamBName.isNotEmpty ? '$teamAName vs $teamBName' : '$teamAName (Waiting for Opponent)',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  // Match PIN Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'PIN: $matchCode',
                          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy PIN',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy, size: 18, color: AppTheme.primaryGold),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: matchCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Match PIN copied to clipboard! 📋'), backgroundColor: Colors.green),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // QR Code
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: QrImageView(
                      data: 'sbcric_match:$matchCode',
                      version: QrVersions.auto,
                      size: 160.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Opponent Captain can scan this QR code or enter PIN in SB CricScore to join!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),

                  // WhatsApp Share Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share, size: 18, color: Colors.white),
                      label: const Text('Share Invite on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final shareMsg = '🏏 Match Invite from $teamAName!\nMatch PIN: $matchCode\nGround: ${_venueController.text.trim()}\nJoin Link: $shareLink';
                        try {
                          final waUrl = Uri.parse('https://api.whatsapp.com/send?text=${Uri.encodeComponent(shareMsg)}');
                          if (await canLaunchUrl(waUrl)) {
                            await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                          } else {
                            await Share.share(shareMsg, subject: 'SB CricScore Match Invite');
                          }
                        } catch (_) {
                          Clipboard.setData(ClipboardData(text: shareMsg));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invite copied to clipboard! 📋'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text('Go to Home', style: TextStyle(color: AppTheme.textMuted)),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: const Color(0xFF070710),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.sports_cricket, size: 18, color: Color(0xFF070710)),
                        label: const Text('Start Match / Toss 🪙', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          // If team B is already selected, go directly to Toss
                          if (!isScheduled && _selectedTeamB != null && _selectedTeamB! > 0) {
                            Navigator.pop(ctx);
                            Navigator.pushReplacement(
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
                            return;
                          }

                          // If QR invite mode, check if opponent has connected
                          try {
                            final res = await _apiService.dio.get('/match_get.php', queryParameters: {'match_id': matchId});
                            final mData = res.data?['match'];
                            final int hostId = int.tryParse(mData?['team_a_id']?.toString() ?? '0') ?? _selectedTeamA!;
                            final int oppId = int.tryParse(mData?['team_b_id']?.toString() ?? '0') ?? 0;
                            final String oppName = mData?['team_b']?.toString() ?? 'Opponent';
                            final String hostName = mData?['team_a']?.toString() ?? teamAName;
                            final int ovs = int.tryParse(mData?['overs_limit']?.toString() ?? '10') ?? 10;

                            if (oppId > 0) {
                              if (context.mounted) {
                                Navigator.pop(ctx);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TossScreen(
                                      matchId: matchId,
                                      teamAId: hostId,
                                      teamBId: oppId,
                                      teamAName: hostName,
                                      teamBName: oppName,
                                      oversLimit: ovs,
                                    ),
                                  ),
                                );
                              }
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('⏳ Waiting for Opponent Captain to scan QR (PIN: $matchCode)... Once scanned, tap "Start Match" again!'),
                                    backgroundColor: Colors.orange,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Checking match status: $e'), backgroundColor: AppTheme.errorRed),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleCreateMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTeamA == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Host Team (Team A)'), backgroundColor: AppTheme.errorRed),
      );
      return;
    }
    if (_selectedTeamB != null && _selectedTeamA == _selectedTeamB) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team A and Team B cannot be the same team'), backgroundColor: AppTheme.errorRed),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      final dateStr = _isScheduled ? DateFormat('yyyy-MM-dd').format(_selectedDate) : null;
      final timeStr = _isScheduled ? _selectedTime.format(context) : null;

      final res = await _apiService.dio.post('/match_create.php', data: {
        'tournament_id': widget.tournamentId,
        'team_a_id': _selectedTeamA,
        'team_b_id': _selectedTeamB,
        'overs_limit': int.tryParse(_oversController.text) ?? 10,
        'wickets_limit': int.tryParse(_wicketsController.text) ?? 10,
        'venue_name': _venueController.text.trim(),
        'district': _selectedDistrict,
        'state': _selectedState,
        'city_area': _cityAreaController.text.trim(),
        'ball_type': _ballType,
        'match_date': dateStr,
        'match_time': timeStr,
        'host_player_ids': _hostPlayingXiIds,
      });

      if (mounted) {
        setState(() => _isCreating = false);
        if (res.data != null && (res.data['success'] == true || res.data['ok'] == true)) {
          final int matchId = int.tryParse(res.data['match_id'].toString()) ?? 0;
          final String matchCode = res.data['match_code']?.toString() ?? 'SB1234';
          final String shareLink = res.data['share_link']?.toString() ?? '';
          
          String teamAName = 'Team A';
          try {
            teamAName = _teams.firstWhere((t) => int.parse(t['id'].toString()) == _selectedTeamA)['name'];
          } catch (_) {}

          String teamBName = '';
          if (_selectedTeamB != null) {
            try {
              teamBName = _teams.firstWhere((t) => int.parse(t['id'].toString()) == _selectedTeamB)['name'];
            } catch (_) {}
          }

          _showMatchCreatedDialog(
            matchId: matchId,
            matchCode: matchCode,
            shareLink: shareLink,
            teamAName: teamAName,
            teamBName: teamBName,
            isScheduled: _isScheduled,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res.data?['message']?.toString() ?? 'Failed to create match'), backgroundColor: AppTheme.errorRed),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating match: $e'), backgroundColor: AppTheme.errorRed),
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
          'CREATE CRICKET MATCH',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Scan Match QR Code',
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryGold),
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18.0),
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
                        margin: const EdgeInsets.only(bottom: 18),
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

                    // ── Match Mode Switcher (Instant vs Scheduled) ──
                    Text(
                      'Match Mode',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isScheduled = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isScheduled ? AppTheme.primaryGold : AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: !_isScheduled ? AppTheme.primaryGold : AppTheme.cardBorder),
                              ),
                              child: Center(
                                child: Text(
                                  '⚡ Instant Match\n(Play Now)',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: !_isScheduled ? const Color(0xFF070710) : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isScheduled = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isScheduled ? AppTheme.primaryGold : AppTheme.cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _isScheduled ? AppTheme.primaryGold : AppTheme.cardBorder),
                              ),
                              child: Center(
                                child: Text(
                                  '📅 Scheduled Match\n(Set Date & Time)',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _isScheduled ? const Color(0xFF070710) : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date & Time pickers if scheduled
                    if (_isScheduled) ...[
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _pickDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today, size: 18, color: AppTheme.primaryGold),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Match Date', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                          Text(
                                            DateFormat('dd MMM yyyy').format(_selectedDate),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
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
                              onTap: _pickTime,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.cardBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppTheme.cardBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 18, color: AppTheme.primaryGold),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Match Time', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                          Text(
                                            _selectedTime.format(context),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                    ],

                    // ── Teams Selection ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Select Teams', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold, padding: EdgeInsets.zero),
                          icon: const Icon(Icons.add_circle_outline, size: 16),
                          label: const Text('Create My Team', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const TeamCreateScreen()),
                            );
                            _fetchTeams();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Host Team (Restricted to user's authorized teams)
                    if (_hostEligibleTeams.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppTheme.primaryGold, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('No Hosting Team Found', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  const Text('You must be a Leader or Co-Leader to host matches.', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGold,
                                foregroundColor: const Color(0xFF070710),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TeamCreateScreen()),
                                );
                                _fetchTeams();
                              },
                              child: const Text('Create Team', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: _selectedTeamA,
                        decoration: const InputDecoration(
                          labelText: 'Host Team (Team A) * [Leader / Co-Leader]',
                          prefixIcon: Icon(Icons.shield_outlined, color: AppTheme.primaryGold),
                        ),
                        items: _hostEligibleTeams.map<DropdownMenuItem<int>>((t) {
                          final String role = (t['user_role'] ?? 'leader').toString().toLowerCase();
                          final bool isLeader = (role == 'leader' || t['is_leader'] == true);
                          final String roleBadge = isLeader ? '👑 Leader' : '⭐ Co-Leader';

                          return DropdownMenuItem<int>(
                            value: int.parse(t['id'].toString()),
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    t['name'] ?? 'Team',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLeader ? AppTheme.primaryGold.withValues(alpha: 0.2) : Colors.purpleAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    roleBadge,
                                    style: TextStyle(
                                      color: isLeader ? AppTheme.primaryGold : Colors.purpleAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() {
                          _selectedTeamA = val;
                          _hostPlayingXiIds.clear();
                        }),
                      ),
                    const SizedBox(height: 8),

                    // Host Team Squad Selector button
                    if (_selectedTeamA != null) ...[
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: _openHostSquadPicker,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.groups, color: AppTheme.primaryGold, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _hostPlayingXiIds.isEmpty
                                      ? 'Select Host Playing XI (Optional)'
                                      : 'Host Playing XI: ${_hostPlayingXiIds.length} Players Selected ✅',
                                  style: const TextStyle(color: AppTheme.primaryGold, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryGold, size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ] else
                      const SizedBox(height: 12),

                    // Opponent Team Section (Direct Opponent Selection or QR Invite)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Opponent Team (Team B)', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
                        Row(
                          children: [
                            ChoiceChip(
                              label: const Text('⚔️ Select Team', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: !_useQrInviteMode,
                              selectedColor: AppTheme.primaryGold,
                              labelStyle: TextStyle(color: !_useQrInviteMode ? const Color(0xFF070710) : Colors.white70),
                              onSelected: (val) => setState(() => _useQrInviteMode = false),
                            ),
                            const SizedBox(width: 6),
                            ChoiceChip(
                              label: const Text('📷 QR Invite', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              selected: _useQrInviteMode,
                              selectedColor: const Color(0xFF00E676),
                              labelStyle: TextStyle(color: _useQrInviteMode ? const Color(0xFF070710) : Colors.white70),
                              onSelected: (val) => setState(() {
                                _useQrInviteMode = true;
                                _selectedTeamB = null;
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_useQrInviteMode)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1B14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4), width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.qr_code_scanner, color: Color(0xFF00E676), size: 22),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'QR / PIN Invite Mode',
                                        style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      SizedBox(width: 6),
                                      Text('• Match PIN 🔒', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                    ],
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'A Match PIN & QR Code will be generated for Opponent Captain to scan & join instantly.',
                                    style: TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        value: _selectedTeamB,
                        decoration: const InputDecoration(
                          labelText: 'Select Opponent Team *',
                          prefixIcon: Icon(Icons.sports_cricket, color: Color(0xFF00E676)),
                        ),
                        items: _teams
                            .where((t) => int.parse(t['id'].toString()) != _selectedTeamA)
                            .map<DropdownMenuItem<int>>((t) {
                          return DropdownMenuItem<int>(
                            value: int.parse(t['id'].toString()),
                            child: Row(
                              children: [
                                const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF00E676)),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    "${t['name']} (${t['city'] ?? 'Tamil Nadu'})",
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedTeamB = val),
                      ),
                    const SizedBox(height: 20),

                    // ── Ground & Ball Type ──
                    Text('Ground & Ball Details', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold)),
                    const SizedBox(height: 10),

                    // Location / District Picker
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await LocationPickerDialog.show(context);
                        if (mounted) {
                          setState(() {
                            _selectedDistrict = LocationService().currentDistrict.value;
                            _selectedState = LocationService().currentState.value;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGold.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on, color: AppTheme.primaryGold, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('District / Region *', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                  Text(
                                    '$_selectedDistrict, $_selectedState',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryGold),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryGold),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _venueController,
                      decoration: const InputDecoration(
                        labelText: 'Ground / Venue Name *',
                        prefixIcon: Icon(Icons.sports_cricket, color: AppTheme.primaryGold),
                      ),
                      validator: (val) => val == null || val.isEmpty ? 'Venue name required' : null,
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _cityAreaController,
                      decoration: const InputDecoration(
                        labelText: 'Area / Town / Locality (Optional)',
                        prefixIcon: Icon(Icons.map, color: AppTheme.primaryGold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _ballType,
                      decoration: const InputDecoration(
                        labelText: 'Ball Type *',
                        prefixIcon: Icon(Icons.sports_baseball, color: AppTheme.primaryGold),
                      ),
                      items: _ballTypes.entries.map((e) {
                        return DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _ballType = val ?? 'tennis_light'),
                    ),
                    const SizedBox(height: 16),

                    // ── Overs & Wickets ──
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _oversController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Overs Limit *',
                              prefixIcon: Icon(Icons.timer, color: AppTheme.primaryGold),
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
                              prefixIcon: Icon(Icons.sports_cricket, color: AppTheme.primaryGold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // ── Create / Generate Button ──
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGold,
                          foregroundColor: const Color(0xFF070710),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _isCreating ? null : _handleCreateMatch,
                        child: _isCreating
                            ? const CircularProgressIndicator(color: Color(0xFF070710))
                            : Text(
                                _isScheduled ? 'Schedule Match & Get QR 📅' : 'Generate Match & QR 🚀',
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
