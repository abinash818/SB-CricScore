import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import 'team_create_screen.dart';
import 'team_detail_screen.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _teams = [];

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final res = await _apiService.dio.get('/team_ops.php?action=list');
      if (mounted) {
        setState(() {
          _teams = res.data['teams'] as List? ?? [];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Teams Directory 🛡️',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: const Color(0xFF070710),
        icon: const Icon(Icons.add_moderator),
        label: Text('CREATE TEAM', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TeamCreateScreen()),
          );
          if (res == true) {
            _fetchTeams();
          }
        },
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              onRefresh: _fetchTeams,
              color: AppTheme.primaryGold,
              child: _teams.isEmpty
                  ? const Center(child: Text('No teams found. Tap "+ CREATE TEAM" below!', style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _teams.length,
                      itemBuilder: (context, index) {
                        final t = _teams[index];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppTheme.primaryGold.withValues(alpha: 0.2),
                              child: Text(
                                t['short_name'] ?? 'TM',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                              ),
                            ),
                            title: Text(t['name'] ?? 'Team', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                            subtitle: Text('${t['player_count'] ?? 0} Players in Squad', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.primaryGold),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TeamDetailScreen(teamId: t['id']),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
