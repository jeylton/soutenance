import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../simulation/simulation_screen.dart';
import '../../services/api.dart';
import '../../services/notification_service.dart';
import 'package:provider/provider.dart';
import '../../state/session_state.dart';
import '../../models/specialty.dart';
import '../profile/profile_screen.dart';
import '../notifications/notifications_screen.dart';
import '../exam/exam_screen.dart';
import 'specialty_journey_screen.dart';

// Translation helper (uses SessionState)
String _t(BuildContext context, String fr, String en) {
  final state = Provider.of<SessionState>(context, listen: false);
  return state.t(fr, en);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialSpecialtyId,
    this.initialCategory,
  });

  final int? initialSpecialtyId;
  final String? initialCategory;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<dynamic> _cases = [];
  List<dynamic> _specialties = [];
  final Set<int> _playedCaseIds = <int>{};
  String _selectedCategory = 'Tous';
  int? _selectedSpecialtyId;
  final ScrollController _specialtyScrollController = ScrollController();
  String _searchQuery = '';
  bool _loading = true;
  String? _error;
  int _examCount = 0;

  static const List<Color> _specialtyColors = [
    Color(0xFFF24E7D),
    Color(0xFF45BEEB),
    Color(0xFF7D57F1),
    Color(0xFFFFB347),
    Color(0xFF2E8B57),
    Color(0xFFDA70D6),
    Color(0xFF4682B4),
  ];

  @override
  void initState() {
    super.initState();
    _selectedSpecialtyId = widget.initialSpecialtyId;
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _selectedCategory = widget.initialCategory!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([Api.getCases(), Api.getSpecialties()]);
      // Start real-time notification listener
      final sessionState = Provider.of<SessionState>(context, listen: false);
      final notifService = Provider.of<NotificationService>(
        context,
        listen: false,
      );
      if (sessionState.userId != null) {
        notifService.startListening(sessionState.userId!);
      }
      int exams = 0;
      final playedCaseIds = <int>{};
      try {
        final examList = await Api.getExamAssignments();
        exams = examList.length;
      } catch (_) {}

      if (sessionState.userId != null && sessionState.userId!.isNotEmpty) {
        // Charger le streak en parallèle
        Api.getStreak().then((s) => sessionState.setStreak(s)).catchError((_) {});

        try {
          final sessions = await Api.getSessions(userId: sessionState.userId!);
          for (final s in sessions) {
            if (s is! Map) continue;
            final caseId = _asInt(s['case_id']);
            if (caseId != null) playedCaseIds.add(caseId);
          }
        } catch (_) {}
      }

      setState(() {
        _cases = results[0].where((c) => c['status'] == 'active').toList();
        _specialties = results[1];
        if (_selectedSpecialtyId != null) {
          final selected = _specialties.cast<Map>().firstWhere(
            (sp) => _asInt(sp['id']) == _selectedSpecialtyId,
            orElse: () => <String, dynamic>{},
          );
          final selectedName = (selected['name'] ?? '').toString().trim();
          if (selectedName.isNotEmpty) {
            _selectedCategory = selectedName;
          }
        }
        _playedCaseIds
          ..clear()
          ..addAll(playedCaseIds);
        _examCount = exams;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  IconData _specialtyIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('cardio')) return LucideIcons.heartPulse;
    if (n.contains('neuro')) return LucideIcons.brain;
    if (n.contains('pneumo')) return LucideIcons.stethoscope;
    if (n.contains('infect')) return LucideIcons.shield;
    if (n.contains('pedi')) return LucideIcons.baby;
    if (n.contains('gastro')) return LucideIcons.pill;
    return LucideIcons.activity;
  }

  Future<void> _startSimulation(
    BuildContext context,
    Map<String, dynamic> c,
  ) async {
    final sessionState = Provider.of<SessionState>(context, listen: false);
    final userId = sessionState.userId ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter')));
      return;
    }
    try {
      final sessionId = await Api.createSession(userId, c['id'] as int);
      final startedCaseId = _asInt(c['id']);
      if (startedCaseId != null && mounted) {
        setState(() => _playedCaseIds.add(startedCaseId));
      }
      sessionState.startCase(c['id'] as int, sessionId, caseData: c);
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const SimulationScreen()));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  @override
  void dispose() {
    _specialtyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Dica Clinic',
                    style: GoogleFonts.outfit(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                      letterSpacing: -0.5,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const NotificationsScreen(),
                            ),
                          );
                          // Refresh count from realtime service
                          final notifService = Provider.of<NotificationService>(
                            context,
                            listen: false,
                          );
                          notifService.refreshUnreadCount();
                        },
                        child: Consumer<NotificationService>(
                          builder: (context, notifService, _) {
                            final unreadCount = notifService.unreadCount;
                            return Stack(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFF7ED),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    LucideIcons.bell,
                                    color: Color(0xFFF59E0B),
                                    size: 22,
                                  ),
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          unreadCount > 9
                                              ? '9+'
                                              : '$unreadCount',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => const ProfileScreen(
                                      showBackButton: true,
                                    ),
                              ),
                            ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.iconBlueBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.user,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  onChanged:
                      (value) =>
                          setState(() => _searchQuery = value.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: _t(
                      context,
                      'Rechercher un symptôme...',
                      'Search a symptom...',
                    ),
                    hintStyle: GoogleFonts.outfit(
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w600,
                    ),
                    prefixIcon: const Icon(
                      LucideIcons.search,
                      color: Color(0xFF94A3B8),
                      size: 22,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    fillColor: Colors.transparent,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Exam banner
              if (_examCount > 0)
                GestureDetector(
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ExamScreen()),
                      ),
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.clipboardCheck,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_examCount ${_t(context, 'examen', 'exam')}${_examCount > 1 ? 's' : ''} ${_t(context, 'disponible', 'available')}${_examCount > 1 ? 's' : ''}',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                _t(
                                  context,
                                  'Mode examen — évaluation officielle',
                                  'Exam mode — official evaluation',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          LucideIcons.chevronRight,
                          color: Colors.white,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

              // Categories
              SingleChildScrollView(
                controller: _specialtyScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap:
                          () => setState(() {
                            _selectedCategory = 'Tous';
                            _selectedSpecialtyId = null;
                          }),
                      child: _buildCategoryTab(
                        'Tous',
                        _selectedCategory == 'Tous',
                      ),
                    ),
                    ..._specialties.asMap().entries.map((entry) {
                      final index = entry.key;
                      final sp = entry.value;
                      final name = sp['name'] ?? '';
                      final spId = _asInt(sp['id']);
                      return GestureDetector(
                        onTap: () {
                          if (spId == null) return;
                          setState(() {
                            _selectedCategory = name;
                            _selectedSpecialtyId = spId;
                          });

                          final specialty = Specialty(
                            id: spId,
                            title: name.toString(),
                            description: 'Progression clinique',
                            icon: _specialtyIcon(name.toString()),
                            color: _specialtyColors[index % _specialtyColors.length],
                            progress: 0,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => SpecialtyJourneyScreen(
                                    specialty: specialty,
                                  ),
                            ),
                          );
                        },
                        child: _buildCategoryTab(
                          name,
                          _selectedCategory == name,
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Motifs Title
              Builder(
                builder: (context) {
                  final filteredCount =
                      _cases.where((c) {
                        if (_selectedCategory != 'Tous' &&
                            _selectedSpecialtyId != null) {
                          final caseSpecId = _asInt(c['specialty_id']);
                          if (caseSpecId != _selectedSpecialtyId) return false;
                        }
                        if (_searchQuery.isNotEmpty) {
                          final reason =
                              (c['consultation_reason'] ?? '')
                                  .toString()
                                  .toLowerCase();
                          final name =
                              (c['patient_name'] ?? '')
                                  .toString()
                                  .toLowerCase();
                          return reason.contains(_searchQuery) ||
                              name.contains(_searchQuery);
                        }
                        return true;
                      }).length;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _t(
                          context,
                          'Motifs de consultation',
                          'Consultation reasons',
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        '$filteredCount ${_t(context, 'disponibles', 'available')}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Text(
                  _error!,
                  style: GoogleFonts.outfit(color: AppColors.primary),
                ),
              if (!_loading && _error == null)
                ..._cases
                    .where((c) {
                      if (_selectedCategory != 'Tous' &&
                          _selectedSpecialtyId != null) {
                        final caseSpecId = _asInt(c['specialty_id']);
                        if (caseSpecId != _selectedSpecialtyId) return false;
                      }
                      if (_searchQuery.isNotEmpty) {
                        final reason =
                            (c['consultation_reason'] ?? '')
                                .toString()
                                .toLowerCase();
                        final name =
                            (c['patient_name'] ?? '').toString().toLowerCase();
                        final symptoms =
                            (c['initial_symptoms'] ?? '')
                                .toString()
                                .toLowerCase();
                        return reason.contains(_searchQuery) ||
                            name.contains(_searchQuery) ||
                            symptoms.contains(_searchQuery);
                      }
                      return true;
                    })
                    .map((c) {
                      final diff = (c['difficulty'] ?? 1) as int;
                      final durationMin =
                          diff <= 1
                              ? '10 min'
                              : diff == 2
                              ? '12 min'
                              : diff == 3
                              ? '15 min'
                              : diff == 4
                              ? '20 min'
                              : '25 min';
                      return _buildMotifCard(
                        context,
                        icon:
                            diff <= 1
                                ? LucideIcons.thermometer
                                : diff == 2
                                ? LucideIcons.heartPulse
                                : diff == 3
                                ? LucideIcons.stethoscope
                                : diff == 4
                                ? LucideIcons.brain
                                : LucideIcons.flame,
                        title:
                            c['consultation_reason'] ??
                            c['patient_name'] ??
                            _t(context, 'Cas', 'Case'),
                        difficulty:
                            diff <= 1
                                ? _t(context, 'TRÈS FACILE', 'VERY EASY')
                                : diff == 2
                                ? _t(context, 'FACILE', 'EASY')
                                : diff == 3
                                ? _t(context, 'INTERMÉDIAIRE', 'INTERMEDIATE')
                                : diff == 4
                                ? _t(context, 'DIFFICILE', 'HARD')
                                : _t(context, 'TRÈS DIFFICILE', 'VERY HARD'),
                        duration: durationMin,
                        stars: diff.clamp(1, 5),
                        color: AppColors.iconBlueBg,
                        iconColor: AppColors.primary,
                        isCompleted: _playedCaseIds.contains(
                          _asInt(c['id']) ?? -1,
                        ),
                        onTap:
                            () => _startSimulation(
                              context,
                              c as Map<String, dynamic>,
                            ),
                      );
                    })
                    .toList(),

              const SizedBox(height: 32),

              // Featured Case Card (first case or empty)
              if (_cases.isNotEmpty) ...[
                GestureDetector(
                  onTap:
                      () => _startSimulation(
                        context,
                        _cases.first as Map<String, dynamic>,
                      ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
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
                                'CAS À DÉCOUVRIR',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white.withValues(alpha: 0.8),
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                (_cases.first['consultation_reason'] ??
                                        _cases.first['patient_name'] ??
                                        _t(context, 'Nouveau cas', 'New case'))
                                    .toString(),
                                style: GoogleFonts.outfit(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _t(
                                  context,
                                  'Commencer la simulation →',
                                  'Start simulation →',
                                ),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        if (_cases.first['avatar'] != null &&
                            _cases.first['avatar'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              Api.normalizeAssetUrl(
                                _cases.first['avatar'].toString(),
                              ),
                              width: 60,
                              height: 80,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Container(
                                    width: 60,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        LucideIcons.activity,
                                        color: Colors.white,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                            ),
                          )
                        else
                          Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Icon(
                                LucideIcons.activity,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab(String title, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        boxShadow:
            isSelected
                ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _buildMotifCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String difficulty,
    required String duration,
    required int stars,
    bool isCompleted = false,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('Click on motif: $title');
            onTap();
          },
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                                height: 1.2,
                              ),
                            ),
                          ),
                          if (isCompleted)
                            const Icon(
                              LucideIcons.checkCircle2,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          const SizedBox(width: 8),
                          const Icon(
                            LucideIcons.chevronRight,
                            color: Color(0xFFCBD5E1),
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Stars
                          ...List.generate(
                            5,
                            (index) => Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Icon(
                                LucideIcons.star,
                                size: 14,
                                color:
                                    index < stars
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            difficulty,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFFF59E0B),
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Icon(
                            LucideIcons.clock,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            duration,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
