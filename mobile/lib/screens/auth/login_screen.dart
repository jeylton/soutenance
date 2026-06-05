import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';
import 'register_screen.dart';
import '../main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  bool _isLoading = false;
  bool _isSocialLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir tous les champs')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final data = await Api.login(email, password);
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
      final savedLocale = user['locale'] as String?;
      if (savedLocale == 'en' || savedLocale == 'fr') {
        sessionState.setLocale(savedLocale!);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
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

  Future<void> _socialLogin(String provider) async {
    setState(() => _isSocialLoading = true);
    try {
      final providerName = provider == 'google' ? 'Google' : 'Apple';
      String? supabaseAccessToken;
      String userEmail = '';
      String userName = '';

      if (provider == 'google') {
        // Real Google Sign-In
        final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          // User cancelled
          setState(() => _isSocialLoading = false);
          return;
        }
        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;

        if (idToken != null) {
          // Authenticate with Supabase using Google ID token
          final supabase = Supabase.instance.client;
          final response = await supabase.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: googleAuth.accessToken,
          );
          supabaseAccessToken = response.session?.accessToken;
          userEmail = response.user?.email ?? googleUser.email;
          userName =
              response.user?.userMetadata?['full_name'] as String? ??
              googleUser.displayName ??
              '';
        } else {
          // Fallback: use Google user info directly
          userEmail = googleUser.email;
          userName = googleUser.displayName ?? '';
        }
      } else if (provider == 'apple') {
        // Apple Sign-In via Supabase OAuth
        try {
          final supabase = Supabase.instance.client;
          await supabase.auth.signInWithOAuth(
            OAuthProvider.apple,
            redirectTo: 'io.supabase.dicaclinic://login-callback/',
          );
          // After OAuth redirect, get current session
          final session = supabase.auth.currentSession;
          if (session != null) {
            supabaseAccessToken = session.accessToken;
            userEmail = supabase.auth.currentUser?.email ?? '';
            userName =
                supabase.auth.currentUser?.userMetadata?['full_name']
                    as String? ??
                '';
          } else {
            setState(() => _isSocialLoading = false);
            return;
          }
        } catch (appleErr) {
          if (appleErr.toString().contains('canceled') ||
              appleErr.toString().contains('cancelled')) {
            setState(() => _isSocialLoading = false);
            return;
          }
          rethrow;
        }
      }

      if (userEmail.isEmpty) {
        throw Exception('Impossible de récupérer l\'email $providerName');
      }

      // Send to our backend with the Supabase access token
      final data = await Api.socialLogin(
        provider,
        userEmail,
        userName,
        supabaseAccessToken: supabaseAccessToken,
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['isNew'] == true
                  ? 'Compte créé avec succès via $providerName !'
                  : 'Connecté via $providerName !',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSocialLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final hPad = screenWidth < 360 ? 20.0 : screenWidth < 480 ? 28.0 : 40.0;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.5),
            radius: 1.5,
            colors: [Color(0xFFF1F7FF), AppColors.background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.iconBlueBg,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      LucideIcons.briefcase,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Dica Clinic',
                  style: GoogleFonts.outfit(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Simulation de raisonnement clinique',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 60),

                // Form
                _buildFieldLabel('EMAIL'),
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
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 32),

                _buildFieldLabel('MOT DE PASSE'),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscureText,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(
                      LucideIcons.lock,
                      size: 22,
                      color: AppColors.textPlaceholder,
                    ),
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

                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Mot de passe oublié ?',
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
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
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Se connecter'),
                              const SizedBox(width: 12),
                              const Icon(LucideIcons.arrowRight, size: 20),
                            ],
                          ),
                ),

                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pas encore de compte ? ',
                      style: GoogleFonts.outfit(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const RegisterScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Créer un compte',
                        style: GoogleFonts.outfit(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
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
                      'ENVIRONNEMENT SÉCURISÉ SSL',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPlaceholder,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
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

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 64),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 24, color: AppColors.textMain),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: AppColors.textMain,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
