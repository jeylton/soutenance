import 'package:flutter/foundation.dart';

class SessionState extends ChangeNotifier {
  int? _caseId;
  int? _sessionId;
  String? _userId;
  String? _token;
  String? _userName;
  String? _userEmail;
  String? _profileType;
  int _xp = 0;
  int _level = 1;
  List<Map<String, dynamic>> _badges = [];
  Map<String, dynamic>? _caseData;
  String? _avatarId;
  String? _activeTitle;
  int _hintBalance = 0;

  // Timer
  int _elapsedSeconds = 0;
  int? _examTimeLimitMinutes;
  bool _isExamMode = false;

  // Language
  String _locale = 'fr';

  // Theme
  bool _isDarkTheme = false;
  bool _useFreePatientVoices = true;

  int? get caseId => _caseId;
  int? get sessionId => _sessionId;
  String? get userId => _userId;
  String? get token => _token;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get profileType => _profileType;
  int get xp => _xp;
  int get level => _level;
  List<Map<String, dynamic>> get badges => _badges;
  int get elapsedSeconds => _elapsedSeconds;
  Map<String, dynamic>? get caseData => _caseData;
  String? get avatarId => _avatarId;
  String? get activeTitle => _activeTitle;
  int get hintBalance => _hintBalance;
  bool get isExamMode => _isExamMode;
  int? get examTimeLimitMinutes => _examTimeLimitMinutes;
  String get locale => _locale;
  bool get isFrench => _locale == 'fr';
  bool get isDarkTheme => _isDarkTheme;
  bool get useFreePatientVoices => _useFreePatientVoices;
  int get remainingSeconds =>
      _isExamMode && _examTimeLimitMinutes != null
          ? (_examTimeLimitMinutes! * 60) - _elapsedSeconds
          : -1;
  bool get isTimeUp =>
      _isExamMode && _examTimeLimitMinutes != null && remainingSeconds <= 0;

  bool get isLoggedIn => _token != null && _userId != null;

  void setUser(
    String userId,
    String token, {
    String? name,
    String? email,
    String? profileType,
  }) {
    _userId = userId;
    _token = token;
    _userName = name;
    _userEmail = email;
    _profileType = profileType;
    notifyListeners();
  }

  void updateProfile({
    String? name,
    String? email,
    String? profileType,
    int? xp,
    int? level,
    List<Map<String, dynamic>>? badges,
    String? avatarId,
    String? activeTitle,
    int? hintBalance,
  }) {
    if (name != null) _userName = name;
    if (email != null) _userEmail = email;
    if (profileType != null) _profileType = profileType;
    if (xp != null) _xp = xp;
    if (level != null) _level = level;
    if (badges != null) _badges = badges;
    if (avatarId != null) _avatarId = avatarId;
    if (activeTitle != null) _activeTitle = activeTitle;
    if (hintBalance != null) _hintBalance = hintBalance;
    notifyListeners();
  }

  void startCase(
    int caseId,
    int sessionId, {
    Map<String, dynamic>? caseData,
    bool isExam = false,
    int? timeLimitMinutes,
  }) {
    _caseId = caseId;
    _sessionId = sessionId;
    _caseData = caseData;
    _elapsedSeconds = 0;
    _isExamMode = isExam;
    _examTimeLimitMinutes = timeLimitMinutes;
    notifyListeners();
  }

  void tickTimer() {
    _elapsedSeconds++;
    notifyListeners();
  }

  void setLocale(String locale) {
    _locale = locale;
    notifyListeners();
  }

  void setDarkTheme(bool value) {
    _isDarkTheme = value;
    notifyListeners();
  }

  void setUseFreePatientVoices(bool value) {
    _useFreePatientVoices = value;
    notifyListeners();
  }

  String t(String fr, String en) => _locale == 'fr' ? fr : en;

  void reset() {
    _caseId = null;
    _sessionId = null;
    _caseData = null;
    _elapsedSeconds = 0;
    _isExamMode = false;
    _examTimeLimitMinutes = null;
    notifyListeners();
  }

  void logout() {
    _caseId = null;
    _sessionId = null;
    _caseData = null;
    _userId = null;
    _token = null;
    _userName = null;
    _userEmail = null;
    _profileType = null;
    _xp = 0;
    _level = 1;
    _badges = [];
    _avatarId = null;
    _activeTitle = null;
    _hintBalance = 0;
    _elapsedSeconds = 0;
    _isExamMode = false;
    _examTimeLimitMinutes = null;
    _isDarkTheme = false;
    _useFreePatientVoices = true;
    notifyListeners();
  }
}
