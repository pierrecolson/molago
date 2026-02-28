'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { CaretLeft, Trash } from '@phosphor-icons/react';
import { Word, Suggestion, isSuggestionResponse } from '@/lib/types';
import { fetchWords, fetchWordById, addWord as apiAddWord, deleteWord as apiDeleteWord } from '@/lib/api';
import Logo from '@/components/Logo';
import WordCard from '@/components/WordCard';
import AddInput from '@/components/AddInput';
import SuggestionBar from '@/components/SuggestionBar';
import DetailHero from '@/components/DetailHero';
import MorphemePills from '@/components/MorphemePills';
import WordFamily from '@/components/WordFamily';
import ExampleCard from '@/components/ExampleCard';
import NuancesCard from '@/components/NuancesCard';
import DeleteModal from '@/components/DeleteModal';
import Toast from '@/components/Toast';
import { useToast } from '@/hooks/useToast';
import styles from './page.module.css';

type Screen = 'list' | 'detail';

interface ShimmerCard {
  korean: string;
}

export default function Home() {
  // ===================== STATE =====================
  const [words, setWords] = useState<Word[]>([]);
  const [screen, setScreen] = useState<Screen>('list');
  const [selectedWord, setSelectedWord] = useState<Word | null>(null);
  const [inputValue, setInputValue] = useState('');
  const [adding, setAdding] = useState(false);
  const [shimmerCards, setShimmerCards] = useState<ShimmerCard[]>([]);
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [deleteModalVisible, setDeleteModalVisible] = useState(false);
  const { message: toastMessage, visible: toastVisible, showToast } = useToast();

  // Set of Korean words in the list for family "in list" check
  const wordListKoreans = useMemo(
    () => new Set(words.map((w) => w.korean)),
    [words]
  );

  // ===================== LOAD WORDS =====================
  useEffect(() => {
    fetchWords().then(setWords).catch(console.error);
  }, []);

  // ===================== BACK BUTTON SUPPORT =====================
  useEffect(() => {
    const handlePopState = () => {
      if (screen === 'detail') {
        setScreen('list');
        setSelectedWord(null);
      }
    };
    window.addEventListener('popstate', handlePopState);
    return () => window.removeEventListener('popstate', handlePopState);
  }, [screen]);

  // ===================== OPEN DETAIL =====================
  const openDetail = useCallback(async (word: Word) => {
    // Fetch full word data (morphemes, family, examples)
    const full = await fetchWordById(word.id);
    if (!full) return;
    setSelectedWord(full);
    setScreen('detail');
    window.history.pushState({ screen: 'detail' }, '', `?word=${word.id}`);
  }, []);

  // ===================== BACK TO LIST =====================
  const goBack = useCallback(() => {
    setScreen('list');
    setSelectedWord(null);
    window.history.pushState({ screen: 'list' }, '', '/');
  }, []);

  // ===================== ADD WORD =====================
  const handleAddWord = useCallback(async () => {
    const val = inputValue.trim();
    if (!val || adding) return;

    setInputValue('');
    setShowSuggestions(false);
    setSuggestions([]);
    setAdding(true);

    // Show shimmer card
    setShimmerCards((prev) => [{ korean: val }, ...prev]);

    try {
      const res = await apiAddWord(val);

      if (isSuggestionResponse(res)) {
        // Remove shimmer, show suggestions
        setShimmerCards((prev) => prev.filter((s) => s.korean !== val));
        setSuggestions(res.suggestions);
        setShowSuggestions(true);
      } else {
        // Success — add word to list, remove shimmer
        setShimmerCards((prev) => prev.filter((s) => s.korean !== val));
        setWords((prev) => [res.word, ...prev]);
        showToast(`${res.word.korean} added`);
      }
    } catch {
      // Remove shimmer on error
      setShimmerCards((prev) => prev.filter((s) => s.korean !== val));
      showToast('Failed to add word');
    } finally {
      setAdding(false);
    }
  }, [inputValue, adding, showToast]);

  // ===================== SUGGESTION SELECT =====================
  const handleSuggestionSelect = useCallback(async (korean: string) => {
    setShowSuggestions(false);
    setSuggestions([]);
    setAdding(true);
    setShimmerCards((prev) => [{ korean }, ...prev]);

    try {
      const res = await apiAddWord(korean);
      setShimmerCards((prev) => prev.filter((s) => s.korean !== korean));

      if (!isSuggestionResponse(res)) {
        setWords((prev) => [res.word, ...prev]);
        showToast(`${res.word.korean} added`);
      }
    } catch {
      setShimmerCards((prev) => prev.filter((s) => s.korean !== korean));
      showToast('Failed to add word');
    } finally {
      setAdding(false);
    }
  }, [showToast]);

  const handleSuggestionDismiss = useCallback(() => {
    setShowSuggestions(false);
    setSuggestions([]);
  }, []);

  // ===================== DELETE WORD =====================
  const handleDelete = useCallback(async () => {
    if (!selectedWord) return;
    setDeleteModalVisible(false);

    try {
      await apiDeleteWord(selectedWord.id);
      setWords((prev) => prev.filter((w) => w.id !== selectedWord.id));
      showToast(`${selectedWord.korean} deleted`);
      goBack();
    } catch {
      showToast('Failed to delete word');
    }
  }, [selectedWord, showToast, goBack]);

  // ===================== FAMILY ADD =====================
  const handleFamilyAdd = useCallback(async (korean: string) => {
    setAdding(true);
    try {
      const res = await apiAddWord(korean);
      if (!isSuggestionResponse(res)) {
        setWords((prev) => [res.word, ...prev]);
        showToast(`${korean} added to your list`);
      }
    } catch {
      showToast('Failed to add word');
    } finally {
      setAdding(false);
    }
  }, [showToast]);

  // ===================== FAMILY NAVIGATE =====================
  const handleFamilyNavigate = useCallback(async (korean: string) => {
    const target = words.find((w) => w.korean === korean);
    if (target) {
      const full = await fetchWordById(target.id);
      if (full) {
        setSelectedWord(full);
        window.history.replaceState({ screen: 'detail' }, '', `?word=${target.id}`);
      }
    }
  }, [words]);

  // ===================== RENDER =====================
  return (
    <div className={styles.app}>
      {/* ============ WORD LIST SCREEN ============ */}
      <div
        className={`${styles.screen} ${screen === 'detail' ? styles.hiddenLeft : ''}`}
      >
        <div className={styles.listHeader}>
          <div className={`content-wrap ${styles.listHeaderInner}`}>
            <Logo />
            <div className={styles.wordCount}>
              {words.length} {words.length === 1 ? 'word' : 'words'}
            </div>
          </div>
        </div>

        <div className={styles.wordList}>
          <div className={`content-wrap ${styles.wordListInner}`}>
            {/* Shimmer cards */}
            {shimmerCards.map((s) => (
              <div key={s.korean} className={styles.shimmerCard}>
                <span className={styles.shimmerKorean}>{s.korean}</span>
                <span className={styles.shimmerText}>Analyzing...</span>
              </div>
            ))}

            {/* Word cards */}
            {words.map((w) => (
              <WordCard
                key={w.id}
                korean={w.korean}
                definition={w.definition}
                usage={w.usage}
                onClick={() => openDetail(w)}
              />
            ))}

            {/* Empty state */}
            {words.length === 0 && shimmerCards.length === 0 && (
              <div className={styles.emptyState}>
                <div className={styles.emptyTitle}>No words yet</div>
                <div className={styles.emptyText}>
                  Add your first Korean word below to start building your vocabulary.
                </div>
              </div>
            )}
          </div>
        </div>

        <AddInput
          value={inputValue}
          onChange={setInputValue}
          onSubmit={handleAddWord}
          disabled={adding}
        />

        <div className="content-wrap">
          <SuggestionBar
            suggestions={suggestions}
            visible={showSuggestions}
            onSelect={handleSuggestionSelect}
            onDismiss={handleSuggestionDismiss}
          />
        </div>
      </div>

      {/* ============ DETAIL SCREEN ============ */}
      <div
        className={`${styles.screen} ${styles.detailScreen} ${screen === 'list' ? styles.hiddenRight : ''}`}
      >
        <div className={styles.detailNav}>
          <div className={`content-wrap ${styles.detailNavInner}`}>
            <button className={styles.backBtn} onClick={goBack}>
              <CaretLeft size={18} />
              Words
            </button>
            <button
              className={styles.deleteBtn}
              onClick={() => setDeleteModalVisible(true)}
            >
              <Trash size={16} />
              Delete
            </button>
          </div>
        </div>

        <div className={styles.detailContent}>
          <div className={`content-wrap ${styles.detailContentInner}`}>
            {selectedWord && (
              <>
                <DetailHero
                  korean={selectedWord.korean}
                  romanization={selectedWord.romanization}
                  definition={selectedWord.definition}
                  literalMeaning={selectedWord.literal_meaning}
                  partOfSpeech={selectedWord.part_of_speech}
                  originType={selectedWord.origin_type}
                  usage={selectedWord.usage}
                />
                <MorphemePills morphemes={selectedWord.morphemes} />
                <WordFamily
                  family={selectedWord.family}
                  morphemes={selectedWord.morphemes}
                  wordListKoreans={wordListKoreans}
                  onAdd={handleFamilyAdd}
                  onNavigate={handleFamilyNavigate}
                />
                <ExampleCard
                  examples={selectedWord.examples}
                  targetKorean={selectedWord.korean}
                />
                <NuancesCard nuances={selectedWord.nuances} />
              </>
            )}
          </div>
        </div>
      </div>

      {/* ============ MODALS & OVERLAYS ============ */}
      <DeleteModal
        korean={selectedWord?.korean ?? ''}
        visible={deleteModalVisible}
        onCancel={() => setDeleteModalVisible(false)}
        onConfirm={handleDelete}
      />

      <Toast message={toastMessage} visible={toastVisible} />
    </div>
  );
}
