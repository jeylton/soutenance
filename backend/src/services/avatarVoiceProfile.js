const voiceOr = (envName, fallback) => (process.env[envName] || fallback || '').trim();

// ─── Google Cloud TTS voice configs par profil ───────────────────────────────
// Voix Neural2 = haute qualité (incluses dans le free tier 1M chars/mois)
// pitch en demi-tons (-20 à +20), speakingRate (0.25 à 4.0)
const GOOGLE_TTS_PROFILES = {
    male_young:   { name: voiceOr('GTTS_VOICE_GIF1', 'fr-FR-Neural2-B'), pitch: 2,  speakingRate: 1.0 },
    female_young: { name: voiceOr('GTTS_VOICE_GIF2', 'fr-FR-Neural2-A'), pitch: 0,  speakingRate: 1.0 },
    male_old:     { name: voiceOr('GTTS_VOICE_GIF3', 'fr-FR-Neural2-D'), pitch: -3, speakingRate: 0.9 },
    female_old:   { name: voiceOr('GTTS_VOICE_GIF4', 'fr-FR-Neural2-C'), pitch: -1, speakingRate: 0.9 },
    child_male:   { name: voiceOr('GTTS_VOICE_GIF5', 'fr-FR-Neural2-B'), pitch: 5,  speakingRate: 1.1 },
    child_female: { name: voiceOr('GTTS_VOICE_GIF6', 'fr-FR-Neural2-A'), pitch: 6,  speakingRate: 1.1 },
};

const AVATAR_VOICE_PROFILES = [
  {
    hint: 'male_young',
    path: '/avatars/gif1.gif',
    ageGroup: 'adult',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF1', '101A8UFM73tcrunWGirw'),
    googleTts: GOOGLE_TTS_PROFILES.male_young,
  },
  {
    hint: 'female_young',
    path: '/avatars/gif2.gif',
    ageGroup: 'adult',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF2', 'fBpCO0Kf0krKLYGOu65w'),
    googleTts: GOOGLE_TTS_PROFILES.female_young,
  },
  {
    hint: 'male_old',
    path: '/avatars/gif3.gif',
    ageGroup: 'senior',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF3', '6aRkp7Pz4MBOSpUyJCTO'),
    googleTts: GOOGLE_TTS_PROFILES.male_old,
  },
  {
    hint: 'female_old',
    path: '/avatars/gif4.gif',
    ageGroup: 'senior',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF4', 'YxrwjAKoUKULGd0g8K9Y'),
    googleTts: GOOGLE_TTS_PROFILES.female_old,
  },
  {
    hint: 'child_male',
    path: '/avatars/gif5.gif',
    ageGroup: 'child',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF5', 'FRY6vOtGqwamgAf39SwP'),
    googleTts: GOOGLE_TTS_PROFILES.child_male,
  },
  {
    hint: 'child_female',
    path: '/avatars/gif6.gif',
    ageGroup: 'child',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF6', 'DOqLhiOMs8JmafdomNTP'),
    googleTts: GOOGLE_TTS_PROFILES.child_female,
  },
];

const normalizeGender = (gender) => {
  const g = (gender || '').toString().toLowerCase();
  if (g.startsWith('f')) return 'female';
  if (g.startsWith('m')) return 'male';
  return 'male';
};

const ageToGroup = (age) => {
  const n = Number(age);
  if (!Number.isFinite(n)) return 'adult';
  if (n <= 14) return 'child';
  if (n >= 60) return 'senior';
  return 'adult';
};

const resolveAvatarProfile = ({ avatar, age, gender } = {}) => {
  const normalizedAvatar = (avatar || '').toString().trim().toLowerCase();
  if (normalizedAvatar) {
    // Legacy avatar filenames (seeded data / older DB rows)
    if (normalizedAvatar.includes('avatar1')) {
      return AVATAR_VOICE_PROFILES.find((p) => p.hint === 'male_young') || AVATAR_VOICE_PROFILES[0];
    }
    if (normalizedAvatar.includes('avatar2')) {
      return AVATAR_VOICE_PROFILES.find((p) => p.hint === 'female_young') || AVATAR_VOICE_PROFILES[0];
    }
    if (normalizedAvatar.includes('avatar3')) {
      return AVATAR_VOICE_PROFILES.find((p) => p.hint === 'male_old') || AVATAR_VOICE_PROFILES[0];
    }
    if (normalizedAvatar.includes('avatar4')) {
      return AVATAR_VOICE_PROFILES.find((p) => p.hint === 'female_old') || AVATAR_VOICE_PROFILES[0];
    }

    const byPath = AVATAR_VOICE_PROFILES.find((p) => p.path.toLowerCase() === normalizedAvatar);
    if (byPath) return byPath;
    const byHint = AVATAR_VOICE_PROFILES.find((p) => p.hint === normalizedAvatar);
    if (byHint) return byHint;
    const bySuffix = AVATAR_VOICE_PROFILES.find((p) => normalizedAvatar.endsWith(p.path.toLowerCase()));
    if (bySuffix) return bySuffix;
  }

  const ageGroup = ageToGroup(age);
  const genderNorm = normalizeGender(gender);
  return (
    AVATAR_VOICE_PROFILES.find((p) => p.ageGroup === ageGroup && p.gender === genderNorm) ||
    AVATAR_VOICE_PROFILES[0]
  );
};

module.exports = {
  AVATAR_VOICE_PROFILES,
  GOOGLE_TTS_PROFILES,
  resolveAvatarProfile,
};
