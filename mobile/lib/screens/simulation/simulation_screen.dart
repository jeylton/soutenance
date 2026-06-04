import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
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

  // Bloc-notes de l'étudiant (persiste pendant la simulation)
  final TextEditingController _notesController = TextEditingController();
  bool _hasNotes = false;

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

  static const double _elevenLabsPlaybackRate = 1.12;

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

    final name = (caseData?['patient_name'] ?? '').toString().trim();
    final medical = caseData?['medical_history'] is Map
        ? Map<String, dynamic>.from(caseData!['medical_history'] as Map)
        : <String, dynamic>{};
    final age = medical['age']?.toString().trim() ?? '';

    // Message d'introduction naturel avec identité du patient
    final buf = StringBuffer('Bonjour Docteur.');
    if (name.isNotEmpty) buf.write(' Je m\'appelle $name.');
    if (age.isNotEmpty) buf.write(' J\'ai $age ans.');
    buf.write(' $reason');

    final firstMessage = buf.toString();
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

    // medical_history.gender est la source de vérité — priorité absolue
    final genderExplicit = rawGender.isNotEmpty;
    String gender = genderExplicit ? _normalizeGender(rawGender) : 'male';
    String ageGroup = _ageToGroup(ageNum);

    // GIF hints → utilisés uniquement pour l'ageGroup, pas pour écraser le gender explicite
    if (avatar.contains('gif5') || avatar.contains('gif6') ||
        avatar.contains('enfant') || avatar.contains('child')) {
      ageGroup = 'child';
      if (!genderExplicit) {
        gender = avatar.contains('gif6') || avatar.contains('enfant femme') ? 'female' : 'male';
      }
    } else if (avatar.contains('gif3') || avatar.contains('gif4') ||
        avatar.contains('senior') || avatar.contains('vieux') || avatar.contains('old')) {
      ageGroup = 'senior';
      if (!genderExplicit) {
        gender = avatar.contains('gif4') || avatar.contains('senior femme') ? 'female' : 'male';
      }
    } else if (!genderExplicit) {
      // Fallback avatar hints pour le gender seulement si non renseigné
      if (avatar.contains('gif2') || avatar.contains('femme') || avatar.contains('female')) {
        gender = 'female';
      } else if (avatar.contains('gif1') || avatar.contains('homme') || avatar.contains('male')) {
        gender = 'male';
      }
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
    double rate = 0.56;
    if (isChild && isFemale) {
      pitch = 1.35;
      rate = 0.64;
    } else if (isChild) {
      pitch = 1.24;
      rate = 0.62;
    } else if (isSenior && isFemale) {
      pitch = 1.0;
      rate = 0.5;
    } else if (isSenior) {
      pitch = 0.78;
      rate = 0.48;
    } else if (isFemale) {
      pitch = 1.12;
      rate = 0.58;
    } else {
      pitch = 0.92;
      rate = 0.56;
    }

    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);

    // Sélection de voix native selon le profil du patient
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        // Garder uniquement les voix françaises
        final frVoices = voices.where((v) {
          final locale = (v['locale'] ?? v['language'] ?? '').toString().toLowerCase();
          return locale.startsWith('fr');
        }).toList();

        if (frVoices.isNotEmpty) {
          // Patterns de genre — couvre Android (fr-fr-x-fra#female_1) et iOS (Amelie, Thomas)
          final femalePatterns = ['female', 'woman', 'femme', 'féminin', '#female', 'amélie', 'amelie', 'audrey', 'marie', 'julie'];
          final malePatterns   = ['male', 'man', 'homme', 'masculin', '#male', 'thomas', 'pierre', 'nicolas', 'julien'];
          final childPatterns  = ['child', 'kid', 'young', 'enfant', 'jeune', 'junior'];
          final seniorPatterns = ['senior', 'old', 'elder', 'aged', 'vieux', 'mature'];

          int scoreVoice(Map<dynamic, dynamic> v) {
            final name   = (v['name']   ?? '').toString().toLowerCase();
            final locale = (v['locale'] ?? '').toString().toLowerCase();
            final combined = '$name $locale';
            int score = 0;

            // Genre (priorité haute)
            final wantedGender = isFemale ? femalePatterns : malePatterns;
            if (wantedGender.any((p) => combined.contains(p))) score += 8;

            // Âge (bonus secondaire)
            if (isChild  && childPatterns.any((p)  => combined.contains(p))) score += 4;
            if (isSenior && seniorPatterns.any((p) => combined.contains(p))) score += 4;

            // Malus si genre opposé détecté clairement
            final oppositeGender = isFemale ? malePatterns : femalePatterns;
            if (oppositeGender.any((p) => combined.contains(p))) score -= 6;

            return score;
          }

          frVoices.sort((a, b) => scoreVoice(b).compareTo(scoreVoice(a)));

          // Si aucune voix ne discrimine le genre (score = 0), prendre une voix par index
          // pour que les profils différents aient au moins des voix différentes
          final best = frVoices.first;
          final bestScore = scoreVoice(best as Map<dynamic, dynamic>);

          Map<dynamic, dynamic> chosen;
          if (bestScore <= 0 && frVoices.length > 1) {
            // Répartir par profil: femme→index 1, homme→index 0, enfant→dernier disponible
            final idx = isChild
                ? frVoices.length - 1
                : isFemale
                ? (frVoices.length > 1 ? 1 : 0)
                : 0;
            chosen = frVoices[idx] as Map<dynamic, dynamic>;
          } else {
            chosen = best;
          }

          await _tts.setVoice({
            'name':   (chosen['name']   ?? '').toString(),
            'locale': (chosen['locale'] ?? 'fr-FR').toString(),
          });
        }
      }
    } catch (_) {
      // Voice selection is best-effort; pitch/rate différencient les profils
    }

    _tts.setStartHandler(() {
      if (mounted) setState(() => _isPatientSpeaking = true);
    });
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isPatientSpeaking = false);
    });
    _tts.setErrorHandler((msg) {
      debugPrint('TTS error: $msg');
      if (mounted) setState(() => _isPatientSpeaking = false);
    });
  }

  Future<void> _stopPatientSpeech() async {
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    if (mounted) setState(() => _isPatientSpeaking = false);
  }

  Future<void> _speakReply(String text) async {
    // Clean up text for speech (remove bullet points, extra whitespace)
    String cleaned =
        text
            .replaceAll(RegExp(r'[â€¢\t]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (cleaned.isNotEmpty) {
      if (_isListening) return;
      if (mounted) setState(() => _isPatientSpeaking = true);

      final sessionState = Provider.of<SessionState>(context, listen: false);
      final caseId = sessionState.caseId;
      final useFreeVoices = sessionState.useFreePatientVoices;

      if (!useFreeVoices && caseId != null && caseId > 0) {
        try {
          final audioBytes = await Api.patientVoiceAudio(caseId, cleaned);
          if (audioBytes.isNotEmpty) {
            await _audioPlayer.stop();
            try {
              await _audioPlayer.setPlaybackRate(_elevenLabsPlaybackRate);
            } catch (_) {
              // Playback rate is best-effort (platform support may vary).
            }
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

    // Ensure the patient is not speaking while the user is answering.
    await _stopPatientSpeech();
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
    final sessionState = Provider.of<SessionState>(context, listen: false);

    // Vérifier la limite de questions
    if (sessionState.isQuestionLimitReached) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Limite de questions atteinte. Passez aux examens ou à la conclusion.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isWaitingReply = true);
    sessionState.incrementQuestionCount();
    sessionState.addChatMessage(text: text, isDoctor: true);

    try {
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
        sessionState.addChatMessage(text: reply, isDoctor: false);
        setState(() {
          _lastPatientReply = reply;
          _isWaitingReply = false;
        });
        _speakReply(reply);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isWaitingReply = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
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
    _notesController.dispose();
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

                    // Barre patient fixe (nom, âge, motif — toujours visible)
                    _buildPatientInfoBar()
                        .animate()
                        .fadeIn(duration: 500.ms, delay: 150.ms)
                        .slideY(begin: -0.3),

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
              // Compteur de questions
              Consumer<SessionState>(
                builder: (context, state, _) {
                  final remaining = state.questionsRemaining;
                  final isLow = remaining <= 5;
                  final isOut = remaining == 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOut
                          ? Colors.red.withValues(alpha: 0.85)
                          : isLow
                              ? const Color(0xFFFFF3CD)
                              : Colors.black.withValues(alpha: 0.5),
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
                        Icon(
                          LucideIcons.messageCircle,
                          size: 15,
                          color: isOut ? Colors.white : isLow ? const Color(0xFF92400E) : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$remaining',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isOut ? Colors.white : isLow ? const Color(0xFF92400E) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
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
              // Bouton achat d'indices
              GestureDetector(
                onTap: _showHintPurchase,
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
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

  Future<void> _showHintPurchase() async {
    final state = Provider.of<SessionState>(context, listen: false);
    final isFr = state.isFrench;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Text(
              isFr ? 'Acheter des indices' : 'Buy Hints',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              isFr ? 'Utilisez vos XP pour obtenir des indices' : 'Use your XP to get hints',
              style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 20),
            _buildHintPackOption(sheetCtx, 'hint_pack_3', '💡', isFr ? '3 Indices' : '3 Hints', '150 XP', state),
            const SizedBox(height: 10),
            _buildHintPackOption(sheetCtx, 'hint_pack_10', '🔦', isFr ? '10 Indices' : '10 Hints', '400 XP', state),
          ],
        ),
      ),
    );
  }

  Widget _buildHintPackOption(
    BuildContext sheetCtx,
    String itemId,
    String icon,
    String label,
    String price,
    SessionState state,
  ) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(sheetCtx);
        try {
          final result = await Api.buyShopItem(itemId);
          if (!mounted) return;
          if (result['error'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['error'].toString()), backgroundColor: Colors.red),
            );
          } else {
            final newBalance = (result['hintBalance'] ?? state.hintBalance) as int;
            state.updateProfile(hintBalance: newBalance);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.isFrench ? '$label achetés !' : '$label purchased!'),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          }
        } catch (_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.isFrench ? 'Erreur d\'achat' : 'Purchase error'), backgroundColor: Colors.red),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                  Text(price, style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
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
      gaplessPlayback: true,
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
    final avatar = _buildAvatarWidget(avatarUrl, size);

    // When speaking: try the talking GIF, fall back to avatar on error.
    // Each rebuild gets a fresh attempt — no permanent disabled state.
    final speakingWidget = Image.asset(
      _talkingGifAsset,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => avatar,
    );

    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 150),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _isPatientSpeaking
            ? KeyedSubtree(key: const ValueKey('speaking'), child: speakingWidget)
            : KeyedSubtree(key: const ValueKey('idle'), child: avatar),
      ),
    );
  }

  Widget _buildPatientInfoBar() {
    final caseData = Provider.of<SessionState>(context, listen: false).caseData;
    final name = (caseData?['patient_name'] ?? '').toString().trim();
    final medical = caseData?['medical_history'] is Map
        ? Map<String, dynamic>.from(caseData!['medical_history'] as Map)
        : <String, dynamic>{};
    final age = medical['age']?.toString().trim() ?? '';
    final gender = (medical['gender'] ?? '').toString().trim();
    final reason = (caseData?['consultation_reason'] ?? '').toString().trim();

    if (name.isEmpty && reason.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icône patient
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nom + âge + genre
                Text(
                  [
                    if (name.isNotEmpty) name,
                    if (age.isNotEmpty) '$age ans',
                    if (gender.isNotEmpty) gender,
                  ].join(' • '),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Motif de consultation
                Text(
                  reason.isNotEmpty ? reason : 'Consultation',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Badge "Patient"
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Patient',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
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

  void _openNotesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Color(0xFFFFFBEB),
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
                    Icon(LucideIcons.pencil, color: const Color(0xFFD97706), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Mes notes',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.x, size: 16, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              // Zone de texte
              Expanded(
                child: TextField(
                  controller: _notesController,
                  maxLines: null,
                  expands: true,
                  autofocus: true,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: const Color(0xFF1E293B),
                    height: 1.7,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Hypothèses diagnostiques, examens à demander, signes importants...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: const Color(0xFFCBD5E1),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  ),
                  onChanged: (v) {
                    final hasContent = v.trim().isNotEmpty;
                    if (hasContent != _hasNotes) {
                      setState(() => _hasNotes = hasContent);
                    }
                  },
                ),
              ),
              // Pied de page
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Text(
                  'Ces notes sont privées et ne seront pas soumises avec votre diagnostic.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Bouton Notes (petit, au-dessus des boutons principaux)
          GestureDetector(
            onTap: _openNotesSheet,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _hasNotes
                    ? const Color(0xFFFEF3C7)
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _hasNotes
                      ? const Color(0xFFFBBF24)
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.pencil,
                    size: 14,
                    color: _hasNotes
                        ? const Color(0xFFD97706)
                        : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _hasNotes ? 'Notes (en cours)' : 'Ouvrir le bloc-notes',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _hasNotes
                          ? const Color(0xFFD97706)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  if (_hasNotes) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Row(
            children: [
          // Examens button
          Expanded(
            child: GestureDetector(
              onTap: () async {
                final ordered = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const ExamOrderSheet(),
                );

                if (!mounted) return;
                if (ordered == true) {
                  await _openExamResults();
                }
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
              onTap: _openExamResults,
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
      ],
    ),
  );
  }

  Future<void> _openExamResults() async {
    final completed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const ExamResultsScreen()));
    if (!mounted) return;

    if (completed == true) {
      await _showEpisodeCompletedCelebration();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _showEpisodeCompletedCelebration() async {
    try {
      SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.25),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 850), () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).pop();
            }
          });
        });

        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
                  width: 280,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 22,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF7FF),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.star,
                          color: Color(0xFFF2B503),
                          size: 34,
                        ),
                      ).animate().scale(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutBack,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Épisode terminé',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Retour au parcours…',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: const Duration(milliseconds: 160))
                .scale(
                  begin: const Offset(0.98, 0.98),
                  end: const Offset(1, 1),
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                ),
          ),
        );
      },
    );
  }
}
