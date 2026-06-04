import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/specialty.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';
import '../simulation/simulation_screen.dart';

class SpecialtyJourneyScreen extends StatefulWidget {
  const SpecialtyJourneyScreen({super.key, required this.specialty});

  static const Map<String, String> _avatarEmojis = {
    'avatar_docteur': '👨‍⚕️',
    'avatar_chirurgien': '🧑‍⚕️',
    'avatar_scientifique': '🔬',
    'avatar_gold': '🖼️',
    'avatar_ninja': '🥷',
    'avatar_diamond': '💎',
    'avatar_robot': '🤖',
    'avatar_crown': '👑',
  };

  final Specialty specialty;

  @override
  State<SpecialtyJourneyScreen> createState() => _SpecialtyJourneyScreenState();
}

class _SpecialtyJourneyScreenState extends State<SpecialtyJourneyScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _cases = [];
  final Set<int> _playedCaseIds = <int>{};
  final Map<int, int> _bestScoreByCaseId = <int, int>{};
  int? _highlightLevel;
  int? _pulseLevel;
  bool _seasonTwoUnlockCelebrated = false;
  bool _seasonThreeUnlockCelebrated = false;
  bool _seasonFourUnlockCelebrated = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _seasonOneKey = GlobalKey();
  final GlobalKey _seasonTwoKey = GlobalKey();
  final GlobalKey _seasonThreeKey = GlobalKey();
  final GlobalKey _seasonFourKey = GlobalKey();

  static const int _requiredStarsForSeasonTwo = 25;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  Future<void> _scrollTo(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  int? _seasonOf(Map<String, dynamic> c) {
    final raw = (c['medical_history'] as Map?)?['season'];
    return _asInt(raw);
  }

  int? _episodeOf(Map<String, dynamic> c) {
    final raw = (c['medical_history'] as Map?)?['episode'];
    return _asInt(raw);
  }

  int _starsFromScore(int score) {
    final clamped = score.clamp(0, 20);
    if (clamped >= 17) return 3;
    if (clamped >= 12) return 2;
    return 1;
  }

  int _starsForCaseId(int caseId) {
    final bestScore = _bestScoreByCaseId[caseId];
    if (bestScore == null) return 0;
    return _starsFromScore(bestScore);
  }

  void _playClickFeedback() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  void _playLockedFeedback() {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  void _pulseNode(int level) {
    setState(() => _pulseLevel = level);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      if (_pulseLevel == level) {
        setState(() => _pulseLevel = null);
      }
    });
  }

  int? _currentLevelOf(List<_SeasonLevelData> levels) {
    for (final level in levels) {
      if (level.state == _SeasonNodeState.current) return level.level;
    }
    return null;
  }

  List<_SlalomNodeData> _slalomNodesFromLevels(
    List<_SeasonLevelData> levels,
  ) {
    final nodes = levels.map((level) {
      final state = switch (level.state) {
        _SeasonNodeState.locked => _SlalomNodeState.locked,
        _SeasonNodeState.current => _SlalomNodeState.current,
        _SeasonNodeState.done => _SlalomNodeState.completed,
      };

      return _SlalomNodeData(
        level: level.level,
        label: 'Niveau ${level.level}',
        state: state,
        stars: level.stars,
        maxStars: 3,
        badge: state == _SlalomNodeState.current ? level.level : null,
      );
    }).toList();

    return [
      const _SlalomNodeData(
        level: 0,
        label: 'DEPART',
        state: _SlalomNodeState.completed,
        stars: 0,
        maxStars: 0,
        isDepart: true,
      ),
      ...nodes,
    ];
  }

  Future<void> _showUnlockCelebration(String title) async {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 820), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          });
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 300,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF7FF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: widget.specialty.color.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_open_rounded,
                      color: Color(0xFF1D7DB5),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = Provider.of<SessionState>(context, listen: false);
      final specialtyId = _asInt(widget.specialty.id) ?? 0;

      final allCasesRaw = await Api.getCases();
      final filtered =
          allCasesRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((c) {
                final status = (c['status'] ?? '').toString().toLowerCase();
                if (status != 'active') return false;
                final sid = _asInt(c['specialty_id']);
                return specialtyId > 0 ? sid == specialtyId : true;
              })
              .toList();

      final played = <int>{};
      final bestScores = <int, int>{};
      final userId = session.userId ?? '';
      if (userId.isNotEmpty) {
        try {
          final sessions = await Api.getSessions(userId: userId);
          for (final s in sessions) {
            if (s is! Map) continue;
            final caseId = _asInt(s['case_id']);
            if (caseId == null) continue;

            // Ignore exam sessions for clinical journey progression.
            final isExam = (s['is_exam'] ?? false) == true;
            if (isExam) continue;

            final score = _asInt(s['score']);
            if (score == null) continue; // not concluded yet

            played.add(caseId);
            final prev = bestScores[caseId];
            if (prev == null || score > prev) {
              bestScores[caseId] = score;
            }
          }
        } catch (_) {
          // best-effort
        }
      }

      if (!mounted) return;
      setState(() {
        _cases = filtered;
        _playedCaseIds
          ..clear()
          ..addAll(played);
        _bestScoreByCaseId
          ..clear()
          ..addAll(bestScores);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _caseForEpisode(
    List<Map<String, dynamic>> cases,
    int season,
    int episode,
  ) {
    for (final c in cases) {
      final s = _seasonOf(c);
      final e = _episodeOf(c);
      if (s == season && e == episode) return c;
    }

    // Fallback (legacy cases without season/episode): use stable ordering.
    final legacy = cases.where((c) => _seasonOf(c) == null && _episodeOf(c) == null).toList();
    legacy.sort((a, b) {
      final ai = _asInt(a['id']) ?? 0;
      final bi = _asInt(b['id']) ?? 0;
      return ai.compareTo(bi);
    });
    if (season == 1 && episode - 1 >= 0 && episode - 1 < legacy.length) {
      return legacy[episode - 1];
    }
    return null;
  }

  int _earnedStarsForSeason(List<Map<String, dynamic>> cases, int season) {
    int stars = 0;
    for (int ep = 1; ep <= 10; ep += 1) {
      final c = _caseForEpisode(cases, season, ep);
      final id = c == null ? null : _asInt(c['id']);
      if (id == null) continue;
      stars += _starsForCaseId(id);
    }
    return stars;
  }

  int? _currentEpisodeForSeason(
    List<Map<String, dynamic>> cases,
    int season,
  ) {
    for (int ep = 1; ep <= 10; ep += 1) {
      final c = _caseForEpisode(cases, season, ep);
      if (c == null) continue;
      final id = _asInt(c['id']);
      if (id == null) continue;
      if (_starsForCaseId(id) == 0) return ep;
    }
    return null;
  }

  List<_SeasonLevelData> _buildSeasonLevels({
    required List<Map<String, dynamic>> cases,
    required int seasonNumber,
    required bool unlocked,
    required int? currentEpisode,
  }) {
    return List<_SeasonLevelData>.generate(10, (index) {
      final level = index + 1;
      if (!unlocked) {
        return _SeasonLevelData(level: level, state: _SeasonNodeState.locked);
      }

      final c = _caseForEpisode(cases, seasonNumber, level);
      if (c == null) {
        return _SeasonLevelData(level: level, state: _SeasonNodeState.locked);
      }

      final id = _asInt(c['id']);
      final episodeStars = id == null ? 0 : _starsForCaseId(id);
      if (episodeStars > 0) {
        return _SeasonLevelData(
          level: level,
          state: _SeasonNodeState.done,
          stars: episodeStars,
        );
      }
      if (currentEpisode == level) {
        return _SeasonLevelData(level: level, state: _SeasonNodeState.current);
      }
      return _SeasonLevelData(level: level, state: _SeasonNodeState.locked);
    });
  }

  Future<void> _startSimulation(
    BuildContext context,
    Map<String, dynamic> c, {
    required int season,
    required int episode,
  }) async {
    final sessionState = Provider.of<SessionState>(context, listen: false);
    final userId = sessionState.userId ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vous connecter')),
      );
      return;
    }
    try {
      final sessionId = await Api.createSession(userId, _asInt(c['id']) ?? 0);
      sessionState.startCase(_asInt(c['id']) ?? 0, sessionId, caseData: c);
      if (!context.mounted) return;
      final completed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (context) => const SimulationScreen()),
      );

      if (!mounted) return;
      if (completed == true) {
        await _load();

        final nextEpisode = episode + 1;
        if (nextEpisode <= 10) {
          setState(() => _highlightLevel = nextEpisode);
          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;
            if (_highlightLevel == nextEpisode) {
              setState(() => _highlightLevel = null);
            }
          });
          await _showUnlockCelebration('Niveau $nextEpisode déverrouillé');
        } else {
          await _showUnlockCelebration('Saison $season terminée');
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _showSeasonLockedDialog(
    BuildContext context, {
    required int earnedStars,
    required int requiredStars,
    required int seasonNumber,
  }) {
    final progress = earnedStars / requiredStars;

    return showDialog<void>(
      context: context,
      barrierColor: const Color(0x993C4A57),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 22,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FCFF),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: const Color(0xFFCFE8FA), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A425A).withValues(alpha: 0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFAEDFFF),
                      borderRadius: BorderRadius.circular(34),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF3B91BE,
                          ).withValues(alpha: 0.22),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 58,
                      color: Color(0xFF2D647E),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Saison $seasonNumber - Specialite ${widget.specialty.title}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF205A78),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCDEBDA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'CONTENU VERROUILLE',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF3B7055),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F6FA),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 88,
                          height: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8EAF6),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 14, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.star,
                                      color: Color(0xFFF2AC00),
                                      size: 54,
                                    ),
                                    SizedBox(width: 10),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                      fontSize: 44 / 2,
                                      color: Color(0xFF205A78),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    children: [
                                      TextSpan(text: '$earnedStars'),
                                      TextSpan(
                                        text: ' / $requiredStars',
                                        style: const TextStyle(
                                          color: Color(0xFFB6BEC7),
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Vous avez besoin de $requiredStars etoiles\npour debloquer les defis\nde la Saison $seasonNumber.',
                                  style: TextStyle(
                                    fontSize: 22 / 2,
                                    height: 1.35,
                                    color: Color(0xFF2F3C49),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(999),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 16,
                                        color: const Color(0xFFD7DEE4),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: progress,
                                        child: Container(
                                          height: 16,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Color(0xFF2A6A87),
                                                Color(0xFF3D8BAA),
                                              ],
                                            ),
                                          ),
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
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        disabledBackgroundColor: const Color(0xFFE0E4E9),
                        disabledForegroundColor: const Color(0xFF96A0AA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.lock, size: 24),
                      label: const Text(
                        'DEBLOQUER',
                        style: TextStyle(
                          fontSize: 20 / 2,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 72,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E6D8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 6,
                        shadowColor: const Color(
                          0xFF2A5D75,
                        ).withValues(alpha: 0.35),
                      ),
                      child: const Text(
                        'Continuer l\'entrainement',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Continuez la Saison 1 pour gagner\nplus d\'etoiles',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20 / 2,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC2CBD3),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCasePreviewSheet(
    BuildContext context, {
    required int level,
    required int season,
    required Map<String, dynamic> caseData,
  }) {
    final patientName = (caseData['patient_name'] ?? 'Cas clinique').toString();
    final age = _asInt(caseData['age'] ?? (caseData['medical_history'] as Map?)?['age']);
    final reason = (caseData['consultation_reason'] ?? '').toString().trim();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x993C4A57),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FCFF),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFFD6EAF8), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF20475F).withValues(alpha: 0.22),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 86,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD6DDE3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD8EFE2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'SAISON $season • CAS #$level',
                      style: const TextStyle(
                        color: Color(0xFF2E6F54),
                        fontSize: 16,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    age != null ? '$patientName,\n$age ans' : patientName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 37 / 2,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F5D7A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (reason.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          size: 24,
                          color: Color(0xFF3A4753),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            reason,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF343E47),
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F6FA),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE0E9F1)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recompenses\npossibles',
                                style: TextStyle(
                                  color: Color(0xFF8CC4E3),
                                  fontSize: 20 / 2,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4,
                                ),
                              ),
                              SizedBox(height: 14),
                              Row(
                                children: [
                                  Icon(
                                    Icons.star,
                                    color: Color(0xFFBFC7D1),
                                    size: 44,
                                  ),
                                  Icon(
                                    Icons.star,
                                    color: Color(0xFFBFC7D1),
                                    size: 44,
                                  ),
                                  Icon(
                                    Icons.star,
                                    color: Color(0xFFBFC7D1),
                                    size: 44,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 132,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFA8E0BF),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF4D8E67,
                                ).withValues(alpha: 0.24),
                                blurRadius: 12,
                                offset: const Offset(0, 7),
                              ),
                            ],
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.bolt,
                                color: Color(0xFF2D6647),
                                size: 44,
                              ),
                              SizedBox(height: 4),
                              Text(
                                '+150\nXP',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF2D6647),
                                  fontSize: 20 / 2,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 76,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _playClickFeedback();
                        Navigator.of(sheetContext).pop();
                        _startSimulation(
                          context,
                          caseData,
                          season: season,
                          episode: level,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E6D8A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 8,
                        shadowColor: const Color(
                          0xFF1E4F68,
                        ).withValues(alpha: 0.35),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 34),
                      label: const Text(
                        'COMMENCER L\'EXAMEN',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text(
                      'Fermer pour l\'instant',
                      style: TextStyle(
                        color: Color(0xFF6A747E),
                        fontWeight: FontWeight.w600,
                        fontSize: 19,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = Provider.of<SessionState>(context);
    const levelsPerSeason = 10;
    const totalStarsPerSeason = levelsPerSeason * 3;

    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF1F5F8),
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F5F8),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 42, color: Color(0xFF8A3B3B)),
                  const SizedBox(height: 12),
                  Text(
                    'Erreur chargement des cas',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF16324A)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6E8295)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _load,
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final seasonOneCases = _cases;
    const seasonOneNumber = 1;
    const seasonTwoNumber = 2;
    const seasonThreeNumber = 3;
    const seasonFourNumber = 4;
    const requiredStarsForNextSeason = _requiredStarsForSeasonTwo;

    final seasonOneStars = _earnedStarsForSeason(seasonOneCases, seasonOneNumber);
    final seasonTwoStars = _earnedStarsForSeason(seasonOneCases, seasonTwoNumber);
    final seasonThreeStars = _earnedStarsForSeason(seasonOneCases, seasonThreeNumber);
    final seasonFourStars = _earnedStarsForSeason(seasonOneCases, seasonFourNumber);

    final seasonTwoUnlocked = seasonOneStars >= requiredStarsForNextSeason;
    final seasonThreeUnlocked = seasonTwoStars >= requiredStarsForNextSeason;
    final seasonFourUnlocked = seasonThreeStars >= requiredStarsForNextSeason;

    if (seasonTwoUnlocked && !_seasonTwoUnlockCelebrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _seasonTwoUnlockCelebrated = true);
        await _showUnlockCelebration('Saison 2 déverrouillée');
      });
    }
    if (seasonThreeUnlocked && !_seasonThreeUnlockCelebrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _seasonThreeUnlockCelebrated = true);
        await _showUnlockCelebration('Saison 3 déverrouillée');
      });
    }
    if (seasonFourUnlocked && !_seasonFourUnlockCelebrated) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        setState(() => _seasonFourUnlockCelebrated = true);
        await _showUnlockCelebration('Saison 4 déverrouillée');
      });
    }

    final currentEpisodeSeasonOne =
        _currentEpisodeForSeason(seasonOneCases, seasonOneNumber);
    final currentEpisodeSeasonTwo = seasonTwoUnlocked
        ? _currentEpisodeForSeason(seasonOneCases, seasonTwoNumber)
        : null;
    final currentEpisodeSeasonThree = seasonThreeUnlocked
        ? _currentEpisodeForSeason(seasonOneCases, seasonThreeNumber)
        : null;
    final currentEpisodeSeasonFour = seasonFourUnlocked
        ? _currentEpisodeForSeason(seasonOneCases, seasonFourNumber)
        : null;

    final seasonOne = _buildSeasonLevels(
      cases: seasonOneCases,
      seasonNumber: seasonOneNumber,
      unlocked: true,
      currentEpisode: currentEpisodeSeasonOne,
    );
    final seasonTwo = _buildSeasonLevels(
      cases: seasonOneCases,
      seasonNumber: seasonTwoNumber,
      unlocked: seasonTwoUnlocked,
      currentEpisode: currentEpisodeSeasonTwo,
    );
    final seasonThree = _buildSeasonLevels(
      cases: seasonOneCases,
      seasonNumber: seasonThreeNumber,
      unlocked: seasonThreeUnlocked,
      currentEpisode: currentEpisodeSeasonThree,
    );
    final seasonFour = _buildSeasonLevels(
      cases: seasonOneCases,
      seasonNumber: seasonFourNumber,
      unlocked: seasonFourUnlocked,
      currentEpisode: currentEpisodeSeasonFour,
    );

    final seasonOneNodes = _slalomNodesFromLevels(seasonOne);
    final seasonTwoNodes = _slalomNodesFromLevels(seasonTwo);
    final seasonThreeNodes = _slalomNodesFromLevels(seasonThree);
    final seasonFourNodes = _slalomNodesFromLevels(seasonFour);
    final currentSeasonOne = _currentLevelOf(seasonOne);
    final currentSeasonTwo = _currentLevelOf(seasonTwo);
    final currentSeasonThree = _currentLevelOf(seasonThree);
    final currentSeasonFour = _currentLevelOf(seasonFour);
    final completedSeasonOne =
        seasonOne.where((l) => l.state == _SeasonNodeState.done).length;

    return Scaffold(
      backgroundColor: const Color(0xFFE9F3FF),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    color: const Color(0xFF4B627A),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          widget.specialty.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2D1B20),
                          ),
                        ),
                        const Text(
                          'Progression clinique',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8A6070),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _SlalomHeaderCard(
              specialty: widget.specialty,
              accent: widget.specialty.color,
              completedLevels: completedSeasonOne,
              totalLevels: levelsPerSeason,
              seasonStars: seasonOneStars,
              totalStars: totalStarsPerSeason,
              xp: session.xp,
            ),
            const SizedBox(height: 16),
            if (seasonOneCases.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _InfoBanner(
                  title: 'Aucun cas clinique publie',
                  message:
                      'Publiez une Saison (10 episodes) depuis le web admin, puis revenez ici.',
                ),
              ),
            _SlalomSeasonSection(
              key: _seasonOneKey,
              title: 'SAISON 1',
              subtitle: 'Niveaux 1 a 10',
              nodes: seasonOneNodes,
              currentLevel: currentSeasonOne,
              onNodeTap: (node) {
                if (node.state == _SlalomNodeState.locked) return;
                _playClickFeedback();
                _pulseNode(node.level);
                final c = _caseForEpisode(
                  seasonOneCases,
                  seasonOneNumber,
                  node.level,
                );
                if (c == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aucun cas publie pour ce niveau.')),
                  );
                  return;
                }
                _showCasePreviewSheet(
                  context,
                  level: node.level,
                  season: seasonOneNumber,
                  caseData: c,
                );
              },
            ),
            const SizedBox(height: 18),
            _SlalomSeasonSection(
              key: _seasonTwoKey,
              title: 'SAISON 2',
              subtitle: 'Niveaux 1 a 10',
              nodes: seasonTwoNodes,
              currentLevel: currentSeasonTwo,
              onSeasonTap:
                  seasonTwoUnlocked
                      ? () {
                        _playClickFeedback();
                        _scrollTo(_seasonTwoKey);
                      }
                      : () {
                        _playLockedFeedback();
                        _showSeasonLockedDialog(
                          context,
                          earnedStars: seasonOneStars,
                          requiredStars: requiredStarsForNextSeason,
                          seasonNumber: seasonTwoNumber,
                        );
                      },
              lockedHint:
                  seasonTwoUnlocked
                      ? null
                      : 'Debloquez la Saison 2 avec $requiredStarsForNextSeason etoiles en Saison 1.',
              onNodeTap:
                  seasonTwoUnlocked
                      ? (node) {
                        if (node.state == _SlalomNodeState.locked) return;
                        _playClickFeedback();
                        _pulseNode(node.level);
                        final c = _caseForEpisode(
                          seasonOneCases,
                          seasonTwoNumber,
                          node.level,
                        );
                        if (c == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Aucun cas publie pour ce niveau.'),
                            ),
                          );
                          return;
                        }
                        _showCasePreviewSheet(
                          context,
                          level: node.level,
                          season: seasonTwoNumber,
                          caseData: c,
                        );
                      }
                      : null,
              onLockedTap:
                  seasonTwoUnlocked
                      ? null
                      : () {
                        _playLockedFeedback();
                        _showSeasonLockedDialog(
                          context,
                          earnedStars: seasonOneStars,
                          requiredStars: requiredStarsForNextSeason,
                          seasonNumber: seasonTwoNumber,
                        );
                      },
            ),
                    const SizedBox(height: 18),
                    _SlalomSeasonSection(
                      key: _seasonThreeKey,
                      title: 'SAISON 3',
                      subtitle: 'Niveaux 1 a 10',
                      nodes: seasonThreeNodes,
                      currentLevel: currentSeasonThree,
                      onSeasonTap:
                          seasonThreeUnlocked
                              ? () {
                                _playClickFeedback();
                                _scrollTo(_seasonThreeKey);
                              }
                              : () {
                                _playLockedFeedback();
                                _showSeasonLockedDialog(
                                  context,
                                  earnedStars: seasonTwoStars,
                                  requiredStars: requiredStarsForNextSeason,
                                  seasonNumber: seasonThreeNumber,
                                );
                              },
                      lockedHint:
                          seasonThreeUnlocked
                              ? null
                              : 'Debloquez la Saison 3 avec $requiredStarsForNextSeason etoiles en Saison 2.',
                      onNodeTap:
                          seasonThreeUnlocked
                              ? (node) {
                                if (node.state == _SlalomNodeState.locked) return;
                                _playClickFeedback();
                                _pulseNode(node.level);
                                final c = _caseForEpisode(
                                  seasonOneCases,
                                  seasonThreeNumber,
                                  node.level,
                                );
                                if (c == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Aucun cas publie pour ce niveau.'),
                                    ),
                                  );
                                  return;
                                }
                                _showCasePreviewSheet(
                                  context,
                                  level: node.level,
                                  season: seasonThreeNumber,
                                  caseData: c,
                                );
                              }
                              : null,
                      onLockedTap:
                          seasonThreeUnlocked
                              ? null
                              : () {
                                _playLockedFeedback();
                                _showSeasonLockedDialog(
                                  context,
                                  earnedStars: seasonTwoStars,
                                  requiredStars: requiredStarsForNextSeason,
                                  seasonNumber: seasonThreeNumber,
                                );
                              },
                    ),
                    const SizedBox(height: 18),
                    _SlalomSeasonSection(
                      key: _seasonFourKey,
                      title: 'SAISON 4',
                      subtitle: 'Niveaux 1 a 10',
                      nodes: seasonFourNodes,
                      currentLevel: currentSeasonFour,
                      onSeasonTap:
                          seasonFourUnlocked
                              ? () {
                                _playClickFeedback();
                                _scrollTo(_seasonFourKey);
                              }
                              : () {
                                _playLockedFeedback();
                                _showSeasonLockedDialog(
                                  context,
                                  earnedStars: seasonThreeStars,
                                  requiredStars: requiredStarsForNextSeason,
                                  seasonNumber: seasonFourNumber,
                                );
                              },
                      lockedHint:
                          seasonFourUnlocked
                              ? null
                              : 'Debloquez la Saison 4 avec $requiredStarsForNextSeason etoiles en Saison 3.',
                      onNodeTap:
                          seasonFourUnlocked
                              ? (node) {
                                if (node.state == _SlalomNodeState.locked) return;
                                _playClickFeedback();
                                _pulseNode(node.level);
                                final c = _caseForEpisode(
                                  seasonOneCases,
                                  seasonFourNumber,
                                  node.level,
                                );
                                if (c == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Aucun cas publie pour ce niveau.'),
                                    ),
                                  );
                                  return;
                                }
                                _showCasePreviewSheet(
                                  context,
                                  level: node.level,
                                  season: seasonFourNumber,
                                  caseData: c,
                                );
                              }
                              : null,
                      onLockedTap:
                          seasonFourUnlocked
                              ? null
                              : () {
                                _playLockedFeedback();
                                _showSeasonLockedDialog(
                                  context,
                                  earnedStars: seasonThreeStars,
                                  requiredStars: requiredStarsForNextSeason,
                                  seasonNumber: seasonFourNumber,
                                );
                              },
                    ),
          ],
        ),
      ),
    );
  }
}

class _TopRecapBar extends StatelessWidget {
  const _TopRecapBar({
    required this.accent,
    required this.specialtyTitle,
    required this.lives,
    required this.xp,
    required this.stars,
    required this.avatarEmoji,
  });

  final Color accent;
  final String specialtyTitle;
  final int lives;
  final int xp;
  final String stars;
  final String? avatarEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E7F2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
                width: 3,
              ),
              color: const Color(0xFF0E2234),
            ),
            child: Center(
              child:
                  avatarEmoji == null
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : Text(
                        avatarEmoji!,
                        style: const TextStyle(fontSize: 24),
                      ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  specialtyTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2F44),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniStatChip(
                        icon: Icons.favorite,
                        iconColor: const Color(0xFFF24E7D),
                        borderColor: const Color(0xFFFBD8E2),
                        value: '$lives/5',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatChip(
                        icon: Icons.bolt,
                        iconColor: const Color(0xFFF2B503),
                        borderColor: const Color(0xFFF8E6A7),
                        value: '$xp XP',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniStatChip(
                        icon: Icons.star,
                        iconColor: const Color(0xFFF2B503),
                        borderColor: const Color(0xFFF8E6A7),
                        value: stars,
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
}

class _MiniStatChip extends StatelessWidget {
  const _MiniStatChip({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2F44),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _SeasonNodeState { done, current, locked }

class _SeasonLevelData {
  const _SeasonLevelData({required this.level, required this.state, this.stars = 0});

  final int level;
  final _SeasonNodeState state;
  final int stars;
}

class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.unlocked,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final bool unlocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: unlocked ? const Color(0xFFEAF7FF) : const Color(0xFFF1F4F7),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color:
                unlocked
                    ? accent.withValues(alpha: 0.35)
                    : const Color(0xFFD8E0E8),
          ),
        ),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.flag_rounded : Icons.lock,
              size: 18,
              color:
                  unlocked ? const Color(0xFF1D7DB5) : const Color(0xFF7A8792),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 1,
                fontWeight: FontWeight.w900,
                color:
                    unlocked
                        ? const Color(0xFF1D5D84)
                        : const Color(0xFF667381),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF7A8C9D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeasonPath extends StatelessWidget {
  const _SeasonPath({
    required this.levels,
    required this.accent,
    required this.avatarEmoji,
    required this.currentLabel,
    required this.highlightLevel,
    required this.pulseLevel,
    required this.onNodeTap,
  });

  final List<_SeasonLevelData> levels;
  final Color accent;
  final String? avatarEmoji;
  final String? currentLabel;
  final int? highlightLevel;
  final int? pulseLevel;
  final void Function(_SeasonLevelData data) onNodeTap;

  double _laneX(int index) {
    const pattern = [0.0, 0.34, -0.22, -0.32, 0.02];
    return pattern[index % pattern.length];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          right: 20,
          top: 110,
          child: _GhostIcon(icon: Icons.biotech_outlined),
        ),
        const Positioned(
          left: 12,
          top: 320,
          child: _GhostIcon(icon: Icons.monitor_heart_outlined),
        ),
        const Positioned(
          right: 28,
          bottom: 90,
          child: _GhostIcon(icon: Icons.medication_outlined),
        ),
        Column(
          children: [
            for (int i = 0; i < levels.length; i++) ...[
              _SeasonNode(
                data: levels[i],
                xPosition: _laneX(i),
                accent: accent,
                avatarEmoji: avatarEmoji,
                currentLabel: currentLabel,
                highlightLevel: highlightLevel,
                pulseLevel: pulseLevel,
                onTap: () => onNodeTap(levels[i]),
              ),
              if (i < levels.length - 1)
                _SeasonConnector(
                  startX: _laneX(i),
                  endX: _laneX(i + 1),
                  color:
                      levels[i + 1].state == _SeasonNodeState.done
                          ? const Color(0xFFA7DDBD)
                          : (levels[i + 1].state == _SeasonNodeState.current
                              ? const Color(0xFF89C6E6)
                              : const Color(0xFFD5DCE4)),
                ),
            ],
          ],
        ),
      ],
    );
  }
}

class _SeasonConnector extends StatelessWidget {
  const _SeasonConnector({
    required this.startX,
    required this.endX,
    required this.color,
  });

  final double startX;
  final double endX;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: CustomPaint(
        painter: _SeasonConnectorPainter(
          startX: startX,
          endX: endX,
          color: color,
        ),
      ),
    );
  }
}

class _SeasonConnectorPainter extends CustomPainter {
  const _SeasonConnectorPainter({
    required this.startX,
    required this.endX,
    required this.color,
  });

  final double startX;
  final double endX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final start = Offset(centerX + (startX * 108), 6);
    final end = Offset(centerX + (endX * 108), size.height - 8);
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _SeasonConnectorPainter oldDelegate) {
    return oldDelegate.startX != startX ||
        oldDelegate.endX != endX ||
        oldDelegate.color != color;
  }
}

class _SeasonNode extends StatelessWidget {
  const _SeasonNode({
    required this.data,
    required this.xPosition,
    required this.accent,
    required this.avatarEmoji,
    required this.currentLabel,
    required this.highlightLevel,
    required this.pulseLevel,
    required this.onTap,
  });

  final _SeasonLevelData data;
  final double xPosition;
  final Color accent;
  final String? avatarEmoji;
  final String? currentLabel;
  final int? highlightLevel;
  final int? pulseLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCurrent = data.state == _SeasonNodeState.current;
    final isLocked = data.state == _SeasonNodeState.locked;
    final isDone = data.state == _SeasonNodeState.done;

    final isHighlighted = highlightLevel != null && data.level == highlightLevel;
    final isPulsing = pulseLevel != null && data.level == pulseLevel;
    final scale = isHighlighted ? 1.095 : (isPulsing ? 1.06 : 1.0);

    final nodeBg =
        isLocked
            ? const Color(0xFFE2E7ED)
            : (isCurrent ? const Color(0xFF2C6B8D) : const Color(0xFFAEE2C2));
    final nodeBorder =
        isLocked
            ? const Color(0xFFC8D0DA)
            : (isCurrent ? const Color(0xFF8AC9ED) : const Color(0xFF3C825A));
    final foreground =
        isLocked
            ? const Color(0xFF7D8792)
            : (isCurrent ? Colors.white : const Color(0xFF2D6E4A));

    return Align(
      alignment: Alignment(xPosition, 0),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              scale: scale,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                width: 98,
                height: 98,
                decoration: BoxDecoration(
                  color: nodeBg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isHighlighted ? accent : nodeBorder,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isHighlighted ? accent : nodeBorder).withValues(
                        alpha: isHighlighted ? 0.34 : 0.24,
                      ),
                      blurRadius: isHighlighted ? 18 : 12,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: -0.78,
                  child: Center(
                    child: Transform.rotate(
                      angle: 0.78,
                      child: isLocked
                          ? Icon(
                              Icons.lock_rounded,
                              color: foreground,
                              size: 30,
                            )
                          : (isCurrent
                              ? _CurrentSeasonAvatar(
                                  avatarEmoji: avatarEmoji,
                                  currentLabel: currentLabel,
                                )
                              : (isDone
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(3, (i) {
                                            final filled = i < data.stars;
                                            return Icon(
                                              filled
                                                  ? Icons.star_rounded
                                                  : Icons.star_outline_rounded,
                                              color: foreground.withValues(
                                                alpha: filled ? 1.0 : 0.5,
                                              ),
                                              size: 16,
                                            );
                                          }),
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          Icons.check_rounded,
                                          color: foreground,
                                          size: 29,
                                        ),
                                      ],
                                    )
                                  : Icon(
                                      Icons.play_arrow_rounded,
                                      color: foreground,
                                      size: 34,
                                    ))),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isCurrent ? 'Niveau ${data.level}' : '${data.level}',
            style: TextStyle(
              color:
                  isCurrent ? const Color(0xFF1F688D) : const Color(0xFF66798A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentSeasonAvatar extends StatelessWidget {
  const _CurrentSeasonAvatar({
    required this.avatarEmoji,
    required this.currentLabel,
  });

  final String? avatarEmoji;
  final String? currentLabel;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF7BC4D0),
      child:
          avatarEmoji != null
              ? Text(avatarEmoji!, style: const TextStyle(fontSize: 20))
              : (currentLabel != null && currentLabel!.trim().isNotEmpty
                  ? Text(
                    currentLabel![0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF184B67),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  )
                  : const Icon(
                    Icons.person_rounded,
                    color: Color(0xFF184B67),
                    size: 24,
                  )),
    );
  }
}

class _GhostIcon extends StatelessWidget {
  const _GhostIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: const Color(0xFFB6C2CF), size: 52);
  }
}

class _DottedBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = const Color(0xFFD9E2EC);
    const spacing = 16.0;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x + 1.5, y + 1.5), 0.9, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

enum _SlalomNodeState { locked, current, completed }

class _SlalomNodeData {
  const _SlalomNodeData({
    required this.level,
    required this.label,
    required this.state,
    required this.stars,
    required this.maxStars,
    this.badge,
    this.isDepart = false,
  });

  final int level;
  final String label;
  final _SlalomNodeState state;
  final int stars;
  final int maxStars;
  final int? badge;
  final bool isDepart;
}

class _SlalomHeaderCard extends StatelessWidget {
  const _SlalomHeaderCard({
    required this.specialty,
    required this.accent,
    required this.completedLevels,
    required this.totalLevels,
    required this.seasonStars,
    required this.totalStars,
    required this.xp,
  });

  final Specialty specialty;
  final Color accent;
  final int completedLevels;
  final int totalLevels;
  final int seasonStars;
  final int totalStars;
  final int xp;

  @override
  Widget build(BuildContext context) {
    final progress = totalStars <= 0 ? 0.0 : seasonStars / totalStars;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent.withValues(alpha: 0.85), accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(specialty.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MODULE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA8899),
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      specialty.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2D1B20),
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderBadge(
                icon: Icons.star,
                iconColor: const Color(0xFFFFB300),
                value: '$seasonStars',
                bgColor: const Color(0xFFFFF6DB),
              ),
              const SizedBox(width: 8),
              _HeaderBadge(
                icon: Icons.bolt,
                iconColor: const Color(0xFFFF8C00),
                value: '$xp',
                bgColor: const Color(0xFFFFF0E0),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Niveaux termines',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D1B20),
                ),
              ),
              const Spacer(),
              Text(
                '$completedLevels / $totalLevels',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D6DA3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFD7E4F4),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF2D6DA3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.bgColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D1B20),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4C8D1)),
      ),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF7A3B49),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8C5A66),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlalomSeasonSection extends StatelessWidget {
  const _SlalomSeasonSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.nodes,
    required this.currentLevel,
    this.onNodeTap,
    this.onLockedTap,
    this.lockedHint,
    this.onSeasonTap,
  });

  final String title;
  final String subtitle;
  final List<_SlalomNodeData> nodes;
  final int? currentLevel;
  final void Function(_SlalomNodeData node)? onNodeTap;
  final VoidCallback? onLockedTap;
  final String? lockedHint;
  final VoidCallback? onSeasonTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SlalomSeasonBadge(
          title: title,
          subtitle: subtitle,
          onTap: onSeasonTap,
        ),
        const SizedBox(height: 12),
        _SlalomMapArea(
          nodes: nodes,
          currentLevel: currentLevel,
          onNodeTap: onNodeTap,
          onLockedTap: onLockedTap,
        ),
        if (lockedHint != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              lockedHint!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8A6070),
              ),
            ),
          ),
      ],
    );
  }
}

class _SlalomMapArea extends StatelessWidget {
  const _SlalomMapArea({
    required this.nodes,
    required this.currentLevel,
    this.onNodeTap,
    this.onLockedTap,
  });

  final List<_SlalomNodeData> nodes;
  final int? currentLevel;
  final void Function(_SlalomNodeData node)? onNodeTap;
  final VoidCallback? onLockedTap;

  List<Offset> _positions(int count) {
    const pattern = [0.50, 0.72, 0.22, 0.68, 0.25, 0.65];
    const top = 0.07;
    const bottom = 0.93;
    final step = (bottom - top) / (count - 1);
    return List.generate(count, (i) {
      final x = i == 0 ? 0.50 : pattern[(i - 1) % pattern.length];
      final y = top + (step * i);
      return Offset(x, y);
    });
  }

  @override
  Widget build(BuildContext context) {
    final nodeCount = nodes.length;
    final canvasHeight = math.max(1000.0, nodeCount * 140.0);
    final positions = _positions(nodeCount);
    final currentIndex =
        currentLevel == null
            ? -1
            : nodes.indexWhere((n) => n.level == currentLevel);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              width: w,
              height: canvasHeight,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE9F3FF), Color(0xFFCFE0F6)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 70,
                    left: 16,
                    child: _EcgDecoration(
                      width: 180,
                      color: const Color(0xFFB7CCE6),
                    ),
                  ),
                  Positioned(
                    top: 90,
                    right: 10,
                    child: _EcgDecoration(
                      width: 130,
                      color: const Color(0xFFB7CCE6),
                      small: true,
                    ),
                  ),
                  const Positioned(
                    top: 480,
                    left: 18,
                    child: Icon(
                      Icons.favorite_border,
                      size: 44,
                      color: Color(0xFFB7CCE6),
                    ),
                  ),
                  const Positioned(
                    top: 240,
                    right: 14,
                    child: Icon(
                      Icons.favorite,
                      size: 32,
                      color: Color(0xFFB7CCE6),
                    ),
                  ),
                  Positioned(
                    top: 350,
                    right: 22,
                    child: _PiscesSymbol(
                      color: const Color(0xFFB7CCE6),
                      size: 42,
                    ),
                  ),
                  Positioned(
                    top: 680,
                    left: 24,
                    child: _PiscesSymbol(
                      color: const Color(0xFFB7CCE6),
                      size: 38,
                    ),
                  ),
                  CustomPaint(
                    size: Size(w, canvasHeight),
                    painter: _SlalomEdgePainter(
                      nodes: nodes,
                      positions: positions,
                      canvasHeight: canvasHeight,
                    ),
                  ),
                  for (int i = 0; i < nodes.length; i += 1)
                    _SlalomNodeWidget(
                      node: nodes[i],
                      x: positions[i].dx * w,
                      y: positions[i].dy * canvasHeight,
                      onTap: nodes[i].isDepart
                          ? null
                          : (nodes[i].state == _SlalomNodeState.locked
                              ? onLockedTap
                              : () => onNodeTap?.call(nodes[i])),
                    ),
                  if (currentIndex >= 0)
                    Positioned(
                      left: math
                          .max(
                            12.0,
                            math.min(
                              positions[currentIndex].dx * w - 140.0,
                              w - 180.0,
                            ),
                          )
                          .toDouble(),
                      top: positions[currentIndex].dy * canvasHeight + 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D6DA3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Vous etes ici',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SlalomSeasonBadge extends StatelessWidget {
  const _SlalomSeasonBadge({
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty && subtitle.isEmpty) {
      return const SizedBox.shrink();
    }
    final content = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: CustomPaint(
                painter: _SlalomDashedLinePainter(color: const Color(0xFFE8334A)),
                size: const Size(double.infinity, 1),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6DA3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: _SlalomDashedLinePainter(color: const Color(0xFFE8334A)),
                size: const Size(double.infinity, 1),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2D1B20),
          ),
        ),
      ],
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}

class _SlalomStarsRow extends StatelessWidget {
  const _SlalomStarsRow({required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: Icon(
            isFilled ? Icons.star : Icons.star_border,
            size: 16,
            color:
                isFilled ? const Color(0xFFFFB300) : const Color(0xFFCCB0BA),
          ),
        );
      }),
    );
  }
}

class _SlalomNodeWidget extends StatelessWidget {
  const _SlalomNodeWidget({
    required this.node,
    required this.x,
    required this.y,
    this.onTap,
  });

  final _SlalomNodeData node;
  final double x;
  final double y;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final starsWidget = node.maxStars > 0
        ? Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _SlalomStarsRow(filled: node.stars, total: node.maxStars),
          )
        : const SizedBox.shrink();

    Widget circle;

    if (node.isDepart) {
      circle = Column(
        children: [
          starsWidget,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              node.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Color(0xFF2D1B20),
              ),
            ),
          ),
        ],
      );
    } else if (node.state == _SlalomNodeState.completed) {
      circle = Column(
        children: [
          starsWidget,
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFFFF6B8A), Color(0xFFE8334A)],
                    center: Alignment(-0.3, -0.3),
                    radius: 0.9,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55E8334A),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 30),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8334A),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _nodeLabel(node.label, color: const Color(0xFFE8334A)),
        ],
      );
    } else if (node.state == _SlalomNodeState.current) {
      circle = Column(
        children: [
          starsWidget,
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1400),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              final pulse = 1.0 + (value < 0.5 ? value : 1 - value) * 0.06;
              final glow = 12 + (value < 0.5 ? value : 1 - value) * 10;
              return Transform.scale(
                scale: pulse,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFF6B8A), Color(0xFFE8334A)],
                          center: Alignment(-0.3, -0.3),
                          radius: 0.9,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x66E8334A),
                            blurRadius: glow,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.monitor_heart,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    if (node.badge != null)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2D1B20),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${node.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          _nodeLabel(node.label),
        ],
      );
    } else {
      circle = Column(
        children: [
          starsWidget,
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFD0C0C8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Color(0xFFAA9099),
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          _nodeLabel(node.label),
        ],
      );
    }

    return Positioned(
      left: x - 60,
      top: y - 60,
      child: SizedBox(
        width: 120,
        child: Center(
          child: GestureDetector(onTap: onTap, child: circle),
        ),
      ),
    );
  }

  Widget _nodeLabel(String text, {Color color = const Color(0xFF2D1B20)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _SlalomEdgePainter extends CustomPainter {
  const _SlalomEdgePainter({
    required this.nodes,
    required this.positions,
    required this.canvasHeight,
  });

  final List<_SlalomNodeData> nodes;
  final List<Offset> positions;
  final double canvasHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF7FA6C9)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < nodes.length - 1; i += 1) {
      final p1 = Offset(
        positions[i].dx * size.width,
        positions[i].dy * canvasHeight,
      );
      final p2 = Offset(
        positions[i + 1].dx * size.width,
        positions[i + 1].dy * canvasHeight,
      );
      _drawDashed(canvas, p1, p2, paint);
    }
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashLen = 10.0;
    const gapLen = 7.0;
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist == 0) return;
    final dxN = dx / dist;
    final dyN = dy / dist;
    double drawn = 0;
    while (drawn < dist) {
      final end = math.min(drawn + dashLen, dist);
      canvas.drawLine(
        Offset(p1.dx + dxN * drawn, p1.dy + dyN * drawn),
        Offset(p1.dx + dxN * end, p1.dy + dyN * end),
        paint,
      );
      drawn += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SlalomDashedLinePainter extends CustomPainter {
  const _SlalomDashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    const dash = 6.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(math.min(x + dash, size.width), 0),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _EcgDecoration extends StatelessWidget {
  const _EcgDecoration({
    required this.width,
    required this.color,
    this.small = false,
  });

  final double width;
  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, small ? 22 : 32),
      painter: _EcgPainter(color: color),
    );
  }
}

class _EcgPainter extends CustomPainter {
  const _EcgPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final h = size.height;
    final w = size.width;
    final mid = h / 2;
    final path = Path()
      ..moveTo(0, mid)
      ..lineTo(w * 0.25, mid)
      ..lineTo(w * 0.35, mid - h * 0.3)
      ..lineTo(w * 0.42, mid + h * 0.45)
      ..lineTo(w * 0.50, mid - h * 0.9)
      ..lineTo(w * 0.58, mid + h * 0.3)
      ..lineTo(w * 0.65, mid)
      ..lineTo(w, mid);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _PiscesSymbol extends StatelessWidget {
  const _PiscesSymbol({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _PiscesPainter(color: color));
  }
}

class _PiscesPainter extends CustomPainter {
  const _PiscesPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width * 0.35;
    for (final yOff in [-r * 0.5, r * 0.5]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx, cy + yOff),
          width: r * 1.6,
          height: r * 1.2,
        ),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        p,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(cx, cy + yOff),
          width: r * 1.6,
          height: r * 1.2,
        ),
        math.pi * 1.15,
        math.pi * 0.7,
        false,
        p,
      );
    }
    canvas.drawLine(Offset(cx, cy - r), Offset(cx, cy + r), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
