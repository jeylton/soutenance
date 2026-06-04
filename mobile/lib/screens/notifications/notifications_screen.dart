import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await Api.getNotifications();
      setState(() {
        _notifications = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(int id, int index) async {
    try {
      await Api.markNotificationRead(id);
      setState(() {
        _notifications[index] = {
          ..._notifications[index] as Map<String, dynamic>,
          'read': true,
        };
      });
      Provider.of<NotificationService>(
        context,
        listen: false,
      ).decrementUnread();
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await Api.markAllNotificationsRead();
      setState(() {
        _notifications =
            _notifications.map((n) {
              final m = Map<String, dynamic>.from(n as Map<String, dynamic>);
              m['read'] = true;
              return m;
            }).toList();
      });
      Provider.of<NotificationService>(context, listen: false).markAllRead();
    } catch (_) {}
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'feedback':
        return LucideIcons.messageSquare;
      case 'badge':
        return LucideIcons.award;
      case 'xp':
        return LucideIcons.coins;
      case 'exam':
        return LucideIcons.clipboardCheck;
      default:
        return LucideIcons.bell;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'feedback':
        return const Color(0xFF3B82F6);
      case 'badge':
        return const Color(0xFFF59E0B);
      case 'xp':
        return const Color(0xFFF59E0B);
      case 'exam':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['read'] != true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Tout lire',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.bellOff,
                      size: 64,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune notification',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadNotifications,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index] as Map<String, dynamic>;
                    final isRead = notif['read'] == true;
                    final type = notif['type'] as String?;
                    final createdAt =
                        notif['created_at'] != null
                            ? DateTime.tryParse(notif['created_at'].toString())
                            : null;
                    final timeAgo =
                        createdAt != null ? _formatTimeAgo(createdAt) : '';

                    return GestureDetector(
                      onTap: () {
                        if (!isRead && notif['id'] != null) {
                          _markAsRead(notif['id'] as int, index);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              isRead ? Colors.white : const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isRead
                                    ? AppColors.border
                                    : AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _colorForType(type).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                _iconForType(type),
                                color: _colorForType(type),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notif['title'] ?? 'Notification',
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight:
                                          isRead
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (notif['body'] != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      notif['body'].toString(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF64748B),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    timeAgo,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
    return '${date.day}/${date.month}/${date.year}';
  }
}
