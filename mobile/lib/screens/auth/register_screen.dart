import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';
import '../main_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _obscureText = true;
  bool _isLoading = false;
  String _selectedProfile = 'Sélectionnez votre statut';
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        _selectedProfile == 'Sélectionnez votre statut') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }
    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le mot de passe doit contenir au moins 8 caractères'),
        ),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await Api.register(email, password, name, _selectedProfile);
      final user = data['user'] as Map<String, dynamic>? ?? {};
      final token = data['token'] as String? ?? '';
      final sessionState = Provider.of<SessionState>(context, listen: false);
      sessionState.setUser(
        user['id']?.toString() ?? '',
        token,
        name: user['full_name'] as String?,
        email: user['email'] as String?,
        profileType: user['profile_type'] as String?,
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.iconBlueBg,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: Icon(
                    LucideIcons.plusSquare,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Création de Compte',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Text(
                  'Rejoignez Dica Clinic pour perfectionner votre raisonnement clinique.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 50),

              // Fields
              _buildFieldLabel('NOM COMPLET'),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Jean Dupont',
                  prefixIcon: const Icon(
                    LucideIcons.user,
                    size: 22,
                    color: AppColors.textPlaceholder,
                  ),
                  fillColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(height: 24),

              _buildFieldLabel('ADRESSE EMAIL'),
              const SizedBox(height: 12),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'nom@exemple.com',
                  prefixIcon: const Icon(
                    LucideIcons.atSign,
                    size: 22,
                    color: AppColors.textPlaceholder,
                  ),
                  fillColor: const Color(0xFFF8FAFC),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 24),

              _buildFieldLabel('TYPE DE PROFIL'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        _selectedProfile == 'Sélectionnez votre statut'
                            ? null
                            : _selectedProfile,
                    hint: Row(
                      children: [
                        const Icon(
                          LucideIcons.graduationCap,
                          size: 22,
                          color: AppColors.textPlaceholder,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sélectionnez votre statut',
                          style: GoogleFonts.outfit(
                            color: AppColors.textPlaceholder,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    isExpanded: true,
                    icon: const Icon(
                      LucideIcons.chevronDown,
                      size: 20,
                      color: AppColors.textPlaceholder,
                    ),
                    items:
                        ['Étudiant', 'Médecin', 'Interne', 'Autre'].map((
                          String value,
                        ) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                    onChanged: (val) => setState(() => _selectedProfile = val!),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _buildFieldLabel('MOT DE PASSE'),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: '••••••••••••',
                  prefixIcon: const Icon(
                    LucideIcons.lock,
                    size: 22,
                    color: AppColors.textPlaceholder,
                  ),
                  fillColor: const Color(0xFFF8FAFC),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? LucideIcons.eyeOff : LucideIcons.eye,
                      size: 22,
                      color: AppColors.textPlaceholder,
                    ),
                    onPressed:
                        () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '  Minimum 8 caractères, incluant des chiffres et des symboles.',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPlaceholder,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

              const SizedBox(height: 60),
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                        : const Text('S\'inscrire'),
              ),

              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Déjà un compte ? ',
                    style: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'Se connecter',
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.shieldCheck,
                    size: 16,
                    color: AppColors.textPlaceholder,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'DONNÉES SÉCURISÉES & CERTIFIÉES',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPlaceholder,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: AppColors.textPlaceholder,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                    children: [
                      const TextSpan(text: 'En continuant, vous acceptez nos '),
                      TextSpan(
                        text: 'Conditions d\'Utilisation',
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: ' et notre '),
                      TextSpan(
                        text: 'Politique de Confidentialité',
                        style: TextStyle(
                          color: AppColors.primary.withOpacity(0.7),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
