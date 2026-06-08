import 'api.dart';

// Gifs disponibles par catégorie (mêmes pools que le web)
const _pools = {
  'male_adult':    ['/avatars/adulte homme.gif', '/avatars/adulte homme 2.gif', '/avatars/adulte homme 3.gif'],
  'female_adult':  ['/avatars/adulte femme.gif', '/avatars/adulte femme 2.gif', '/avatars/ADULTE FEMME 3.gif'],
  'male_senior':   ['/avatars/senior homme.gif', '/avatars/senior homme 2.gif'],
  'female_senior': ['/avatars/senior femme.gif'],
  'male_child':    ['/avatars/enfant homme.gif'],
  'female_child':  ['/avatars/enfant femme.gif'],
};

String _encodeAvatarPath(String path) {
  // Encode chaque segment du chemin pour gérer les espaces et accents
  return path.split('/').map((s) => s.isEmpty ? s : Uri.encodeComponent(s)).join('/');
}

/// Retourne l'URL complète du gif avatar à afficher.
/// Priorité : avatar sauvegardé en DB (choix de l'admin).
/// Fallback : gif aléatoire déduit du genre+âge.
String resolvePatientAvatarUrl(Map<String, dynamic>? caseData) {
  // 1) Avatar choisi par l'admin → on le respecte
  final storedAvatar = (caseData?['avatar'] ?? '').toString().trim();
  if (storedAvatar.isNotEmpty) {
    return Api.normalizeAssetUrl(_encodeAvatarPath(storedAvatar));
  }

  // 2) Fallback : genre + âge depuis medical_history
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

  final pool = _pools['${gender}_$ageGroup'] ?? _pools['male_adult']!;
  final path = pool[(DateTime.now().millisecondsSinceEpoch) % pool.length];
  return Api.normalizeAssetUrl(_encodeAvatarPath(path));
}
