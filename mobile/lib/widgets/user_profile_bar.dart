import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../state/session_state.dart';

class UserProfileBar extends StatelessWidget {
  const UserProfileBar({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final isFr = session.isFrench;
    final hints = session.hintBalance;
    final streakDays = session.streak;
    final topLabel = session.rankLabel;
    final trophies = session.trophies;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildInfoPill(
                emoji: '⭐',
                label: isFr ? 'Étoiles' : 'Stars',
                value: '$trophies',
              ),
              const SizedBox(width: 10),
              _buildInfoPill(
                emoji: '🪙',
                label: 'XP',
                value: '${session.xp}',
              ),
              const SizedBox(width: 10),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    const Center(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: Color(0xFFF59E0B),
                        size: 28,
                      ),
                    ),
                    Positioned(
                      right: 7,
                      bottom: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFF2D7A3)),
                        ),
                        child: Text(
                          '$trophies',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF16324A),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: _StreakChip(streakDays: streakDays)),
              const SizedBox(width: 6),
              Flexible(
                child: _BadgeChip(
                  icon: Icons.stars_rounded,
                  text: 'Top $topLabel',
                  bgColor: const Color(0xFFEEF6FF),
                  fgColor: const Color(0xFF2B83F6),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: _BadgeChip(
                  icon: Icons.lightbulb_rounded,
                  text: '$hints 💡',
                  bgColor: const Color(0xFFFFF9EC),
                  fgColor: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPill({
    String? emoji,
    IconData? icon,
    Color? iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FBFE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8F0F8)),
        ),
        child: Row(
          children: [
            if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 16))
            else if (icon != null)
              Icon(icon, size: 17, color: iconColor),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6A7E90),
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16324A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streakDays});
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final isHot = streakDays >= 3;
    final session = context.watch<SessionState>();
    final isFr = session.isFrench;
    final label = streakDays == 0
        ? (isFr ? 'Aucune série' : 'No streak')
        : (isFr ? 'Série $streakDays j' : '$streakDays day streak');

    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isHot ? const Color(0xFFFFEFE8) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: isHot ? Border.all(color: const Color(0xFFFF6B35).withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: isHot ? const Color(0xFFFF6B35) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isHot ? const Color(0xFFFF6B35) : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );

    if (isHot) {
      chip = chip
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1.0, end: 1.04, duration: 800.ms, curve: Curves.easeInOut);
    }

    return chip;
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.icon,
    required this.text,
    required this.bgColor,
    required this.fgColor,
  });

  final IconData icon;
  final String text;
  final Color bgColor;
  final Color fgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: fgColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
