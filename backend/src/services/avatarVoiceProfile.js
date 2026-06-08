const voiceOr = (envName, fallback) => (process.env[envName] || fallback || '').trim();

// ─── Profils voix Google Cloud TTS ───────────────────────────────────────────
const GOOGLE_TTS_PROFILES = {
  male_young:   { name: voiceOr('GTTS_VOICE_GIF1', 'fr-FR-Neural2-B'), pitch: 2,  speakingRate: 1.0 },
  female_young: { name: voiceOr('GTTS_VOICE_GIF2', 'fr-FR-Neural2-A'), pitch: 0,  speakingRate: 1.0 },
  male_old:     { name: voiceOr('GTTS_VOICE_GIF3', 'fr-FR-Neural2-D'), pitch: -3, speakingRate: 0.9 },
  female_old:   { name: voiceOr('GTTS_VOICE_GIF4', 'fr-FR-Neural2-C'), pitch: -1, speakingRate: 0.9 },
  child_male:   { name: voiceOr('GTTS_VOICE_GIF5', 'fr-FR-Neural2-B'), pitch: 5,  speakingRate: 1.1 },
  child_female: { name: voiceOr('GTTS_VOICE_GIF6', 'fr-FR-Neural2-A'), pitch: 6,  speakingRate: 1.1 },
};

// ─── Profils avatar/voix (un par catégorie genre+âge) ────────────────────────
const AVATAR_VOICE_PROFILES = [
  {
    hint: 'male_young',
    ageGroup: 'adult',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF1', '101A8UFM73tcrunWGirw'),
    googleTts: GOOGLE_TTS_PROFILES.male_young,
  },
  {
    hint: 'female_young',
    ageGroup: 'adult',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF2', 'fBpCO0Kf0krKLYGOu65w'),
    googleTts: GOOGLE_TTS_PROFILES.female_young,
  },
  {
    hint: 'male_old',
    ageGroup: 'senior',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF3', '6aRkp7Pz4MBOSpUyJCTO'),
    googleTts: GOOGLE_TTS_PROFILES.male_old,
  },
  {
    hint: 'female_old',
    ageGroup: 'senior',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF4', 'YxrwjAKoUKULGd0g8K9Y'),
    googleTts: GOOGLE_TTS_PROFILES.female_old,
  },
  {
    hint: 'child_male',
    ageGroup: 'child',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF5', 'FRY6vOtGqwamgAf39SwP'),
    googleTts: GOOGLE_TTS_PROFILES.child_male,
  },
  {
    hint: 'child_female',
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

// Déduit le profil voix depuis le nom du fichier gif
const profileFromFilename = (filename) => {
  const f = filename.toLowerCase();
  const isFemale  = f.includes('femme') || f.includes('female');
  const isMale    = f.includes('homme') || f.includes('male');
  const isChild   = f.includes('enfant') || f.includes('child');
  const isSenior  = f.includes('senior') || f.includes('vieux') || f.includes('old');

  if (isChild  && isFemale) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'child_female');
  if (isChild)              return AVATAR_VOICE_PROFILES.find(p => p.hint === 'child_male');
  if (isSenior && isFemale) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'female_old');
  if (isSenior)             return AVATAR_VOICE_PROFILES.find(p => p.hint === 'male_old');
  if (isFemale)             return AVATAR_VOICE_PROFILES.find(p => p.hint === 'female_young');
  if (isMale)               return AVATAR_VOICE_PROFILES.find(p => p.hint === 'male_young');

  // Legacy gif1-gif6
  if (f.includes('gif6') || f.includes('avatar6')) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'child_female');
  if (f.includes('gif5') || f.includes('avatar5')) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'child_male');
  if (f.includes('gif4') || f.includes('avatar4')) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'female_old');
  if (f.includes('gif3') || f.includes('avatar3')) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'male_old');
  if (f.includes('gif2') || f.includes('avatar2')) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'female_young');
  if (f.includes('gif1') || f.includes('avatar1')) return AVATAR_VOICE_PROFILES.find(p => p.hint === 'male_young');

  return null;
};

const resolveAvatarProfile = ({ avatar, age, gender } = {}) => {
  // medical_history.gender = source de vérité pour la voix
  if (gender) {
    const ageGroup = ageToGroup(age);
    const genderNorm = normalizeGender(gender);
    return (
      AVATAR_VOICE_PROFILES.find((p) => p.ageGroup === ageGroup && p.gender === genderNorm) ||
      AVATAR_VOICE_PROFILES[0]
    );
  }

  // Pas de genre explicite → déduire depuis le nom du gif
  const avatarPath = (avatar || '').toString().trim();
  if (avatarPath) {
    const filename = avatarPath.split('/').pop();
    const fromFile = profileFromFilename(filename);
    if (fromFile) return fromFile;
  }

  return AVATAR_VOICE_PROFILES[0];
};

module.exports = {
  AVATAR_VOICE_PROFILES,
  GOOGLE_TTS_PROFILES,
  resolveAvatarProfile,
};
