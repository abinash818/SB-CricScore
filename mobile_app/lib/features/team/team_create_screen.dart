import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import 'team_detail_screen.dart';

class TeamCreateScreen extends StatefulWidget {
  final int? tournamentId;
  const TeamCreateScreen({super.key, this.tournamentId});

  @override
  State<TeamCreateScreen> createState() => _TeamCreateScreenState();
}

class _TeamCreateScreenState extends State<TeamCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _shortNameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Captain / Creator details
  final TextEditingController _creatorNameController = TextEditingController();
  final TextEditingController _creatorMobileController = TextEditingController();
  final TextEditingController _creatorJerseyController = TextEditingController(text: '7');
  String _creatorRole = 'All-Rounder';
  String _creatorBattingStyle = 'Right Hand Bat';
  String _creatorBowlingStyle = 'Right Arm Medium';
  bool _addMeAsCaptain = true;

  final ApiService _apiService = ApiService();

  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  bool? _isNameAvailable;
  String _availabilityMessage = '';
  Timer? _debounceTimer;

  String _selectedIcon = 'shield';
  final List<Map<String, dynamic>> _iconOptions = [
    {'key': 'shield', 'icon': Icons.shield, 'label': 'Shield'},
    {'key': 'trophy', 'icon': Icons.emoji_events, 'label': 'Trophy'},
    {'key': 'fire', 'icon': Icons.local_fire_department, 'label': 'Fire'},
    {'key': 'flash', 'icon': Icons.bolt, 'label': 'Thunder'},
    {'key': 'star', 'icon': Icons.star, 'label': 'Star'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final res = await _apiService.getProfile();
      if (res['success'] == true && res['user'] != null) {
        final u = res['user'];
        setState(() {
          if (_creatorNameController.text.isEmpty && u['name'] != null) {
            _creatorNameController.text = u['name'];
          }
          if (_creatorMobileController.text.isEmpty && u['phone'] != null) {
            _creatorMobileController.text = u['phone'];
          }
          if (_cityController.text.isEmpty && u['city'] != null) {
            _cityController.text = u['city'];
          }
          if (u['role'] != null) _creatorRole = u['role'];
          if (u['batting_style'] != null) _creatorBattingStyle = u['batting_style'];
          if (u['bowling_style'] != null) _creatorBowlingStyle = u['bowling_style'];
          if (u['jersey_number'] != null && u['jersey_number'].toString().isNotEmpty) {
            _creatorJerseyController.text = u['jersey_number'].toString();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _nameController.dispose();
    _shortNameController.dispose();
    _cityController.dispose();
    _creatorNameController.dispose();
    _creatorMobileController.dispose();
    _creatorJerseyController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    _debounceTimer?.cancel();

    // Auto-generate short name
    final words = val.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      _shortNameController.text = (words[0][0] + words[1][0]).toUpperCase();
    } else if (val.trim().length >= 3) {
      _shortNameController.text = val.trim().substring(0, 3).toUpperCase();
    }

    if (val.trim().length < 2) {
      setState(() {
        _isNameAvailable = null;
        _availabilityMessage = '';
        _isCheckingAvailability = false;
      });
      return;
    }

    setState(() {
      _isCheckingAvailability = true;
      _availabilityMessage = 'Checking availability...';
    });

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final res = await _apiService.checkTeamNameAvailability(val.trim()).timeout(const Duration(milliseconds: 2500));
        if (mounted) {
          setState(() {
            _isCheckingAvailability = false;
            _isNameAvailable = (res['available'] == true);
            _availabilityMessage = res['message'] ?? (_isNameAvailable! ? 'Team name is available! ✅' : 'Name already taken! ❌');
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _isCheckingAvailability = false;
            _isNameAvailable = true; // Non-blocking fallback
            _availabilityMessage = '';
          });
        }
      }
    });
  }

  void _handleCreateTeam() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isNameAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an available team name!'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String creatorName = _creatorNameController.text.trim().isNotEmpty
          ? _creatorNameController.text.trim()
          : 'Team Captain';

      final res = await _apiService.createUserTeam(
        name: _nameController.text.trim(),
        shortName: _shortNameController.text.trim(),
        city: _cityController.text.trim(),
        icon: _selectedIcon,
        tournamentId: widget.tournamentId ?? 1,
        addCaptain: _addMeAsCaptain,
        creatorName: creatorName,
        creatorMobile: _creatorMobileController.text.trim(),
        creatorRole: _creatorRole,
        creatorBattingStyle: _creatorBattingStyle,
        creatorBowlingStyle: _creatorBowlingStyle,
        creatorJersey: _creatorJerseyController.text.trim().isNotEmpty ? _creatorJerseyController.text.trim() : '7',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Team created with you as Captain! 🎉'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          
          final newTeamId = res['team_id'] ?? 0;
          if (newTeamId > 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => TeamDetailScreen(teamId: newTeamId)),
            );
          } else {
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Failed to create team'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.errorRed),
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
          'Create Team & Squad 🛡️',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🛡️ Team Details Section
              Text(
                'Team Information',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 14),

              // Team Name Field with Live Availability Indicator
              TextFormField(
                controller: _nameController,
                onChanged: _onNameChanged,
                validator: (v) => v == null || v.trim().isEmpty ? 'Team name is required' : null,
                decoration: InputDecoration(
                  labelText: 'Team Full Name *',
                  hintText: 'e.g. Chennai Super Kings, Kovai Strikers',
                  prefixIcon: const Icon(Icons.shield_outlined, color: AppTheme.primaryGold),
                  suffixIcon: _isCheckingAvailability
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryGold),
                          ),
                        )
                      : (_isNameAvailable == null
                          ? null
                          : Icon(
                              _isNameAvailable! ? Icons.check_circle : Icons.cancel,
                              color: _isNameAvailable! ? Colors.greenAccent : AppTheme.errorRed,
                            )),
                ),
              ),
              if (_availabilityMessage.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Text(
                    _availabilityMessage,
                    style: TextStyle(
                      color: _isNameAvailable == true
                          ? Colors.greenAccent
                          : (_isNameAvailable == false ? AppTheme.errorRed : AppTheme.primaryGold),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Short Name & City Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _shortNameController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Short Name (CSK)',
                        hintText: 'e.g. CSK',
                        prefixIcon: Icon(Icons.text_fields, color: AppTheme.primaryGold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City / Ground',
                        hintText: 'e.g. Chennai',
                        prefixIcon: Icon(Icons.location_city, color: AppTheme.primaryGold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Team Badge / Logo Selector
              Text(
                'Team Emblem',
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _iconOptions.map((opt) {
                  final isSel = (_selectedIcon == opt['key']);
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = opt['key']),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryGold.withValues(alpha: 0.2) : const Color(0xFF131326),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppTheme.primaryGold : Colors.white10,
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(opt['icon'], color: isSel ? AppTheme.primaryGold : Colors.white60, size: 24),
                          const SizedBox(height: 3),
                          Text(
                            opt['label'],
                            style: TextStyle(
                              color: isSel ? AppTheme.primaryGold : Colors.white60,
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 👑 Captain / Owner Inclusion Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryGold.withValues(alpha: 0.12),
                      const Color(0xFF131326),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryGold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              'Team Leader / Captain',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryGold,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _addMeAsCaptain,
                          activeThumbColor: AppTheme.primaryGold,
                          onChanged: (v) => setState(() => _addMeAsCaptain = v),
                        ),
                      ],
                    ),
                    const Text(
                      'Automatically add you as the Team Captain & Squad Member.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    if (_addMeAsCaptain) ...[
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _creatorNameController,
                        validator: (v) => _addMeAsCaptain && (v == null || v.trim().isEmpty) ? 'Captain name is required' : null,
                        decoration: const InputDecoration(
                          labelText: 'Captain Name *',
                          prefixIcon: Icon(Icons.person, color: AppTheme.primaryGold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _creatorMobileController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number',
                                prefixIcon: Icon(Icons.phone, color: AppTheme.primaryGold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _creatorJerseyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Jersey #',
                                prefixIcon: Icon(Icons.tag, color: AppTheme.primaryGold),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: ['All-Rounder', 'Batsman', 'Bowler', 'Wicket Keeper'].contains(_creatorRole) ? _creatorRole : 'All-Rounder',
                        decoration: const InputDecoration(
                          labelText: 'Playing Role',
                          prefixIcon: Icon(Icons.sports_cricket, color: AppTheme.primaryGold),
                        ),
                        dropdownColor: const Color(0xFF131326),
                        items: const [
                          DropdownMenuItem(value: 'All-Rounder', child: Text('All-Rounder')),
                          DropdownMenuItem(value: 'Batsman', child: Text('Batsman')),
                          DropdownMenuItem(value: 'Bowler', child: Text('Bowler')),
                          DropdownMenuItem(value: 'Wicket Keeper', child: Text('Wicket Keeper')),
                        ],
                        onChanged: (v) => setState(() => _creatorRole = v!),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Create Team Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: const Color(0xFF070710),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleCreateTeam,
                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.rocket_launch, size: 20),
                  label: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF070710)),
                        )
                      : Text(
                          'CREATE TEAM & MANAGE SQUAD 🚀',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
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
