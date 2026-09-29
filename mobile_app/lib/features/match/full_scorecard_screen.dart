import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';

class FullScorecardScreen extends StatefulWidget {
  final int matchId;
  const FullScorecardScreen({super.key, required this.matchId});

  @override
  State<FullScorecardScreen> createState() => _FullScorecardScreenState();
}

class _FullScorecardScreenState extends State<FullScorecardScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _scorecard = [];

  @override
  void initState() {
    super.initState();
    _fetchScorecard();
  }

  Future<void> _fetchScorecard() async {
    try {
      final res = await _apiService.dio.get('/scorecard_get.php?match_id=${widget.matchId}');
      if (mounted) {
        setState(() {
          _scorecard = res.data['scorecard'] as List? ?? [];
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
          'Full Scorecard 📋',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: AppTheme.primaryGold),
            tooltip: 'Share Scorecard',
            onPressed: () async {
              try {
                final res = await _apiService.getMatchShareSummary(widget.matchId);
                if (res['success'] == true && res['share_text'] != null) {
                  Share.share(res['share_text']);
                }
              } catch (_) {}
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : DefaultTabController(
              length: _scorecard.isEmpty ? 1 : _scorecard.length,
              child: Column(
                children: [
                  TabBar(
                    indicatorColor: AppTheme.primaryGold,
                    labelColor: AppTheme.primaryGold,
                    unselectedLabelColor: AppTheme.textMuted,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    tabs: _scorecard.isEmpty
                        ? [const Tab(text: 'Scorecard')]
                        : _scorecard.map((inn) {
                            return Tab(text: '${inn['batting_team']} Innings');
                          }).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: _scorecard.isEmpty
                          ? [const Center(child: Text('No scorecard data available', style: TextStyle(color: AppTheme.textMuted)))]
                          : _scorecard.map((inn) {
                              final batting = inn['batting'] as List? ?? [];
                              final bowling = inn['bowling'] as List? ?? [];

                              return SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _sectionTitle('BATTING'),
                                    const SizedBox(height: 12),
                                    _buildBattingTable(batting),
                                    const SizedBox(height: 28),
                                    _sectionTitle('BOWLING'),
                                    const SizedBox(height: 12),
                                    _buildBowlingTable(bowling),
                                  ],
                                ),
                              );
                            }).toList(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryGold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildBattingTable(List<dynamic> batting) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(1),
          5: FlexColumnWidth(1.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: const Color(0xFF131326),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            children: [
              _headerCell('Batter'),
              _headerCell('R'),
              _headerCell('B'),
              _headerCell('4s'),
              _headerCell('6s'),
              _headerCell('SR'),
            ],
          ),
          ...batting.map((bt) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bt['name'] ?? 'Batter', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(bt['dismissal'] ?? 'not out', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                ),
                _dataCell('${bt['runs']}', isBold: true),
                _dataCell('${bt['balls']}'),
                _dataCell('${bt['fours']}'),
                _dataCell('${bt['sixes']}'),
                _dataCell('${bt['sr']}'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBowlingTable(List<dynamic> bowling) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: FlexColumnWidth(1.5),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: const Color(0xFF131326),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            children: [
              _headerCell('Bowler'),
              _headerCell('O'),
              _headerCell('R'),
              _headerCell('W'),
              _headerCell('ECO'),
            ],
          ),
          ...bowling.map((bw) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Text(bw['name'] ?? 'Bowler', style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14)),
                ),
                _dataCell('${bw['overs']}'),
                _dataCell('${bw['runs']}'),
                _dataCell('${bw['wickets']}', isBold: true),
                _dataCell('${bw['economy']}'),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryGold),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _dataCell(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          color: isBold ? AppTheme.primaryGold : AppTheme.textPrimary,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
