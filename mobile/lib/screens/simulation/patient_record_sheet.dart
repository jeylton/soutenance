import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../state/session_state.dart';

class PatientRecordSheet extends StatelessWidget {
  const PatientRecordSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final caseData = Provider.of<SessionState>(context, listen: false).caseData;
    final medicalHistory =
        (caseData?['medical_history'] is Map)
            ? caseData!['medical_history'] as Map<String, dynamic>
            : <String, dynamic>{};

    // Extract data from medical_history
    final antecedents =
        (medicalHistory['antecedents'] is Map)
            ? medicalHistory['antecedents'] as Map<String, dynamic>
            : <String, dynamic>{};
    final antecedentsPerso =
        (antecedents['perso'] is List)
            ? (antecedents['perso'] as List).map((e) => e.toString()).toList()
            : <String>[];
    final familiaux =
        (antecedents['familiaux'] is Map)
            ? antecedents['familiaux'] as Map<String, dynamic>
            : <String, dynamic>{};
    final allergies =
        (medicalHistory['allergies'] is List)
            ? (medicalHistory['allergies'] as List)
                .map((e) => e.toString())
                .toList()
            : <String>[];
    final habits =
        (medicalHistory['habits'] is List)
            ? (medicalHistory['habits'] as List)
            : <dynamic>[];

    // Build family entries
    final familyEntries = <Map<String, String>>[];
    familiaux.forEach((key, value) {
      if (value is List) {
        for (final condition in value) {
          familyEntries.add({
            'name': _capitalize(key),
            'condition': condition.toString(),
          });
        }
      } else if (value is String && value.isNotEmpty) {
        familyEntries.add({'name': _capitalize(key), 'condition': value});
      }
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.contact,
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
                        'Carnet de Santé',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      if (caseData?['patient_name'] != null)
                        Text(
                          caseData!['patient_name'],
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Content
          Expanded(
            child:
                (antecedentsPerso.isEmpty &&
                        familyEntries.isEmpty &&
                        allergies.isEmpty &&
                        habits.isEmpty)
                    ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.fileQuestion,
                            size: 48,
                            color: const Color(0xFFCBD5E1),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aucune donnée médicale disponible\npour ce patient.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (antecedentsPerso.isNotEmpty) ...[
                          _buildSection(
                            icon: LucideIcons.user,
                            iconColor: AppColors.primary,
                            iconBg: AppColors.primary.withValues(alpha: 0.1),
                            title: 'Antécédents Personnels',
                            child: _buildListCard(antecedentsPerso),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (familyEntries.isNotEmpty) ...[
                          _buildSection(
                            icon: LucideIcons.users,
                            iconColor: const Color(0xFF8B5CF6),
                            iconBg: const Color(0xFFF3EDFF),
                            title: 'Antécédents Familiaux',
                            child: _buildFamilyCard(familyEntries),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (allergies.isNotEmpty) ...[
                          _buildSection(
                            icon: LucideIcons.alertTriangle,
                            iconColor: const Color(0xFFEF4444),
                            iconBg: const Color(0xFFFEF2F2),
                            title: 'Allergies',
                            child: _buildAllergiesCard(allergies),
                          ),
                          const SizedBox(height: 20),
                        ],
                        if (habits.isNotEmpty) ...[
                          _buildSection(
                            icon: LucideIcons.activity,
                            iconColor: const Color(0xFF22C55E),
                            iconBg: const Color(0xFFEFFFF5),
                            title: 'Habitudes de Vie',
                            child: _buildHabitsCard(habits),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
          ),

          // Close Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Fermer',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildListCard(List<String> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
            items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        entry.value,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: Color(0xFFF1F5F9),
                    ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildFamilyCard(List<Map<String, String>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children:
            items.asMap().entries.map((entry) {
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.value['name']!,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          entry.value['condition']!,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                      height: 1,
                      indent: 18,
                      endIndent: 18,
                      color: Color(0xFFF1F5F9),
                    ),
                ],
              );
            }).toList(),
      ),
    );
  }

  Widget _buildAllergiesCard(List<String> allergies) {
    if (allergies.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          allergies.map((allergy) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    LucideIcons.alertCircle,
                    size: 14,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    allergy,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFEF4444),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildHabitsCard(List<dynamic> habits) {
    if (habits.isEmpty) return const SizedBox.shrink();

    final habitWidgets = <Widget>[];
    for (int i = 0; i < habits.length; i++) {
      final h = habits[i];
      String label;
      String? sublabel;
      if (h is String) {
        label = h;
      } else if (h is Map) {
        label = (h['label'] ?? h['name'] ?? h.toString()).toString();
        sublabel = h['sublabel']?.toString() ?? h['detail']?.toString();
      } else {
        label = h.toString();
      }

      habitWidgets.add(
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.heart,
                      color: Color(0xFF22C55E),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        if (sublabel != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            sublabel,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < habits.length - 1)
              const Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: Color(0xFFF1F5F9),
              ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: habitWidgets),
    );
  }
}
