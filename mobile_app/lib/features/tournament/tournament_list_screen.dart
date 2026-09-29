import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import 'tournament_create_screen.dart';
import 'tournament_detail_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _tournaments = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _apiService.getTournaments(search: _searchQuery);
      if (res['success'] == true) {
        setState(() {
          _tournaments = res['tournaments'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load tournaments';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext meContext) {
    const bgDark = Color(0xFF070710);
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: const Text(
          '🏆 Tournaments',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: goldColor),
            onPressed: _loadTournaments,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TournamentCreateScreen()),
          );
          if (created == true) {
            _loadTournaments();
          }
        },
        backgroundColor: goldColor,
        icon: const Icon(Icons.add, color: Colors.black),
        label: const Text('Create Tournament', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _loadTournaments();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search tournaments...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                prefixIcon: const Icon(Icons.search, color: goldColor),
                filled: true,
                fillColor: cardBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: goldColor.withOpacity(0.3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: goldColor.withOpacity(0.3)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: goldColor),
                ),
              ),
            ),
          ),

          // Main List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: goldColor))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _loadTournaments,
                              style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                              child: const Text('Retry', style: TextStyle(color: Colors.black)),
                            ),
                          ],
                        ),
                      )
                    : _tournaments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.emoji_events_outlined, size: 64, color: goldColor.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  'No Tournaments Found',
                                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Tap "+ Create Tournament" below to start',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: goldColor,
                            onRefresh: _loadTournaments,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _tournaments.length,
                              itemBuilder: (context, index) {
                                final tour = _tournaments[index];
                                final int id = int.tryParse(tour['id'].toString()) ?? 0;
                                final String name = tour['name'] ?? 'Unnamed Tournament';
                                final String type = tour['type'] ?? 'round_robin';
                                final int teams = int.tryParse(tour['team_count']?.toString() ?? '0') ?? 0;
                                final int matches = int.tryParse(tour['match_count']?.toString() ?? '0') ?? 0;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: goldColor.withOpacity(0.2)),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(16),
                                    leading: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: goldColor.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: goldColor.withOpacity(0.5)),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.emoji_events, color: goldColor, size: 26),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _buildBadge(
                                            type == 'round_robin' ? '🔄 Round Robin' : '⚡ Knockout',
                                            Colors.blueAccent,
                                          ),
                                          _buildBadge('🛡️ $teams Teams', Colors.orangeAccent),
                                          _buildBadge('🏏 $matches Matches', Colors.greenAccent),
                                        ],
                                      ),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, color: goldColor, size: 16),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TournamentDetailScreen(tournamentId: id),
                                        ),
                                      ).then((_) => _loadTournaments());
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
