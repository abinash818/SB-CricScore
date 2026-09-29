import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';

class CricketFeedScreen extends StatefulWidget {
  const CricketFeedScreen({super.key});

  @override
  State<CricketFeedScreen> createState() => _CricketFeedScreenState();
}

class _CricketFeedScreenState extends State<CricketFeedScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    try {
      final res = await _apiService.dio.get('/feed_ops.php?action=list');
      if (mounted) {
        setState(() {
          _posts = res.data['posts'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleLike(int postId, int index) async {
    setState(() {
      final isLiked = _posts[index]['is_liked'] == true;
      _posts[index]['is_liked'] = !isLiked;
      _posts[index]['likes_count'] += isLiked ? -1 : 1;
    });

    try {
      await _apiService.dio.post('/feed_ops.php?action=like', data: {'post_id': postId});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'CRICKET COMMUNITY',
          style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold))
          : RefreshIndicator(
              onRefresh: _loadFeed,
              color: AppTheme.primaryGold,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final p = _posts[index];
                  final isLiked = p['is_liked'] == true;

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
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryGold.withOpacity(0.2),
                              child: Text(
                                ((p['author_name'] as String?) ?? 'C')[0].toUpperCase(),
                                style: const TextStyle(color: AppTheme.primaryGold, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['author_name'] ?? 'Cricketer',
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  p['author_city'] ?? 'India',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          p['content'] ?? '',
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? AppTheme.errorRed : AppTheme.textMuted,
                              ),
                              onPressed: () => _toggleLike(p['id'], index),
                            ),
                            Text(
                              '${p['likes_count']}',
                              style: TextStyle(color: isLiked ? AppTheme.errorRed : AppTheme.textMuted),
                            ),
                            const SizedBox(width: 24),
                            const Icon(Icons.chat_bubble_outline, color: AppTheme.textMuted, size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '${p['comments_count']}',
                              style: const TextStyle(color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }
}
