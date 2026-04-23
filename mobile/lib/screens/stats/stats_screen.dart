import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';
import '../profile/leaderboard_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<dynamic> _sessions = [];
  List<dynamic> _quizAttempts = [];
  List<dynamic> _leaderboard = [];
  Map<String, dynamic> _gamification = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.getSessions(),
        Api.getGamification(),
        Api.getLeaderboard(),
        Api.getQuizAttempts(),
      ]);
      final state = Provider.of<SessionState>(context, listen: false);
      final gam = results[1] as Map<String, dynamic>;
      state.updateProfile(
        xp: (gam['xp'] ?? 0) as int,
        level: (gam['level'] ?? 1) as int,
      );
      setState(() {
        _sessions = results[0] as List<dynamic>;
        _gamification = gam;
        _leaderboard = results[2] as List<dynamic>;
        _quizAttempts = results[3] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = _sessions.where((s) => s['score'] != null).toList();
    final totalScore = completed.fold<double>(
      0,
      (sum, s) => sum + ((s['score'] ?? 0) as num).toDouble(),
    );
    final quizBonus = _quizAttempts.fold<double>(
      0,
      (sum, a) =>
          sum +
          (((a as Map<String, dynamic>)['points_earned'] ?? 0) as num)
              .toDouble(),
    );
    final globalScore = totalScore + quizBonus;
    final avgScore =
        completed.isNotEmpty ? (totalScore / completed.length) : 0.0;
    final quizAvgPercent =
        _quizAttempts.isEmpty
            ? 0.0
            : _quizAttempts.fold<double>(
                  0,
                  (sum, a) =>
                      sum +
                      ((((a as Map<String, dynamic>)['accuracy'] ?? 0) as num)
                          .toDouble()),
                ) /
                _quizAttempts.length;
    // ignore: unused_local_variable
    final avgPercent = (avgScore * 5).round(); // score/20 → percentage
    final totalRuns = completed.length + _quizAttempts.length;
    final globalPercent =
        totalRuns == 0
            ? 0.0
            : ((avgPercent.toDouble() * completed.length) +
                    (quizAvgPercent * _quizAttempts.length)) /
                totalRuns;

    // last 5 sessions
    final last5 = completed.length > 5 ? completed.sublist(0, 5) : completed;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Text(
                  'Tableau des Scores',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),

                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(60),
                      child: CircularProgressIndicator(),
                    ),
                  ),

                if (!_loading) ...[
                  // Top Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SCORE GLOBAL',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withOpacity(0.8),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    totalRuns == 0
                                        ? '—'
                                        : globalPercent.toStringAsFixed(1),
                                    style: GoogleFonts.outfit(
                                      fontSize: 48,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    totalRuns == 0 ? '' : ' %',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          height: 60,
                          width: 1,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'POINTS TOTAUX',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withOpacity(0.8),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${globalScore.round()}',
                                style: GoogleFonts.outfit(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildKpiChip(
                        'Cas: ${completed.length}',
                        LucideIcons.stethoscope,
                      ),
                      _buildKpiChip(
                        'Quiz: ${_quizAttempts.length}',
                        LucideIcons.graduationCap,
                      ),
                      _buildKpiChip(
                        'Bonus quiz: ${quizBonus.round()}',
                        LucideIcons.sparkles,
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  // Progression
                  if (last5.isNotEmpty) ...[
                    _buildSectionTitle(
                      'PROGRESSION (${last5.length} DERNIÈRES)',
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: SizedBox(
                        height: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children:
                              last5.reversed.toList().asMap().entries.map((
                                entry,
                              ) {
                                final s = entry.value;
                                final score =
                                    ((s['score'] ?? 0) as num).toDouble();
                                final pct = (score / 20 * 100).clamp(
                                  0.0,
                                  100.0,
                                );
                                return _buildBar(
                                  pct,
                                  '${score.toStringAsFixed(0)}',
                                  isLatest: entry.key == last5.length - 1,
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],

                  // Recent Scores
                  if (completed.isNotEmpty) ...[
                    _buildSectionTitle('SCORES RÉCENTS'),
                    const SizedBox(height: 24),
                    ...completed.take(5).map((s) {
                      final score = ((s['score'] ?? 0) as num).toDouble();
                      final pct = (score / 20 * 100).round();
                      final good = score >= 10;
                      return _buildRecentScoreItem(
                        title: 'Session #${s['id']}',
                        time: _formatDate(s['created_at']),
                        score: '$pct%',
                        statusIcon:
                            good
                                ? LucideIcons.checkCircle2
                                : LucideIcons.alertCircle,
                        statusColor:
                            good
                                ? const Color(0xFF00C88C)
                                : const Color(0xFFF59E0B),
                      );
                    }),
                  ],

                  if (completed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              LucideIcons.barChart2,
                              size: 48,
                              color: const Color(0xFF94A3B8),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Aucune session terminée',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Les scores apparaîtront ici après vos simulations',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ─── Gamification Section ───
                  const SizedBox(height: 24),
                  _buildSectionTitle('PROGRESSION'),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Text(
                                  '${_gamification['level'] ?? 1}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Niveau ${_gamification['level'] ?? 1}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_gamification['xp'] ?? 0} XP',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              LucideIcons.trophy,
                              color: Color(0xFFF59E0B),
                              size: 28,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value:
                                ((_gamification['xp'] ?? 0) as int) %
                                500 /
                                500.0,
                            minHeight: 8,
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${((_gamification['xp'] ?? 0) as int) % 500}/500 XP pour le niveau suivant',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badges
                  if ((_gamification['badges'] as List?)?.isNotEmpty ??
                      false) ...[
                    const SizedBox(height: 24),
                    _buildSectionTitle('BADGES OBTENUS'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children:
                          (_gamification['badges'] as List).map((b) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    b['icon'] ?? '🏅',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    b['name'] ?? '',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                    ),
                  ],

                  // Leaderboard — Top 5 mini classement
                  if (_leaderboard.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildSectionTitle('TOP 5 CLASSEMENT'),
                        const Spacer(),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const LeaderboardScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text(
                                Provider.of<SessionState>(
                                  context,
                                  listen: false,
                                ).t('Voir tout', 'See all'),
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                LucideIcons.chevronRight,
                                size: 14,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Mini podium for top 3
                    if (_leaderboard.length >= 3)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildMiniPodiumUser(_leaderboard[1], 2, 60),
                            _buildMiniPodiumUser(_leaderboard[0], 1, 80),
                            _buildMiniPodiumUser(_leaderboard[2], 3, 50),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),

                    // Ranks 4 & 5
                    ..._leaderboard
                        .skip(3)
                        .take(2)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                          final rank = entry.key + 4;
                          final u = entry.value as Map<String, dynamic>;
                          final userInfo = u['users'] as Map<String, dynamic>?;
                          final name =
                              userInfo?['full_name'] ??
                              u['full_name'] ??
                              'Anonyme';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    '#$rank',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.iconBlueBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      name.isNotEmpty
                                          ? name[0].toUpperCase()
                                          : '?',
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${u['xp'] ?? 0} XP',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                  ],
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final d = DateTime.parse(date.toString());
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return date.toString();
    }
  }

  Widget _buildKpiChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF334155)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: const Color(0xFF94A3B8),
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildMiniPodiumUser(dynamic userData, int rank, double height) {
    final u = userData as Map<String, dynamic>;
    final userInfo = u['users'] as Map<String, dynamic>?;
    final name = userInfo?['full_name'] ?? u['full_name'] ?? 'Anonyme';
    final medal =
        rank == 1
            ? '🥇'
            : rank == 2
            ? '🥈'
            : '🥉';
    final xp = u['xp'] ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  rank == 1
                      ? const Color(0xFFFFD700)
                      : Colors.white.withOpacity(0.4),
              width: rank == 1 ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 70,
          child: Text(
            name.split(' ').first,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '$xp XP',
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 6),
        // Podium bar
        Container(
          width: 56,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(rank == 1 ? 0.25 : 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Center(
            child: Text(
              '#$rank',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBar(double percent, String label, {bool isLatest = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${percent.toInt()}%',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 8,
          height: percent * 0.8,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(isLatest ? 1.0 : 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: isLatest ? FontWeight.w900 : FontWeight.w600,
            color: isLatest ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentScoreItem({
    required String title,
    required String time,
    required String score,
    required IconData statusIcon,
    required Color statusColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: statusColor, size: 22),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            score,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
