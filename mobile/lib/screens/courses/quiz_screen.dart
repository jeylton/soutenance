import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../models/specialty.dart';
import '../../widgets/background_wave_painter.dart';
import '../../widgets/specialty_card.dart';
import '../../widgets/user_profile_bar.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _seasonOneKey = GlobalKey();
  final GlobalKey _seasonTwoKey = GlobalKey();
  final GlobalKey _seasonThreeKey = GlobalKey();
  final GlobalKey _seasonFourKey = GlobalKey();

  Specialty? _selectedSpecialty;

  // Spécialités chargées depuis l'API (remplace la liste hardcodée)
  List<Specialty> _specialties = [];
  bool _loadingSpecialties = true;

  static const List<Color> _specialtyColors = [
    Color(0xFFF24E7D), Color(0xFF45BEEB), Color(0xFF7D57F1),
    Color(0xFFFFB347), Color(0xFF2E8B57), Color(0xFFDA70D6),
    Color(0xFF4682B4), Color(0xFF20B2AA), Color(0xFFCD5C5C),
    Color(0xFF48D1CC), Color(0xFFFF8C00), Color(0xFFB22222),
    Color(0xFF6A5ACD), Color(0xFF9932CC), Color(0xFFFFD700),
    Color(0xFF90EE90), Color(0xFF1E90FF), Color(0xFFFF69B4),
  ];

  static const Map<String, IconData> _specialtyIcons = {
    'cardiologie': Icons.favorite,
    'pneumologie': Icons.air,
    'neurologie': Icons.psychology,
    'gastro': Icons.restaurant,
    'dermatologie': Icons.spa,
    'pediatrie': Icons.child_care,
    'gynecologie': Icons.pregnant_woman,
    'urologie': Icons.water_drop,
    'orl': Icons.hearing,
    'ophtalmologie': Icons.visibility,
    'rhumatologie': Icons.accessibility,
    'endocrinologie': Icons.biotech,
    'nephrologie': Icons.shield,
    'hematologie': Icons.bloodtype,
    'psychiatrie': Icons.self_improvement,
    'chirurgie': Icons.healing,
    'interne': Icons.medical_services,
    'infectiologie': Icons.bug_report,
  };

  IconData _iconForSpecialty(String name) {
    final n = name.toLowerCase();
    for (final entry in _specialtyIcons.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return Icons.local_hospital;
  }

  Future<void> _loadSpecialties() async {
    try {
      final raw = await Api.getSpecialties();
      if (!mounted) return;

      // Specialty IDs that have at least one published quiz
      final quizSpecialtyIds = _publishedQuizzes
          .map((q) => q['specialty_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      final loaded = raw.whereType<Map>().toList().asMap().entries.map((entry) {
        final idx = entry.key;
        final sp = Map<String, dynamic>.from(entry.value);
        final id = sp['id']?.toString() ?? '';
        final name = (sp['name'] ?? '').toString();
        final hasQuiz = quizSpecialtyIds.contains(id);
        return Specialty(
          id: int.tryParse(id) ?? 0,
          title: name,
          description: hasQuiz ? 'Quiz disponibles' : 'Bientôt disponible',
          icon: _iconForSpecialty(name),
          color: _specialtyColors[idx % _specialtyColors.length],
          progress: 0.0,
        );
      }).toList();

      setState(() {
        _specialties = loaded;
        _loadingSpecialties = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSpecialties = false);
    }
  }

  List<Map<String, dynamic>> _publishedQuizzes = [];
  final Set<String> _playedQuizKeys = <String>{};
  final Map<String, int> _bestStarsByQuizKey = <String, int>{};
  bool _loadingPublished = true;
  String _publishedError = '';
  Timer? _pollTimer;

  static const int _episodesPerSeason = 10;
  static const int _maxStarsPerEpisode = 3;
  // Même règle que les cas cliniques: 25/30 étoiles pour Saison 2.
  static const int _requiredStarsForSeasonTwo = 25;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _refreshAll();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _bgController.dispose();
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

  // Retourne l'ID de la spécialité directement depuis le modèle (chargé depuis l'API)
  int? _specialtyIdOf(Specialty specialty) => specialty.id;

  Widget _buildSpecialtyPicker() {
    return Scaffold(
      backgroundColor: const Color(0xFFF2FAFE),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
                return CustomPaint(
                  painter: BackgroundWavePainter(_bgController.value),
                );
              },
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: UserProfileBar(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 32,
                    ),
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E3A5F),
                            ),
                            children: [
                              TextSpan(text: 'Choisis ta '),
                              TextSpan(
                                text: 'specialite',
                                style: TextStyle(color: Color(0xFF3FB1E4)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Selectionne une specialite pour acceder aux quiz correspondants.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF7A8D9F),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loadingSpecialties)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_specialties.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 32),
                      child: Text(
                        'Aucune spécialité avec des quiz publiés pour le moment.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Color(0xFF7A8D9F)),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final specialty = _specialties[index];
                        return SpecialtyCard(
                          specialty: specialty,
                          onTap: () {
                            setState(() => _selectedSpecialty = specialty);
                          },
                        );
                      }, childCount: _specialties.length),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.95,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startAutoRefresh() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _loadPublishedQuizzes(showLoader: false);
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadPublishedQuizzes(), _loadPlayedQuizKeys()]);
    await _loadSpecialties();
  }

  Future<void> _loadPlayedQuizKeys() async {
    try {
      final attemptsRaw = await Api.getQuizAttempts();
      if (!mounted) return;

      final Map<String, int> nextBestStars = <String, int>{};
      final Set<String> nextPlayedKeys = <String>{};

      for (final row in attemptsRaw) {
        if (row is! Map) continue;
        final attempt = Map<String, dynamic>.from(row);
        final quizKey = (attempt['quiz_key'] ?? '').toString().trim();
        if (quizKey.isEmpty) continue;

        final accuracyRaw = attempt['accuracy'];
        final scoreRaw = attempt['score'];
        final totalRaw = attempt['total'];

        double accuracy = 0;
        if (accuracyRaw is num) {
          accuracy = accuracyRaw.toDouble();
        } else {
          final parsed = double.tryParse(accuracyRaw?.toString() ?? '');
          if (parsed != null) accuracy = parsed;
        }

        if (accuracy <= 0) {
          final int good =
              scoreRaw is num
                  ? scoreRaw.toInt()
                  : int.tryParse(scoreRaw?.toString() ?? '') ?? 0;
          final int total =
              totalRaw is num
                  ? totalRaw.toInt()
                  : int.tryParse(totalRaw?.toString() ?? '') ?? 0;
          if (total > 0) accuracy = good / total;
        }

        final stars = _starsFromAccuracy(accuracy);
        if (stars <= 0) continue;

        nextPlayedKeys.add(quizKey);
        final prev = nextBestStars[quizKey] ?? 0;
        if (stars > prev) nextBestStars[quizKey] = stars;
      }
      setState(() {
        _playedQuizKeys
          ..clear()
          ..addAll(nextPlayedKeys);
        _bestStarsByQuizKey
          ..clear()
          ..addAll(nextBestStars);
      });
    } catch (_) {}
  }

  Future<void> _loadPublishedQuizzes({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _loadingPublished = true);
    }
    try {
      final rows = await Api.getPublishedQuizzes();
      if (!mounted) return;
      setState(() {
        _publishedQuizzes =
            rows
                .whereType<Map>()
                .map((r) => Map<String, dynamic>.from(r))
                .toList();
        _publishedError = '';
        if (showLoader) _loadingPublished = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publishedError = e.toString();
        if (showLoader) _loadingPublished = false;
      });
    }
  }

  Future<void> _openQuizSheet(Map<String, dynamic> quiz) async {
    final questions =
        (quiz['questions'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList();

    if (questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quiz vide. Réessayez.')));
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuizRunnerSheet(quiz: quiz, questions: questions),
    );
    if (!mounted) return;
    await _loadPlayedQuizKeys();
  }

  String _quizKeyOf(Map<String, dynamic> quiz) {
    return (quiz['quiz_key'] ?? quiz['id'] ?? '').toString().trim();
  }

  bool _isQuizPlayed(Map<String, dynamic> quiz) {
    final key = _quizKeyOf(quiz);
    return key.isNotEmpty && _playedQuizKeys.contains(key);
  }

  int _starsFromAccuracy(double accuracy) {
    final clamped = accuracy.clamp(0.0, 1.0);
    if (clamped <= 0) return 0;
    // Seuils alignés sur les cas cliniques: 17/20 et 12/20 => 85% et 60%.
    if (clamped >= 0.85) return 3;
    if (clamped >= 0.60) return 2;
    return 1;
  }

  int _starsForQuiz(Map<String, dynamic> quiz) {
    final key = _quizKeyOf(quiz);
    if (key.isEmpty) return 0;
    return _bestStarsByQuizKey[key] ?? 0;
  }

  int _earnedStarsForSeason(List<Map<String, dynamic>> quizzes, int season) {
    int stars = 0;
    for (int ep = 1; ep <= _episodesPerSeason; ep += 1) {
      final q = _quizForEpisode(quizzes, season, ep);
      if (q == null) continue;
      stars += _starsForQuiz(q);
    }
    return stars;
  }

  int? _currentEpisodeForSeason(List<Map<String, dynamic>> quizzes, int season) {
    for (int ep = 1; ep <= _episodesPerSeason; ep += 1) {
      final q = _quizForEpisode(quizzes, season, ep);
      if (q == null) continue;
      if (!_isQuizPlayed(q)) return ep;
    }
    return null;
  }

  bool _hasAnyEpisodeQuiz(List<Map<String, dynamic>> quizzes, int season) {
    for (int ep = 1; ep <= _episodesPerSeason; ep += 1) {
      if (_quizForEpisode(quizzes, season, ep) != null) return true;
    }
    return false;
  }

  int _completedEpisodesForSeason(List<Map<String, dynamic>> quizzes, int season) {
    int count = 0;
    for (int ep = 1; ep <= _episodesPerSeason; ep += 1) {
      final q = _quizForEpisode(quizzes, season, ep);
      if (q == null) continue;
      if (_isQuizPlayed(q)) count += 1;
    }
    return count;
  }

  List<_SlalomNodeData> _slalomNodesForQuizSeason({
    required List<Map<String, dynamic>> quizzes,
    required int season,
    required bool seasonUnlocked,
    required int? currentEpisode,
  }) {
    final nodes = <_SlalomNodeData>[];
    for (int ep = 1; ep <= _episodesPerSeason; ep += 1) {
      final quiz = _quizForEpisode(quizzes, season, ep);
      final hasQuiz = quiz != null;
      final played = quiz != null && _isQuizPlayed(quiz);
      final unlocked =
          seasonUnlocked &&
          hasQuiz &&
          (played || (currentEpisode != null && ep == currentEpisode));

      final state =
          unlocked
              ? (played ? _SlalomNodeState.completed : _SlalomNodeState.current)
              : _SlalomNodeState.locked;

      nodes.add(
        _SlalomNodeData(
          level: ep,
          label: 'Episode $ep',
          state: state,
          stars: quiz == null ? 0 : _starsForQuiz(quiz),
          maxStars: 3,
          badge: state == _SlalomNodeState.current ? ep : null,
          payload: quiz,
        ),
      );
    }

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


  void _showSeasonLockedSnackBar({
    required int seasonNumber,
    required int earnedStars,
    required int requiredStars,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Saison $seasonNumber verrouillee — $earnedStars/$requiredStars etoiles en Saison ${seasonNumber - 1}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F172A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Map<String, dynamic>? _quizForEpisode(
    List<Map<String, dynamic>> quizzes,
    int season,
    int episode,
  ) {
    for (final q in quizzes) {
      // Backend/admin may send episode under different keys (legacy):
      // - episode (preferred)
      // - level / niveau (fallback)
      // Same for season.
      final rawSeason = q['season'] ?? q['saison'] ?? q['season_number'];
      final rawEpisode =
          q['episode'] ?? q['level'] ?? q['niveau'] ?? q['episode_number'];
      final s =
          rawSeason is num
              ? rawSeason.toInt()
              : int.tryParse(rawSeason?.toString() ?? '');
      final e =
          rawEpisode is num
              ? rawEpisode.toInt()
              : int.tryParse(rawEpisode?.toString() ?? '');
      if (s == season && e == episode) return q;
    }
    return null;
  }

  double _laneX(int displayIndex) {
    const pattern = [0.0, 0.34, -0.22, -0.32, 0.02];
    return pattern[displayIndex % pattern.length];
  }

  Color _connectorColor(_JourneyNodeStatus lowerStatus) {
    switch (lowerStatus) {
      case _JourneyNodeStatus.done:
        return const Color(0xFFA7DDBD);
      case _JourneyNodeStatus.active:
        return const Color(0xFF89C6E6);
      case _JourneyNodeStatus.locked:
        return const Color(0xFFD5DCE4);
    }
  }


  @override
  Widget build(BuildContext context) {
    if (_selectedSpecialty == null) {
      return _buildSpecialtyPicker();
    }

    final selectedSpecialty = _selectedSpecialty!;
    final specialtyId = _specialtyIdOf(selectedSpecialty);
    final quizzes = specialtyId == null
        ? _publishedQuizzes
        : _publishedQuizzes.where((q) {
            final rawId = q['specialty_id'];
            if (rawId is num) return rawId.toInt() == specialtyId;
            return int.tryParse(rawId?.toString() ?? '') == specialtyId;
          }).toList();

    final seasonOneStars = _earnedStarsForSeason(quizzes, 1);
    final seasonTwoStars = _earnedStarsForSeason(quizzes, 2);
    final seasonThreeStars = _earnedStarsForSeason(quizzes, 3);
    final totalStarsPerSeason = _episodesPerSeason * _maxStarsPerEpisode;
    final seasonTwoUnlocked = seasonOneStars >= _requiredStarsForSeasonTwo;
    final seasonThreeUnlocked = seasonTwoStars >= _requiredStarsForSeasonTwo;
    final seasonFourUnlocked = seasonThreeStars >= _requiredStarsForSeasonTwo;

    final seasonOneHasQuiz = _hasAnyEpisodeQuiz(quizzes, 1);
    final seasonTwoHasQuiz = _hasAnyEpisodeQuiz(quizzes, 2);
    final seasonThreeHasQuiz = _hasAnyEpisodeQuiz(quizzes, 3);
    final seasonFourHasQuiz = _hasAnyEpisodeQuiz(quizzes, 4);
    final currentSeasonOne = _currentEpisodeForSeason(quizzes, 1);
    final currentSeasonTwo =
        seasonTwoUnlocked ? _currentEpisodeForSeason(quizzes, 2) : null;
    final currentSeasonThree =
        seasonThreeUnlocked ? _currentEpisodeForSeason(quizzes, 3) : null;
    final currentSeasonFour =
        seasonFourUnlocked ? _currentEpisodeForSeason(quizzes, 4) : null;
    final seasonOneNodes = _slalomNodesForQuizSeason(
      quizzes: quizzes,
      season: 1,
      seasonUnlocked: true,
      currentEpisode: currentSeasonOne,
    );
    final seasonTwoNodes = _slalomNodesForQuizSeason(
      quizzes: quizzes,
      season: 2,
      seasonUnlocked: seasonTwoUnlocked,
      currentEpisode: currentSeasonTwo,
    );
    final seasonThreeNodes = _slalomNodesForQuizSeason(
      quizzes: quizzes,
      season: 3,
      seasonUnlocked: seasonThreeUnlocked,
      currentEpisode: currentSeasonThree,
    );
    final seasonFourNodes = _slalomNodesForQuizSeason(
      quizzes: quizzes,
      season: 4,
      seasonUnlocked: seasonFourUnlocked,
      currentEpisode: currentSeasonFour,
    );
    final completedSeasonOne = _completedEpisodesForSeason(quizzes, 1);

    return Scaffold(
      backgroundColor: const Color(0xFFE9F3FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
              controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        setState(() => _selectedSpecialty = null);
                      },
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      color: const Color(0xFF4B627A),
                    ),
                    Expanded(
                      child: Text(
                        '${selectedSpecialty.title} • Quiz',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2D1B20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _SlalomHeaderCard(
                specialty: selectedSpecialty,
                accent: selectedSpecialty.color,
                completedEpisodes: completedSeasonOne,
                totalEpisodes: _episodesPerSeason,
                seasonStars: seasonOneStars,
                totalStars: totalStarsPerSeason,
              ),
              const SizedBox(height: 16),
              if (_loadingPublished)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 50),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (!seasonOneHasQuiz)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _InfoBanner(
                      title: 'Aucun quiz publie',
                      message:
                          'Publiez une Saison (10 episodes) depuis le web admin, puis revenez ici.',
                    ),
                  ),
                _SlalomSeasonSection(
                  key: _seasonOneKey,
                  title: 'SAISON 1',
                  subtitle: 'Episodes 1 a 10',
                  nodes: seasonOneNodes,
                  currentLevel: currentSeasonOne,
                  onNodeTap: (node) {
                    if (node.state == _SlalomNodeState.locked) return;
                    final quiz = node.payload;
                    if (quiz == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Quiz indisponible.')),
                      );
                      return;
                    }
                    _openQuizSheet(quiz);
                  },
                ),
                const SizedBox(height: 18),
                _SlalomSeasonSection(
                  key: _seasonTwoKey,
                  title: 'SAISON 2',
                  subtitle: 'Episodes 1 a 10',
                  nodes: seasonTwoNodes,
                  currentLevel: currentSeasonTwo,
                  onSeasonTap:
                      seasonTwoUnlocked
                          ? () => _scrollTo(_seasonTwoKey)
                          : () => _showSeasonLockedSnackBar(
                            seasonNumber: 2,
                            earnedStars: seasonOneStars,
                            requiredStars: _requiredStarsForSeasonTwo,
                          ),
                  lockedHint:
                      seasonTwoUnlocked
                          ? null
                          : 'Debloquez la Saison 2 avec $_requiredStarsForSeasonTwo etoiles en Saison 1.',
                  onNodeTap:
                      seasonTwoUnlocked
                          ? (node) {
                            if (node.state == _SlalomNodeState.locked) return;
                            final quiz = node.payload;
                            if (quiz == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Quiz indisponible.')),
                              );
                              return;
                            }
                            _openQuizSheet(quiz);
                          }
                          : null,
                  onLockedTap:
                      seasonTwoUnlocked
                          ? null
                          : () => _showSeasonLockedSnackBar(
                            seasonNumber: 2,
                            earnedStars: seasonOneStars,
                            requiredStars: _requiredStarsForSeasonTwo,
                          ),
                ),
                if (!seasonTwoHasQuiz)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Aucun quiz publie pour la Saison 2 pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A6070),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                _SlalomSeasonSection(
                  key: _seasonThreeKey,
                  title: 'SAISON 3',
                  subtitle: 'Episodes 1 a 10',
                  nodes: seasonThreeNodes,
                  currentLevel: currentSeasonThree,
                  onSeasonTap:
                      seasonThreeUnlocked
                          ? () => _scrollTo(_seasonThreeKey)
                          : () => _showSeasonLockedSnackBar(
                            seasonNumber: 3,
                            earnedStars: seasonTwoStars,
                            requiredStars: _requiredStarsForSeasonTwo,
                          ),
                  lockedHint:
                      seasonThreeUnlocked
                          ? null
                          : 'Debloquez la Saison 3 avec $_requiredStarsForSeasonTwo etoiles en Saison 2.',
                  onNodeTap:
                      seasonThreeUnlocked
                          ? (node) {
                            if (node.state == _SlalomNodeState.locked) return;
                            final quiz = node.payload;
                            if (quiz == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Quiz indisponible.')),
                              );
                              return;
                            }
                            _openQuizSheet(quiz);
                          }
                          : null,
                  onLockedTap:
                      seasonThreeUnlocked
                          ? null
                          : () => _showSeasonLockedSnackBar(
                            seasonNumber: 3,
                            earnedStars: seasonTwoStars,
                            requiredStars: _requiredStarsForSeasonTwo,
                          ),
                ),
                if (!seasonThreeHasQuiz)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Aucun quiz publie pour la Saison 3 pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A6070),
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                _SlalomSeasonSection(
                  key: _seasonFourKey,
                  title: 'SAISON 4',
                  subtitle: 'Episodes 1 a 10',
                  nodes: seasonFourNodes,
                  currentLevel: currentSeasonFour,
                  onSeasonTap:
                      seasonFourUnlocked
                          ? () => _scrollTo(_seasonFourKey)
                          : () => _showSeasonLockedSnackBar(
                            seasonNumber: 4,
                            earnedStars: seasonThreeStars,
                            requiredStars: _requiredStarsForSeasonTwo,
                          ),
                  lockedHint:
                      seasonFourUnlocked
                          ? null
                          : 'Debloquez la Saison 4 avec $_requiredStarsForSeasonTwo etoiles en Saison 3.',
                  onNodeTap:
                      seasonFourUnlocked
                          ? (node) {
                            if (node.state == _SlalomNodeState.locked) return;
                            final quiz = node.payload;
                            if (quiz == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Quiz indisponible.')),
                              );
                              return;
                            }
                            _openQuizSheet(quiz);
                          }
                          : null,
                  onLockedTap:
                      seasonFourUnlocked
                          ? null
                          : () => _showSeasonLockedSnackBar(
                            seasonNumber: 4,
                            earnedStars: seasonThreeStars,
                            requiredStars: _requiredStarsForSeasonTwo,
                          ),
                ),
                if (!seasonFourHasQuiz)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Aucun quiz publie pour la Saison 4 pour le moment.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8A6070),
                      ),
                    ),
                  ),
                if (_publishedError.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      'Erreur chargement quiz: $_publishedError',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _JourneyNodeStatus { locked, active, done }

enum _JourneyNodeVisual { locked, active, done, home }


class _JourneyConnector extends StatelessWidget {
  const _JourneyConnector({
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
      height: 74,
      child: CustomPaint(
        painter: _ConnectorPainter(startX: startX, endX: endX, color: color),
      ),
    );
  }
}

class _JourneyNodeTile extends StatelessWidget {
  const _JourneyNodeTile({
    required this.xPosition,
    required this.status,
    required this.visual,
    this.levelLabel,
    this.onTap,
  });

  final double xPosition;
  final _JourneyNodeStatus status;
  final _JourneyNodeVisual visual;
  final String? levelLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool isLocked = status == _JourneyNodeStatus.locked;
    final bool isDone = status == _JourneyNodeStatus.done;

    final Color nodeBg =
        isLocked
            ? const Color(0xFFD8DEE4)
            : (isDone ? const Color(0xFFAEE2C2) : const Color(0xFF2A5D7A));
    final Color nodeBorder =
        isLocked
            ? const Color(0xFFC9D2DB)
            : (isDone ? const Color(0xFF3F8860) : const Color(0xFF7BC1E4));
    final Color contentColor =
        isLocked
            ? const Color(0xFF7D8792)
            : (isDone ? const Color(0xFF2F6E4A) : Colors.white);

    return Align(
      alignment: Alignment(xPosition, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (levelLabel != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7FF),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF8FC8E8)),
              ),
              child: Text(
                levelLabel!,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: const Color(0xFF1E668A),
                ),
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: nodeBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: nodeBorder, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: nodeBorder.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: -math.pi / 4,
                  child: Center(
                    child: Transform.rotate(
                      angle: math.pi / 4,
                      child: _NodeCenterContent(
                        visual: visual,
                        color: contentColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeCenterContent extends StatelessWidget {
  const _NodeCenterContent({required this.visual, required this.color});

  final _JourneyNodeVisual visual;
  final Color color;

  @override
  Widget build(BuildContext context) {
    switch (visual) {
      case _JourneyNodeVisual.locked:
        return Icon(Icons.lock_rounded, color: color, size: 30);
      case _JourneyNodeVisual.home:
        return Icon(Icons.home_rounded, color: color, size: 32);
      case _JourneyNodeVisual.done:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_rounded, color: color, size: 16),
            const SizedBox(height: 4),
            Icon(Icons.check_rounded, color: color, size: 30),
          ],
        );
      case _JourneyNodeVisual.active:
        return Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF78C5D2),
            border: Border.all(color: const Color(0xFFEAF7FF), width: 4),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF124C65),
            size: 24,
          ),
        );
    }
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
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
    final start = Offset(centerX + (startX * 110), 8);
    final end = Offset(centerX + (endX * 110), size.height - 8);
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 8
          ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.startX != startX ||
        oldDelegate.endX != endX ||
        oldDelegate.color != color;
  }
}

class _MapDecorations extends StatelessWidget {
  const _MapDecorations();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        Positioned(
          right: 20,
          top: 146,
          child: Icon(
            Icons.medication_rounded,
            size: 36,
            color: Color(0xFFA0B8C6),
          ),
        ),
        Positioned(
          left: 34,
          top: 340,
          child: Icon(
            Icons.medical_services_rounded,
            size: 46,
            color: Color(0xFFC3E6D1),
          ),
        ),
        Positioned(
          left: 90,
          bottom: 140,
          child: Icon(
            Icons.monitor_heart_rounded,
            size: 54,
            color: Color(0xFFC6CDD7),
          ),
        ),
        Positioned(
          right: 30,
          bottom: 92,
          child: Icon(Icons.spa_rounded, size: 48, color: Color(0xFF95BCA9)),
        ),
      ],
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFBED0DD);
    const double step = 44;
    const double radius = 1.4;
    for (double y = 14; y < size.height; y += step) {
      for (double x = 10; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _QuizRunnerSheet extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final List<Map<String, dynamic>> questions;

  const _QuizRunnerSheet({required this.quiz, required this.questions});

  @override
  State<_QuizRunnerSheet> createState() => _QuizRunnerSheetState();
}

class _QuizRunnerSheetState extends State<_QuizRunnerSheet> {
  static const int _totalSeconds = 90;

  int _index = 0;
  int _score = 0;
  String _selectedOption = '';
  bool _answered = false;
  bool _completed = false;
  int _secondsLeft = _totalSeconds;
  Timer? _timer;
  DateTime _startedAt = DateTime.now();
  Map<String, dynamic>? _reward;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsLeft = _totalSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _completed) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _answered = true;
          _selectedOption = '';
          _completed = true;
        });
        final total = widget.questions.length;
        final success = total > 0 && _score >= (total / 2);
        _playFinishFeedback(success: success);
        _submitReward();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _currentAnswer() =>
      (widget.questions[_index]['answer'] ?? '').toString().toUpperCase();

  String get _formattedTime {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _optionColor(int index, String answer) {
    if (!_answered) return Colors.white;
    if (index == answer.codeUnitAt(0) - 65) {
      return const Color(0xFFE8F5E9);
    }
    if (_selectedOption.isNotEmpty &&
        index == _selectedOption.codeUnitAt(0) - 65 &&
        _selectedOption != answer) {
      return const Color(0xFFFFEBEE);
    }
    return Colors.white;
  }

  Color _optionBorderColor(int index, String answer) {
    if (!_answered) return const Color(0xFFE0E0E0);
    if (index == answer.codeUnitAt(0) - 65) return const Color(0xFF66BB6A);
    if (_selectedOption.isNotEmpty &&
        index == _selectedOption.codeUnitAt(0) - 65 &&
        _selectedOption != answer) {
      return const Color(0xFFEF5350);
    }
    return const Color(0xFFE0E0E0);
  }

  Widget? _optionTrailing(int index, String answer) {
    if (!_answered) return null;
    if (index == answer.codeUnitAt(0) - 65) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFF66BB6A),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 18),
      );
    }
    if (_selectedOption.isNotEmpty &&
        index == _selectedOption.codeUnitAt(0) - 65 &&
        _selectedOption != answer) {
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: Color(0xFFEF5350),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      );
    }
    return null;
  }

  Widget _buildResultIcon(bool success) {
    if (success) {
      return Stack(
        alignment: Alignment.center,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 90)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: const Positioned(
              top: 2,
              right: 18,
              child: Icon(Icons.star, color: Colors.yellow, size: 16),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.scale(scale: value, child: child),
              );
            },
            child: const Positioned(
              top: 14,
              left: 12,
              child: Icon(Icons.star, color: Colors.white, size: 12),
            ),
          ),
        ],
      );
    }

    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF5350),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF5350).withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(Icons.close_rounded, color: Colors.white, size: 60),
    );
  }

  void _choose(String key) {
    if (_answered || _completed) return;
    setState(() {
      _selectedOption = key;
      _answered = true;
      if (key == _currentAnswer()) _score += 1;
    });
    _playAnswerFeedback(isCorrect: key == _currentAnswer());
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted || _completed) return;
      _next();
    });
  }

  void _playAnswerFeedback({required bool isCorrect}) {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
    try {
      if (isCorrect) {
        HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  void _playFinishFeedback({required bool success}) {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      if (success) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    } catch (_) {}
  }

  Future<void> _next() async {
    if (!_answered) return;
    if (_index >= widget.questions.length - 1) {
      final total = widget.questions.length;
      final success = total > 0 && _score >= (total / 2);
      setState(() => _completed = true);
      _playFinishFeedback(success: success);
      await _submitReward();
      return;
    }
    setState(() {
      _index += 1;
      _selectedOption = '';
      _answered = false;
    });
  }

  int _starCount(int total) {
    if (total <= 0) return 0;
    final ratio = _score / total;
    if (ratio >= 0.85) return 3;
    if (ratio >= 0.70) return 2;
    if (ratio >= 0.50) return 1;
    return 0;
  }

  Future<void> _submitReward() async {
    if (_reward != null) return;
    try {
      final elapsed = DateTime.now().difference(_startedAt).inSeconds;
      final result = await Api.submitQuizReward(
        quizKey: (widget.quiz['quiz_key'] ?? 'quiz-generic').toString(),
        score: _score,
        total: widget.questions.length,
        timeSpentSeconds: elapsed,
      );
      if (!mounted) return;
      setState(() => _reward = result);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.questions[_index];
    final options = Map<String, dynamic>.from(q['options'] ?? {});
    final answer = _currentAnswer();
    final progress = (_index + (_completed ? 1 : 0)) / widget.questions.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.98,
      minChildSize: 0.85,
      maxChildSize: 0.98,
      builder: (_, controller) {
        final totalQuestions = widget.questions.length;
        final isSuccess =
          _completed && totalQuestions > 0
            ? _score >= (totalQuestions / 2)
            : false;
        final stars = _starCount(totalQuestions);

        return Container(
          color: const Color(0xFF29B6F6),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0277BD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      Text(
                        '${(_index + 1).toString().padLeft(2, '0')} of ${totalQuestions.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _secondsLeft < 15
                              ? const Color(0xFFEF5350)
                              : const Color(0xFF0277BD),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _secondsLeft < 15
                                  ? Icons.timer_off_outlined
                                  : Icons.timer_outlined,
                              color: Colors.white,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formattedTime,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF0277BD),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF69F0AE),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _completed
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildResultIcon(isSuccess),
                            const SizedBox(height: 12),
                            Text(
                              isSuccess ? 'Felicitations !' : 'Dommage !',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color:
                                    isSuccess
                                        ? const Color(0xFF212121)
                                        : const Color(0xFFEF5350),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(3, (i) {
                                final filled = i < stars;
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Icon(
                                    filled ? Icons.star_rounded : Icons.star_outline,
                                    color:
                                        filled
                                            ? const Color(0xFFFFB300)
                                            : const Color(0xFFBDBDBD),
                                    size: 32,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                            if (_reward != null)
                              Text(
                                '+${_reward!['points_earned'] ?? 0} points | +${_reward!['xp_earned'] ?? 0} XP',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF29B6F6),
                                ),
                              )
                            else
                              const Text(
                                'Calcul des recompenses...',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF29B6F6),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 18),
                                label: const Text(
                                  'OK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                        : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (q['category'] ?? 'Quiz').toString(),
                              style: const TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              (q['question'] ?? '').toString(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Expanded(
                              child: ListView.separated(
                                controller: controller,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) {
                                  final key = String.fromCharCode(65 + i);
                                  final value = (options[key] ?? '').toString();
                                  final correctIndex = answer.codeUnitAt(0) - 65;
                                  final isCorrectOption = _answered && i == correctIndex;
                                  final isWrongSelected = _answered &&
                                      _selectedOption.isNotEmpty &&
                                      i == _selectedOption.codeUnitAt(0) - 65 &&
                                      _selectedOption != answer;

                                  Widget tile = AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _optionColor(i, answer),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _optionBorderColor(i, answer),
                                        width: isCorrectOption || isWrongSelected ? 2.5 : 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            value,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF424242),
                                            ),
                                          ),
                                        ),
                                        if (_optionTrailing(i, answer) != null)
                                          _optionTrailing(i, answer)!,
                                      ],
                                    ),
                                  );

                                  // Animation déclenchée quand _answered change
                                  if (isCorrectOption) {
                                    tile = tile
                                        .animate(key: ValueKey('correct_$_index'))
                                        .scaleXY(
                                          begin: 1.0, end: 1.04,
                                          duration: 150.ms,
                                          curve: Curves.easeOut,
                                        )
                                        .then()
                                        .scaleXY(
                                          begin: 1.04, end: 1.0,
                                          duration: 150.ms,
                                          curve: Curves.easeIn,
                                        );
                                  } else if (isWrongSelected) {
                                    tile = tile
                                        .animate(key: ValueKey('wrong_$_index'))
                                        .moveX(begin: 0, end: 10, duration: 55.ms)
                                        .then()
                                        .moveX(begin: 10, end: -10, duration: 80.ms)
                                        .then()
                                        .moveX(begin: -10, end: 10, duration: 80.ms)
                                        .then()
                                        .moveX(begin: 10, end: 0, duration: 55.ms);
                                  }

                                  return GestureDetector(
                                    onTap: _answered ? null : () => _choose(key),
                                    child: tile,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 20),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
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
    this.payload,
  });

  final int level;
  final String label;
  final _SlalomNodeState state;
  final int stars;
  final int maxStars;
  final int? badge;
  final bool isDepart;
  final Map<String, dynamic>? payload;
}

class _SlalomHeaderCard extends StatelessWidget {
  const _SlalomHeaderCard({
    required this.specialty,
    required this.accent,
    required this.completedEpisodes,
    required this.totalEpisodes,
    required this.seasonStars,
    required this.totalStars,
  });

  final Specialty specialty;
  final Color accent;
  final int completedEpisodes;
  final int totalEpisodes;
  final int seasonStars;
  final int totalStars;

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
                      'QUIZ',
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
                icon: Icons.play_arrow_rounded,
                iconColor: const Color(0xFFE8334A),
                value: '$completedEpisodes',
                bgColor: const Color(0xFFFFEFF3),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Episodes termines',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D1B20),
                ),
              ),
              const Spacer(),
              Text(
                '$completedEpisodes / $totalEpisodes',
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [Color(0xFFFF6B8A), Color(0xFFE8334A)],
                    center: Alignment(-0.3, -0.3),
                    radius: 0.9,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x66E8334A),
                      blurRadius: 16,
                      offset: Offset(0, 6),
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
