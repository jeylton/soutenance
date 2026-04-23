const voiceOr = (envName, fallback) => (process.env[envName] || fallback || '').trim();

const AVATAR_VOICE_PROFILES = [
  {
    hint: 'male_young',
    path: '/avatars/gif1.gif',
    ageGroup: 'adult',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF1', '101A8UFM73tcrunWGirw'),
  },
  {
    hint: 'female_young',
    path: '/avatars/gif2.gif',
    ageGroup: 'adult',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF2', 'fBpCO0Kf0krKLYGOu65w'),
  },
  {
    hint: 'male_old',
    path: '/avatars/gif3.gif',
    ageGroup: 'senior',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF3', '6aRkp7Pz4MBOSpUyJCTO'),
  },
  {
    hint: 'female_old',
    path: '/avatars/gif4.gif',
    ageGroup: 'senior',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF4', 'YxrwjAKoUKULGd0g8K9Y'),
  },
  {
    hint: 'child_male',
    path: '/avatars/gif5.gif',
    ageGroup: 'child',
    gender: 'male',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF5', 'FRY6vOtGqwamgAf39SwP'),
  },
  {
    hint: 'child_female',
    path: '/avatars/gif6.gif',
    ageGroup: 'child',
    gender: 'female',
    voiceId: voiceOr('ELEVENLABS_VOICE_GIF6', 'DOqLhiOMs8JmafdomNTP'),
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
  resolveAvatarProfile,
};
