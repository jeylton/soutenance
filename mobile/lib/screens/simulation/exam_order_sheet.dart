import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import 'package:provider/provider.dart';
import '../../state/session_state.dart';
import 'exam_results_screen.dart';

class ExamItem {
  final String name;
  final String delay;
  bool isOrdered;

  ExamItem({required this.name, required this.delay, this.isOrdered = false});
}

class ExamCategory {
  final String name;
  bool isExpanded;
  final List<ExamItem> items;

  ExamCategory({
    required this.name,
    required this.items,
    this.isExpanded = true,
  });
}

class ExamOrderSheet extends StatefulWidget {
  const ExamOrderSheet({super.key});

  @override
  State<ExamOrderSheet> createState() => _ExamOrderSheetState();
}

class _ExamOrderSheetState extends State<ExamOrderSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  final List<ExamCategory> _categories = [];
  bool _loading = true;
  // ignore: unused_field
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    try {
      final sessionState = Provider.of<SessionState>(context, listen: false);
      final caseId = sessionState.caseId ?? 0;
      final list = await Api.getCaseExams(caseId);
      setState(() {
        _categories.clear();
        _categories.add(
          ExamCategory(
            name: 'EXAMENS DU CAS',
            items:
                list
                    .map(
                      (e) => ExamItem(
                        name: e['name'] as String,
                        delay: 'Délai: -',
                      ),
                    )
                    .toList(),
          ),
        );
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  int get _orderedCount =>
      _categories.expand((c) => c.items).where((e) => e.isOrdered).length;

  List<ExamCategory> get _filtered {
    if (_query.isEmpty) return _categories;
    return _categories
        .map(
          (cat) => ExamCategory(
            name: cat.name,
            isExpanded: cat.isExpanded,
            items:
                cat.items
                    .where(
                      (e) =>
                          e.name.toLowerCase().contains(_query.toLowerCase()),
                    )
                    .toList(),
          ),
        )
        .where((cat) => cat.items.isNotEmpty)
        .toList();
  }

  void _resetAll() {
    setState(() {
      for (var cat in _categories) {
        for (var item in cat.items) {
          item.isOrdered = false;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    'Commander des\nExamens',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1E293B),
                      height: 1.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      size: 18,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: GoogleFonts.outfit(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Rechercher un examen...',
                  hintStyle: GoogleFonts.outfit(
                    color: const Color(0xFF94A3B8),
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    LucideIcons.search,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Exam List
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children:
                  (_loading
                      ? [
                        Container(
                          padding: const EdgeInsets.all(24),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      ]
                      : _filtered.map((cat) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category Header
                            InkWell(
                              onTap:
                                  () => setState(
                                    () => cat.isExpanded = !cat.isExpanded,
                                  ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  12,
                                  24,
                                  8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      cat.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFF64748B),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Icon(
                                      cat.isExpanded
                                          ? LucideIcons.chevronUp
                                          : LucideIcons.chevronDown,
                                      size: 16,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),

                            // Items
                            if (cat.isExpanded)
                              ...cat.items.map((exam) => _buildExamRow(exam)),
                          ],
                        );
                      }).toList()),
            ),
          ),

          // Bottom Bar
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_orderedCount examen${_orderedCount > 1 ? 's' : ''} sélectionné${_orderedCount > 1 ? 's' : ''}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                GestureDetector(
                  onTap: _resetAll,
                  child: Text(
                    'RÉINITIALISER',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFEF4444),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Validate Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _orderedCount > 0 ? _submitOrders : null,
                icon: const Icon(LucideIcons.send, size: 20),
                label: Text(
                  'Valider la demande',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  disabledBackgroundColor: const Color(0xFFCBD5E1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrders() async {
    final sessionState = Provider.of<SessionState>(context, listen: false);
    final sessionId = sessionState.sessionId ?? 0;
    try {
      for (final cat in _categories) {
        for (final item in cat.items.where((i) => i.isOrdered)) {
          await Api.addExam(sessionId, item.name);
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ExamResultsScreen()));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur commande examens: $e')));
    }
  }

  Widget _buildExamRow(ExamItem exam) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.name,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      exam.delay,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              // Commander / + button
              exam.isOrdered
                  ? ElevatedButton(
                    onPressed: () => setState(() => exam.isOrdered = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Commander',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  )
                  : GestureDetector(
                    onTap: () => setState(() => exam.isOrdered = true),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        LucideIcons.plus,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const Divider(
          height: 1,
          indent: 24,
          endIndent: 24,
          color: Color(0xFFE2E8F0),
        ),
      ],
    );
  }
}
