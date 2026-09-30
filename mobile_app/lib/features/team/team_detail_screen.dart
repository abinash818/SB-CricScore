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
                            Tab(icon: Icon(Icons.search, size: 18), text: 'Search Mobile / Name'),
                            Tab(icon: Icon(Icons.person_add, size: 18), text: 'Quick Add (Manual)'),
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
                                      labelText: 'Mobile Number (Optional)',
                                      hintText: 'Enter 10 digits or leave empty',
                                      helperText: 'Optional: For searching and player verification',
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
            SnackBar(content: Text('${player['name']} added to team! 🎉'), backgroundColor: Colors.green),
          );
          _fetchTeamSquad();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to add player'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding player: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
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
            SnackBar(content: Text('$name registered and added to squad! 🎉'), backgroundColor: Colors.green),
          );
          _fetchTeamSquad();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to register player'), backgroundColor: Colors.redAccent),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error registering player: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _handleSetClanRole(int playerId, String playerName, String role) async {
    try {
      final res = await _apiService.setClanRole(widget.teamId, playerId, role);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Role updated!'), backgroundColor: Colors.green),
          );
          _fetchTeamSquad();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update role: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _handleSetCaptain(int playerId, String playerName) async {
    try {
      final res = await _apiService.setCaptain(widget.teamId, playerId);
      if (mounted) {
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$playerName is now the Team Leader / Captain! 👑'), backgroundColor: Colors.green),
          );
          _fetchTeamSquad();
        }
      }
    } catch (_) {}
  }

  Future<void> _handleRemovePlayer(int playerId, String playerName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131326),
        title: Text('Remove Player?', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to remove $playerName from this squad?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.white60))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _apiService.removePlayer(widget.teamId, playerId);
        if (mounted) {
          if (res['success'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$playerName removed from squad'), backgroundColor: Colors.orange),
            );
            _fetchTeamSquad();
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.gold)),
      );
    }

    final teamName = _team?['name'] ?? 'Team Squad';
    final tournId = _team?['tournament_id'] ?? 1;
    final inviteLink = 'https://sbastro.com/tournament/pages/register_player.php?team_id=${widget.teamId}&tour_id=$tournId';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          teamName,
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
                border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
                        child: const Icon(Icons.shield, color: AppTheme.gold, size: 32),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teamName,
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Text(
                              '${_team?['short_name'] ?? 'TEAM'} • ${_team?['city'] ?? 'Tamil Nadu'}',
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Squad Size: ${_squad.length} Players',
                              style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Share WhatsApp Registration Link Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text(
                        'SHARE SQUAD REGISTRATION LINK 📲',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      onPressed: () {
                        final shareText = '🏏 Join our team *$teamName* on SB CricScore!\n\nRegister yourself into our squad with your photo here:\n$inviteLink';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Registration Link Copied!\n$shareText'),
                            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
                            backgroundColor: const Color(0xFF25D366),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Squad Players (${_squad.length})',
                  style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppTheme.gold),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Player', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _showAddPlayerSheet,
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_squad.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.group_outlined, size: 48, color: Colors.white24),
                    const SizedBox(height: 12),
                    Text(
                      'No players in squad yet.\nTap "ADD PLAYER" to search or register players!',
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
                  final String teamRole = (player['team_role'] ?? ((player['is_captain'] == 1 || player['is_captain'] == '1') ? 'leader' : 'member')).toString().toLowerCase();
                  final bool isLeader = (teamRole == 'leader' || player['is_captain'] == 1 || player['is_captain'] == '1');
                  final bool isCoLeader = (teamRole == 'co_leader');
                  final playerId = int.tryParse(player['id'].toString()) ?? 0;
                  final pName = player['name'] ?? 'Player';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isLeader
                          ? AppTheme.gold.withValues(alpha: 0.12)
                          : isCoLeader
                              ? Colors.purpleAccent.withValues(alpha: 0.1)
                              : AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLeader
                            ? AppTheme.gold
                            : isCoLeader
                                ? Colors.purpleAccent.withValues(alpha: 0.6)
                                : Colors.white10,
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isLeader
                            ? AppTheme.gold
                            : isCoLeader
                                ? Colors.purpleAccent
                                : const Color(0xFF1E1E38),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: (isLeader || isCoLeader) ? Colors.black : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              pName,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ),
                          if (isLeader)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                              child: const Text('👑 LEADER', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10)),
                            )
                          else if (isCoLeader)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.purpleAccent, borderRadius: BorderRadius.circular(4)),
                              child: const Text('⭐ CO-LEADER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '📞 ${player['mobile'] ?? 'N/A'} • ${player['role'] ?? 'BAT'} • #${player['jersey_number'] ?? '-'}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white60),
                        color: const Color(0xFF1E1E38),
                        onSelected: (val) {
                          if (val == 'leader') {
                            _handleSetCaptain(playerId, pName);
                          } else if (val == 'co_leader') {
                            _handleSetClanRole(playerId, pName, 'co_leader');
                          } else if (val == 'member') {
                            _handleSetClanRole(playerId, pName, 'member');
                          } else if (val == 'remove') {
                            _handleRemovePlayer(playerId, pName);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (!isLeader)
                            const PopupMenuItem(
                              value: 'leader',
                              child: Row(
                                children: [
                                  Icon(Icons.star, color: Colors.amber, size: 18),
                                  SizedBox(width: 8),
                                  Text('Make Team Leader 👑', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          if (!isCoLeader)
                            const PopupMenuItem(
                              value: 'co_leader',
                              child: Row(
                                children: [
                                  Icon(Icons.military_tech, color: Colors.purpleAccent, size: 18),
                                  SizedBox(width: 8),
                                  Text('Promote to Co-Leader ⭐', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          if (isLeader || isCoLeader)
                            const PopupMenuItem(
                              value: 'member',
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline, color: Colors.white70, size: 18),
                                  SizedBox(width: 8),
                                  Text('Set as Regular Member 🏏', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                SizedBox(width: 8),
                                Text('Remove Player', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
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
