import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<dynamic> _specialties = [];
  List<Map<String, dynamic>> _publishedQuizzes = [];
  final Set<String> _playedQuizKeys = <String>{};
  int? _selectedSpecialtyId;
  final ScrollController _specialtyScrollController = ScrollController();
  bool _loadingSpecialties = true;
  bool _loadingPublished = true;
  String _publishedError = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _specialtyScrollController.dispose();
    super.dispose();
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  void _startAutoRefresh() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      _loadPublishedQuizzes(showLoader: false);
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadSpecialties(),
      _loadPublishedQuizzes(),
      _loadPlayedQuizKeys(),
    ]);
  }

  Future<void> _loadPlayedQuizKeys() async {
    try {
      final summary = await Api.getQuizAttemptsSummary();
      if (!mounted) return;
      setState(() {
        _playedQuizKeys
          ..clear()
          ..addAll(summary.entries.where((e) => e.value > 0).map((e) => e.key));
      });
    } catch (_) {}
  }

  Future<void> _loadSpecialties() async {
    try {
      final specialties = await Api.getSpecialties();
      if (!mounted) return;
      setState(() {
        _specialties = specialties;
        _loadingSpecialties = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSpecialties = false);
    }
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

  List<Map<String, dynamic>> get _filteredQuizzes {
    if (_selectedSpecialtyId == null) return _publishedQuizzes;
    return _publishedQuizzes.where((q) {
      final qSpecialtyId = _asInt(q['specialty_id']);
      return qSpecialtyId == _selectedSpecialtyId;
    }).toList();
  }

  List<Map<String, dynamic>> get _specialtyTabs {
    if (_specialties.isNotEmpty) {
      return _specialties
          .map((sp) {
            final id = _asInt(sp['id']);
            final name = (sp['name'] ?? '').toString();
            return {'id': id, 'name': name};
          })
          .where((sp) => sp['id'] != null)
          .cast<Map<String, dynamic>>()
          .toList();
    }

    final unique = <int, String>{};
    for (final q in _publishedQuizzes) {
      final id = _asInt(q['specialty_id']);
      if (id == null) continue;
      final name = (q['specialty_name'] ?? '').toString().trim();
      unique[id] = name.isEmpty ? 'Spécialité $id' : name;
    }
    return unique.entries.map((e) => {'id': e.key, 'name': e.value}).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quiz',
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.iconBlueBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.clipboardCheck,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Choisissez une spécialité puis lancez un quiz déjà publié depuis le web admin.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              if (_loadingSpecialties && _specialtyTabs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                Text(
                  'Filtrer par spécialité',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  controller: _specialtyScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedSpecialtyId = null);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _selectedSpecialtyId == null
                                      ? AppColors.primary
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Toutes',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w800,
                                color:
                                    _selectedSpecialtyId == null
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ..._specialtyTabs.map((sp) {
                        final id = _asInt(sp['id']);
                        final name = (sp['name'] ?? '').toString();
                        final selected =
                            id != null && _selectedSpecialtyId == id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () {
                              if (id != null) {
                                setState(() => _selectedSpecialtyId = id);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    selected
                                        ? AppColors.primary
                                        : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                name,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  color:
                                      selected
                                          ? Colors.white
                                          : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (_specialtyTabs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Aucune spécialité disponible pour le moment.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quiz publiés',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              if (_publishedError.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Text(
                    'Erreur chargement quiz: $_publishedError',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFFB91C1C),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_loadingPublished)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_filteredQuizzes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _selectedSpecialtyId == null
                        ? 'Aucun quiz publié pour le moment. Publiez-le depuis le web admin.'
                        : 'Aucun quiz publié pour cette spécialité.',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                )
              else
                ..._filteredQuizzes.map((quiz) {
                  final quizKey =
                      (quiz['quiz_key'] ?? quiz['id'] ?? '').toString().trim();
                  final isPlayed =
                      quizKey.isNotEmpty && _playedQuizKeys.contains(quizKey);
                  final quizQuestions =
                      (quiz['questions'] as List<dynamic>? ?? [])
                          .whereType<Map>()
                          .map((q) => Map<String, dynamic>.from(q))
                          .toList();
                  final title = (quiz['title'] ?? 'Quiz').toString();
                  final disease =
                      (quiz['disease'] ?? 'Non précisée').toString();
                  final count = quizQuestions.length;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              if (isPlayed) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      LucideIcons.checkCircle2,
                                      size: 14,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Déjà joué',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                'Maladie: $disease',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$count questions',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 96,
                            maxWidth: 112,
                          ),
                          child: ElevatedButton(
                            onPressed:
                                quizQuestions.isEmpty
                                    ? null
                                    : () => _openQuizSheet(quiz),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(LucideIcons.play, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Jouer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizRunnerSheet extends StatefulWidget {
  final Map<String, dynamic> quiz;
  final List<Map<String, dynamic>> questions;

  const _QuizRunnerSheet({required this.quiz, required this.questions});

  @override
  State<_QuizRunnerSheet> createState() => _QuizRunnerSheetState();
}

class _QuizRunnerSheetState extends State<_QuizRunnerSheet> {
  static const int _secondsPerQuestion = 15;

  int _index = 0;
  int _score = 0;
  String _selectedOption = '';
  bool _timedOut = false;
  bool _answered = false;
  bool _completed = false;
  int _secondsLeft = _secondsPerQuestion;
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
    _secondsLeft = _secondsPerQuestion;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _completed || _answered) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() {
          _timedOut = true;
          _answered = true;
          _selectedOption = '';
        });
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

  void _choose(String key) {
    if (_answered || _completed) return;
    setState(() {
      _selectedOption = key;
      _timedOut = false;
      _answered = true;
      if (key == _currentAnswer()) _score += 1;
    });
    _timer?.cancel();
  }

  Future<void> _next() async {
    if (!_answered) return;
    if (_index >= widget.questions.length - 1) {
      setState(() => _completed = true);
      await _submitReward();
      return;
    }
    setState(() {
      _index += 1;
      _selectedOption = '';
      _timedOut = false;
      _answered = false;
    });
    _startTimer();
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
      initialChildSize: 0.95,
      minChildSize: 0.7,
      maxChildSize: 0.98,
      builder:
          (_, controller) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(22),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  (widget.quiz['title'] ?? 'Quiz').toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Maladie: ${(widget.quiz['disease'] ?? 'Non spécifiée').toString()}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (!_completed) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_index + 1}/${widget.questions.length}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  _secondsLeft <= 5
                                      ? const Color(0xFFFEF2F2)
                                      : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '⏱ ${_secondsLeft}s',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color:
                                    _secondsLeft <= 5
                                        ? const Color(0xFFDC2626)
                                        : const Color(0xFF475569),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Score: $_score',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      (q['question'] ?? '').toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...['A', 'B', 'C', 'D'].map((key) {
                    final value = (options[key] ?? '').toString();
                    final isSelected = _selectedOption == key;
                    final isCorrect = _answered && key == answer;
                    final isWrong = _answered && isSelected && key != answer;

                    Color border = const Color(0xFFE2E8F0);
                    Color bg = Colors.white;
                    if (isCorrect) {
                      border = const Color(0xFF86EFAC);
                      bg = const Color(0xFFF0FDF4);
                    } else if (isWrong) {
                      border = const Color(0xFFFCA5A5);
                      bg = const Color(0xFFFEF2F2);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: _answered ? null : () => _choose(key),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border),
                          ),
                          child: Text(
                            '$key) $value',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (_answered) ...[
                    const SizedBox(height: 6),
                    if (_timedOut) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Text(
                          'Temps écoulé: réponse non trouvée. Bonne réponse: $answer) ${(options[answer] ?? '').toString()}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      (q['explanation'] ?? '').toString(),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _index >= widget.questions.length - 1
                              ? 'Terminer le quiz'
                              : 'Question suivante',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Examen terminé',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Score: $_score/${widget.questions.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _reward == null
                              ? 'Calcul des récompenses...'
                              : '+${_reward!['points_earned'] ?? 0} points | +${_reward!['xp_earned'] ?? 0} XP',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        if (_reward != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Multiplicateur rejoue: x${_reward!['replay_multiplier'] ?? 1}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(
                        'Fermer',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
    );
  }
}
