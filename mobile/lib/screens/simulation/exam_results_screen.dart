import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import 'feedback_screen.dart';
import 'package:provider/provider.dart';
import '../../state/session_state.dart';
import '../../services/api.dart';

class ExamResult {
  final String name;
  final String category;
  final String time;
  final String? imagingFindingLabel;
  final String? findingText;
  final List<ExamValue>? values;

  const ExamResult({
    required this.name,
    required this.category,
    required this.time,
    this.imagingFindingLabel,
    this.findingText,
    this.values,
  });
}

class ExamValue {
  final String label;
  final String value;
  final bool isAbnormal;

  const ExamValue({
    required this.label,
    required this.value,
    this.isAbnormal = false,
  });
}

// ignore: unused_element
const List<ExamResult> _mockResults = [
  ExamResult(
    name: 'Complete Blood Count (CBC)',
    category: 'LABORATORY',
    time: '10:30 AM',
    values: [
      ExamValue(label: 'Hemoglobin', value: '14.2 g/dL'),
      ExamValue(
        label: 'White Blood Cell Count',
        value: '12,500 /mm³ ↑',
        isAbnormal: true,
      ),
      ExamValue(label: 'Platelets', value: '250,000 /mm³'),
    ],
  ),
  ExamResult(
    name: 'Chest X-Ray (PA/Lateral)',
    category: 'RADIOLOGY',
    time: '11:15 AM',
    imagingFindingLabel: 'CLINICAL FINDING',
    findingText:
        'Normal cardiothoracic ratio. No evidence of pulmonary consolidation, pleural effusion, or pneumothorax. Bony thorax appears intact.',
  ),
  ExamResult(
    name: '12-Lead ECG',
    category: 'CARDIOLOGY',
    time: '10:45 AM',
    imagingFindingLabel: 'INTERPRETATION',
    findingText:
        'Sinus tachycardia at 105 bpm. ST-segment elevation in leads V1-V4 suggesting acute anteroseptal myocardial infarction.',
  ),
  ExamResult(
    name: 'Cardiac Troponin I',
    category: 'LABORATORY',
    time: '11:30 AM',
    values: [
      ExamValue(label: 'Result', value: '4.50 ng/mL (High)', isAbnormal: true),
    ],
  ),
];

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({super.key});

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _requested = [];
  bool _loading = true;
  String? _error;

  // Form controllers for Conclusion tab
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _justificationController =
      TextEditingController();
  final TextEditingController _medicationController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _frequencyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequestedExams();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _diagnosisController.dispose();
    _justificationController.dispose();
    _medicationController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildExamTab(), _buildConclusionTab(context)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 24, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.chevronLeft,
                size: 22,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            "Résultats d'Examens",
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: TabBar(
        controller: _tabController,
        labelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        unselectedLabelStyle: GoogleFonts.outfit(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
        labelColor: AppColors.primary,
        unselectedLabelColor: const Color(0xFF94A3B8),
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorWeight: 3,
        dividerColor: const Color(0xFFE2E8F0),
        tabs: const [Tab(text: 'EXAM'), Tab(text: 'CONCLUSION')],
      ),
    );
  }

  Widget _buildExamTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Requested Exams Header
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.clipboardList,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'REQUESTED EXAMS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),

        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              style: GoogleFonts.outfit(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (!_loading && _error == null)
          ..._requested.map((e) => _buildRequestedCard(e)),
      ],
    );
  }

  Future<void> _loadRequestedExams() async {
    try {
      final sessionState = Provider.of<SessionState>(context, listen: false);
      final id = sessionState.sessionId ?? 0;
      final list = await Api.getSessionExams(id);
      setState(() {
        _requested = List<Map<String, dynamic>>.from(list);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Widget _buildRequestedCard(Map<String, dynamic> exam) {
    final name = (exam['name'] ?? '') as String;
    final result = _sanitizeRawResult((exam['result'] ?? '') as String);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'EXAM',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Résultats bruts laboratoire/imagerie (sans interprétation)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF4F46E5),
                    ),
                  ),
                ),
                Text(
                  result.isEmpty ? 'Aucun résultat brut disponible' : result,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _sanitizeRawResult(String input) {
    if (input.trim().isEmpty) return '';
    final normalized = input.replaceAll('\r\n', '\n').trim();
    final lines = normalized.split('\n');
    final filtered = <String>[];

    final banned = [
      RegExp(r'\bdiagnostic\b', caseSensitive: false),
      RegExp(r'\binterpr[eé]tation\b', caseSensitive: false),
      RegExp(r'\bconclusion\b', caseSensitive: false),
      RegExp(r'\bimpression\b', caseSensitive: false),
      RegExp(r'\bsugg[eè]re\b', caseSensitive: false),
      RegExp(r'\bcompatible avec\b', caseSensitive: false),
      RegExp(r'\bprobable\b', caseSensitive: false),
      RegExp(r'\bindique\b', caseSensitive: false),
    ];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final hasInterpretation = banned.any((r) => r.hasMatch(line));
      if (!hasInterpretation) filtered.add(line);
    }

    if (filtered.isEmpty) {
      return 'Données techniques disponibles, mais les lignes interprétatives ont été masquées pour l\'entraînement.';
    }
    return filtered.join('\n');
  }

  // ignore: unused_element
  Widget _buildResultCard(ExamResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.name,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            result.category,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              color: Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            result.time,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Card Content
          if (result.values != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children:
                    result.values!.map((val) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              val.label,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                            Text(
                              val.value,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:
                                    val.isAbnormal
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              ),
            ),

          if (result.findingText != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Text(
                result.imagingFindingLabel ?? 'FINDING',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                result.findingText!,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                  height: 1.55,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConclusionTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Chief Complaint banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  LucideIcons.messageSquare,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CHIEF COMPLAINT',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Male, 58 years old, presenting with acute retrosternal chest pain radiating to the left arm, associated with diaphoresis and shortness of breath for 2 hours.',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Final Diagnosis
        _buildFormLabel('FINAL DIAGNOSIS'),
        const SizedBox(height: 8),
        _buildSearchField(
          controller: _diagnosisController,
          hint: 'Search for a diagnosis (e.g. Myocardial...)',
          icon: LucideIcons.search,
        ),
        const SizedBox(height: 20),

        // Clinical Justification
        _buildFormLabel('CLINICAL JUSTIFICATION'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _justificationController,
            maxLines: 5,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFF374151),
            ),
            decoration: InputDecoration(
              hintText:
                  'Briefly justify your diagnosis based on clinical findings and exams...',
              hintStyle: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF94A3B8),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.all(18),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Treatment Plan
        _buildFormLabel('TREATMENT PLAN'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTreatmentField(
                label: 'MEDICATION',
                controller: _medicationController,
                hint: 'e.g. Aspirin',
              ),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              Row(
                children: [
                  Expanded(
                    child: _buildTreatmentField(
                      label: 'DOSAGE',
                      controller: _dosageController,
                      hint: 'e.g. 300mg',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTreatmentField(
                      label: 'FREQUENCY',
                      controller: _frequencyController,
                      hint: 'e.g. Once',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () async {
              final sessionState = Provider.of<SessionState>(
                context,
                listen: false,
              );
              final id = sessionState.sessionId ?? 0;
              final timeSpent = sessionState.elapsedSeconds;
              try {
                final result = await Api.concludeSession(
                  id,
                  _diagnosisController.text,
                  _justificationController.text,
                  timeSpent,
                  treatment: {
                    'medication': _medicationController.text,
                    'dosage': _dosageController.text,
                    'frequency': _frequencyController.text,
                  },
                );
                final score = (result['score'] ?? 0) as int;
                final expectedTreatment =
                    result['expected_treatment'] as List<dynamic>?;
                final treatmentNotes = result['treatment_notes'] as String?;
                final expectedDiagnosis =
                    result['expected_diagnosis'] as String?;
                if (mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => FeedbackScreen(
                            score: score,
                            sessionId: id,
                            expectedTreatment: expectedTreatment,
                            treatmentNotes: treatmentNotes,
                            expectedDiagnosis: expectedDiagnosis,
                          ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur soumission: $e')),
                  );
                }
              }
            },
            icon: const Icon(LucideIcons.send, size: 20),
            label: Text(
              'Submit for Evaluation',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
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
        ),
        const SizedBox(height: 12),
        Text(
          'By submitting, your diagnosis will be compared with the clinical gold standard and your score will be calculated.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF94A3B8),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildFormLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF64748B),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.outfit(fontSize: 14, color: const Color(0xFF374151)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
            fontSize: 14,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildTreatmentField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: const Color(0xFF374151),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              color: const Color(0xFFCBD5E1),
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
