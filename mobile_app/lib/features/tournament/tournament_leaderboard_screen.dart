import 'package:flutter/material.dart';
import '../../core/api_service.dart';

class TournamentLeaderboardScreen extends StatefulWidget {
  final int tournamentId;

  const TournamentLeaderboardScreen({super.key, required this.tournamentId});

  @override
  State<TournamentLeaderboardScreen> createState() => _TournamentLeaderboardScreenState();
}

class _TournamentLeaderboardScreenState extends State<TournamentLeaderboardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;

  String _selectedCategory = 'runs'; // 'runs', 'wickets', 'mvp', 'sixes', 'fours'

  List<dynamic> _batsmen = [];
  List<dynamic> _bowlers = [];
  List<dynamic> _mvp = [];
  List<dynamic> _sixes = [];
  List<dynamic> _fours = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _apiService.getTournamentStats(widget.tournamentId);
      if (res['success'] == true || res['batsmen'] != null) {
        setState(() {
          _batsmen = res['batsmen'] ?? [];
          _bowlers = res['bowlers'] ?? [];
          _mvp = res['mvp'] ?? [];
          _sixes = res['most_sixes'] ?? [];
          _fours = res['most_fours'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load leaderboard stats';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading stats: $e';
        _isLoading = false;
      });
    }
  }

  List<dynamic> _getCurrentList() {
    switch (_selectedCategory) {
      case 'wickets':
        return _bowlers;
      case 'mvp':
        return _mvp;
      case 'sixes':
        return _sixes;
      case 'fours':
        return _fours;
      case 'runs':
      default:
        return _batsmen;
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF070710);
    const goldColor = Color(0xFFDFBA73);

    final currentList = _getCurrentList();

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '👑 Tournament Leaderboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: goldColor),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Column(
        children: [
          // Category Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildCategoryChip('runs', '🏏 Orange Cap (Runs)', Colors.orangeAccent),
                const SizedBox(width: 8),
                _buildCategoryChip('wickets', '🎯 Purple Cap (Wickets)', Colors.purpleAccent),
                const SizedBox(width: 8),
                _buildCategoryChip('mvp', '🌟 MVP Impact', goldColor),
                const SizedBox(width: 8),
                _buildCategoryChip('sixes', '💥 Most 6s', Colors.redAccent),
                const SizedBox(width: 8),
                _buildCategoryChip('fours', '⚡ Most 4s', Colors.blueAccent),
              ],
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
                              onPressed: _loadStats,
                              style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                              child: const Text('Retry', style: TextStyle(color: Colors.black)),
                            ),
                          ],
                        ),
                      )
                    : currentList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.leaderboard_outlined, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                const Text(
                                  'No Leaderboard Stats Recorded',
                                  style: TextStyle(color: Colors.white70, fontSize: 15),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Stats will automatically update as matches complete',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            color: goldColor,
                            onRefresh: _loadStats,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: currentList.length,
                              itemBuilder: (context, index) {
                                final item = currentList[index];
                                final int rank = index + 1;
                                final String name = item['name'] ?? 'Player';
                                final String team = item['team'] ?? 'Free Agent';

                                return _buildLeaderboardCard(rank, name, team, item);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String id, String label, Color color) {
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
      selectedColor: color,
      backgroundColor: const Color(0xFF121222),
      side: BorderSide(color: isSelected ? color : color.withValues(alpha: 0.3)),
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = id);
      },
    );
  }

  Widget _buildLeaderboardCard(int rank, String name, String team, Map<String, dynamic> item) {
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    Color rankColor = Colors.white54;
    String rankBadge = '#$rank';
    if (rank == 1) {
      rankColor = goldColor;
      rankBadge = '👑 #1';
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankBadge = '🥈 #2';
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankBadge = '🥉 #3';
    }

    String mainStatText = '';
    String subStatText = '';

    if (_selectedCategory == 'runs') {
      final int runs = int.tryParse(item['runs']?.toString() ?? '0') ?? 0;
      final double sr = double.tryParse(item['sr']?.toString() ?? '0.0') ?? 0.0;
      final int matches = int.tryParse(item['matches']?.toString() ?? '0') ?? 0;
      mainStatText = '$runs Runs';
      subStatText = '$matches M • SR: $sr';
    } else if (_selectedCategory == 'wickets') {
      final int wkts = int.tryParse(item['wickets']?.toString() ?? '0') ?? 0;
      final double econ = double.tryParse(item['econ']?.toString() ?? '0.0') ?? 0.0;
      final int matches = int.tryParse(item['matches']?.toString() ?? '0') ?? 0;
      mainStatText = '$wkts Wkts';
      subStatText = '$matches M • Econ: $econ';
    } else if (_selectedCategory == 'mvp') {
      final int pts = int.tryParse(item['points']?.toString() ?? '0') ?? 0;
      final int runs = int.tryParse(item['runs']?.toString() ?? '0') ?? 0;
      final int wkts = int.tryParse(item['wickets']?.toString() ?? '0') ?? 0;
      mainStatText = '$pts Pts';
      subStatText = '$runs R • $wkts W';
    } else if (_selectedCategory == 'sixes') {
      final int count = int.tryParse(item['count']?.toString() ?? '0') ?? 0;
      mainStatText = '$count Sixes';
      subStatText = 'Boundary King';
    } else if (_selectedCategory == 'fours') {
      final int count = int.tryParse(item['count']?.toString() ?? '0') ?? 0;
      mainStatText = '$count Fours';
      subStatText = 'Boundary King';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: rank == 1 ? goldColor.withValues(alpha: 0.12) : cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: rank == 1 ? goldColor.withValues(alpha: 0.5) : goldColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Rank Badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: rankColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: rankColor.withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                rankBadge,
                style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Player Name & Team
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  team,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                ),
              ],
            ),
          ),

          // Main Stat Display
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                mainStatText,
                style: const TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 2),
              Text(
                subStatText,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
