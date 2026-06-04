import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/specialty.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';
import 'specialty_journey_screen.dart';
import '../../widgets/background_wave_painter.dart';
import '../../widgets/specialty_card.dart';
import '../../widgets/user_profile_bar.dart';

class SpecialtySelectionScreen extends StatefulWidget {
  const SpecialtySelectionScreen({super.key});

  @override
  State<SpecialtySelectionScreen> createState() =>
      _SpecialtySelectionScreenState();
}

class _SpecialtySelectionScreenState extends State<SpecialtySelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgController;
  List<Specialty> _specialties = [];
  bool _loading = true;
  String? _error;

  static const List<Color> _specialtyColors = [
    Color(0xFFF24E7D),
    Color(0xFF45BEEB),
    Color(0xFF7D57F1),
    Color(0xFFFFB347),
    Color(0xFF2E8B57),
    Color(0xFFDA70D6),
    Color(0xFF4682B4),
    Color(0xFFFF8C00),
  ];

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString().trim());
  }

  IconData _specialtyIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('cardio')) return Icons.favorite;
    if (n.contains('neuro')) return Icons.psychology;
    if (n.contains('pneumo')) return Icons.air;
    if (n.contains('infect')) return Icons.bug_report;
    if (n.contains('pedi')) return Icons.child_care;
    if (n.contains('gastro')) return Icons.restaurant;
    if (n.contains('derm')) return Icons.spa;
    if (n.contains('gyne')) return Icons.pregnant_woman;
    if (n.contains('uro')) return Icons.water_drop;
    if (n.contains('orl')) return Icons.hearing;
    if (n.contains('opht')) return Icons.visibility;
    if (n.contains('rhum')) return Icons.accessibility;
    if (n.contains('endo')) return Icons.biotech;
    if (n.contains('neph')) return Icons.shield;
    if (n.contains('hema')) return Icons.bloodtype;
    if (n.contains('psy')) return Icons.self_improvement;
    if (n.contains('chir')) return Icons.healing;
    if (n.contains('interne')) return Icons.medical_services;
    return Icons.auto_awesome;
  }

  Future<void> _loadSpecialties() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Api.getSpecialties();
      final rows =
          raw.whereType<Map>().map((sp) => Map<String, dynamic>.from(sp));
      final mapped = <Specialty>[];
      var index = 0;
      for (final sp in rows) {
        final id = _asInt(sp['id']);
        if (id == null) continue;
        final name = (sp['name'] ?? '').toString().trim();
        final color = _specialtyColors[index % _specialtyColors.length];
        mapped.add(
          Specialty(
            id: id,
            title: name.isEmpty ? 'Spécialité' : name,
            description: 'Progression clinique',
            icon: _specialtyIcon(name),
            color: color,
            progress: 0.0,
          ),
        );
        index += 1;
      }

      if (!mounted) return;
      setState(() {
        _specialties = mapped;
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

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _loadSpecialties();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final name = (session.userName ?? '').trim();
    final welcomeText = name.isEmpty ? 'Bienvenue' : 'Bienvenue, $name';

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
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            welcomeText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                    child: Column(
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
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
                        SizedBox(height: 12),
                        Text(
                          'Progresse dans chaque domaine, debloque des niveaux et deviens un veritable expert clinique.',
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
                if (_loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (_error != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 28,
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cloud_off,
                            size: 44,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadSpecialties,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount:
                            MediaQuery.of(context).size.width > 600 ? 3 : 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio:
                            MediaQuery.of(context).size.width < 360 ? 0.9 : 1.1,
                      ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final specialty = _specialties[index];

                        return SpecialtyCard(
                          specialty: specialty,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => SpecialtyJourneyScreen(
                                      specialty: specialty,
                                    ),
                              ),
                            );
                          },
                        );
                      }, childCount: _specialties.length),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
