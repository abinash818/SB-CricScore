import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';

class TeamDetailScreen extends StatefulWidget {
  final int teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _team;
  List<dynamic> _squad = [];

  final TextEditingController _playerNameController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _jerseyController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedRole = 'BAT';
  bool _isCaptain = false;
  String _battingStyle = 'Right Hand Bat';
  String _bowlingStyle = 'Right Arm Medium';

  List<dynamic> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _fetchTeamSquad();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchTeamSquad() async {
    try {
      final res = await _apiService.dio.get('/team_ops.php?action=get&team_id=${widget.teamId}');
      if (mounted) {
        setState(() {
          _team = res.data['team'];
          _squad = res.data['squad'] as List? ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchQueryChanged(String val, StateSetter setSheetState) {
    _searchDebounce?.cancel();
    if (val.trim().length < 2) {
      setSheetState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setSheetState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final res = await _apiService.searchPlayersByPhoneOrName(val.trim());
        if (mounted) {
          setSheetState(() {
            _searchResults = res['players'] as List? ?? [];
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setSheetState(() => _isSearching = false);
      }
    });
  }

  void _showAddPlayerSheet() {
    _playerNameController.clear();
    _mobileController.clear();
    _jerseyController.clear();
    _searchController.clear();
    _searchResults = [];
    _selectedRole = 'BAT';
    _isCaptain = false;
    _battingStyle = 'Right Hand Bat';
    _bowlingStyle = 'Right Arm Medium';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DefaultTabController(
          length: 2,
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  left: 20,
                  right: 20,
                  top: 20,
                ),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.65,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Add Squad Players 🏏',
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.gold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white70),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Tabs: Search vs Manual Register
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF131326),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TabBar(
                          indicatorColor: AppTheme.gold,
                          labelColor: AppTheme.gold,
                          unselectedLabelColor: Colors.white60,
                          tabs: const [
                            Tab(icon: Icon(Icons.phone_android, size: 18), text: 'Search Phone / Name'),
                            Tab(icon: Icon(Icons.person_add, size: 18), text: 'Register New'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: TabBarView(
                          children: [
                            // TAB 1: Search by Mobile Number or Name
                            Column(
                              children: [
                                TextField(
                                  controller: _searchController,
                                  onChanged: (v) => _onSearchQueryChanged(v, setSheetState),
                                  decoration: InputDecoration(
                                    labelText: 'Search by Mobile Number or Name',
                                    hintText: 'e.g. 9876543210 or Karthik',
                                    prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                                    suffixIcon: _isSearching
                                        ? const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold)),
                                          )
                                        : null,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _searchResults.isEmpty
                                      ? Center(
                                          child: Text(
                                            _searchController.text.length >= 2
                                                ? 'No matching players found.\nUse the "Register New" tab to add them!'
                                                : 'Enter 10-digit mobile number or name to search registered players',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _searchResults.length,
                                          itemBuilder: (context, idx) {
                                            final p = _searchResults[idx];
                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF16162E),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.white10),
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: AppTheme.gold.withOpacity(0.2),
                                                    child: Text(
                                                      p['name'] != null && p['name'].toString().isNotEmpty
                                                          ? p['name'][0].toUpperCase()
                                                          : 'P',
                                                      style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          p['name'] ?? 'Player',
                                                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                                                        ),
                                                        Text(
                                                          '📞 ${p['mobile'] ?? 'N/A'} • ${p['role'] ?? 'Player'}',
                                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                                        ),
                                                        if (p['batting_style'] != null)
                                                          Text(
                                                            '${p['batting_style']} • ${p['bowling_style'] ?? ''}',
                                                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppTheme.gold,
                                                      foregroundColor: Colors.black,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                    ),
                                                    onPressed: () async {
                                                      Navigator.pop(ctx);
                                                      await _addExistingPlayerToSquad(p);
                                                    },
                                                    child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),

                            // TAB 2: Register New Player
                            SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(
                                    controller: _playerNameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Player Name *',
                                      prefixIcon: Icon(Icons.person, color: AppTheme.gold),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _mobileController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Mobile Number (10 Digits)',
                                      prefixIcon: Icon(Icons.phone, color: AppTheme.gold),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: DropdownButtonFormField<String>(
                                          value: _selectedRole,
                                          decoration: const InputDecoration(labelText: 'Role'),
                                          dropdownColor: const Color(0xFF131326),
                                          items: ['BAT', 'BOWL', 'AR', 'WK']
                                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                              .toList(),
                                          onChanged: (v) => setSheetState(() => _selectedRole = v!),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: _jerseyController,
                                          keyboardType: TextInputType.number,
                                          decoration: const InputDecoration(labelText: 'Jersey #'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: _battingStyle,
                                    decoration: const InputDecoration(labelText: 'Batting Style'),
                                    dropdownColor: const Color(0xFF131326),
                                    items: ['Right Hand Bat', 'Left Hand Bat']
                                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                        .toList(),
                                    onChanged: (v) => setSheetState(() => _battingStyle = v!),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: _bowlingStyle,
                                    decoration: const InputDecoration(labelText: 'Bowling Style'),
                                    dropdownColor: const Color(0xFF131326),
                                    items: [
                                      'Right Arm Fast',
                                      'Right Arm Medium',
                                      'Right Arm Off-spin',
                                      'Right Arm Leg-spin',
                                      'Left Arm Fast',
                                      'Left Arm Spin'
                                    ].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                                    onChanged: (v) => setSheetState(() => _bowlingStyle = v!),
                                  ),
                                  const SizedBox(height: 6),
                                  CheckboxListTile(
                                    title: const Text('Make Team Captain 👑', style: TextStyle(color: Colors.white, fontSize: 13)),
                                    value: _isCaptain,
                                    activeColor: AppTheme.gold,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) => setSheetState(() => _isCaptain = val ?? false),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gold, foregroundColor: Colors.black),
                                      onPressed: () async {
                                        final name = _playerNameController.text.trim();
                                        if (name.isEmpty) return;
                                        Navigator.pop(ctx);
                                        await _registerNewPlayer(name);
                                      },
                                      child: const Text('REGISTER & ADD TO SQUAD 🚀', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _addExistingPlayerToSquad(Map<String, dynamic> player) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.captainRegisterPlayer(
        teamId: widget.teamId,
        name: player['name'] ?? 'Player',
        mobile: player['mobile'] ?? '',
        role: player['role'] ?? 'BAT',
        battingStyle: player['batting_style'] ?? 'Right Hand Bat',
        bowlingStyle: player['bowling_style'] ?? 'Right Arm Medium',
        jerseyNumber: player['jersey_number'] ?? '',
        skipOtp: true,
      );
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${player['name']} added to team!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to add'), backgroundColor: Colors.redAccent),
          );
        }
      }
      _fetchTeamSquad();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerNewPlayer(String name) async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.captainRegisterPlayer(
        teamId: widget.teamId,
        name: name,
        mobile: _mobileController.text.trim(),
        role: _selectedRole,
        battingStyle: _battingStyle,
        bowlingStyle: _bowlingStyle,
        jerseyNumber: _jerseyController.text.trim(),
        skipOtp: true,
      );
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name registered and added to squad!'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to register'), backgroundColor: Colors.redAccent),
          );
        }
      }
      _fetchTeamSquad();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          _team?['name'] ?? 'Team Squad',
          style: GoogleFonts.outfit(color: AppTheme.gold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.gold,
        foregroundColor: const Color(0xFF070710),
        icon: const Icon(Icons.person_add),
        label: Text('ADD PLAYER', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        onPressed: _showAddPlayerSheet,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Team Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.gold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppTheme.gold.withOpacity(0.2),
                    child: const Icon(Icons.shield, color: AppTheme.gold, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _team?['name'] ?? 'Team',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          '${_team?['short_name'] ?? 'TEAM'} • ${_team?['city'] ?? 'Tamil Nadu'}',
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Squad Size: ${_squad.length} Players (Unlimited)',
                          style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Squad Players (${_squad.length})',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 12),

            if (_squad.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.group_outlined, size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      'No players added yet.\nTap "ADD PLAYER" to search by mobile or register players!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white54),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _squad.length,
                itemBuilder: (context, index) {
                  final player = _squad[index];
                  final isCapt = (player['is_captain'] == 1);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isCapt ? AppTheme.gold.withOpacity(0.1) : AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isCapt ? AppTheme.gold : Colors.white10),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCapt ? AppTheme.gold : const Color(0xFF1E1E38),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isCapt ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              player['name'] ?? 'Player',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                          if (isCapt)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                              child: const Text('👑 CAPTAIN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '📞 ${player['mobile'] ?? 'N/A'} • ${player['role'] ?? 'BAT'} • ${player['batting_style'] ?? 'Right Hand Bat'}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
