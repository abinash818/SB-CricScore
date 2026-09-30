import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/location_service.dart';
import '../location/location_picker_dialog.dart';
import 'tournament_create_screen.dart';
import 'tournament_detail_screen.dart';

class TournamentListScreen extends StatefulWidget {
  const TournamentListScreen({super.key});

  @override
  State<TournamentListScreen> createState() => _TournamentListScreenState();
}

class _TournamentListScreenState extends State<TournamentListScreen> {
  final ApiService _apiService = ApiService();
  final LocationService _locService = LocationService();

  bool _isLoading = true;
  String? _error;
  List<dynamic> _tournaments = [];
  String _searchQuery = '';
  String _selectedDistrictFilter = 'All TN';

  final List<String> _quickDistrictChips = [
    'All TN',
    'Coimbatore',
    'Chennai',
    'Madurai',
    'Salem',
    'Tiruppur',
    'Erode',
    'Tiruchirappalli (Trichy)',
  ];

  @override
  void initState() {
    super.initState();
    // Default to user's saved district or All TN
    _selectedDistrictFilter = _locService.currentDistrict.value;
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final String? distParam = (_selectedDistrictFilter == 'All TN' || _selectedDistrictFilter == 'All')
          ? null
          : _selectedDistrictFilter;

      final res = await _apiService.getTournaments(
        search: _searchQuery,
        district: distParam,
      );
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

  void _selectDistrictChip(String chip) {
    setState(() {
      _selectedDistrictFilter = chip;
    });
    _loadTournaments();
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF070710);
    const cardBg = Color(0xFF121222);
    const goldColor = Color(0xFFDFBA73);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Text(
          '🏆 Tournaments Explorer',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: 'Filter by Location',
            icon: const Icon(Icons.location_on, color: goldColor),
            onPressed: () async {
              await LocationPickerDialog.show(context);
              setState(() {
                _selectedDistrictFilter = _locService.currentDistrict.value;
              });
              _loadTournaments();
            },
          ),
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
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _loadTournaments();
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search tournaments, ground, district...',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.search, color: goldColor),
                filled: true,
                fillColor: cardBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF222238)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: goldColor),
                ),
              ),
            ),
          ),

          // ── Location Filter Chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._quickDistrictChips.map((dist) {
                    final isSelected = (_selectedDistrictFilter == dist);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ActionChip(
                        backgroundColor: isSelected ? goldColor : cardBg,
                        side: BorderSide(
                          color: isSelected ? goldColor : const Color(0xFF222238),
                        ),
                        label: Text(
                          dist,
                          style: TextStyle(
                            color: isSelected ? const Color(0xFF070710) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () => _selectDistrictChip(dist),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      avatar: const Icon(Icons.tune, color: goldColor, size: 14),
                      backgroundColor: cardBg,
                      side: const BorderSide(color: Color(0xFF222238)),
                      label: const Text(
                        'More Districts 📍',
                        style: TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () async {
                        await LocationPickerDialog.show(context);
                        setState(() {
                          _selectedDistrictFilter = _locService.currentDistrict.value;
                        });
                        _loadTournaments();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Tournaments List View ──
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
                                const Icon(Icons.emoji_events_outlined, size: 64, color: Colors.white24),
                                const SizedBox(height: 12),
                                Text(
                                  'No tournaments found in $_selectedDistrictFilter',
                                  style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Try selecting "All TN" or create your own tournament!',
                                  style: TextStyle(color: Colors.white38, fontSize: 12),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: goldColor, foregroundColor: Colors.black),
                                  icon: const Icon(Icons.public),
                                  label: const Text('Show All Tamil Nadu', style: TextStyle(fontWeight: FontWeight.bold)),
                                  onPressed: () => _selectDistrictChip('All TN'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _tournaments.length,
                            itemBuilder: (context, index) {
                              final t = _tournaments[index];
                              final int id = int.tryParse(t['id'].toString()) ?? 0;
                              final String name = t['name'] ?? 'Unnamed Tournament';
                              final String type = t['type'] ?? 'round_robin';
                              final String district = t['district'] ?? 'Tamil Nadu';
                              final String? cityArea = t['city_area'];
                              final int teamCount = int.tryParse(t['team_count']?.toString() ?? '0') ?? 0;
                              final int matchCount = int.tryParse(t['match_count']?.toString() ?? '0') ?? 0;

                              return Card(
                                color: cardBg,
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: (district == _locService.currentDistrict.value)
                                        ? goldColor.withValues(alpha: 0.4)
                                        : const Color(0xFF222238),
                                    width: 1.2,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => TournamentDetailScreen(tournamentId: id),
                                      ),
                                    ).then((_) => _loadTournaments());
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: goldColor.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Icon(Icons.emoji_events, color: goldColor, size: 24),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: GoogleFonts.outfit(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.location_on, color: goldColor, size: 12),
                                                      const SizedBox(width: 3),
                                                      Text(
                                                        cityArea != null ? '$cityArea, $district' : district,
                                                        style: const TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.w600),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 14),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(color: Colors.white10, height: 1),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildStatBadge(Icons.groups, '$teamCount Teams'),
                                            _buildStatBadge(Icons.sports_cricket, '$matchCount Matches'),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF1E1E38),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                type == 'knockout' ? 'Knockout' : 'Round Robin',
                                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.white38),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
