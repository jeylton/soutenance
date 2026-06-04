import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../theme/app_theme.dart';
import '../../services/api.dart';
import 'package:provider/provider.dart';
import '../../state/session_state.dart';

class ChatMessage {
  final String text;
  final bool isDoctor;
  final DateTime time;

  ChatMessage({required this.text, required this.isDoctor, required this.time});
}

class PatientChatSheet extends StatefulWidget {
  const PatientChatSheet({super.key});

  @override
  State<PatientChatSheet> createState() => _PatientChatSheetState();
}

class _PatientChatSheetState extends State<PatientChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  static const double _elevenLabsPlaybackRate = 1.12;
  bool _isSending = false;
  int? _editingIndex;
  ChatMessage? _lastDeletedMessage;
  int? _lastDeletedIndex;

  List<ChatMessage> _messages = [];

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

    final genderExplicit = rawGender.isNotEmpty;
    String gender = genderExplicit ? _normalizeGender(rawGender) : 'male';
    String ageGroup = _ageToGroup(ageNum);

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
      if (avatar.contains('gif2') || avatar.contains('femme') || avatar.contains('female')) {
        gender = 'female';
      } else if (avatar.contains('gif1') || avatar.contains('homme') || avatar.contains('male')) {
        gender = 'male';
      }
    }

    return (gender: gender, ageGroup: ageGroup);
  }

  @override
  void initState() {
    super.initState();
    final state = Provider.of<SessionState>(context, listen: false);
    final caseData = state.caseData;
    final reason = caseData?['consultation_reason'] ?? 'Je ne me sens pas bien';

    // Charger depuis SessionState (messages partagés vocal + texte)
    final shared = state.chatMessages;
    if (shared.isEmpty) {
      // Premier message d'accueil
      final greeting = ChatMessage(
        text: 'Bonjour Docteur. $reason',
        isDoctor: false,
        time: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      _messages = [greeting];
      state.addChatMessage(text: greeting.text, isDoctor: false);
    } else {
      _messages = shared.map((m) => ChatMessage(
        text: m['text'] as String,
        isDoctor: m['isDoctor'] as bool,
        time: DateTime.tryParse(m['time'] as String? ?? '') ?? DateTime.now(),
      )).toList();
    }
    _initTts();
  }

  Future<void> _initTts() async {
    final caseData = Provider.of<SessionState>(context, listen: false).caseData;

    await _tts.setLanguage('fr-FR');
    await _tts.setVolume(1.0);

    final profile = _resolvePatientVoiceClass(caseData);
    final isFemale = profile.gender == 'female';
    final isChild = profile.ageGroup == 'child';
    final isSenior = profile.ageGroup == 'senior';

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

    // Try to pick a matching French voice for the right gender
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

    _tts.setStartHandler(() {});
    _tts.setCompletionHandler(() {});
  }

  Future<void> _speakReply(String text) async {
    String cleaned =
        text
            .replaceAll(RegExp(r'[•\t]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    if (cleaned.isEmpty) return;

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
            // Playback rate is best-effort.
          }
          await _audioPlayer.play(BytesSource(audioBytes));
          return;
        }
      } catch (_) {
        // Fallback to native TTS below when ElevenLabs is unavailable.
      }
    }

    await _tts.speak(cleaned);
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _tts.stop();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

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

    sessionState.incrementQuestionCount();

    setState(() {
      _isSending = true;
      if (_editingIndex != null &&
          _editingIndex! >= 0 &&
          _editingIndex! < _messages.length) {
        _messages[_editingIndex!] = ChatMessage(
          text: trimmed,
          isDoctor: true,
          time: DateTime.now(),
        );
        _editingIndex = null;
      } else {
        _messages.add(
          ChatMessage(text: trimmed, isDoctor: true, time: DateTime.now()),
        );
        sessionState.addChatMessage(text: trimmed, isDoctor: true);
      }
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final caseId = sessionState.caseId ?? 0;
      final sessionId = sessionState.sessionId;

      if (sessionId != null) {
        Api.saveChatMessage(sessionId, 'doctor', trimmed);
      }

      final reply = await Api.patientReply(caseId, question: trimmed);

      if (sessionId != null) {
        Api.saveChatMessage(sessionId, 'patient', reply);
      }

      if (!mounted) return;

      setState(() {
        _messages.add(
          ChatMessage(text: reply, isDoctor: false, time: DateTime.now()),
        );
        _isSending = false;
      });
      sessionState.addChatMessage(text: reply, isDoctor: false);
      _scrollToBottom();
      _speakReply(reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
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
            _buildHeader(context),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isSending) {
                    return _buildTypingIndicator();
                  }
                  final msg = _messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),

            // Input Area
            _buildInputArea(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final state = Provider.of<SessionState>(context);
    final caseData = state.caseData;
    final avatarUrl = Api.normalizeAssetUrl(
      (caseData?['avatar'] ?? '').toString(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child:
                avatarUrl.isNotEmpty
                    ? ClipOval(
                      child: Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (context, error, stackTrace) => const Icon(
                              LucideIcons.user,
                              color: AppColors.primary,
                              size: 24,
                            ),
                      ),
                    )
                    : const Icon(
                      LucideIcons.user,
                      color: AppColors.primary,
                      size: 24,
                    ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient (Simulation)',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'En ligne • IA Clinique',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Compteur de questions restantes
                Builder(builder: (_) {
                  final remaining = state.questionsRemaining;
                  final isLow = remaining <= 5;
                  final isOut = remaining == 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOut
                          ? const Color(0xFFEF4444)
                          : isLow
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isOut ? '🚫 Limite atteinte' : '💬 $remaining questions restantes',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isOut
                            ? Colors.white
                            : isLow
                                ? const Color(0xFF92400E)
                                : const Color(0xFF0369A1),
                      ),
                    ),
                  );
                }),
              ],
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
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isDoctor = msg.isDoctor;
    final messageIndex = _messages.indexOf(msg);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isDoctor ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Patient avatar (left)
          if (!isDoctor) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.user,
                color: AppColors.primary,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Bubble
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              child: Column(
                crossAxisAlignment:
                    isDoctor
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onLongPress:
                        isDoctor
                            ? () => _showMessageActions(messageIndex, msg)
                            : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDoctor ? AppColors.primary : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isDoctor ? 20 : 4),
                          bottomRight: Radius.circular(isDoctor ? 4 : 20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                isDoctor
                                    ? AppColors.primary.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Text(
                        msg.text,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color:
                              isDoctor ? Colors.white : const Color(0xFF1E293B),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.time),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Doctor avatar (right)
          if (isDoctor) ...[
            const SizedBox(width: 8),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.stethoscope,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.user,
              color: AppColors.primary,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return _AnimatedDot(delay: Duration(milliseconds: i * 200));
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Quick suggestion chips
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_editingIndex != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 8, 10, 4),
                      child: Row(
                        children: [
                          const Icon(
                            LucideIcons.pencil,
                            size: 14,
                            color: Color(0xFF0EA5E9),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Modification de votre question',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0369A1),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _editingIndex = null;
                                _controller.clear();
                              });
                            },
                            child: const Icon(
                              LucideIcons.x,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Poser une question au patient...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                    ),
                    onSubmitted: _sendMessage,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.send,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(int index, ChatMessage msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (_) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.pencil),
                    title: Text(
                      'Modifier cette question',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w700),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _editingIndex = index;
                        _controller.text = msg.text;
                      });
                      _focusNode.requestFocus();
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      LucideIcons.trash2,
                      color: Color(0xFFEF4444),
                    ),
                    title: Text(
                      'Supprimer ce message',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _deleteMessage(index);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  void _deleteMessage(int index) {
    if (index < 0 || index >= _messages.length) return;
    setState(() {
      _lastDeletedMessage = _messages[index];
      _lastDeletedIndex = index;
      _messages.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = null;
        _controller.clear();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Message supprimé'),
        action: SnackBarAction(label: 'ANNULER', onPressed: _undoDeleteMessage),
      ),
    );
  }

  void _undoDeleteMessage() {
    final deleted = _lastDeletedMessage;
    final deletedIndex = _lastDeletedIndex;
    if (deleted == null || deletedIndex == null) return;

    setState(() {
      final insertIndex = deletedIndex.clamp(0, _messages.length);
      _messages.insert(insertIndex, deleted);
      _lastDeletedMessage = null;
      _lastDeletedIndex = null;
    });
  }
}

// Animated bouncing dot for typing indicator
class _AnimatedDot extends StatefulWidget {
  final Duration delay;
  const _AnimatedDot({required this.delay});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder:
          (_, __) => Transform.translate(
            offset: Offset(0, _anim.value),
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                shape: BoxShape.circle,
              ),
            ),
          ),
    );
  }
}
