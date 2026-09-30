import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../auth/phone_login_screen.dart';
import '../team/team_create_screen.dart';
import '../team/team_detail_screen.dart';

class PlayerProfileScreen extends StatefulWidget {
  final int? playerId;
  const PlayerProfileScreen({super.key, this.playerId});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  String _activeTab = 'batting'; // 'batting', 'bowling', 'teams', 'form'

  @override
  void initState() {
    super.initState();
    _fetchPlayerProfile();
  }

  Future<void> _fetchPlayerProfile() async {
    try {
      final query = widget.playerId != null ? '?player_id=${widget.playerId}' : '';
      final res = await _apiService.dio.get('/player_profile_get.php$query');
      if (mounted) {
        setState(() {
          _profileData = res.data;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditProfileSheet(Map<String, dynamic> player) {
    final nameCtrl = TextEditingController(text: player['name'] ?? '');
    final cityCtrl = TextEditingController(text: player['city'] ?? '');
    final jerseyCtrl = TextEditingController(text: player['jersey_number']?.toString() ?? '');

    // Normalize Role
    String normalizeRole(dynamic raw) {
      if (raw == null) return 'All-Rounder';
      final r = raw.toString().trim().toUpperCase();
      if (r == 'BAT' || r == 'BATSMAN' || r.contains('BATTER')) return 'Batsman';
      if (r == 'BOWL' || r == 'BOWLER' || r.contains('BOWLER')) return 'Bowler';
      if (r == 'WK' || r.contains('WICKET') || r.contains('KEEPER')) return 'Wicketkeeper';
      return 'All-Rounder';
    }

    // Normalize Batting Style
    String normalizeBatting(dynamic raw) {
      if (raw == null) return 'Right Hand Bat';
      final s = raw.toString().trim().toLowerCase();
      if (s.contains('left') || s.contains('lhb')) return 'Left Hand Bat';
      return 'Right Hand Bat';
    }

    // Normalize Bowling Style
    String normalizeBowling(dynamic raw) {
      final valid = [
        'Right Arm Fast',
        'Right Arm Medium',
        'Right Arm Off Break',
        'Right Arm Leg Break',
        'Left Arm Fast',
        'Left Arm Orthodox',
        'Left Arm Chinaman'
      ];
      if (raw == null) return 'Right Arm Medium';
      final str = raw.toString().trim();
      if (valid.contains(str)) return str;
      if (str.toLowerCase().contains('fast')) return 'Right Arm Fast';
      if (str.toLowerCase().contains('spin') || str.toLowerCase().contains('break')) return 'Right Arm Off Break';
      if (str.toLowerCase().contains('left')) return 'Left Arm Fast';
      return 'Right Arm Medium';
    }

    String selectedRole = normalizeRole(player['role']);
    String battingStyle = normalizeBatting(player['batting_style']);
    String bowlingStyle = normalizeBowling(player['bowling_style']);
    XFile? pickedImage;
    Uint8List? pickedImageBytes;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Profile ✏️',
                          style: GoogleFonts.outfit(color: AppTheme.gold, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Avatar + Photo Picker
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppTheme.gold.withValues(alpha: 0.2),
                            backgroundImage: pickedImageBytes != null
                                ? MemoryImage(pickedImageBytes!)
                                : (player['profile_pic'] != null && player['profile_pic'].toString().isNotEmpty
                                    ? NetworkImage(ApiService.getImageUrl(player['profile_pic'].toString())) as ImageProvider
                                    : null),
                            child: (pickedImageBytes == null && (player['profile_pic'] == null || player['profile_pic'].toString().isEmpty))
                                ? Text(
                                    ((player['name'] as String?) ?? 'P')[0].toUpperCase(),
                                    style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.gold),
                                  )
                                : null,

                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () async {
                                final picker = ImagePicker();
                                final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 600, maxHeight: 600, imageQuality: 80);
                                if (img != null) {
                                  final bytes = await img.readAsBytes();
                                  setSheetState(() {
                                    pickedImage = img;
                                    pickedImageBytes = bytes;
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: AppTheme.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.black, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text('Tap camera icon to change photo 📸', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Player Full Name *',
                        prefixIcon: Icon(Icons.person, color: AppTheme.gold),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Role + Jersey #
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            value: ['All-Rounder', 'Batsman', 'Bowler', 'Wicketkeeper'].contains(selectedRole) ? selectedRole : 'All-Rounder',
                            decoration: const InputDecoration(labelText: 'Playing Role'),
                            dropdownColor: const Color(0xFF131326),
                            items: const [
                              DropdownMenuItem(value: 'All-Rounder', child: Text('🏏 All-Rounder')),
                              DropdownMenuItem(value: 'Batsman', child: Text('🏏 Batsman')),
                              DropdownMenuItem(value: 'Bowler', child: Text('⚡ Bowler')),
                              DropdownMenuItem(value: 'Wicketkeeper', child: Text('🧤 Wicketkeeper')),
                            ],
                            onChanged: (v) => setSheetState(() => selectedRole = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: jerseyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Jersey #',
                              prefixIcon: Icon(Icons.tag, color: AppTheme.gold),
                              hintText: 'e.g. 7',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Batting Style
                    DropdownButtonFormField<String>(
                      value: ['Right Hand Bat', 'Left Hand Bat'].contains(battingStyle) ? battingStyle : 'Right Hand Bat',
                      decoration: const InputDecoration(labelText: 'Batting Style'),
                      dropdownColor: const Color(0xFF131326),
                      items: const [
                        DropdownMenuItem(value: 'Right Hand Bat', child: Text('Right Hand Bat')),
                        DropdownMenuItem(value: 'Left Hand Bat', child: Text('Left Hand Bat')),
                      ],
                      onChanged: (v) => setSheetState(() => battingStyle = v!),
                    ),
                    const SizedBox(height: 12),

                    // Bowling Style
                    DropdownButtonFormField<String>(
                      value: ['Right Arm Fast', 'Right Arm Medium', 'Right Arm Off Break', 'Right Arm Leg Break', 'Left Arm Fast', 'Left Arm Orthodox', 'Left Arm Chinaman'].contains(bowlingStyle) ? bowlingStyle : 'Right Arm Medium',
                      decoration: const InputDecoration(labelText: 'Bowling Style'),
                      dropdownColor: const Color(0xFF131326),
                      items: const [
                        DropdownMenuItem(value: 'Right Arm Fast', child: Text('Right Arm Fast (Pace)')),
                        DropdownMenuItem(value: 'Right Arm Medium', child: Text('Right Arm Medium')),
                        DropdownMenuItem(value: 'Right Arm Off Break', child: Text('Right Arm Off Break (Spin)')),
                        DropdownMenuItem(value: 'Right Arm Leg Break', child: Text('Right Arm Leg Break (Spin)')),
                        DropdownMenuItem(value: 'Left Arm Fast', child: Text('Left Arm Fast')),
                        DropdownMenuItem(value: 'Left Arm Orthodox', child: Text('Left Arm Orthodox (Spin)')),
                        DropdownMenuItem(value: 'Left Arm Chinaman', child: Text('Left Arm Chinaman (Spin)')),
                      ],
                      onChanged: (v) => setSheetState(() => bowlingStyle = v!),
                    ),
                    const SizedBox(height: 12),

                    // City / Ground
                    TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City / Hometown',
                        prefixIcon: Icon(Icons.location_city, color: AppTheme.gold),
                        hintText: 'e.g. Coimbatore, Chennai',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving ? null : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Player name is required')),
                            );
                            return;
                          }

                          setSheetState(() => isSaving = true);
                          try {
                            final res = await _apiService.updateProfile(
                              name: name,
                              city: cityCtrl.text.trim(),
                              role: selectedRole,
                              jerseyNumber: jerseyCtrl.text.trim(),
                              battingStyle: battingStyle,
                              bowlingStyle: bowlingStyle,
                              imagePath: pickedImage?.path,
                              imageBytes: pickedImageBytes,
                              imageName: pickedImage?.name,
                            );

                            if (mounted) {
                              Navigator.pop(ctx);
                              if (res['success'] == true) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profile updated successfully! 🎉'), backgroundColor: Colors.green),
                                );
                                _fetchPlayerProfile();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(res['message'] ?? 'Failed to update profile'), backgroundColor: Colors.redAccent),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              setSheetState(() => isSaving = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.redAccent),
                              );
                            }
                          }
                        },
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                            : Text(
                                'SAVE PROFILE CHANGES 💾',
                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGold)),
      );
    }

    final player = _profileData?['player'] ?? {};
    final batting = _profileData?['batting_stats'] ?? {};
    final bowling = _profileData?['bowling_stats'] ?? {};
    final recentForm = _profileData?['recent_form'] as List? ?? [];

    if (player.isEmpty && widget.playerId == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Player Profile 🏏',
            style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppTheme.background,
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGold.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.person_outline, size: 56, color: AppTheme.primaryGold),
                ),
                const SizedBox(height: 24),
                Text(
                  'Guest Mode',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Log in with your mobile number to view your cricket profile, batting & bowling stats, and tournament history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
                      );
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('LOGIN / REGISTER'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Player Profile 🏏',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Edit Profile',
            icon: const Icon(Icons.edit_note, color: AppTheme.primaryGold, size: 28),
            onPressed: () => _showEditProfileSheet(player),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchPlayerProfile,
        color: AppTheme.primaryGold,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 👤 Player Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                          backgroundImage: player['profile_pic'] != null && player['profile_pic'].toString().isNotEmpty
                              ? NetworkImage(ApiService.getImageUrl(player['profile_pic'].toString()))
                              : null,
                          child: (player['profile_pic'] == null || player['profile_pic'].toString().isEmpty)
                              ? Text(
                                  ((player['name'] as String?) ?? 'P')[0].toUpperCase(),
                                  style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                                )
                              : null,

                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () => _showEditProfileSheet(player),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryGold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.black, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          player['name'] ?? 'Cricketer',
                          style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        if (player['jersey_number'] != null && player['jersey_number'].toString().isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primaryGold, width: 1),
                            ),
                            child: Text(
                              '#${player['jersey_number']}',
                              style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${player['city'] ?? 'Tamil Nadu'} • ${player['role'] ?? 'All-Rounder'}',
                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGold,
                        side: const BorderSide(color: AppTheme.primaryGold),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit Profile & Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: () => _showEditProfileSheet(player),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildChip(player['batting_style'] ?? 'Right-hand bat'),
                        const SizedBox(width: 8),
                        _buildChip(player['bowling_style'] ?? 'Right-arm medium'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 📱 Touch Tabs Bar (Batting / Bowling / Teams / Form)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D1C),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildTouchTabItem('batting', '🏏 Batting', Icons.sports_cricket),
                    _buildTouchTabItem('bowling', '🎯 Bowling', Icons.sports_baseball),
                    _buildTouchTabItem('teams', '🛡️ Teams', Icons.shield),
                    _buildTouchTabItem('form', '📈 Form', Icons.trending_up),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 🏏 TAB 1: BATTING CAREER
              if (_activeTab == 'batting') ...[
                // Hero Highlights
                Row(
                  children: [
                    Expanded(child: _buildHeroStatBox('RUNS', '${batting['runs'] ?? 0}', AppTheme.primaryGold)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHeroStatBox('HS', '${batting['highest_score'] ?? 0}', const Color(0xFF06B6D4))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHeroStatBox('AVG', '${batting['average'] ?? '0.00'}', const Color(0xFF10B981))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHeroStatBox('S/R', '${batting['strike_rate'] ?? '0.00'}', const Color(0xFFF59E0B))),
                  ],
                ),
                const SizedBox(height: 16),

                // Detailed Batting Grid
                _sectionTitle('DETAILED BATTING STATS'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      _statCell('Matches', '${batting['matches'] ?? player['total_matches'] ?? 0}'),
                      _statCell('Innings', '${batting['innings'] ?? 0}'),
                      _statCell('Not Outs', '${batting['not_outs'] ?? 0}'),
                      _statCell('Balls Faced', '${batting['balls'] ?? 0}'),
                      _statCell('50s / 100s', '${batting['fifties'] ?? 0} / ${batting['hundreds'] ?? 0}', isHighlight: true),
                      _statCell('Fours (4s)', '${batting['fours'] ?? 0}'),
                      _statCell('Sixes (6s)', '${batting['sixes'] ?? 0}'),
                      _statCell('Boundary Runs', '${((batting['fours'] ?? 0) * 4) + ((batting['sixes'] ?? 0) * 6)}'),
                      _statCell('Runs / Inn', (batting['innings'] ?? 0) > 0 ? ((batting['runs'] ?? 0) / (batting['innings'] ?? 1)).toStringAsFixed(1) : '0.0'),
                    ],
                  ),
                ),
              ],

              // 🎯 TAB 2: BOWLING CAREER
              if (_activeTab == 'bowling') ...[
                // Hero Highlights
                Row(
                  children: [
                    Expanded(child: _buildHeroStatBox('WICKETS', '${bowling['wickets'] ?? 0}', const Color(0xFFF43F5E))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHeroStatBox('BBI', '${bowling['best_bowling'] ?? '-'}', AppTheme.primaryGold)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHeroStatBox('ECONOMY', '${bowling['economy'] ?? '0.00'}', const Color(0xFF10B981))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildHeroStatBox('AVG', '${bowling['average'] ?? '0.00'}', const Color(0xFF06B6D4))),
                  ],
                ),
                const SizedBox(height: 16),

                // Detailed Bowling Grid
                _sectionTitle('DETAILED BOWLING STATS'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.5,
                    children: [
                      _statCell('Matches', '${bowling['matches'] ?? player['total_matches'] ?? 0}'),
                      _statCell('Innings', '${bowling['innings'] ?? 0}'),
                      _statCell('Overs', '${bowling['overs'] ?? '0.0'}'),
                      _statCell('Legal Balls', '${bowling['legal_balls'] ?? 0}'),
                      _statCell('Strike Rate', '${bowling['strike_rate'] ?? '0.0'}'),
                      _statCell('3w / 5w Hauls', '${bowling['three_wickets'] ?? 0} / ${bowling['five_wickets'] ?? 0}', isHighlight: true),
                      _statCell('Runs Given', '${bowling['runs'] ?? 0}'),
                      _statCell('Wides (WD)', '${bowling['wides'] ?? 0}'),
                      _statCell('No Balls (NB)', '${bowling['no_balls'] ?? 0}'),
                    ],
                  ),
                ),
              ],

              // 🛡️ TAB 3: MY TEAMS & SQUADS
              if (_activeTab == 'teams') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _sectionTitle('MY TEAMS & SQUADS 🛡️'),
                    TextButton.icon(
                      style: TextButton.styleFrom(foregroundColor: AppTheme.primaryGold),
                      icon: const Icon(Icons.add_circle, size: 18),
                      label: const Text('Create Team', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        final created = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TeamCreateScreen()),
                        );
                        if (created == true) {
                          _fetchPlayerProfile();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FutureBuilder<Map<String, dynamic>>(
                  future: _apiService.getMyTeams(
                    ownerId: widget.playerId == null
                        ? (player['user_id'] != null
                            ? int.tryParse(player['user_id'].toString())
                            : (player['id'] != null ? int.tryParse(player['id'].toString()) : null))
                        : null,
                    playerId: widget.playerId,
                    mobile: player['mobile']?.toString() ?? player['phone']?.toString(),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: AppTheme.primaryGold)));
                    }
                    final teams = snapshot.data?['teams'] as List? ?? [];
                    if (teams.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.shield_outlined, color: Colors.white38, size: 36),
                            const SizedBox(height: 8),
                            const Text('No teams created yet.', style: TextStyle(color: Colors.white70)),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGold, foregroundColor: Colors.black),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('CREATE YOUR TEAM NOW'),
                              onPressed: () async {
                                final created = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const TeamCreateScreen()),
                                );
                                if (created == true) setState(() {});
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: teams.length,
                      itemBuilder: (context, index) {
                        final t = teams[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryGold.withOpacity(0.3)),
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: t['id'])),
                              );
                            },
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                              child: const Icon(Icons.shield, color: AppTheme.primaryGold),
                            ),
                            title: Text(
                              t['name'] ?? 'Team',
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${t['short_name'] ?? 'TEAM'} • ${t['city'] ?? 'Tamil Nadu'} • ${t['player_count'] ?? 0} Players',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.primaryGold),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],

              // 📈 TAB 4: RECENT FORM
              if (_activeTab == 'form') ...[
                _sectionTitle('RECENT INNINGS FORM'),
                const SizedBox(height: 12),
                if (recentForm.isNotEmpty) ...[
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentForm.length,
                      itemBuilder: (context, index) {
                        final runs = recentForm[index];
                        final isFifty = runs >= 50;
                        return Container(
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          decoration: BoxDecoration(
                            color: isFifty ? AppTheme.primaryGold.withOpacity(0.2) : AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isFifty ? AppTheme.primaryGold : AppTheme.cardBorder),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$runs',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  color: isFifty ? AppTheme.primaryGold : AppTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Runs',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isFifty ? AppTheme.primaryGold : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Center(
                      child: Text('No recent match innings recorded yet.', style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTouchTabItem(String key, String label, IconData icon) {
    final isSelected = _activeTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGold : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? const Color(0xFF070710) : AppTheme.textMuted,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? const Color(0xFF070710) : AppTheme.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStatBox(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppTheme.textMuted,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryGold,
        letterSpacing: 1.1,
      ),
    );
  }

  Widget _buildChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF131326),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
      ),
    );
  }

  Widget _statCell(String label, String value, {bool isHighlight = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isHighlight ? AppTheme.primaryGold : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 10.5),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
