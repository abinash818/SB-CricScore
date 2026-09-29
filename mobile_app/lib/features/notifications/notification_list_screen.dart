import 'package:flutter/material.dart';
import '../../core/api_service.dart';
import '../match/live_match_viewer_screen.dart';
import '../match/full_scorecard_screen.dart';
import '../tournament/tournament_detail_screen.dart';

class NotificationListScreen extends StatefulWidget {
  const NotificationListScreen({super.key});

  @override
  State<NotificationListScreen> createState() => _NotificationListScreenState();
}

class _NotificationListScreenState extends State<NotificationListScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;

  List<dynamic> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _apiService.getNotifications();
      if (res['success'] == true) {
        setState(() {
          _notifications = res['notifications'] ?? [];
          _unreadCount = res['unread_count'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res['message'] ?? 'Failed to load notifications';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading notifications: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _apiService.markNotificationRead();
      _loadNotifications();
    } catch (_) {}
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _unreadCount > 0 ? '🔔 Notifications ($_unreadCount)' : '🔔 Notifications & Alerts',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read', style: TextStyle(color: goldColor, fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: goldColor))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadNotifications,
                        style: ElevatedButton.styleFrom(backgroundColor: goldColor),
                        child: const Text('Retry', style: TextStyle(color: Colors.black)),
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          const Text('No Notifications Yet', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          const SizedBox(height: 6),
                          const Text('Live match alerts & updates will appear here', style: TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: goldColor,
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final item = _notifications[index];
                          final int id = int.tryParse(item['id'].toString()) ?? 0;
                          final String title = item['title'] ?? 'Alert';
                          final String body = item['body'] ?? '';
                          final String type = item['type'] ?? 'system';
                          final bool isRead = (int.tryParse(item['is_read']?.toString() ?? '0') ?? 0) == 1;
                          final int targetId = int.tryParse(item['target_id']?.toString() ?? '0') ?? 0;

                          IconData iconData = Icons.notifications;
                          Color iconColor = goldColor;
                          if (type == 'match') {
                            iconData = Icons.sports_cricket;
                            iconColor = Colors.redAccent;
                          } else if (type == 'result') {
                            iconData = Icons.emoji_events;
                            iconColor = Colors.greenAccent;
                          } else if (type == 'milestone') {
                            iconData = Icons.star;
                            iconColor = Colors.orangeAccent;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: isRead ? cardBg : goldColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isRead ? goldColor.withValues(alpha: 0.15) : goldColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(14),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: iconColor.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: iconColor.withValues(alpha: 0.4)),
                                ),
                                child: Center(
                                  child: Icon(iconData, color: iconColor, size: 22),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      title,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: goldColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6.0),
                                child: Text(
                                  body,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              onTap: () async {
                                if (!isRead) {
                                  await _apiService.markNotificationRead(notificationId: id);
                                }
                                if (targetId > 0) {
                                  if (type == 'match') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => LiveMatchViewerScreen(matchId: targetId)),
                                    );
                                  } else if (type == 'result') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => FullScorecardScreen(matchId: targetId)),
                                    );
                                  } else if (type == 'tournament') {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => TournamentDetailScreen(tournamentId: targetId)),
                                    );
                                  }
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
