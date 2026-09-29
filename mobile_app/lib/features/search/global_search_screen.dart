import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../player/player_profile_screen.dart';
import '../team/team_detail_screen.dart';
import '../tournament/tournament_detail_screen.dart';
import '../match/live_match_viewer_screen.dart';
import '../match/full_scorecard_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isLoading = false;
  String _selectedCategory = 'all'; // 'all', 'players', 'teams', 'tournaments', 'matches'

  List<dynamic> _players = [];
  List<dynamic> _teams = [];
  List<dynamic> _tournaments = [];
  List<dynamic> _matches = [];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.length < 2) {
      setState(() {
        _players = [];
        _teams = [];
        _tournaments = [];
        _matches = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await _apiService.searchGlobal(clean, type: _selectedCategory);
      if (mounted && res['success'] == true) {
        setState(() {
          _players = res['players'] ?? [];
          _teams = res['teams'] ?? [];
          _tournaments = res['tournaments'] ?? [];
          _matches = res['matches'] ?? [];
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool get _hasResults =>
      _players.isNotEmpty || _teams.isNotEmpty || _tournaments.isNotEmpty || _matches.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF070710);
    const goldColor = Color(0xFFDFBA73);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Search players, teams, tournaments...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 15),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white54),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Categories Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildCategoryChip('all', '🌐 All Results'),
                const SizedBox(width: 8),
                _buildCategoryChip('players', '👤 Players (${_players.length})'),
                const SizedBox(width: 8),
                _buildCategoryChip('teams', '🛡️ Teams (${_teams.length})'),
                const SizedBox(width: 8),
                _buildCategoryChip('tournaments', '🏆 Tournaments (${_tournaments.length})'),
                const SizedBox(width: 8),
                _buildCategoryChip('matches', '🏏 Matches (${_matches.length})'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Main Results Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: goldColor))
                : _searchController.text.trim().length < 2
                    ? _buildEmptyPrompt()
                    : !_hasResults
                        ? _buildNoResultsFound()
                        : ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            children: [
                              // 👤 Players Section
                              if ((_selectedCategory == 'all' || _selectedCategory == 'players') &&
                                  _players.isNotEmpty) ...[
                                _buildSectionHeader('👤 PLAYERS', Colors.blueAccent),
                                ..._players.map((p) => _buildPlayerTile(p)),
                                const SizedBox(height: 16),
                              ],

                              // 🛡️ Teams Section
                              if ((_selectedCategory == 'all' || _selectedCategory == 'teams') &&
                                  _teams.isNotEmpty) ...[
                                _buildSectionHeader('🛡️ TEAMS', Colors.orangeAccent),
                                ..._teams.map((t) => _buildTeamTile(t)),
                                const SizedBox(height: 16),
                              ],

                              // 🏆 Tournaments Section
                              if ((_selectedCategory == 'all' || _selectedCategory == 'tournaments') &&
                                  _tournaments.isNotEmpty) ...[
                                _buildSectionHeader('🏆 TOURNAMENTS', goldColor),
                                ..._tournaments.map((tour) => _buildTournamentTile(tour)),
                                const SizedBox(height: 16),
                              ],

                              // 🏏 Matches Section
                              if ((_selectedCategory == 'all' || _selectedCategory == 'matches') &&
                                  _matches.isNotEmpty) ...[
                                _buildSectionHeader('🏏 MATCHES', Colors.greenAccent),
                                ..._matches.map((m) => _buildMatchTile(m)),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label) {
    const goldColor = Color(0xFFDFBA73);
    final bool isSelected = _selectedCategory == id;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: goldColor,
      backgroundColor: const Color(0xFF121222),
      side: BorderSide(color: isSelected ? goldColor : goldColor.withValues(alpha: 0.3)),
      onSelected: (val) {
        if (val) {
          setState(() => _selectedCategory = id);
          _performSearch(_searchController.text);
        }
      },
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
      ),
    );
  }

  Widget _buildPlayerTile(Map<String, dynamic> p) {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);
    final int id = int.tryParse(p['id'].toString()) ?? 0;
    final String name = p['name'] ?? 'Player';
    final String role = p['role'] ?? 'BAT';
    final String team = p['team_name'] ?? 'Free Agent';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldColor.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('$role • $team', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: goldColor, size: 14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PlayerProfileScreen(playerId: id)),
          );
        },
      ),
    );
  }

  Widget _buildTeamTile(Map<String, dynamic> t) {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);
    final int id = int.tryParse(t['id'].toString()) ?? 0;
    final String name = t['name'] ?? 'Team';
    final String short = t['short_name'] ?? 'TM';
    final int players = int.tryParse(t['player_count']?.toString() ?? '0') ?? 0;
    final String tournament = t['tournament_name'] ?? 'Tournament Team';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldColor.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.2),
          child: Text(short, style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text('$players Players • $tournament', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: goldColor, size: 14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TeamDetailScreen(teamId: id)),
          );
        },
      ),
    );
  }

  Widget _buildTournamentTile(Map<String, dynamic> tour) {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);
    final int id = int.tryParse(tour['id'].toString()) ?? 0;
    final String name = tour['name'] ?? 'Tournament';
    final String type = tour['type'] ?? 'round_robin';
    final int teams = int.tryParse(tour['team_count']?.toString() ?? '0') ?? 0;
    final int matches = int.tryParse(tour['match_count']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldColor.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: goldColor.withValues(alpha: 0.2),
          child: const Icon(Icons.emoji_events, color: goldColor, size: 20),
        ),
        title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${type == 'round_robin' ? 'Round Robin' : 'Knockout'} • $teams Teams • $matches Matches',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: goldColor, size: 14),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => TournamentDetailScreen(tournamentId: id)),
          );
        },
      ),
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> m) {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);
    final int id = int.tryParse(m['id'].toString()) ?? 0;
    final String teamA = m['team_a_short'] ?? m['team_a_name'] ?? 'Team A';
    final String teamB = m['team_b_short'] ?? m['team_b_name'] ?? 'Team B';
    final String status = m['status'] ?? 'scheduled';
    final String tourName = m['tournament_name'] ?? 'Match';

    Color statusColor = Colors.orangeAccent;
    String statusText = 'SCHEDULED';
    if (status == 'live') {
      statusColor = Colors.redAccent;
      statusText = 'LIVE 🔴';
    } else if (status == 'completed') {
      statusColor = Colors.greenAccent;
      statusText = 'FINISHED';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: goldColor.withValues(alpha: 0.15)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusText,
            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 10),
          ),
        ),
        title: Text('$teamA vs $teamB', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(tourName, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, color: goldColor, size: 14),
        onTap: () {
          if (status == 'completed') {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FullScorecardScreen(matchId: id)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => LiveMatchViewerScreen(matchId: id)),
            );
          }
        },
      ),
    );
  }

  Widget _buildEmptyPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 56, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          const Text('Search CricScore Platform', style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: 6),
          const Text('Type player names, teams, or tournaments', style: TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNoResultsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 56, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            'No matches found for "${_searchController.text}"',
            style: const TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 6),
          const Text('Try searching with different keywords', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
