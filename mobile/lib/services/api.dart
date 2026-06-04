import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

class Api {
  // URL du backend en production (Render)
  static const _prodUrl = 'https://soutenance-8f7j.onrender.com';

  static String get baseUrl {
    const configured = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (configured.trim().isNotEmpty) return configured.trim();

    // En production ou sur vrai appareil → backend Render
    if (kIsWeb) return _prodUrl;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _prodUrl;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _prodUrl;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return 'http://localhost:5000';
    }
  }

  static String normalizeAssetUrl(String? rawUrl) {
    final url = (rawUrl ?? '').trim();
    if (url.isEmpty) return '';
    if (url.startsWith('/')) return '$baseUrl$url';
    if (!url.startsWith('http://') && !url.startsWith('https://')) return url;

    final baseHost = Uri.tryParse(baseUrl)?.host;
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty || baseHost == null) return url;

    if (parsed.host == 'localhost' || parsed.host == '127.0.0.1') {
      return parsed.replace(host: baseHost).toString();
    }
    return url;
  }

  static String? _token;

  static void setToken(String? token) => _token = token;

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ─── Auth ───
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'email': email, 'password': password}),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _token = data['token'] as String?;
      return data;
    }
    throw Exception(data['error'] ?? 'Erreur de connexion');
  }

  static Future<Map<String, dynamic>> socialLogin(
    String provider,
    String email,
    String fullName, {
    String? supabaseAccessToken,
  }) async {
    final body = {'provider': provider, 'email': email, 'full_name': fullName};
    if (supabaseAccessToken != null) {
      body['supabase_access_token'] = supabaseAccessToken;
    }
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/social'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _token = data['token'] as String?;
      return data;
    }
    throw Exception(data['error'] ?? 'Erreur d\'authentification sociale');
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String fullName,
    String profileType,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'email': email,
        'password': password,
        'full_name': fullName,
        'profile_type': profileType,
      }),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _token = data['token'] as String?;
      return data;
    }
    throw Exception(data['error'] ?? 'Erreur d\'inscription');
  }

  static Future<Map<String, dynamic>> getMe() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['user'] ?? {}) as Map<String, dynamic>;
    }
    throw Exception('Erreur chargement profil');
  }

  static Future<void> updateProfile(Map<String, dynamic> updates) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/api/auth/me'),
      headers: _headers,
      body: json.encode(updates),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Erreur mise à jour profil');
    }
  }

  // ─── Cases ───
  static Future<List<dynamic>> getCases() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/cases'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['cases'] ?? []) as List<dynamic>;
    }
    throw Exception('Erreur chargement des cas');
  }

  static Future<Map<String, dynamic>> getCase(int caseId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/cases/$caseId'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['case'] ?? {}) as Map<String, dynamic>;
    }
    throw Exception('Erreur chargement du cas');
  }

  static Future<List<dynamic>> getCaseExams(int caseId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/cases/$caseId/exams'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['exams'] ?? []) as List<dynamic>;
    }
    throw Exception('Erreur chargement des examens');
  }

  // ─── Courses ───
  static Future<List<dynamic>> getCourses() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/courses'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['courses'] ?? []) as List<dynamic>;
    }
    throw Exception('Erreur chargement des cours');
  }

  // ─── Quiz ───
  static Future<Map<String, dynamic>> generateQuiz({
    required int specialtyId,
    int questionCount = 30,
    String? disease,
    int? caseId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/llm/generate-quiz'),
      headers: _headers,
      body: json.encode({
        'specialty_id': specialtyId,
        'question_count': questionCount,
        if (caseId != null) 'case_id': caseId,
        if (disease != null && disease.trim().isNotEmpty)
          'disease': disease.trim(),
      }),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['quiz'] ?? {}) as Map<String, dynamic>;
    }
    throw Exception(data['error'] ?? 'Erreur génération quiz');
  }

  static Future<List<dynamic>> getQuizDiseasesBySpecialty(
    int specialtyId,
  ) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/llm/quiz-diseases/$specialtyId'),
      headers: _headers,
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['diseases'] ?? []) as List<dynamic>;
    }
    throw Exception(data['error'] ?? 'Erreur chargement maladies quiz');
  }

  static Future<List<dynamic>> getQuizCasesBySpecialty(int specialtyId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/llm/quiz-cases/$specialtyId'),
      headers: _headers,
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['cases'] ?? []) as List<dynamic>;
    }
    throw Exception(data['error'] ?? 'Erreur chargement cas quiz');
  }

  static Future<List<dynamic>> getPublishedQuizzes({int? specialtyId}) async {
    final uri = Uri.parse('$baseUrl/api/llm/published-quizzes').replace(
      queryParameters:
          specialtyId != null ? {'specialty_id': specialtyId.toString()} : null,
    );
    final res = await http.get(uri, headers: _headers);
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['quizzes'] ?? []) as List<dynamic>;
    }
    throw Exception(data['error'] ?? 'Erreur chargement quiz publiés');
  }

  static Future<Map<String, dynamic>> submitQuizReward({
    required String quizKey,
    required int score,
    required int total,
    required int timeSpentSeconds,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/gamification/quiz-reward'),
      headers: _headers,
      body: json.encode({
        'quiz_key': quizKey,
        'score': score,
        'total': total,
        'time_spent_seconds': timeSpentSeconds,
      }),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }
    throw Exception(data['error'] ?? 'Erreur récompense quiz');
  }

  static Future<Map<String, int>> getQuizAttemptsSummary() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/gamification/quiz-attempts'),
      headers: _headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return {};
    }

    final data = json.decode(res.body) as Map<String, dynamic>;
    final summaryRaw = data['summary'];
    if (summaryRaw is! Map) return {};

    final summary = <String, int>{};
    summaryRaw.forEach((key, value) {
      final quizKey = key.toString().trim();
      if (quizKey.isEmpty) return;
      final count =
          value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
      if (count > 0) {
        summary[quizKey] = count;
      }
    });
    return summary;
  }

  static Future<List<dynamic>> getQuizAttempts() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/gamification/quiz-attempts'),
      headers: _headers,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return [];
    }
    final data = json.decode(res.body) as Map<String, dynamic>;
    return (data['attempts'] ?? []) as List<dynamic>;
  }

  // ─── Specialties ───
  static Future<List<dynamic>> getSpecialties() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/specialties'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['specialties'] ?? []) as List<dynamic>;
    }
    throw Exception('Erreur chargement des spécialités');
  }

  // ─── Sessions ───
  static Future<int> createSession(String userId, int caseId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions'),
      headers: _headers,
      body: json.encode({'user_id': userId, 'case_id': caseId}),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['id'] as int);
    }
    throw Exception(data['error'] ?? 'Erreur création session');
  }

  static Future<Map<String, dynamic>> addExam(
    int sessionId,
    String examName,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/exams'),
      headers: _headers,
      body: json.encode({'exam_name': examName}),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['exam'] ?? {}) as Map<String, dynamic>;
    }
    throw Exception(data['error'] ?? 'Erreur demande examen');
  }

  static Future<List<dynamic>> getSessionExams(int sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/sessions/$sessionId/exams'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['exams'] ?? []) as List<dynamic>;
    }
    throw Exception('Erreur chargement examens session');
  }

  static Future<Map<String, dynamic>> concludeSession(
    int sessionId,
    String diagnosis,
    String plan,
    int timeSpent, {
    Map<String, String>? treatment,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions/$sessionId/conclude'),
      headers: _headers,
      body: json.encode({
        'diagnosis': diagnosis,
        'plan': plan,
        'time_spent': timeSpent,
        if (treatment != null) 'treatment': treatment,
      }),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return data;
    }
    throw Exception(data['error'] ?? 'Erreur conclusion session');
  }

  static Future<String> patientReply(int caseId, {String? question}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/llm/patient'),
      headers: _headers,
      body: json.encode({'case_id': caseId, 'question': question}),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['reply'] ?? '') as String;
    }
    throw Exception(data['error'] ?? 'Erreur IA patient');
  }

  static Future<Uint8List> patientVoiceAudio(
    int caseId,
    String text, {
    String? voiceId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/llm/patient-voice'),
      headers: _headers,
      body: json.encode({
        'case_id': caseId,
        'text': text,
        if (voiceId != null && voiceId.trim().isNotEmpty) 'voice_id': voiceId,
      }),
    );

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }

    try {
      final data = json.decode(res.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Erreur audio ElevenLabs');
    } catch (_) {
      throw Exception('Erreur audio ElevenLabs (${res.statusCode})');
    }
  }

  static Future<String> tutorFeedback(int sessionId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/llm/tutor'),
      headers: _headers,
      body: json.encode({'session_id': sessionId}),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['feedback'] ?? '') as String;
    }
    throw Exception(data['error'] ?? 'Erreur IA tuteur');
  }

  // ─── All sessions (for stats) ───
  static Future<List<dynamic>> getSessions({String? userId}) async {
    String url = '$baseUrl/api/sessions';
    if (userId != null) url += '?user_id=$userId';
    final res = await http.get(Uri.parse(url), headers: _headers);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['sessions'] ?? []) as List<dynamic>;
    }
    throw Exception('Erreur chargement sessions');
  }

  static Future<Map<String, dynamic>> getSession(int sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/sessions/$sessionId'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['session'] ?? {}) as Map<String, dynamic>;
    }
    try {
      final data = json.decode(res.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Erreur chargement session');
    } catch (_) {
      throw Exception('Erreur chargement session (${res.statusCode})');
    }
  }

  // ─── Chat Messages ───
  static Future<void> saveChatMessage(
    int sessionId,
    String role,
    String content,
  ) async {
    await http.post(
      Uri.parse('$baseUrl/api/chat/$sessionId'),
      headers: _headers,
      body: json.encode({'role': role, 'content': content}),
    );
  }

  static Future<List<dynamic>> getChatHistory(int sessionId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/chat/$sessionId'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['messages'] ?? []) as List<dynamic>;
    }
    return [];
  }

  // ─── Gamification ───
  static Future<Map<String, dynamic>> getGamification() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/gamification/me'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    return {'xp': 0, 'level': 1, 'badges': []};
  }

  static Future<List<dynamic>> getLeaderboard() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/gamification/leaderboard'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['leaderboard'] ?? []) as List<dynamic>;
    }
    return [];
  }

  // ─── Streak ───
  static Future<int> getStreak() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/api/gamification/streak'),
        headers: _headers,
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        return (data['streak'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  // ─── Shop ───
  static Future<Map<String, dynamic>> getShopItems() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/gamification/shop'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    try {
      final data = json.decode(res.body) as Map<String, dynamic>;
      throw Exception(data['error'] ?? 'Erreur boutique');
    } catch (_) {
      throw Exception('Erreur boutique');
    }
  }

  static Future<Map<String, dynamic>> buyShopItem(String itemId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/gamification/shop/buy'),
      headers: _headers,
      body: json.encode({'itemId': itemId}),
    );
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ─── Notifications ───
  static Future<List<dynamic>> getNotifications() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['notifications'] ?? []) as List<dynamic>;
    }
    return [];
  }

  static Future<void> markNotificationRead(int id) async {
    await http.patch(
      Uri.parse('$baseUrl/api/notifications/$id/read'),
      headers: _headers,
    );
  }

  static Future<void> markAllNotificationsRead() async {
    await http.patch(
      Uri.parse('$baseUrl/api/notifications/read-all'),
      headers: _headers,
    );
  }

  // ─── Exam Assignments ───
  static Future<List<dynamic>> getExamAssignments() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/exam-assignments'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = json.decode(res.body) as Map<String, dynamic>;
      return (data['assignments'] ?? []) as List<dynamic>;
    }
    return [];
  }

  static Future<int> createExamSession(
    String userId,
    int caseId,
    int? examAssignmentId,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sessions'),
      headers: _headers,
      body: json.encode({
        'user_id': userId,
        'case_id': caseId,
        'is_exam': true,
        'exam_assignment_id': examAssignmentId,
      }),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['id'] as int);
    }
    throw Exception(data['error'] ?? 'Erreur création session examen');
  }

  // ─── Inventory ───
  static Future<Map<String, dynamic>> getInventory() async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/gamification/inventory'),
      headers: _headers,
    );
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return json.decode(res.body) as Map<String, dynamic>;
    }
    return {'ownedItems': [], 'hintBalance': 0};
  }

  // ─── Equip item (avatar or title) ───
  static Future<Map<String, dynamic>> equipItem(String itemId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/gamification/equip'),
      headers: _headers,
      body: json.encode({'itemId': itemId}),
    );
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ─── Use a hint ───
  static Future<Map<String, dynamic>> useHint() async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/gamification/use-hint'),
      headers: _headers,
    );
    return json.decode(res.body) as Map<String, dynamic>;
  }

  // ─── Get AI Hint for a case ───
  static Future<String> getCaseHint(
    int caseId, {
    String type = 'general',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/llm/hint'),
      headers: _headers,
      body: json.encode({'case_id': caseId, 'hint_type': type}),
    );
    final data = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (data['hint'] ?? '') as String;
    }
    throw Exception(data['error'] ?? 'Erreur génération indice');
  }
}
