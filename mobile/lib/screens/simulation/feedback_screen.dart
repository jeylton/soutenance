import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';

class FeedbackScreen extends StatefulWidget {
  final int score;
  final int sessionId;
  final List<dynamic>? expectedTreatment;
  final String? treatmentNotes;
  final String? expectedDiagnosis;
  final bool popToRootOnFinish;

  const FeedbackScreen({
    super.key,
    required this.score,
    required this.sessionId,
    this.expectedTreatment,
    this.treatmentNotes,
    this.expectedDiagnosis,
    this.popToRootOnFinish = true,
  });

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _tutorFeedback = '';
  bool _loadingFeedback = true;

  int get _stars {
    if (widget.score >= 17) return 3;
    if (widget.score >= 12) return 2;
    if (widget.score >= 1)  return 1;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _loadTutorFeedback();

    // Haptic feedback selon le score
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_stars == 3) {
        HapticFeedback.heavyImpact();
      } else if (_stars >= 1) {
        HapticFeedback.mediumImpact();
      }
    });
  }

  String _cleanFeedback(String text) {
    return text
        .replaceAll(RegExp(r'\*{1,3}'), '')   // retire * ** ***
        .replaceAll(RegExp(r'#{1,6}\s*'), '')  // retire ## titres
        .replaceAll(RegExp(r'_{1,2}'), '')     // retire _ __
        .replaceAll(RegExp(r'^\s*[-•]\s+', multiLine: true), '• ') // normalise les puces
        .replaceAll(RegExp(r'\n{3,}'), '\n\n') // max 2 sauts de ligne
        .trim();
  }

  Future<void> _loadTutorFeedback() async {
    const maxAttempts = 14; // ~21s
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (!mounted) return;
      try {
        final session = await Api.getSession(widget.sessionId);
        final raw = (session['feedback'] ?? '').toString();
        final feedback = _cleanFeedback(raw);
        if (feedback.trim().isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _tutorFeedback = feedback;
            _loadingFeedback = false;
          });
          return;
        }
      } catch (_) {
        // Ignore transient errors; we'll retry.
      }

      await Future.delayed(const Duration(milliseconds: 1500));
    }

    if (!mounted) return;
    setState(() {
      _tutorFeedback =
          'Feedback en cours de génération. Réessayez dans quelques secondes.';
      _loadingFeedback = false;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildVictoryBanner(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                children: [
                  _buildMetricCards(),
                  const SizedBox(height: 24),
                  if (widget.expectedDiagnosis != null &&
                      widget.expectedDiagnosis!.isNotEmpty)
                    _buildExpectedDiagnosis(),
                  if (widget.expectedTreatment != null &&
                      widget.expectedTreatment!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildExpectedTreatment(),
                  ],
                  const SizedBox(height: 24),
                  _buildTutorAnalysis(),
                  const SizedBox(height: 32),
                  _buildFinishButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVictoryBanner(BuildContext context) {
    final stars = _stars;
    final List<List<Color>> gradients = [
      [const Color(0xFFEF4444), const Color(0xFFDC2626)], // 0 étoiles — rouge
      [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)], // 1 étoile  — bleu
      [const Color(0xFF10B981), const Color(0xFF059669)], // 2 étoiles — vert
      [const Color(0xFFF59E0B), const Color(0xFFD97706)], // 3 étoiles — or
    ];
    final msgs = ['À améliorer', 'Bien essayé !', 'Bien joué !', 'Excellent ! 🏆'];
    final gradient = gradients[stars.clamp(0, 3)];
    final msg = msgs[stars.clamp(0, 3)];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Column(
        children: [
          // Bouton fermer
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => widget.popToRootOnFinish
                  ? Navigator.of(context).popUntil((r) => r.isFirst)
                  : Navigator.of(context).pop(true),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.x, size: 18, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Score
          Text(
            '${widget.score}/20',
            style: GoogleFonts.outfit(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1,
            ),
          ).animate().scale(
            begin: const Offset(0.5, 0.5),
            end: const Offset(1, 1),
            duration: 500.ms,
            curve: Curves.elasticOut,
          ),

          const SizedBox(height: 6),
          Text(
            msg,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

          const SizedBox(height: 20),

          // Étoiles animées
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (i) {
              final filled = i < stars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 48,
                  color: filled ? const Color(0xFFFDE68A) : Colors.white.withValues(alpha: 0.3),
                ).animate(delay: Duration(milliseconds: 400 + i * 200))
                  .scale(
                    begin: const Offset(0, 0),
                    end: const Offset(1, 1),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  )
                  .then()
                  .shimmer(
                    duration: 800.ms,
                    color: filled ? Colors.white : Colors.transparent,
                  ),
              );
            }),
          ),
        ],
      ),
    );
  }


  Widget _buildMetricCards() {
    final s = widget.score;
    final diagLabel =
        s >= 14
            ? 'Excellent'
            : s >= 10
            ? 'Bon'
            : 'À revoir';
    final effLabel =
        s >= 16
            ? 'Optimal'
            : s >= 10
            ? 'Correct'
            : 'Faible';
    final commLabel = s >= 12 ? 'Bon' : 'Moyen';
    final metrics = [
      {
        'label': 'DIAGNOSTIC',
        'value': diagLabel,
        'icon': LucideIcons.checkSquare,
        'color': s >= 14 ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
      },
      {
        'label': 'EFFICACITÉ',
        'value': effLabel,
        'icon': LucideIcons.zap,
        'color': AppColors.primary,
      },
      {
        'label': 'COMM.',
        'value': commLabel,
        'icon': LucideIcons.messageSquare,
        'color': const Color(0xFFF59E0B),
      },
    ];
    return Row(
      children:
          metrics.map((m) {
            final color = m['color'] as Color;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        m['icon'] as IconData,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      m['label'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m['value'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildTutorAnalysis() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  LucideIcons.graduationCap,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analyse du Tuteur',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Tuteur IA • Pédagogie Clinique',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _loadingFeedback
              ? const Center(child: CircularProgressIndicator())
              : Text(
                _tutorFeedback,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                  height: 1.6,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildExpectedDiagnosis() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  LucideIcons.stethoscope,
                  color: Color(0xFF6366F1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Diagnostic Attendu',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              widget.expectedDiagnosis!,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF4338CA),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpectedTreatment() {
    final meds = widget.expectedTreatment!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  LucideIcons.pill,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Traitement de Référence',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...meds.map<Widget>((med) {
            final m = med is Map ? med : {};
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.pill,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m['medication']?.toString() ?? 'Médicament',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (m['dosage'] != null &&
                          m['dosage'].toString().isNotEmpty)
                        _treatmentChip('Dosage', m['dosage'].toString()),
                      if (m['frequency'] != null &&
                          m['frequency'].toString().isNotEmpty)
                        _treatmentChip('Posologie', m['frequency'].toString()),
                      if (m['duration'] != null &&
                          m['duration'].toString().isNotEmpty)
                        _treatmentChip('Durée', m['duration'].toString()),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          if (widget.treatmentNotes != null &&
              widget.treatmentNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    LucideIcons.info,
                    size: 16,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.treatmentNotes!,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF92400E),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _treatmentChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1FAE5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF065F46),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          if (widget.popToRootOnFinish) {
            // Existing behavior (exam mode): return to main screen.
            Navigator.of(context).popUntil((route) => route.isFirst);
          } else {
            // Case mode: bubble up a completion result.
            Navigator.of(context).pop(true);
          }
        },
        icon: const Icon(LucideIcons.logOut, size: 20),
        label: Text(
          'Terminer la session',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

