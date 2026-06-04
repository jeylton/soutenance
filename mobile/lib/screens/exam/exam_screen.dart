import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';
import '../simulation/simulation_screen.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  List<dynamic> _assignments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      final data = await Api.getExamAssignments();
      setState(() {
        _assignments = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startExam(Map<String, dynamic> assignment) async {
    final sessionState = Provider.of<SessionState>(context, listen: false);
    final userId = sessionState.userId ?? '';
    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Veuillez vous connecter')));
      return;
    }

    // Check due date
    if (assignment['due_date'] != null) {
      final due = DateTime.tryParse(assignment['due_date'].toString());
      if (due != null && DateTime.now().isAfter(due)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cet examen est expiré'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    // Confirm start
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(
              'Démarrer l\'examen',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assignment['cases']?['consultation_reason'] ?? 'Cas clinique',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (assignment['time_limit'] != null)
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Temps limité : ${assignment['time_limit']} minutes',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  'Attention : mode examen — votre performance sera évaluée.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Commencer'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    try {
      final caseId = assignment['case_id'] as int;
      final sessionId = await Api.createExamSession(
        userId,
        caseId,
        assignment['id'] as int?,
      );

      // Load case data
      final caseData = await Api.getCase(caseId);
      final timeLimit = assignment['time_limit'] as int?;
      sessionState.startCase(
        caseId,
        sessionId,
        caseData: caseData,
        isExam: true,
        timeLimitMinutes: timeLimit,
      );

      if (mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SimulationScreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Examens',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _assignments.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.clipboardCheck,
                      size: 64,
                      color: Colors.grey[300],
                    ).animate().fadeIn(duration: 600.ms),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun examen programmé',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vos enseignants n\'ont pas encore assigné d\'examens',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _loadExams,
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _assignments.length,
                  itemBuilder: (context, index) {
                    final a = _assignments[index] as Map<String, dynamic>;
                    final caseName =
                        (a['cases']
                            as Map<String, dynamic>?)?['consultation_reason'] ??
                        (a['cases']
                            as Map<String, dynamic>?)?['patient_name'] ??
                        'Cas #${a['case_id']}';
                    final timeLimit = a['time_limit'];
                    final dueDate =
                        a['due_date'] != null
                            ? DateTime.tryParse(a['due_date'].toString())
                            : null;
                    final isExpired =
                        dueDate != null && DateTime.now().isAfter(dueDate);
                    final group = a['group_name'];

                    return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors:
                                  isExpired
                                      ? [
                                        const Color(0xFFF1F5F9),
                                        const Color(0xFFE2E8F0),
                                      ]
                                      : [
                                        const Color(0xFFF5F3FF),
                                        const Color(0xFFEDE9FE),
                                      ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color:
                                  isExpired
                                      ? const Color(0xFFCBD5E1)
                                      : const Color(
                                        0xFF8B5CF6,
                                      ).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isExpired ? null : () => _startExam(a),
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color:
                                                isExpired
                                                    ? Colors.grey[300]
                                                    : const Color(
                                                      0xFF8B5CF6,
                                                    ).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Icon(
                                            LucideIcons.clipboardCheck,
                                            color:
                                                isExpired
                                                    ? Colors.grey[500]
                                                    : const Color(0xFF8B5CF6),
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isExpired ? 'EXPIRÉ' : 'EXAMEN',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      isExpired
                                                          ? Colors.grey[500]
                                                          : const Color(
                                                            0xFF8B5CF6,
                                                          ),
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                caseName,
                                                style: GoogleFonts.outfit(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      isExpired
                                                          ? Colors.grey[500]
                                                          : const Color(
                                                            0xFF1E293B,
                                                          ),
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isExpired)
                                          const Icon(
                                            LucideIcons.chevronRight,
                                            color: Color(0xFF8B5CF6),
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      children: [
                                        if (timeLimit != null) ...[
                                          Icon(
                                            LucideIcons.clock,
                                            size: 14,
                                            color:
                                                isExpired
                                                    ? Colors.grey[400]
                                                    : Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$timeLimit min',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isExpired
                                                      ? Colors.grey[400]
                                                      : Colors.orange,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                        ],
                                        if (dueDate != null) ...[
                                          Icon(
                                            LucideIcons.calendar,
                                            size: 14,
                                            color:
                                                isExpired
                                                    ? Colors.red[300]
                                                    : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${dueDate.day}/${dueDate.month}/${dueDate.year}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isExpired
                                                      ? Colors.red[300]
                                                      : Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                        ],
                                        if (group != null) ...[
                                          Icon(
                                            LucideIcons.users,
                                            size: 14,
                                            color:
                                                isExpired
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            group,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color:
                                                  isExpired
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(delay: (index * 100).ms, duration: 400.ms)
                        .slideX(begin: 0.1, end: 0);
                  },
                ),
              ),
    );
  }
}
