import { Morpheme } from './types';

// ===================== USAGE CONFIG =====================

export type UsageLevel = 'high' | 'mid' | 'low';

export interface UsageInfo {
  label: string;
  colorClass: string;
}

export const usageConfig: Record<UsageLevel, UsageInfo> = {
  high: { label: 'Common', colorClass: 'usageHigh' },
  mid: { label: 'Moderate', colorClass: 'usageMid' },
  low: { label: 'Rare', colorClass: 'usageLow' },
};

// ===================== MORPHEME HIGHLIGHTING =====================

/**
 * Highlights shared morpheme syllables in a family word's Korean text.
 * Returns an array of { char, highlighted } for rendering.
 */
export function highlightSharedMorphemes(
  familyKorean: string,
  parentMorphemes: Morpheme[]
): Array<{ char: string; highlighted: boolean }> {
  const morphemeSyllables = parentMorphemes
    .filter((m) => m.hanja !== '—')
    .map((m) => m.korean);

  return Array.from(familyKorean).map((char) => ({
    char,
    highlighted: morphemeSyllables.includes(char),
  }));
}

// ===================== WORD HIGHLIGHTING IN EXAMPLES =====================

/**
 * Splits an example Korean sentence into parts, highlighting the target word
 * and any conjugated forms.
 * Returns an array of { text, highlighted } for rendering.
 */
export function highlightWordInExample(
  exampleKr: string,
  targetKorean: string
): Array<{ text: string; highlighted: boolean }> {
  const escaped = targetKorean.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Match the target word + any trailing Hangul (conjugated forms)
  const regex = new RegExp(`(${escaped}[가-힣]*)`, 'g');
  const parts: Array<{ text: string; highlighted: boolean }> = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  while ((match = regex.exec(exampleKr)) !== null) {
    if (match.index > lastIndex) {
      parts.push({ text: exampleKr.slice(lastIndex, match.index), highlighted: false });
    }
    parts.push({ text: match[1], highlighted: true });
    lastIndex = match.index + match[0].length;
  }

  if (lastIndex < exampleKr.length) {
    parts.push({ text: exampleKr.slice(lastIndex), highlighted: false });
  }

  return parts.length > 0 ? parts : [{ text: exampleKr, highlighted: false }];
}
