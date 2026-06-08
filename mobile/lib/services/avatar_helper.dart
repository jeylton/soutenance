import 'api.dart';

/// Résout le chemin correct du gif avatar en fonction du genre et de l'âge
/// du patient (medical_history). Le genre est la source de vérité.
String resolvePatientAvatarUrl(Map<String, dynamic>? caseData) {
  final medical =
      caseData?['medical_history'] is Map
          ? Map<String, dynamic>.from(caseData!['medical_history'] as Map)
          : <String, dynamic>{};

  // Gender: medical_history.gender est prioritaire
  final rawGender =
      (medical['gender'] ?? caseData?['gender'] ?? '').toString().toLowerCase();
  final String gender;
  if (rawGender.startsWith('f')) {
    gender = 'female';
  } else if (rawGender.startsWith('m')) {
    gender = 'male';
  } else {
    // Aucun genre explicite → on lit le nom du gif comme fallback
    final avatar = (caseData?['avatar'] ?? '').toString().toLowerCase();
    if (avatar.contains('gif2') || avatar.contains('gif4') || avatar.contains('gif6')) {
      gender = 'female';
    } else {
      gender = 'male';
    }
  }

  // Age group
  final ageRaw = medical['age'] ?? caseData?['age'];
  final ageNum = ageRaw is num ? ageRaw : double.tryParse(ageRaw?.toString() ?? '');
  final String ageGroup;
  if (ageNum != null && ageNum <= 14) {
    ageGroup = 'child';
  } else if (ageNum != null && ageNum >= 60) {
    ageGroup = 'senior';
  } else {
    ageGroup = 'adult';
  }

  // Mapping (gender, ageGroup) → gif
  const gifMap = {
    'male_adult':   '/avatars/gif1.gif',
    'female_adult': '/avatars/gif2.gif',
    'male_senior':  '/avatars/gif3.gif',
    'female_senior':'/avatars/gif4.gif',
    'male_child':   '/avatars/gif5.gif',
    'female_child': '/avatars/gif6.gif',
  };

  final path = gifMap['${gender}_$ageGroup'] ?? '/avatars/gif1.gif';
  return Api.normalizeAssetUrl(path);
}
