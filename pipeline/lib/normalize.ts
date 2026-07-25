/**
 * Normalisation entre les listes NIKL (lemmes en 다, POS coréens, homographes numérotés)
 * et les lemmes/tags produits par Kiwi. C'est le point de fragilité n°2 du plan :
 * toute divergence crée de faux « inconnus » et empêche la convergence du vérificateur.
 */

// POS coréens (fichiers NIKL) → tags Kiwi.
const POS_MAP: Record<string, string> = {
  '명사': 'NNG',
  '고유명사': 'NNP',
  '의존명사': 'NNB',
  '대명사': 'NP',
  '수사': 'NR',
  '동사': 'VV',
  '형용사': 'VA',
  '보조동사': 'VX',
  '보조형용사': 'VX',
  '관형사': 'MM',
  '부사': 'MAG',
  '접속부사': 'MAJ',
  '감탄사': 'IC',
  '조사': 'J',
  '어미': 'E',
  '접사': 'XS',
};

/** Nettoie un lemme NIKL : homographes (가다01 → 가다), espaces, annotations entre parenthèses. */
export function cleanLemma(raw: string): string {
  return raw
    .replace(/\d+$/, '')          // numéro d'homographe final
    .replace(/\(.*?\)/g, '')      // annotations (준말) etc.
    .replace(/[~〜]/g, '')        // marqueurs de liaison
    .trim();
}

/**
 * Normalise une entrée NIKL vers la convention Kiwi :
 * - map du POS coréen vers le tag Kiwi
 * - verbes/adjectifs : retire le 다 final (Kiwi lemmatise 먹었어요 → 먹, pas 먹다)
 */
export function normalizeNiklEntry(rawLemma: string, rawPos: string): { lemma: string; pos: string } {
  let lemma = cleanLemma(rawLemma);
  const posKo = (rawPos ?? '').trim().replace(/\d+$/, '');
  const pos = POS_MAP[posKo] ?? posKo ?? '';
  if ((pos === 'VV' || pos === 'VA' || pos === 'VX') && lemma.endsWith('다')) {
    lemma = lemma.slice(0, -1);
  }
  return { lemma, pos };
}

/**
 * Tags Kiwi considérés comme « mots de contenu » pour la mesure de couverture.
 * Les particules (J*), terminaisons (E*), ponctuation (S*) etc. sont grammaticales :
 * elles n'entrent pas dans le calcul (elles sont « connues » par construction du niveau).
 */
const CONTENT_TAG_PREFIXES = ['NNG', 'NNP', 'NNB', 'NP', 'NR', 'VV', 'VA', 'VX', 'MM', 'MAG', 'MAJ', 'IC', 'XR', 'SL'];

export function isContentTag(tag: string): boolean {
  return CONTENT_TAG_PREFIXES.some((p) => tag.startsWith(p));
}

/**
 * Mots-outils et items toujours « supposés connus » quel que soit le profil :
 * copule, verbes support ultra-fréquents, pronoms de base. Sans cette allowlist,
 * le moindre 하다/있다 non présent dans le profil casserait la couverture.
 */
export const ALWAYS_KNOWN_LEMMAS = new Set([
  '하', '되', '있', '없', '이', '아니', '같', '보', '주', '받', '가', '오', '말', '것', '수', '때',
  '거', '저', '나', '너', '우리', '그', '이', '뭐', '왜', '어떻', '좀', '더', '안', '못', '잘', '다',
  '한', '두', '세', '네',
]);

/** Clé de comparaison profil ↔ texte. On compare sur le lemme seul (pas le POS) :
 * les écarts de tag entre listes et Kiwi (NNG vs NNB, VV vs VX) créeraient des faux négatifs. */
export function lemmaKey(lemma: string): string {
  return cleanLemma(lemma);
}
