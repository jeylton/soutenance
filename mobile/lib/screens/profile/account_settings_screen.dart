import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../state/session_state.dart';
import '../../services/api.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _twoFactorEnabled = true;
  bool _useFreePatientVoices = true;
  bool _saving = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _institutionCtrl;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<SessionState>(context, listen: false);
    _useFreePatientVoices = state.useFreePatientVoices;
    _nameCtrl = TextEditingController(text: state.userName ?? '');
    _emailCtrl = TextEditingController(text: state.userEmail ?? '');
    _phoneCtrl = TextEditingController();
    _institutionCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _institutionCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.updateProfile({'full_name': _nameCtrl.text.trim()});
      final state = Provider.of<SessionState>(context, listen: false);
      state.updateProfile(name: _nameCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          'Paramètres du compte',
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('INFORMATIONS PERSONNELLES'),
            const SizedBox(height: 16),
            _buildSettingsContainer([
              _buildEditableField('NOM COMPLET', _nameCtrl),
              _buildDivider(),
              _buildEditableField('EMAIL', _emailCtrl),
              _buildDivider(),
              _buildEditableField('TÉLÉPHONE', _phoneCtrl),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('PROFESSION'),
            const SizedBox(height: 16),
            _buildSettingsContainer([
              _buildDropdownField('TITRE', 'Étudiant en 5ème année'),
              _buildDivider(),
              _buildSettinsField('SPÉCIALITÉ', 'Médecine Interne'),
              _buildDivider(),
              _buildSettinsField('INSTITUTION', 'Faculté de Médecine de Paris'),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('SÉCURITÉ'),
            const SizedBox(height: 16),
            _buildSettingsContainer([
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(
                  'Changer le mot de passe',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  'Dernière modification il y a 3 mois',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
                trailing: const Icon(
                  LucideIcons.chevronRight,
                  color: Color(0xFFCBD5E1),
                  size: 20,
                ),
                onTap: () {},
              ),
              _buildDivider(),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(
                  'Double Authentification (2FA)',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  _twoFactorEnabled ? 'ACTIVÉ' : 'DÉSACTIVÉ',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color:
                        _twoFactorEnabled
                            ? const Color(0xFF00C88C)
                            : const Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                value: _twoFactorEnabled,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF00C88C),
                onChanged: (val) => setState(() => _twoFactorEnabled = val),
              ),
            ]),

            const SizedBox(height: 32),
            _buildSectionHeader('AUDIO IA'),
            const SizedBox(height: 16),
            _buildSettingsContainer([
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                title: Text(
                  'Voix gratuites (appareil)',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                subtitle: Text(
                  _useFreePatientVoices
                      ? 'ACTIVÉES — voix locales, sans quota'
                      : 'DÉSACTIVÉES — voix distante quand disponible',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color:
                        _useFreePatientVoices
                            ? const Color(0xFF00C88C)
                            : const Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                ),
                value: _useFreePatientVoices,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF00C88C),
                onChanged: (val) {
                  setState(() => _useFreePatientVoices = val);
                  final state = Provider.of<SessionState>(
                    context,
                    listen: false,
                  );
                  state.setUseFreePatientVoices(val);
                },
              ),
            ]),

            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: AppColors.primary,
              ),
              child: Text(
                'Enregistrer les modifications',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF94A3B8),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsContainer(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettinsField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const Icon(
                LucideIcons.chevronDown,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Color(0xFFF1F5F9), thickness: 1);
  }

  Widget _buildEditableField(String label, TextEditingController ctrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: ctrl,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1E293B),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
