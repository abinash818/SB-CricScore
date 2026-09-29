import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';

class MatchAnalyticsScreen extends StatefulWidget {
  final int matchId;
  const MatchAnalyticsScreen({super.key, required this.matchId});

  @override
  State<MatchAnalyticsScreen> createState() => _MatchAnalyticsScreenState();
}

class _MatchAnalyticsScreenState extends State<MatchAnalyticsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _analytics = [];

  @override
  void initState() {
    super.initState();
    _fetchAnalytics();
  }

  Future<void> _fetchAnalytics() async {
    try {
      final res = await _apiService.dio.get('/analytics_get.php?match_id=${widget.matchId}');
      if (mounted) {
        setState(() {
          _analytics = res.data['analytics'] as List? ?? [];
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
          'Match Analytics 📈',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : _analytics.isEmpty
              ? const Center(child: Text('No analytics data available yet', style: TextStyle(color: AppTheme.textMuted)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Match Stats Overview Grid
                      _sectionTitle('MATCH OVERVIEW'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Dot Ball %',
                              value: '${_analytics[0]['dot_percentage'] ?? 0}%',
                              icon: Icons.pie_chart_outline,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricCard(
                              title: 'Boundary %',
                              value: '${_analytics[0]['boundary_percentage'] ?? 0}%',
                              icon: Icons.sports_cricket,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Manhattan Chart (Runs Per Over)
                      _sectionTitle('📊 MANHATTAN (RUNS PER OVER)'),
                      const SizedBox(height: 12),
                      ..._analytics.map((inn) {
                        final manhattan = inn['manhattan'] as List? ?? [];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${inn['batting_team']} Innings',
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 160,
                                child: manhattan.isEmpty
                                    ? const Center(child: Text('No over data', style: TextStyle(color: AppTheme.textMuted)))
                                    : ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: manhattan.length,
                                        itemBuilder: (context, idx) {
                                          final item = manhattan[idx];
                                          final runs = (item['runs'] as num? ?? 0).toDouble();
                                          final wickets = item['wickets'] ?? 0;
                                          final over = item['over'];

                                          // Scale height max 20 runs
                                          final barHeight = (runs / 20.0) * 120.0;

                                          return Container(
                                            margin: const EdgeInsets.only(right: 12),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                if (wickets > 0)
                                                  Container(
                                                    margin: const EdgeInsets.only(bottom: 4),
                                                    padding: const EdgeInsets.all(3),
                                                    decoration: const BoxDecoration(
                                                      color: AppTheme.errorRed,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Text(
                                                      '$wickets W',
                                                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                Text(
                                                  '${runs.toInt()}',
                                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Container(
                                                  width: 24,
                                                  height: barHeight.clamp(8.0, 120.0),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryGold,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Ov $over',
                                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Worm Chart (Cumulative Runs Progress)
                      _sectionTitle('🐛 WORM CHART (CUMULATIVE PROGRESS)'),
                      const SizedBox(height: 12),
                      ..._analytics.map((inn) {
                        final worm = inn['worm'] as List? ?? [];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${inn['batting_team']} Total: ${inn['total_runs']} Runs',
                                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: worm.length,
                                  itemBuilder: (ctx, idx) {
                                    final w = worm[idx];
                                    return Container(
                                      margin: const EdgeInsets.only(right: 14),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF131326),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppTheme.cardBorder),
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text('Ov ${w['over']}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Text('${w['runs']} Runs', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryGold, fontSize: 14)),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
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

  Widget _buildMetricCard({required String title, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryGold, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGold),
          ),
        ],
      ),
    );
  }
}
