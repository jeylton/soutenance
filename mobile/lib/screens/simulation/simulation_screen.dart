import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import '../../state/session_state.dart';
import 'exam_order_sheet.dart';
import 'exam_results_screen.dart';
import 'patient_chat_sheet.dart';
import 'patient_record_sheet.dart';

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  Timer? _timer;
  static const String _talkingGifAsset = 'assets/gif/patient_talking.gif';
  bool _didSpeakInitialMessage = false;

  // Speech-to-text
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _spokenText = '';
  String? _lastPatientReply;
  bool _isWaitingReply = false;
  bool _isPatientSpeaking = false;

  // Text-to-speech (patient voice)
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = Provider.of<SessionState>(context, listen: false);
      state.tickTimer();
      // Auto-conclude when exam time is up
      if (state.isExamMode && state.isTimeUp) {
        _timer?.cancel();
        _autoConcludeExam();
      }
    });
    _initSpeech();
    _initTts().then((_) => _speakInitialPatientMessage());
  }

  Future<void> _speakInitialPatientMessage() async {
    if (_didSpeakInitialMessage || !mounted) return;
    final sessionState = Provider.of<SessionState>(context, listen: false);
    final caseData = sessionState.caseData;
    final reason = (caseData?['consultation_reason'] ?? '').toString().trim();
    if (reason.isEmpty) return;

    final firstMessage = 'Bonjour Docteur. $reason';
    _didSpeakInitialMessage = true;

    final sessionId = sessionState.sessionId;
    if (sessionId != null) {
      Api.saveChatMessage(sessionId, 'patient', firstMessage);
    }

    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _speakReply(firstMessage);
  }

  Future<void> _autoConcludeExam() async {
    final state = Provider.of<SessionState>(context, listen: false);
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    try {
      await Api.concludeSession(
        sessionId,
        'Temps écoulé - non soumis',
        '',
        state.elapsedSeconds,
      );
    } catch (_) {}
    if (mounted) {
      // Force leave simulation immediately when time is up.
      Navigator.of(context).pop(true);
    }
  }

  String _normalizeGender(String raw) {
    final g = raw.toLowerCase();
    if (g.startsWith('f') || g.contains('woman') || g.contains('femme')) {
      return 'female';
    }
    return 'male';
  }

  String _ageToGroup(num? age) {
    if (age == null) return 'adult';
    if (age <= 14) return 'child';
    if (age >= 60) return 'senior';
    return 'adult';
  }

  ({String gender, String ageGroup}) _resolvePatientVoiceClass(
    Map<String, dynamic>? caseData,
  ) {
    final medical =
        caseData?['medical_history'] is Map
            ? Map<String, dynamic>.from(caseData!['medical_history'] as Map)
            : <String, dynamic>{};

    final avatar = (caseData?['avatar'] ?? '').toString().toLowerCase();
    final rawGender =
        (medical['gender'] ?? caseData?['gender'] ?? '').toString();
    final caseAge = caseData == null ? null : caseData['age'];
    final ageNum =
        medical['age'] is num
            ? medical['age'] as num
            : (caseAge is num ? caseAge : null);

    String gender = _normalizeGender(rawGender);
    String ageGroup = _ageToGroup(ageNum);

    // Strong avatar naming hints from your GIF catalog.
    if (avatar.contains('gif5') ||
        avatar.contains('enfant homme') ||
        (avatar.contains('child') && avatar.contains('male'))) {
      return (gender: 'male', ageGroup: 'child');
    }
    if (avatar.contains('gif6') ||
        avatar.contains('enfant femme') ||
        (avatar.contains('child') && avatar.contains('female'))) {
      return (gender: 'female', ageGroup: 'child');
    }
    if (avatar.contains('gif3') ||
        avatar.contains('senior homme') ||
        (avatar.contains('senior') && avatar.contains('male'))) {
      return (gender: 'male', ageGroup: 'senior');
    }
    if (avatar.contains('gif4') ||
        avatar.contains('senior femme') ||
        (avatar.contains('senior') && avatar.contains('female'))) {
      return (gender: 'female', ageGroup: 'senior');
    }
    if (avatar.contains('gif1') ||
        avatar.contains('adulte homme') ||
        (avatar.contains('adult') && avatar.contains('male'))) {
      return (gender: 'male', ageGroup: 'adult');
    }
    if (avatar.contains('gif2') ||
        avatar.contains('adulte femme') ||
        (avatar.contains('adult') && avatar.contains('female'))) {
      return (gender: 'female', ageGroup: 'adult');
    }

    if (avatar.contains('femme') || avatar.contains('female')) {
      gender = 'female';
    }
    if (avatar.contains('homme') || avatar.contains('male')) {
      gender = 'male';
    }
    if (avatar.contains('enfant') || avatar.contains('child')) {
      ageGroup = 'child';
    }
    if (avatar.contains('senior') ||
        avatar.contains('vieux') ||
        avatar.contains('old')) {
      ageGroup = 'senior';
    }

    return (gender: gender, ageGroup: ageGroup);
  }

  Future<void> _initTts() async {
    final caseData = Provider.of<SessionState>(context, listen: false).caseData;

    await _tts.setLanguage('fr-FR');
    await _tts.setVolume(1.0);

    final profile = _resolvePatientVoiceClass(caseData);
    final isFemale = profile.gender == 'female';
    final isChild = profile.ageGroup == 'child';
    final isSenior = profile.ageGroup == 'senior';

    // Device TTS tuning: free voices, adapted to avatar age + gender.
    double pitch = 1.0;
    double rate = 0.5;
    if (isChild && isFemale) {
      pitch = 1.35;
      rate = 0.58;
    } else if (isChild) {
      pitch = 1.24;
      rate = 0.56;
    } else if (isSenior && isFemale) {
      pitch = 1.0;
      rate = 0.46;
    } else if (isSenior) {
      pitch = 0.78;
      rate = 0.44;
    } else if (isFemale) {
      pitch = 1.12;
      rate = 0.52;
    } else {
      pitch = 0.92;
      rate = 0.5;
    }

    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);

    // Try to pick a matching voice on platforms that support it
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final frVoices =
            voices.where((v) {
              final locale =
                  (v['locale'] ?? v['language'] ?? '').toString().toLowerCase();
              return locale.startsWith('fr');
            }).toList();

        if (frVoices.isNotEmpty) {
          final ageHints =
              isChild
                  ? ['child', 'kid', 'young', 'jeune', 'enfant']
                  : isSenior
                  ? ['senior', 'old', 'elder', 'aged', 'vieux']
                  : ['adult'];
          final genderHints =
              isFemale
                  ? ['female', 'woman', 'femme']
                  : ['male', 'man', 'homme'];

          int scoreVoice(Map<dynamic, dynamic> v) {
            final name = (v['name'] ?? '').toString().toLowerCase();
            int score = 0;
            if (genderHints.any((h) => name.contains(h))) score += 4;
            if (ageHints.any((h) => name.contains(h))) score += 2;
            return score;
          }

          frVoices.sort((a, b) => scoreVoice(b).compareTo(scoreVoice(a)));
          final match = frVoices.first;

          await _tts.setVoice({
            'name': match['name'],
            'locale': match['locale'] ?? 'fr-FR',
          });
        }
      }
    } catch (_) {
      // Voice selection is best-effort; pitch handles the rest
    }

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isPatientSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPatientSpeaking = false);
    });
    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
    });
  }

  Future<void> _speakReply(String text) async {
    // Clean up text for speech (remove bullet points, extra whitespace)
    String cleaned =
        text
            .replaceAll(RegExp(r'[â€¢\t]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (cleaned.isNotEmpty) {
      if (mounted) setState(() => _isPatientSpeaking = true);

      final sessionState = Provider.of<SessionState>(context, listen: false);
      final caseId = sessionState.caseId;
      final useFreeVoices = sessionState.useFreePatientVoices;

      if (!useFreeVoices && caseId != null && caseId > 0) {
        try {
          final audioBytes = await Api.patientVoiceAudio(caseId, cleaned);
          if (audioBytes.isNotEmpty) {
            await _audioPlayer.stop();
            _audioPlayer.onPlayerComplete.first.then((_) {
              if (mounted) setState(() => _isPatientSpeaking = false);
            });
            await _audioPlayer.play(BytesSource(audioBytes));
            return;
          }
        } catch (_) {
          // Fallback to native TTS when ElevenLabs is unavailable.
        }
      }

      await _tts.speak(cleaned);
    }
  }

  Future<bool> _confirmQuitCase() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Quitter le cas ?',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF1E293B),
              ),
            ),
            content: Text(
              'Votre progression de session restera enregistree. Voulez-vous quitter maintenant ?',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Annuler',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Quitter',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
    );
    return ok == true;
  }

  Future<void> _handleBack() async {
    final shouldQuit = await _confirmQuitCase();
    if (shouldQuit && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_isListening) _stopListening();
          }
        },
        onError: (error) {
          debugPrint('Speech error: ${error.errorMsg}');
          if (mounted) setState(() => _isListening = false);
        },
      );
      debugPrint('Speech available: $_speechAvailable');
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech init failed: $e');
      _speechAvailable = false;
    }
  }

  void _startListening() async {
    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reconnaissance vocale non disponible. Utilisez le chat texte.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _isListening = true;
      _spokenText = '';
      _lastPatientReply = null;
    });
    await _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() => _spokenText = result.recognizedWords);
        }
      },
      localeId: 'fr_FR',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  void _stopListening() async {
    await _speech.stop();
    if (!mounted) return;
    setState(() => _isListening = false);
    if (_spokenText.trim().isNotEmpty) {
      _sendVoiceMessage(_spokenText.trim());
    }
  }

  Future<void> _sendVoiceMessage(String text) async {
    setState(() => _isWaitingReply = true);
    try {
      final sessionState = Provider.of<SessionState>(context, listen: false);
      final caseId = sessionState.caseId;
      final sessionId = sessionState.sessionId;
      if (sessionId != null) {
        Api.saveChatMessage(sessionId, 'doctor', text);
      }
      final reply = await Api.patientReply(caseId ?? 0, question: text);
      if (sessionId != null) {
        Api.saveChatMessage(sessionId, 'patient', reply);
      }
      if (mounted) {
        setState(() {
          _lastPatientReply = reply;
          _isWaitingReply = false;
        });
        // Patient speaks the reply aloud
        _speakReply(reply);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWaitingReply = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _tts.stop();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Background - Semi-blurred medical room feel
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE2F1F8),
                    Color(0xFFB3E5FC),
                    Color(0xFFE1F5FE),
                  ],
                ),
              ),
            ),

            // Subtle room furniture hints using containers (Abstract)
            Positioned(
              left: -100,
              bottom: 150,
              child: Opacity(
                opacity: 0.3,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.5),
                        blurRadius: 100,
                        spreadRadius: 50,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned.fill(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header (taille fixe)
                    Align(
                      alignment: Alignment.topCenter,
                      child: _buildHeader(context),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),

                    // Zone centrale - scrollable pour éviter overflow
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight:
                                MediaQuery.of(context).size.height * 0.55,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Patient area
                              _buildPatientArea()
                                  .animate()
                                  .fadeIn(duration: 800.ms, delay: 200.ms)
                                  .scale(begin: const Offset(0.9, 0.9)),

                              const SizedBox(height: 8),

                              // Interaction controls
                              _buildInteractionControls().animate().fadeIn(
                                duration: 800.ms,
                                delay: 400.ms,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Boutons bas (taille fixe)
                    Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                          child: _buildBottomActions(),
                        )
                        .animate()
                        .fadeIn(duration: 800.ms, delay: 600.ms)
                        .slideY(begin: 0.2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLoadingHint = false;

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _handleBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Timer
              Consumer<SessionState>(
                builder: (context, state, _) {
                  final isExam =
                      state.isExamMode && state.examTimeLimitMinutes != null;
                  final remaining = state.remainingSeconds;
                  final isLow = isExam && remaining < 120; // < 2 min
                  final displayTime =
                      isExam
                          ? _formatTime(remaining.clamp(0, 99999))
                          : _formatTime(state.elapsedSeconds);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isLow
                              ? Colors.red.withValues(alpha: 0.7)
                              : Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isExam ? LucideIcons.timerOff : LucideIcons.clock,
                          color: isLow ? Colors.white : Colors.blueAccent,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          displayTime,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Hint button
              Consumer<SessionState>(
                builder: (context, state, _) {
                  final hints = state.hintBalance;
                  return GestureDetector(
                    onTap: hints > 0 ? _useHint : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color:
                            hints > 0
                                ? const Color(0xFFFEF3C7)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _isLoadingHint
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : Icon(
                                LucideIcons.lightbulb,
                                color:
                                    hints > 0
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFCBD5E1),
                                size: 18,
                              ),
                          const SizedBox(width: 4),
                          Text(
                            '$hints',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color:
                                  hints > 0
                                      ? const Color(0xFF92400E)
                                      : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              // Clinical File Button
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const PatientRecordSheet(),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.fileText,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Dossier',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _useHint() async {
    final state = Provider.of<SessionState>(context, listen: false);
    final caseId = state.caseId;
    if (caseId == null) return;

    final hintType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choisir le type d\'indice',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 14),
                _buildHintTypeOption(
                  label: 'Indice examen utile',
                  subtitle: 'Oriente vers un examen a demander',
                  onTap: () => Navigator.pop(sheetContext, 'exam'),
                ),
                _buildHintTypeOption(
                  label: 'Indice symptome cle',
                  subtitle: 'Souligne un signe clinique important',
                  onTap: () => Navigator.pop(sheetContext, 'symptom'),
                ),
                _buildHintTypeOption(
                  label: 'Indice raisonnement',
                  subtitle: 'Donne une piste de reflexion globale',
                  onTap: () => Navigator.pop(sheetContext, 'general'),
                ),
              ],
            ),
          ),
    );
    if (hintType == null) return;

    setState(() => _isLoadingHint = true);
    try {
      // Consume one hint
      final result = await Api.useHint();
      if (result['success'] == true) {
        final newBalance = (result['hintBalance'] ?? 0) as int;
        state.updateProfile(hintBalance: newBalance);

        // Get AI hint
        final hint = await Api.getCaseHint(caseId, type: hintType);

        if (!mounted) return;
        {
          showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  title: Row(
                    children: [
                      const Text('ðŸ’¡', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Text(
                        'Indice',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  content: Text(
                    hint,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      height: 1.5,
                      color: const Color(0xFF475569),
                    ),
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        'OK',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Erreur'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingHint = false);
    }
  }

  Widget _buildHintTypeOption({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.lightbulb, color: Color(0xFFF59E0B)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(String url, double size) {
    final isSvg = url.contains('/svg') || url.endsWith('.svg');
    if (isSvg) {
      return SvgPicture.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholderBuilder:
            (_) => const Center(child: CircularProgressIndicator()),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder:
          (context, error, stackTrace) => Container(
            color: AppColors.iconBlueBg,
            child: Icon(
              LucideIcons.user,
              color: AppColors.primary,
              size: size * 0.4,
            ),
          ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildPatientVisual(String avatarUrl, double size) {
    final isPatientTurn = _isWaitingReply || _isPatientSpeaking;
    final isGifAvatar = avatarUrl.toLowerCase().endsWith('.gif');

    if (isGifAvatar) {
      return _buildAvatarWidget(avatarUrl, size);
    }

    if (!isPatientTurn) {
      return _buildAvatarWidget(avatarUrl, size);
    }

    return Image.asset(
      _talkingGifAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildAvatarWidget(avatarUrl, size);
      },
    );
  }

  Widget _buildPatientArea() {
    final caseData = Provider.of<SessionState>(context, listen: false).caseData;
    final patientName = caseData?['patient_name'] ?? 'Patient';
    final consultationReason =
        caseData?['consultation_reason'] ?? 'Consultation';
    final avatarUrl = Api.normalizeAssetUrl(caseData?['avatar'] as String?);
    final effectiveAvatar =
        avatarUrl.isNotEmpty
            ? avatarUrl
            : 'https://api.dicebear.com/7.x/avataaars/svg?seed=${Uri.encodeComponent(patientName)}&backgroundColor=b6e3f4';
    final isPatientTurn = _isWaitingReply || _isPatientSpeaking;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapt sizes based on available width (proxy for screen size)
        final screenH = MediaQuery.of(context).size.height;
        final avatarSize = screenH < 700 ? 130.0 : 160.0;
        final bubblePadding = screenH < 700 ? 14.0 : 20.0;
        final gap = screenH < 700 ? 14.0 : 20.0;
        final avatarCard = Container(
          width: avatarSize,
          height: avatarSize,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildPatientVisual(effectiveAvatar, avatarSize),
          ),
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Patient Avatar (animated breathing effect)
              if (isPatientTurn)
                avatarCard
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scaleXY(
                      begin: 1.0,
                      end: _isPatientSpeaking ? 1.06 : 1.03,
                      duration: _isPatientSpeaking ? 600.ms : 1200.ms,
                      curve: Curves.easeInOut,
                    )
                    .shimmer(
                      duration: 2200.ms,
                      color: Colors.white.withValues(alpha: 0.1),
                    )
              else
                avatarCard,
              SizedBox(height: gap),

              // Dialogue Bubble
              Container(
                padding: EdgeInsets.all(bubblePadding),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PATIENT (AI)',
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '"Bonjour Docteur. $consultationReason"',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF1E293B),
                        fontWeight: FontWeight.w700,
                        fontSize: screenH < 700 ? 14 : 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInteractionControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Show spoken text or patient reply
        if (_spokenText.isNotEmpty ||
            _lastPatientReply != null ||
            _isWaitingReply)
          Container(
            margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.25,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_spokenText.isNotEmpty) ...[
                    Text(
                      'VOUS',
                      style: GoogleFonts.outfit(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _spokenText,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                  if (_isWaitingReply)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Le patient réfléchit...',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

        // Patient reply in separate constrained container
        if (_lastPatientReply != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.2,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    'PATIENT',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastPatientReply!,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Mic (Hold to Speak) - real voice input
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              onTap: () {
                if (!_speechAvailable) {
                  // Fallback: open chat if speech unavailable
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const PatientChatSheet(),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Maintenez le bouton enfonce pour parler'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isListening ? 90 : 80,
                height: _isListening ? 90 : 80,
                decoration: BoxDecoration(
                  color:
                      _isListening
                          ? const Color(0xFFEF4444)
                          : AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening
                              ? const Color(0xFFEF4444)
                              : AppColors.primary)
                          .withValues(alpha: 0.4),
                      blurRadius: _isListening ? 30 : 20,
                      spreadRadius: _isListening ? 8 : 4,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? LucideIcons.micOff : LucideIcons.mic,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(width: 28),

            // Keyboard button â†’ opens chat (alternative)
            GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const PatientChatSheet(),
                );
              },
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.keyboard,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Visualizer bar (animated when listening)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            8,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 4,
              height:
                  _isListening ? (index % 3 + 2) * 6.0 : (index % 3 + 1) * 4.0,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color:
                    _isListening
                        ? const Color(0xFFEF4444).withValues(alpha: 0.7)
                        : AppColors.primary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isListening ? 'ECOUTE EN COURS...' : 'MAINTENIR POUR PARLER',
          style: GoogleFonts.outfit(
            color:
                _isListening
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF64748B),
            fontWeight: FontWeight.w900,
            fontSize: 11,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Examens button
          Expanded(
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ExamOrderSheet(),
                );
              },
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.microscope,
                      size: 20,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Examens',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Diagnostic button
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExamResultsScreen()),
                );
              },
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.checkSquare,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Diagnostic',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
