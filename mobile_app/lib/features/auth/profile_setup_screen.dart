import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../main_navigation_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _jerseyController = TextEditingController();
  final ApiService _apiService = ApiService();

  String _battingStyle = 'Right-hand bat';
  String _bowlingStyle = 'Right-arm medium';
  String _role = 'All-Rounder';
  String _preferredFormat = 'T20';
  File? _imageFile;
  bool _isLoading = false;

  void _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final res = await _apiService.updateProfile(
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        battingStyle: _battingStyle,
        bowlingStyle: _bowlingStyle,
        role: _role,
        jerseyNumber: _jerseyController.text.trim(),
        preferredFormat: _preferredFormat,
        imagePath: _imageFile?.path,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (res['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile Setup Complete! Welcome to SB CricScore'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Update failed'),
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
      appBar: AppBar(
        title: Text(
          'Setup Cricket Profile',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF131326),
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null
                          ? const Icon(Icons.person, size: 50, color: AppTheme.primaryGold)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF070710)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Upload Profile Picture',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                validator: (v) => v == null || v.trim().isEmpty ? 'City is required' : null,
                decoration: const InputDecoration(
                  labelText: 'City / Location *',
                  prefixIcon: Icon(Icons.location_city, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Playing Role',
                  prefixIcon: Icon(Icons.sports_cricket, color: AppTheme.primaryGold),
                ),
                dropdownColor: const Color(0xFF131326),
                items: ['Batter', 'Bowler', 'All-Rounder', 'Wicket-Keeper Batter']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _role = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _battingStyle,
                decoration: const InputDecoration(
                  labelText: 'Batting Style',
                  prefixIcon: Icon(Icons.sports_baseball, color: AppTheme.primaryGold),
                ),
                dropdownColor: const Color(0xFF131326),
                items: ['Right-hand bat', 'Left-hand bat']
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _battingStyle = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _bowlingStyle,
                decoration: const InputDecoration(
                  labelText: 'Bowling Style',
                  prefixIcon: Icon(Icons.sports_cricket_outlined, color: AppTheme.primaryGold),
                ),
                dropdownColor: const Color(0xFF131326),
                items: [
                  'Right-arm fast',
                  'Right-arm medium',
                  'Right-arm off-break',
                  'Right-arm leg-break',
                  'Left-arm fast',
                  'Left-arm orthodox',
                ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _bowlingStyle = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _jerseyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jersey Number (Optional)',
                  prefixIcon: Icon(Icons.numbers, color: AppTheme.primaryGold),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF070710),
                          ),
                        )
                      : const Text('SAVE & GET STARTED'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
