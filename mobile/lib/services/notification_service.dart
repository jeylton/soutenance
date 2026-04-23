import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service de notifications en temps réel via Supabase Realtime.
/// Écoute les INSERT sur la table `notifications` pour l'utilisateur connecté.
class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  RealtimeChannel? _channel;
  String? _userId;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  final List<Map<String, dynamic>> _recentNotifications = [];
  List<Map<String, dynamic>> get recentNotifications =>
      List.unmodifiable(_recentNotifications);

  /// Stream contrôleur pour les nouvelles notifications (pour les listeners ponctuels)
  final _newNotifController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewNotification =>
      _newNotifController.stream;

  /// Initialise l'écoute en temps réel pour un utilisateur donné.
  void startListening(String userId) {
    if (_userId == userId && _channel != null) return; // already listening
    stopListening();
    _userId = userId;

    final supabase = Supabase.instance.client;

    _channel = supabase.channel('notifications:$userId').onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'notifications',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (payload) {
        final newRow = payload.newRecord;
        if (newRow.isNotEmpty) {
          _recentNotifications.insert(0, Map<String, dynamic>.from(newRow));
          // Keep only last 50
          if (_recentNotifications.length > 50) {
            _recentNotifications.removeLast();
          }
          if (newRow['read'] != true) {
            _unreadCount++;
          }
          _newNotifController.add(Map<String, dynamic>.from(newRow));
          notifyListeners();
        }
      },
    ).subscribe();

    // Load initial unread count
    _loadUnreadCount(userId);
  }

  Future<void> _loadUnreadCount(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);
      _unreadCount = (response as List).length;
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationService: failed to load unread count: $e');
    }
  }

  /// Met à jour le compteur quand l'utilisateur lit des notifications
  void decrementUnread([int by = 1]) {
    _unreadCount = (_unreadCount - by).clamp(0, 9999);
    notifyListeners();
  }

  void markAllRead() {
    _unreadCount = 0;
    for (final n in _recentNotifications) {
      n['read'] = true;
    }
    notifyListeners();
  }

  /// Rafraîchit le compteur non-lu depuis la BD
  Future<void> refreshUnreadCount() async {
    if (_userId != null) {
      await _loadUnreadCount(_userId!);
    }
  }

  /// Arrête l'écoute (déconnexion)
  void stopListening() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
      _channel = null;
    }
    _userId = null;
    _unreadCount = 0;
    _recentNotifications.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    stopListening();
    _newNotifController.close();
    super.dispose();
  }
}
