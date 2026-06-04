import 'package:flutter/material.dart';

class ImmersiveRecapBar extends StatelessWidget {
  const ImmersiveRecapBar({
    super.key,
    required this.title,
    required this.avatarLetter,
    required this.level,
    required this.xp,
    required this.lives,
    required this.trophies,
    required this.topPercent,
    required this.streakDays,
    this.accent = const Color(0xFF2E7CA5),
  });

  final String title;
  final String? avatarLetter;
  final int level;
  final int xp;
  final int lives;
  final int trophies;
  final int topPercent;
  final int streakDays;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF1F9FF)],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5EAF8), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.45), width: 3),
                  color: const Color(0xFF0E2234),
                ),
                child: Center(
                  child: Text(
                    avatarLetter ?? 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2F44),
                  ),
                ),
              ),
              _Pill(
                icon: Icons.workspace_premium,
                iconColor: const Color(0xFFF59E0B),
                text: '$trophies',
                borderColor: const Color(0xFFFDE4B2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Pill(
                  icon: Icons.layers_rounded,
                  iconColor: const Color(0xFF2563EB),
                  text: 'Niv. $level',
                  borderColor: const Color(0xFFCFE0FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  icon: Icons.bolt,
                  iconColor: const Color(0xFFF59E0B),
                  text: '$xp XP',
                  borderColor: const Color(0xFFFDE4B2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pill(
                  icon: Icons.favorite,
                  iconColor: const Color(0xFFF43F5E),
                  text: '$lives vies',
                  borderColor: const Color(0xFFFBD2DC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _Tag(
                  icon: Icons.local_fire_department_rounded,
                  text: 'Serie $streakDays',
                  color: const Color(0xFFEA580C),
                  bg: const Color(0xFFFFEEE4),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Tag(
                  icon: Icons.stars_rounded,
                  text: 'Top $topPercent%',
                  color: const Color(0xFF2563EB),
                  bg: const Color(0xFFEFF6FF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.iconColor,
    required this.text,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final String text;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFDFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2A37),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({
    required this.icon,
    required this.text,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
