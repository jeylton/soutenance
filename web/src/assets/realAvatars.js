const resolveApiBase = () => {
  const envBase = (import.meta.env.VITE_API_URL || '').trim().replace(/\/$/, '');
  if (envBase) return envBase;
  if (typeof window === 'undefined') return 'http://localhost:5000';
  const host = window.location.hostname;
  if (host === 'localhost' || host === '127.0.0.1') return 'http://localhost:5000';
  return '';
};

const API_BASE = resolveApiBase();

const voiceOr = (envName, fallback) => (import.meta.env[envName] || fallback || '').trim();

const AVATAR_PROFILES = [
  {
    hint: 'male_young',
    label: 'GIF 1',
    path: '/avatars/gif1.gif',
    ageGroup: 'adult',
    gender: 'male',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF1', '101A8UFM73tcrunWGirw'),
  },
  {
    hint: 'female_young',
    label: 'GIF 2',
    path: '/avatars/gif2.gif',
    ageGroup: 'adult',
    gender: 'female',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF2', 'fBpCO0Kf0krKLYGOu65w'),
  },
  {
    hint: 'male_old',
    label: 'GIF 3',
    path: '/avatars/gif3.gif',
    ageGroup: 'senior',
    gender: 'male',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF3', '6aRkp7Pz4MBOSpUyJCTO'),
  },
  {
    hint: 'female_old',
    label: 'GIF 4',
    path: '/avatars/gif4.gif',
    ageGroup: 'senior',
    gender: 'female',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF4', 'YxrwjAKoUKULGd0g8K9Y'),
  },
  {
    hint: 'child_male',
    label: 'GIF 5',
    path: '/avatars/gif5.gif',
    ageGroup: 'child',
    gender: 'male',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF5', 'FRY6vOtGqwamgAf39SwP'),
  },
  {
    hint: 'child_female',
    label: 'GIF 6',
    path: '/avatars/gif6.gif',
    ageGroup: 'child',
    gender: 'female',
    voiceId: voiceOr('VITE_ELEVENLABS_VOICE_GIF6', 'DOqLhiOMs8JmafdomNTP'),
  },
];

const toAbsoluteUrl = (path) => {
  if (!path) return '';
  return API_BASE ? `${API_BASE}${path}` : path;
};

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

export const REAL_AVATARS = AVATAR_PROFILES.map((a) => ({
  ...a,
  img: toAbsoluteUrl(a.path),
  animated: true,
}));

export const resolveAvatarProfile = ({ hint, age, gender } = {}) => {
  const normalizedHint = (hint || '').toString().trim().toLowerCase();
  if (normalizedHint) {
    const byHint = REAL_AVATARS.find((a) => a.hint === normalizedHint);
    if (byHint) return byHint;
  }

  const ageGroup = ageToGroup(age);
  const genderNorm = normalizeGender(gender);
  const byAgeAndGender = REAL_AVATARS.find(
    (a) => a.ageGroup === ageGroup && a.gender === genderNorm,
  );
  if (byAgeAndGender) return byAgeAndGender;

  return REAL_AVATARS[0];
};

export const resolveAvatarByValue = (value) => {
  const raw = (value || '').toString().trim();
  if (!raw) return null;
  return (
    REAL_AVATARS.find((a) => a.path === raw) ||
    REAL_AVATARS.find((a) => a.img === raw) ||
    REAL_AVATARS.find((a) => a.img.endsWith(raw)) ||
    null
  );
};