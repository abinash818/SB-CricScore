import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String _selectedCategory = 'all'; // 'all', 'highlights', 'match_finder', 'general'
  List<dynamic> _posts = [];

  final List<Map<String, String>> _categories = [
    {'key': 'all', 'label': '🔥 All Feed'},
    {'key': 'highlights', 'label': '⚡ Match Highlights'},
    {'key': 'match_finder', 'label': '🤝 Match & Player Finder'},
    {'key': 'general', 'label': '🏏 Cricket Buzz'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.getFeed(category: _selectedCategory);
      if (mounted) {
        setState(() {
          _posts = res['posts'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onCategorySelected(String key) {
    if (_selectedCategory == key) return;
    setState(() {
      _selectedCategory = key;
    });
    _loadFeed();
  }

  void _toggleLike(int postId, int index) async {
    if (index >= _posts.length) return;
    final isLiked = _posts[index]['is_liked'] == true;
    setState(() {
      _posts[index]['is_liked'] = !isLiked;
      _posts[index]['likes_count'] = (_posts[index]['likes_count'] as int? ?? 0) + (isLiked ? -1 : 1);
    });

    try {
      await _apiService.toggleFeedLike(postId);
    } catch (_) {
      // Revert if API fails
      if (mounted) {
        setState(() {
          _posts[index]['is_liked'] = isLiked;
          _posts[index]['likes_count'] = (_posts[index]['likes_count'] as int? ?? 0) + (isLiked ? 1 : -1);
        });
      }
    }
  }

  void _deletePost(int postId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        title: Text('Delete Post?', style: GoogleFonts.outfit(color: AppTheme.primaryGold, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove this post from Community Feed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await _apiService.deleteFeedPost(postId);
        if (res['success'] == true) {
          setState(() {
            _posts.removeAt(index);
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post deleted successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete post')),
          );
        }
      }
    }
  }

  void _launchWhatsAppChat(String rawNumber, String content) async {
    String cleanNumber = rawNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.length == 10) cleanNumber = '91$cleanNumber';

    final text = Uri.encodeComponent(
      '🏏 Hi from SB CricScore Community!\nI saw your post:\n"$content"\nLet\'s connect!',
    );
    final url = Uri.parse('https://wa.me/$cleanNumber?text=$text');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp for $rawNumber')),
        );
      }
    }
  }

  void _sharePost(Map<String, dynamic> post) {
    final author = post['author_name'] ?? 'Cricketer';
    final content = post['content'] ?? '';
    final type = post['post_type'] == 'match_finder' ? '🤝 Match/Player Finder' : '🏏 Cricket Update';
    final shareText = '$type on SB CricScore:\n\n"$content"\n- By $author\n\nDownload SB CricScore App: https://sbastro.com/tournament/';
    Share.share(shareText);
  }

  void _openCreatePostModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CreatePostBottomSheet(
        onPostCreated: () {
          _loadFeed();
        },
      ),
    );
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Just now';
    try {
      final dt = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryGold.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4)),
              ),
              child: const Icon(Icons.people_alt, color: AppTheme.primaryGold, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'CRICKET COMMUNITY',
              style: GoogleFonts.outfit(
                color: AppTheme.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 18,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        backgroundColor: AppTheme.background,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.primaryGold),
            tooltip: 'Refresh Feed',
            onPressed: _loadFeed,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryGold,
        foregroundColor: const Color(0xFF070710),
        elevation: 6,
        icon: const Icon(Icons.edit, size: 20, color: Color(0xFF070710)),
        label: Text(
          'Post Update',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        onPressed: _openCreatePostModal,
      ),
      body: Column(
        children: [
          // ── Category Pills Filter Bar ──
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final isSelected = _selectedCategory == cat['key'];
                return GestureDetector(
                  onTap: () => _onCategorySelected(cat['key']!),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryGold : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryGold : AppTheme.cardBorder,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.primaryGold.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        cat['label']!,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? const Color(0xFF070710) : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Feed Posts List / Empty State ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGold),
                  )
                : RefreshIndicator(
                    onRefresh: _loadFeed,
                    color: AppTheme.primaryGold,
                    backgroundColor: AppTheme.cardBg,
                    child: _posts.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                            itemCount: _posts.length,
                            itemBuilder: (context, index) {
                              return _buildPostCard(_posts[index], index);
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Post Card Widget ──
  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final postId = post['id'] as int? ?? 0;
    final authorName = post['author_name'] ?? 'SB Cricketer';
    final authorCity = post['author_city'] ?? 'India';
    final authorRole = post['author_role'] ?? 'Cricketer';
    final authorPic = post['author_pic'];
    final content = post['content'] ?? '';
    final imageUrl = post['image_url'];
    final postType = post['post_type'] ?? 'general';
    final whatsappNumber = post['whatsapp_number'] as String? ?? '';
    final isLiked = post['is_liked'] == true;
    final likesCount = post['likes_count'] as int? ?? 0;
    final isAuthor = post['is_author'] == true;
    final timeAgo = _formatTimeAgo(post['created_at']);

    Color badgeColor = AppTheme.primaryGold;
    String badgeText = '🏏 CRICKET BUZZ';
    IconData badgeIcon = Icons.sports_cricket;

    if (postType == 'highlight') {
      badgeColor = const Color(0xFFFF9100);
      badgeText = '⚡ HIGHLIGHT';
      badgeIcon = Icons.bolt;
    } else if (postType == 'match_finder') {
      badgeColor = const Color(0xFF00E676);
      badgeText = '🤝 MATCH FINDER';
      badgeIcon = Icons.handshake;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: postType == 'match_finder'
              ? const Color(0xFF00E676).withOpacity(0.3)
              : AppTheme.cardBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Author Info & Tag ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                // Author Avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.primaryGold.withOpacity(0.5), width: 1.5),
                  ),
                  child: ClipOval(
                    child: authorPic != null && authorPic.toString().isNotEmpty
                        ? Image.network(
                            ApiService.getImageUrl(authorPic.toString()),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _buildAvatarFallback(authorName),
                          )
                        : _buildAvatarFallback(authorName),
                  ),
                ),
                const SizedBox(width: 12),
                // Author Name & Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryGold.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              authorRole,
                              style: const TextStyle(
                                color: AppTheme.primaryGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 11, color: AppTheme.textMuted),
                          const SizedBox(width: 2),
                          Text(
                            authorCity,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                          const SizedBox(width: 6),
                          Text(
                            timeAgo,
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Type Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          color: badgeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Post Text Content ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                height: 1.45,
                color: AppTheme.textPrimary,
              ),
            ),
          ),

          // ── Post Attached Image (if any) ──
          if (imageUrl != null && imageUrl.toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  ApiService.getImageUrl(imageUrl.toString()),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      height: 200,
                      color: const Color(0xFF131326),
                      child: const Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryGold),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],

          // ── Match Finder Direct WhatsApp Connect Card ──
          if (postType == 'match_finder' && whatsappNumber.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF25D366),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Looking to play a match / join squad?',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00E676),
                          ),
                        ),
                        Text(
                          'WhatsApp: +$whatsappNumber',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: Size.zero,
                    ),
                    icon: const Icon(Icons.send, size: 13, color: Colors.white),
                    label: const Text('Connect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _launchWhatsAppChat(whatsappNumber, content),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.cardBorder),

          // ── Action Bar: Likes, Comments, Share, Delete ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like Button
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _toggleLike(postId, index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? AppTheme.errorRed : AppTheme.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$likesCount',
                          style: TextStyle(
                            color: isLiked ? AppTheme.errorRed : AppTheme.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Share to WhatsApp / Friends
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _sharePost(post),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, color: AppTheme.textMuted, size: 19),
                        SizedBox(width: 6),
                        Text(
                          'Share',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // Delete Button (Author only)
                if (isAuthor)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted, size: 19),
                    tooltip: 'Delete Post',
                    onPressed: () => _deletePost(postId, index),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarFallback(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
    return Container(
      color: AppTheme.primaryGold.withOpacity(0.18),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.outfit(
            color: AppTheme.primaryGold,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  // ── Ultra-Modern Empty State ──
  Widget _buildEmptyState() {
    String emptyTitle = 'No Community Posts Yet';
    String emptySubtitle = 'Be the first to share match highlights, organize a cricket match, or find players in your area!';

    if (_selectedCategory == 'highlights') {
      emptyTitle = 'No Match Highlights Yet';
      emptySubtitle = 'Share sixes, wickets, and match celebration moments with the cricket community!';
    } else if (_selectedCategory == 'match_finder') {
      emptyTitle = 'No Match & Player Requests';
      emptySubtitle = 'Need an opponent team for Sunday match? Or short of 2 players? Post a Match Finder request!';
    }

    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGold.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.primaryGold.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(
                  Icons.sports_cricket,
                  size: 38,
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryGold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGold,
                  foregroundColor: const Color(0xFF070710),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add, size: 20, color: Color(0xFF070710)),
                label: Text(
                  'Post First Update ✍️',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                onPressed: _openCreatePostModal,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── CREATE POST MODAL BOTTOM SHEET ──
class _CreatePostBottomSheet extends StatefulWidget {
  final VoidCallback onPostCreated;

  const _CreatePostBottomSheet({required this.onPostCreated});

  @override
  State<_CreatePostBottomSheet> createState() => _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends State<_CreatePostBottomSheet> {
  final ApiService _apiService = ApiService();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  String _postType = 'general'; // 'general', 'highlight', 'match_finder'
  XFile? _selectedImage;
  bool _isSubmitting = false;

  void _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      setState(() => _selectedImage = picked);
    }
  }

  void _submitPost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your post message')),
      );
      return;
    }

    if (_postType == 'match_finder' && _whatsappController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide your WhatsApp number for teams to reach you')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      MultipartFile? imageFile;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();
        imageFile = MultipartFile.fromBytes(bytes, filename: _selectedImage!.name);
      }

      final res = await _apiService.createFeedPost(
        content: text,
        postType: _postType,
        whatsappNumber: _whatsappController.text.trim(),
        imageFile: imageFile,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (res['success'] == true) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Post published! 🎉')),
          );
          widget.onPostCreated();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Failed to publish post')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error creating post. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 18,
        right: 18,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share Cricket Update 🏏',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Post Type Selector
            Text(
              'Select Post Category:',
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildTypeChip('general', '🏏 Cricket Buzz'),
                const SizedBox(width: 8),
                _buildTypeChip('highlight', '⚡ Highlight'),
                const SizedBox(width: 8),
                _buildTypeChip('match_finder', '🤝 Match Finder'),
              ],
            ),
            const SizedBox(height: 16),

            // Text Field
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: _postType == 'match_finder'
                    ? 'E.g., Sunday 7 AM match available at Ground A. Looking for opponent team or 2 all-rounders!'
                    : (_postType == 'highlight'
                        ? 'E.g., What a finish! Scored 24 off the last over to win the championship! 🏆⚡'
                        : 'Share tournament updates, match thoughts, squad news, or player achievements...'),
                hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
              ),
            ),
            const SizedBox(height: 14),

            // WhatsApp Number Field (if match_finder)
            if (_postType == 'match_finder') ...[
              TextField(
                controller: _whatsappController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'WhatsApp Mobile Number',
                  hintText: '9876543210 (Teams will reach you directly)',
                  prefixIcon: Icon(Icons.chat, color: Color(0xFF25D366)),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Photo Preview & Attachment
            if (_selectedImage != null) ...[
              Stack(
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FutureBuilder<Uint8List>(
                        future: _selectedImage!.readAsBytes(),
                        builder: (ctx, snap) {
                          if (snap.hasData) {
                            return Image.memory(snap.data!, fit: BoxFit.cover);
                          }
                          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGold));
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Action Buttons (Add Photo & Publish)
            Row(
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGold,
                    side: const BorderSide(color: AppTheme.cardBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add_photo_alternate, size: 20),
                  label: Text(_selectedImage == null ? 'Add Photo' : 'Change Photo', style: const TextStyle(fontSize: 13)),
                  onPressed: _pickImage,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGold,
                      foregroundColor: const Color(0xFF070710),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSubmitting ? null : _submitPost,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF070710)),
                          )
                        : Text(
                            'Publish Post 🚀',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _postType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _postType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryGold.withOpacity(0.18) : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primaryGold : AppTheme.cardBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primaryGold : AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
