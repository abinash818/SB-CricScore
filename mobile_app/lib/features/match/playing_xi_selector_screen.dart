import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';

class PlayingXiSelectorScreen extends StatefulWidget {
  final int matchId;
  final int teamId;
  final String teamName;
  final VoidCallback? onSaved;

  const PlayingXiSelectorScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
    this.onSaved,
  });

  @override
  State<PlayingXiSelectorScreen> createState() => _PlayingXiSelectorScreenState();
}

class _PlayingXiSelectorScreenState extends State<PlayingXiSelectorScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _saving = false;
  List<dynamic> _squad = [];

  final List<int> _selectedPlayingXI = [];
  final List<int> _selectedSubs = [];
  int? _captainId;
  int? _wkId;

  @override
  void initState() {
    super.initState();
    _loadSquadAndLineup();
  }

  Future<void> _loadSquadAndLineup() async {
    setState(() => _loading = true);
    try {
      // 1. Fetch Team Squad
      final teamRes = await _api.dio.get('/team_ops.php', queryParameters: {
        'action': 'get',
        'team_id': widget.teamId,
      });
      if (teamRes.data['success'] == true) {
        _squad = teamRes.data['squad'] ?? [];
      }

      // 2. Fetch existing Lineup if any
      final lineupRes = await _api.getPlayingXI(widget.matchId);
      if (lineupRes['success'] == true) {
        final teamXI = (lineupRes['team_a_playing_xi'] as List? ?? []) +
            (lineupRes['team_b_playing_xi'] as List? ?? []);
        final teamSubs = (lineupRes['team_a_substitutes'] as List? ?? []) +
            (lineupRes['team_b_substitutes'] as List? ?? []);

        for (var p in teamXI) {
          if (p['team_id'] == widget.teamId) {
            final pid = p['player_id'] is int ? p['player_id'] : int.tryParse('${p['player_id']}');
            if (pid != null && !_selectedPlayingXI.contains(pid)) {
              _selectedPlayingXI.add(pid);
              if (p['is_captain'] == 1) _captainId = pid;
              if (p['is_wicketkeeper'] == 1) _wkId = pid;
            }
          }
        }

        for (var p in teamSubs) {
          if (p['team_id'] == widget.teamId) {
            final pid = p['player_id'] is int ? p['player_id'] : int.tryParse('${p['player_id']}');
            if (pid != null && !_selectedSubs.contains(pid)) {
              _selectedSubs.add(pid);
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading squad: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _togglePlayer(int playerId) {
    setState(() {
      if (_selectedPlayingXI.contains(playerId)) {
        _selectedPlayingXI.remove(playerId);
        if (_captainId == playerId) _captainId = null;
        if (_wkId == playerId) _wkId = null;
      } else if (_selectedSubs.contains(playerId)) {
        _selectedSubs.remove(playerId);
      } else {
        if (_selectedPlayingXI.length < 11) {
          _selectedPlayingXI.add(playerId);
        } else if (_selectedSubs.length < 3) {
          _selectedSubs.add(playerId);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 11 Playing XI and 3 Substitutes reached!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    });
  }

  Future<void> _saveLineup() async {
    if (_selectedPlayingXI.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least 1 player for Playing XI')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final res = await _api.savePlayingXI(
        matchId: widget.matchId,
        teamId: widget.teamId,
        playingXiIds: _selectedPlayingXI,
        substituteIds: _selectedSubs,
        captainId: _captainId,
        wicketkeeperId: _wkId,
      );

      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Lineup saved successfully!'),
            backgroundColor: AppTheme.gold,
          ),
        );
        widget.onSaved?.call();
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Failed to save lineup')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    } finally {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          '${widget.teamName} - Lineup (11+3)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardBackground,
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _saveLineup,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
                  )
                : const Icon(Icons.check_circle, color: AppTheme.gold),
            label: Text(
              'Save',
              style: GoogleFonts.outfit(
                color: AppTheme.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.gold))
          : Column(
              children: [
                // Top Status Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    border: Border(
                      bottom: BorderSide(color: AppTheme.gold.withOpacity(0.2)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Playing XI: ${_selectedPlayingXI.length}/11',
                              style: GoogleFonts.outfit(
                                color: _selectedPlayingXI.length == 11
                                    ? Colors.greenAccent
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Substitutes: ${_selectedSubs.length}/3',
                              style: GoogleFonts.outfit(
                                color: AppTheme.gold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Total: ${_selectedPlayingXI.length + _selectedSubs.length}/14',
                          style: GoogleFonts.outfit(
                            color: AppTheme.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Squad List
                Expanded(
                  child: _squad.isEmpty
                      ? Center(
                          child: Text(
                            'No players in team squad.\nAdd players in Team screen first.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _squad.length,
                          itemBuilder: (context, index) {
                            final player = _squad[index];
                            final pid = player['id'] is int
                                ? player['id']
                                : int.parse('${player['id']}');
                            final isXI = _selectedPlayingXI.contains(pid);
                            final isSub = _selectedSubs.contains(pid);
                            final isCapt = (_captainId == pid);
                            final isWk = (_wkId == pid);

                            int xiIndex = _selectedPlayingXI.indexOf(pid) + 1;
                            int subIndex = _selectedSubs.indexOf(pid) + 1;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isXI
                                    ? AppTheme.gold.withOpacity(0.12)
                                    : (isSub
                                        ? Colors.blueGrey.withOpacity(0.2)
                                        : AppTheme.cardBackground),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isXI
                                      ? AppTheme.gold
                                      : (isSub
                                          ? Colors.cyanAccent.withOpacity(0.5)
                                          : Colors.white10),
                                ),
                              ),
                              child: ListTile(
                                onTap: () => _togglePlayer(pid),
                                leading: CircleAvatar(
                                  backgroundColor: isXI
                                      ? AppTheme.gold
                                      : (isSub ? Colors.cyan : Colors.white12),
                                  child: Text(
                                    isXI
                                        ? '$xiIndex'
                                        : (isSub ? 'S$subIndex' : '${index + 1}'),
                                    style: GoogleFonts.outfit(
                                      color: (isXI || isSub)
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        player['name'] ?? 'Player',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (isCapt)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'C',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11),
                                        ),
                                      ),
                                    if (isWk) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.lightBlueAccent,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'WK',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Text(
                                  '${player['role'] ?? 'Player'} • ${player['batting_style'] ?? 'Right Hand Bat'}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                trailing: isXI
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Set as Captain',
                                            icon: Icon(
                                              Icons.star,
                                              color: isCapt
                                                  ? Colors.amber
                                                  : Colors.white24,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _captainId = isCapt ? null : pid;
                                              });
                                            },
                                          ),
                                          IconButton(
                                            tooltip: 'Set as Wicketkeeper',
                                            icon: Icon(
                                              Icons.sports_baseball,
                                              color: isWk
                                                  ? Colors.lightBlueAccent
                                                  : Colors.white24,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _wkId = isWk ? null : pid;
                                              });
                                            },
                                          ),
                                        ],
                                      )
                                    : (isSub
                                        ? const Chip(
                                            label: Text('Sub'),
                                            backgroundColor: Colors.cyan,
                                            labelStyle: TextStyle(
                                                color: Colors.black,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold),
                                          )
                                        : const Icon(Icons.add_circle_outline,
                                            color: Colors.white38)),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
