import 'api.dart';

/// Retourne l'URL du gif avatar à afficher.
/// Priorité : avatar sauvegardé en DB (choix de l'admin).
/// Fallback : gif déduit du genre+âge si avatar vide.
String resolvePatientAvatarUrl(Map<String, dynamic>? caseData) {
  // 1) Avatar explicitement choisi par l'admin → on le respecte
  final storedAvatar = (caseData?['avatar'] ?? '').toString().trim();
  if (storedAvatar.isNotEmpty) {
    return Api.normalizeAssetUrl(storedAvatar);
  }

  // 2) Fallback : déduire depuis genre + âge
  final medical =
      caseData?['medical_history'] is Map
          ? Map<String, dynamic>.from(caseData!['medical_history'] as Map)
          : <String, dynamic>{};

  final rawGender =
      (medical['gender'] ?? caseData?['gender'] ?? '').toString().toLowerCase();
  final String gender =
      rawGender.startsWith('f') ? 'female' : 'male';

  final ageRaw = medical['age'] ?? caseData?['age'];
  final ageNum = ageRaw is num ? ageRaw : double.tryParse(ageRaw?.toString() ?? '');
  final String ageGroup =
      (ageNum != null && ageNum <= 14) ? 'child'
      : (ageNum != null && ageNum >= 60) ? 'senior'
      : 'adult';

  const gifMap = {
    'male_adult':    '/avatars/gif1.gif',
    'female_adult':  '/avatars/gif2.gif',
    'male_senior':   '/avatars/gif3.gif',
    'female_senior': '/avatars/gif4.gif',
    'male_child':    '/avatars/gif5.gif',
    'female_child':  '/avatars/gif6.gif',
  };

  final path = gifMap['${gender}_$ageGroup'] ?? '/avatars/gif1.gif';
  return Api.normalizeAssetUrl(path);
}
