import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../state/session_state.dart';
import '../../services/api.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import 'account_settings_screen.dart';
import 'case_history_screen.dart';
import 'leaderboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool showBackButton;

  const ProfileScreen({super.key, this.showBackButton = false});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Avatar emoji map matching SHOP_ITEMS
  static const Map<String, String> _avatarEmojis = {
    'avatar_docteur': '🩺',
    'avatar_chirurgien': '🧑‍⚕️',
    'avatar_scientifique': '🔬',
    'avatar_gold': '🥇',
    'avatar_ninja': '🥷',
    'avatar_diamond': '💎',
    'avatar_robot': '🤖',
    'avatar_crown': '👑',
  };

  List<dynamic> _ownedAvatars = [];
  String? _activeAvatarId;
  String _rankLabel = '--';
  String _activityLabel = 'Régulier';
  int _totalTrophies = 0;

  static const int _trophiesPerLevel = 10;

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _loadProfileMeta();
  }

  Future<void> _loadProfileMeta() async {
    try {
      final state = Provider.of<SessionState>(context, listen: false);
      final userId = state.userId;
      if (userId == null || userId.trim().isEmpty) return;

      final results = await Future.wait([
        Api.getGamification(),
        Api.getLeaderboard(),
        Api.getSessions(userId: userId),
      ]);

      final gamification = results[0] as Map<String, dynamic>;
      final leaderboard = results[1] as List<dynamic>;
      final sessions = results[2] as List<dynamic>;

      final trophies =
          (gamification['trophies'] is num)
              ? (gamification['trophies'] as num).toInt()
              : int.tryParse((gamification['trophies'] ?? 0).toString()) ?? 0;
      final xp =
          (gamification['xp'] is num)
              ? (gamification['xp'] as num).toInt()
              : int.tryParse((gamification['xp'] ?? 0).toString()) ?? 0;
      final level =
          (gamification['level'] is num)
              ? (gamification['level'] as num).toInt()
              : int.tryParse((gamification['level'] ?? 1).toString()) ?? 1;

      final rawBadges = (gamification['badges'] as List<dynamic>?) ?? [];
      final badges =
          rawBadges
              .whereType<Map>()
              .map((b) => Map<String, dynamic>.from(b))
              .toList();

      state.updateProfile(xp: xp, level: level, badges: badges);

      String rank = '--';
      final idx = leaderboard.indexWhere(
        (u) => (u is Map && (u['user_id'] ?? '').toString() == userId),
      );
      if (idx >= 0) {
        final total = leaderboard.length;
        final percentile = ((idx + 1) / (total == 0 ? 1 : total)) * 100;
        rank = 'Top ${percentile.ceil()}%';
      }

      final now = DateTime.now();
      final activeDays = <String>{};
      for (final s in sessions) {
        if (s is! Map) continue;
        final rawDate = (s['created_at'] ?? '').toString();
        final dt = DateTime.tryParse(rawDate);
        if (dt == null) continue;
        final diff = now.difference(dt.toLocal()).inDays;
        if (diff >= 0 && diff <= 6) {
          final key = '${dt.year}-${dt.month}-${dt.day}';
          activeDays.add(key);
        }
      }

      String activity = 'Régulier';
      if (activeDays.length >= 5) {
        activity = 'Quotidien';
      } else if (activeDays.length >= 3) {
        activity = 'Fréquent';
      }

      if (!mounted) return;
      setState(() {
        _rankLabel = rank;
        _activityLabel = activity;
        _totalTrophies = trophies;
      });

      // Partager trophées et classement avec le reste de l'app (UserProfileBar, etc.)
      state.setTrophiesAndRank(trophies: trophies, rankLabel: rank);
    } catch (_) {
      // Keep defaults when profile meta cannot be loaded.
    }
  }

  Future<void> _loadInventory() async {
    try {
      final inv = await Api.getInventory();
      final owned =
          (inv['ownedItems'] as List<dynamic>?)
              ?.where((i) => i['category'] == 'avatar')
              .toList() ??
          [];
      if (!mounted) return;
      final state = Provider.of<SessionState>(context, listen: false);
      setState(() {
        _ownedAvatars = owned;
        _activeAvatarId = inv['activeAvatarId'] as String?;
      });
      state.updateProfile(
        avatarId: _activeAvatarId,
        activeTitle: inv['activeTitleId'] as String?,
        hintBalance: (inv['hintBalance'] ?? 0) as int,
      );
    } catch (_) {}
  }

  void _showAvatarPicker(BuildContext context) {
    final state = Provider.of<SessionState>(context, listen: false);
    final isFr = state.isFrench;
    final starterAvatars = [
      {'id': 'avatar_docteur', 'name': isFr ? 'Docteur' : 'Doctor'},
      {'id': 'avatar_chirurgien', 'name': isFr ? 'Chirurgien' : 'Surgeon'},
      {
        'id': 'avatar_scientifique',
        'name': isFr ? 'Scientifique' : 'Scientist',
      },
    ];
    final ownedIds =
        _ownedAvatars
            .map((e) => (e as Map<String, dynamic>)['id']?.toString() ?? '')
            .toSet();
    final available = [
      ...starterAvatars.where(
        (s) => !ownedIds.contains((s['id'] ?? '').toString()),
      ),
      ..._ownedAvatars.cast<Map<String, dynamic>>(),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isFr ? 'Choisir un Avatar' : 'Choose Avatar',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isFr
                    ? 'Choisissez votre image de profil'
                    : 'Choose your profile image',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: available.length + 1, // +1 for default
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Default avatar (initial)
                      final isActive = _activeAvatarId == null;
                      return _buildAvatarOption(
                        ctx,
                        null,
                        state.userName?.isNotEmpty == true
                            ? state.userName![0].toUpperCase()
                            : 'U',
                        isFr ? 'Par défaut' : 'Default',
                        isActive,
                        false,
                      );
                    }
                    final item = available[index - 1];
                    final id = item['id'] as String;
                    final isOwned = ownedIds.contains(id);
                    final isActive = _activeAvatarId == id;
                    return _buildAvatarOption(
                      ctx,
                      id,
                      _avatarEmojis[id] ?? '🎭',
                      isFr
                          ? (item['name'] ?? '')
                          : (item['name_en'] ?? item['name'] ?? ''),
                      isActive,
                      !isOwned,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarOption(
    BuildContext ctx,
    String? avatarId,
    String display,
    String label,
    bool isActive,
    bool localOnly,
  ) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(ctx);
        if (avatarId == null) {
          // Unequip — set to default
          setState(() => _activeAvatarId = null);
          final state = Provider.of<SessionState>(context, listen: false);
          state.updateProfile(avatarId: '');
          return;
        }
        try {
          if (!localOnly) {
            await Api.equipItem(avatarId);
          }
          if (!mounted) return;
          setState(() => _activeAvatarId = avatarId);
          final state = Provider.of<SessionState>(context, listen: false);
          state.updateProfile(avatarId: avatarId);
        } catch (_) {}
      },
      child: Container(
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isActive ? 2.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              display,
              style: TextStyle(fontSize: avatarId == null ? 32 : 38),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? AppColors.primary : const Color(0xFF94A3B8),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (isActive) ...[
              const SizedBox(height: 2),
              const Icon(LucideIcons.check, color: AppColors.primary, size: 14),
            ],
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final state = Provider.of<SessionState>(context, listen: false);
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              state.t('Langue', 'Language'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _languageOption(ctx, state, 'fr', '🇫🇷', 'Français'),
                const SizedBox(height: 8),
                _languageOption(ctx, state, 'en', '🇬🇧', 'English'),
              ],
            ),
          ),
    );
  }

  String _levelStatus(int level, bool isFr) {
    if (level >= 8) return isFr ? 'Médecin Senior' : 'Senior Physician';
    if (level >= 5) return isFr ? 'Médecin' : 'Physician';
    if (level >= 3) return isFr ? 'Interne' : 'Resident';
    return isFr ? 'Étudiant' : 'Student';
  }


  Widget _languageOption(
    BuildContext ctx,
    SessionState state,
    String locale,
    String flag,
    String label,
  ) {
    final isSelected = state.locale == locale;
    return InkWell(
      onTap: () {
        state.setLocale(locale);
        Api.updateProfile({'locale': locale});
        Navigator.pop(ctx);
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              locale == 'fr' ? 'Langue: Français' : 'Language: English',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color:
                      isSelected ? AppColors.primary : const Color(0xFF475569),
                ),
              ),
            ),
            if (isSelected)
              const Icon(LucideIcons.check, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileExperienceCard(
    SessionState state,
    String name,
    String profileType,
    String status,
    bool isFr,
  ) {
    final trophies = _totalTrophies;
    final xp = state.xp;
    final level = (trophies ~/ _trophiesPerLevel) + 1;
    final currentLevelFloor = (level - 1) * _trophiesPerLevel;
    final nextLevelCap = level * _trophiesPerLevel;
    final trophiesInLevel = (trophies - currentLevelFloor).clamp(
      0,
      _trophiesPerLevel,
    );
    final progress =
        (trophiesInLevel / _trophiesPerLevel).clamp(0, 1).toDouble();
    final trophiesToNext = (nextLevelCap - trophies).clamp(0, 999999);
    final awards = state.badges.length;
    final progressPercent = (progress * 100).toStringAsFixed(0);
    final nextLevel = level + 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final compact = screenWidth < 390;
    final avatarSize = compact ? 78.0 : 90.0;
    final nameFontSize = compact ? 20.0 : 24.0;
    final roleFontSize = compact ? 12.0 : 13.0;
    final badgeFontSize = compact ? 10.0 : 11.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -25,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E88E5).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -26,
            bottom: -24,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.10),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF6FBFF)],
              ),
              border: Border.all(color: const Color(0xFFD9ECFF), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.10),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6DBDFF), Color(0xFF1E88E5)],
                            ),
                          ),
                          padding: const EdgeInsets.all(3),
                          child: ClipOval(
                            child: Container(
                              color: const Color(0xFFEAF5FF),
                              child: Center(
                                child:
                                    _activeAvatarId != null &&
                                            _avatarEmojis.containsKey(
                                              _activeAvatarId,
                                            )
                                        ? Text(
                                          _avatarEmojis[_activeAvatarId]!,
                                          style: TextStyle(
                                            fontSize: compact ? 32 : 38,
                                          ),
                                        )
                                        : Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : 'U',
                                          style: GoogleFonts.outfit(
                                            fontSize: compact ? 29 : 34,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                          ),
                                        ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -3,
                          bottom: -2,
                          child: GestureDetector(
                            onTap: () => _showAvatarPicker(context),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                              ),
                              child: const Icon(
                                LucideIcons.pencil,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(width: compact ? 10 : 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: nameFontSize,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF172554),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            profileType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: roleFontSize,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE7F4FF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              status,
                              style: GoogleFonts.outfit(
                                fontSize: badgeFontSize,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF8FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFCAE7FF)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDDF0FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                LucideIcons.layers,
                                size: 16,
                                color: Color(0xFF0C4A6E),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${isFr ? 'Niveau' : 'Level'} $level',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    '$trophies trophées',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F3FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFDCD7FF)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Center(
                                child: Text('🪙', style: TextStyle(fontSize: 18)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$xp XP',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    isFr ? 'XP disponible' : 'Available XP',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6D28D9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isFr
                          ? 'Progression vers le prochain niveau'
                          : 'Progress to next level',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF334155),
                      ),
                    ),
                    Text(
                      '$progressPercent%',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Stack(
                    children: [
                      Container(height: 12, color: const Color(0xFFE2E8F0)),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 850),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return FractionallySizedBox(
                            widthFactor: value,
                            child: Container(
                              height: 12,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0EA5E9),
                                    Color(0xFF22D3EE),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$trophies / $nextLevelCap trophées',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      isFr
                          ? '$trophiesToNext trophées pour Niv. $nextLevel'
                          : '$trophiesToNext trophies to Lvl $nextLevel',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _profileStatTile(
                        icon: LucideIcons.badgePercent,
                        label: 'Rank',
                        value: _rankLabel,
                        bg: const Color(0xFFEFF6FF),
                        iconColor: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _profileStatTile(
                        icon: LucideIcons.activity,
                        label: isFr ? 'Actif' : 'Active',
                        value: _activityLabel,
                        bg: const Color(0xFFECFDF5),
                        iconColor: const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _profileStatTile(
                        icon: LucideIcons.award,
                        label: isFr ? 'Récompenses' : 'Awards',
                        value: '$awards',
                        bg: const Color(0xFFF5F3FF),
                        iconColor: const Color(0xFF7C3AED),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color bg,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<SessionState>(context);
    final name = state.userName ?? 'Utilisateur';
    final profileType = state.profileType ?? 'Étudiant';
    final isFr = state.isFrench;
    final effectiveLevel = (_totalTrophies ~/ _trophiesPerLevel) + 1;
    final status = _levelStatus(effectiveLevel, isFr);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              if (widget.showBackButton)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(LucideIcons.chevronLeft),
                        tooltip: state.t('Retour', 'Back'),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.t('Profil', 'Profile'),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              _buildProfileExperienceCard(
                state,
                name,
                profileType,
                status,
                isFr,
              ),
              const SizedBox(height: 16),

              // Menu Options
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildMenuOption(
                      icon: LucideIcons.userPlus,
                      label: state.t(
                        'Paramètres du compte',
                        'Account Settings',
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const AccountSettingsScreen(),
                          ),
                        );
                      },
                      color: AppColors.iconBlueBg,
                      iconColor: AppColors.primary,
                    ),
                    _buildMenuOption(
                      icon: LucideIcons.userCheck,
                      label: state.t('Langue', 'Language'),
                      trailing: state.isFrench ? 'Français' : 'English',
                      onTap: () => _showLanguageDialog(context),
                      color: const Color(0xFFF3E8FF),
                      iconColor: const Color(0xFFA855F7),
                    ),
                    _buildMenuOption(
                      icon: LucideIcons.history,
                      label: state.t('Historique des cas', 'Case History'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const CaseHistoryScreen(),
                          ),
                        );
                      },
                      color: AppColors.iconOrangeBg,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                    _buildMenuOption(
                      icon: LucideIcons.trophy,
                      label: state.t('Classement', 'Leaderboard'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const LeaderboardScreen(),
                          ),
                        );
                      },
                      color: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFF59E0B),
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xFFF1F5F9),
                      indent: 70,
                    ),
                    _buildMenuOption(
                      icon: LucideIcons.logOut,
                      label: state.t('Déconnexion', 'Log Out'),
                      onTap: () {
                        final ss = Provider.of<SessionState>(
                          context,
                          listen: false,
                        );
                        ss.logout();
                        Api.setToken(null);
                        NotificationService().stopListening();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      color: AppColors.iconRedBg,
                      iconColor: const Color(0xFFEF4444),
                      isDestructive: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption({
    required IconData icon,
    required String label,
    String? trailing,
    required VoidCallback onTap,
    required Color color,
    required Color iconColor,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color:
                      isDestructive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1E293B),
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            const SizedBox(width: 12),
            const Icon(
              LucideIcons.chevronRight,
              color: Color(0xFFCBD5E1),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
