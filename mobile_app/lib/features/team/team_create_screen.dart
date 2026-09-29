import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';

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
  void dispose() {
    _debounceTimer?.cancel();
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
      final res = await _apiService.createUserTeam(
        name: _nameController.text.trim(),
        shortName: _shortNameController.text.trim(),
        city: _cityController.text.trim(),
        icon: _selectedIcon,
        tournamentId: widget.tournamentId ?? 1,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Team created successfully! 🎉'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          Navigator.pop(context, true);
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
          'Create My Team 🛡️',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Team Details',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Team Name Field with Live Availability Indicator
              TextFormField(
                controller: _nameController,
                onChanged: _onNameChanged,
                validator: (v) => v == null || v.trim().isEmpty ? 'Team name is required' : null,
                decoration: InputDecoration(
                  labelText: 'Team Full Name *',
                  hintText: 'e.g. Chennai Super Kings, Kovai Warriors',
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
              const SizedBox(height: 16),

              // Short Name
              TextFormField(
                controller: _shortNameController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Short Name / Prefix (e.g. CSK, FCC)',
                  hintText: 'e.g. CSK',
                  prefixIcon: Icon(Icons.text_fields, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 16),

              // City / Town
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'City / Town / Ground Location',
                  hintText: 'e.g. Chennai, Coimbatore, Salem',
                  prefixIcon: Icon(Icons.location_city, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 20),

              // Team Badge / Logo Selector
              Text(
                'Select Team Emblem',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _iconOptions.map((opt) {
                  final isSel = (_selectedIcon == opt['key']);
                  return InkWell(
                    onTap: () => setState(() => _selectedIcon = opt['key']),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryGold.withOpacity(0.2) : const Color(0xFF131326),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppTheme.primaryGold : Colors.white10,
                          width: isSel ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(opt['icon'], color: isSel ? AppTheme.primaryGold : Colors.white60, size: 28),
                          const SizedBox(height: 4),
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
              const SizedBox(height: 40),

              // Create Team Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGold,
                    foregroundColor: const Color(0xFF070710),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _handleCreateTeam,
                  child: _isLoading
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
