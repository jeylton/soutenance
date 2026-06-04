import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';

class CaseHistoryScreen extends StatefulWidget {
  const CaseHistoryScreen({super.key});

  @override
  State<CaseHistoryScreen> createState() => _CaseHistoryScreenState();
}

class _CaseHistoryScreenState extends State<CaseHistoryScreen> {
  List<dynamic> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final state = Provider.of<SessionState>(context, listen: false);
      final sessions = await Api.getSessions(userId: state.userId);
      // Only keep sessions that have a score (completed)
      final completed =
          sessions
              .where((s) => s is Map<String, dynamic> && s['score'] != null)
              .toList();
      setState(() {
        _sessions = completed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showFeedbackSheet(Map<String, dynamic> session) {
    final feedback = session['feedback'] as String?;
    final score = session['score'] ?? 0;
    final caseInfo = session['cases'] as Map<String, dynamic>?;
    final patientName = caseInfo?['patient_name'] ?? 'Patient';
    final progress = session['progress'] as Map<String, dynamic>?;
    final conclusion = progress?['conclusion'] as Map<String, dynamic>?;
    final studentDiagnosis = conclusion?['diagnosis'] ?? 'Non renseigné';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (_, scrollController) => Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                LucideIcons.messageSquare,
                                color: AppColors.primary,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Feedback Tuteur',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    patientName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: (score >= 14
                                        ? const Color(0xFF00C88C)
                                        : score >= 10
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFEF4444))
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$score/20',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color:
                                      score >= 14
                                          ? const Color(0xFF00C88C)
                                          : score >= 10
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Student diagnosis
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF1F5F9)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VOTRE DIAGNOSTIC',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                studentDiagnosis,
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      // Feedback content
                      Expanded(
                        child:
                            feedback != null && feedback.isNotEmpty
                                ? ListView(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    Text(
                                      feedback,
                                      style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF334155),
                                        height: 1.7,
                                      ),
                                    ),
                                  ],
                                )
                                : Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        LucideIcons.alertCircle,
                                        size: 40,
                                        color: Color(0xFF94A3B8),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Feedback non disponible',
                                        style: GoogleFonts.outfit(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            LucideIcons.chevronLeft,
            color: AppColors.textMain,
            size: 28,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Historique des Cas',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Text(
                  _error!,
                  style: GoogleFonts.outfit(color: AppColors.primary),
                ),
              )
              : _sessions.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.inbox,
                      size: 48,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune session terminée',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complétez un cas clinique pour le voir ici',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFB0B8C4),
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: () async {
                  setState(() => _loading = true);
                  await _loadSessions();
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final s = _sessions[index] as Map<String, dynamic>;
                    return _buildHistoryCard(s);
                  },
                ),
              ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> session) {
    final score = (session['score'] ?? 0) as num;
    final caseInfo = session['cases'] as Map<String, dynamic>?;
    final patientName = caseInfo?['patient_name'] ?? 'Cas clinique';
    final reason = caseInfo?['consultation_reason'] ?? '';
    final avatarUrl = Api.normalizeAssetUrl(caseInfo?['avatar'] as String?);
    final hasFeedback =
        session['feedback'] != null &&
        (session['feedback'] as String).isNotEmpty;
    final createdAt = session['created_at'] ?? '';
    final dateStr =
        createdAt.toString().length >= 10
            ? createdAt.toString().substring(0, 10)
            : '';
    final timeSpent = (session['time_spent'] ?? 0) as num;
    final minutes = (timeSpent / 60).floor();
    final seconds = (timeSpent % 60).toInt();
    final timeStr =
        timeSpent > 0 ? '${minutes}m ${seconds > 0 ? '${seconds}s' : ''}' : '';

    // Student diagnosis from progress
    final progress = session['progress'] as Map<String, dynamic>?;
    final conclusion = progress?['conclusion'] as Map<String, dynamic>?;
    final studentDiagnosis = conclusion?['diagnosis'] ?? '';

    final scoreColor =
        score >= 14
            ? const Color(0xFF00C88C)
            : score >= 10
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section with avatar + info
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      avatarUrl.isNotEmpty
                          ? (avatarUrl.contains('.svg')
                              ? SvgPicture.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                placeholderBuilder:
                                    (_) => const Icon(
                                      LucideIcons.user,
                                      color: Color(0xFF94A3B8),
                                    ),
                              )
                              : Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => const Icon(
                                      LucideIcons.user,
                                      color: Color(0xFF94A3B8),
                                    ),
                              ))
                          : const Icon(
                            LucideIcons.user,
                            color: Color(0xFF94A3B8),
                            size: 26,
                          ),
                ),
                const SizedBox(width: 14),
                // Patient name + reason
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patientName,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (reason.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          reason,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Score badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${score.toInt()}/20',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: scoreColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Divider
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Bottom section with meta + action
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              children: [
                // Meta row
                Row(
                  children: [
                    if (dateStr.isNotEmpty) ...[
                      Icon(
                        LucideIcons.calendar,
                        size: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                    if (timeStr.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      Icon(
                        LucideIcons.clock,
                        size: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        timeStr,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (studentDiagnosis.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          studentDiagnosis,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                // Feedback button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child:
                      hasFeedback
                          ? ElevatedButton.icon(
                            onPressed: () => _showFeedbackSheet(session),
                            icon: const Icon(
                              LucideIcons.messageSquare,
                              size: 18,
                            ),
                            label: Text(
                              'Revoir le feedback',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          )
                          : OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(LucideIcons.alertCircle, size: 18),
                            label: Text(
                              'Pas de feedback',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF94A3B8),
                              side: const BorderSide(
                                color: Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
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
}
