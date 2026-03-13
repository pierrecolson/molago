'use client';

import { useEffect, useState, useCallback, useMemo } from 'react';
import { CaretLeft, Trash } from '@phosphor-icons/react';
import { Word, Suggestion, isSuggestionResponse } from '@/lib/types';
import { fetchWords, fetchWordById, addWord as apiAddWord, deleteWord as apiDeleteWord, ApiError } from '@/lib/api';
import Logo from '@/components/Logo';
import WordCard from '@/components/WordCard';
import AddInput from '@/components/AddInput';
import SuggestionBar from '@/components/SuggestionBar';
import AddWordSheet from '@/components/AddWordSheet';
import { useIsMobile } from '@/hooks/useIsMobile';
import { fixMorphemeKorean } from '@/lib/utils';
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
  const [loading, setLoading] = useState(true);
  const [screen, setScreen] = useState<Screen>('list');
  const [selectedWord, setSelectedWord] = useState<Word | null>(null);
  const [inputValue, setInputValue] = useState('');
  const [adding, setAdding] = useState(false);
  const [shimmerCards, setShimmerCards] = useState<ShimmerCard[]>([]);
  const [suggestions, setSuggestions] = useState<Suggestion[]>([]);
  const [showSuggestions, setShowSuggestions] = useState(false);
  const [deleteModalVisible, setDeleteModalVisible] = useState(false);
  const [addError, setAddError] = useState('');
  const [loadError, setLoadError] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [pendingWord, setPendingWord] = useState<Word | null>(null);
  const [shimmerWord, setShimmerWord] = useState('');
  const { message: toastMessage, visible: toastVisible, showToast } = useToast();
  const isMobile = useIsMobile();

  // Set of Korean words in the list for family "in list" check
  const wordListKoreans = useMemo(
    () => new Set(words.map((w) => w.korean)),
    [words]
  );

  // ===================== LOAD WORDS =====================
  const loadWords = useCallback(() => {
    setLoading(true);
    setLoadError(false);
    fetchWords()
      .then((data) => {
        setWords(data);
        setLoading(false);
      })
      .catch((err) => {
        console.error(err);
        setLoadError(true);
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    loadWords();
  }, [loadWords]);

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
    try {
      const full = await fetchWordById(word.id);
      if (!full) return;
      setSelectedWord(full);
      setScreen('detail');
      window.history.pushState({ screen: 'detail' }, '', `?word=${word.id}`);
    } catch (err) {
      console.error('Failed to load word details:', err);
    }
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
    setAddError('');
    setShowSuggestions(false);
    setSuggestions([]);
    setAdding(true);

    // Mobile: show shimmer in sheet; Desktop: show shimmer card in list
    if (isMobile) {
      setShimmerWord(val);
    } else {
      setShimmerCards((prev) => [{ korean: val }, ...prev]);
    }

    try {
      const res = await apiAddWord(val);

      if (isSuggestionResponse(res)) {
        setShimmerCards((prev) => prev.filter((s) => s.korean !== val));
        setShimmerWord('');
        setSuggestions(res.suggestions);
        setShowSuggestions(true);
      } else if (isMobile) {
        // Mobile: show result in sheet, wait for user to confirm
        setShimmerWord('');
        setPendingWord(res.word);
      } else {
        // Desktop: add immediately
        setShimmerCards((prev) => prev.filter((s) => s.korean !== val));
        setWords((prev) => [res.word, ...prev]);
        showToast(`${res.word.korean} added`);
      }
    } catch (err) {
      setShimmerCards((prev) => prev.filter((s) => s.korean !== val));
      setShimmerWord('');
      if (err instanceof ApiError) {
        setAddError(err.userMessage);
      } else {
        setAddError("Couldn't get the definition. Please try again.");
      }
    } finally {
      setAdding(false);
    }
  }, [inputValue, adding, showToast, isMobile]);

  // ===================== SUGGESTION SELECT =====================
  const handleSuggestionSelect = useCallback(async (korean: string) => {
    setShowSuggestions(false);
    setSuggestions([]);
    setAdding(true);

    if (isMobile) {
      setShimmerWord(korean);
    } else {
      setShimmerCards((prev) => [{ korean }, ...prev]);
    }

    try {
      const res = await apiAddWord(korean);
      setShimmerCards((prev) => prev.filter((s) => s.korean !== korean));

      if (!isSuggestionResponse(res)) {
        if (isMobile) {
          setShimmerWord('');
          setPendingWord(res.word);
        } else {
          setWords((prev) => [res.word, ...prev]);
          showToast(`${res.word.korean} added`);
        }
      }
    } catch (err) {
      setShimmerCards((prev) => prev.filter((s) => s.korean !== korean));
      setShimmerWord('');
      const msg = err instanceof ApiError ? err.userMessage : "Couldn't get the definition. Please try again.";
      setAddError(msg);
    } finally {
      setAdding(false);
    }
  }, [showToast, isMobile]);

  const handleSuggestionDismiss = useCallback(() => {
    setShowSuggestions(false);
    setSuggestions([]);
  }, []);

  // ===================== CONFIRM ADD (mobile sheet) =====================
  const handleConfirmAdd = useCallback((word: Word) => {
    setWords((prev) => [word, ...prev]);
    showToast(`${word.korean} added`);
    setSheetOpen(false);
    setPendingWord(null);
    setShimmerWord('');
  }, [showToast]);

  // ===================== DELETE WORD =====================
  const handleDelete = useCallback(async () => {
    if (!selectedWord) return;
    setDeleteModalVisible(false);

    try {
      await apiDeleteWord(selectedWord.id);
      setWords((prev) => prev.filter((w) => w.id !== selectedWord.id));
      showToast(`${selectedWord.korean} deleted`);
      goBack();
    } catch (err) {
      const msg = err instanceof ApiError ? err.userMessage : "Couldn't delete. Try again.";
      showToast(msg);
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
    } catch (err) {
      const msg = err instanceof ApiError ? err.userMessage : "Couldn't add word. Please try again.";
      showToast(msg);
    } finally {
      setAdding(false);
    }
  }, [showToast]);

  // ===================== FAMILY NAVIGATE =====================
  const handleFamilyNavigate = useCallback(async (korean: string) => {
    const target = words.find((w) => w.korean === korean);
    if (target) {
      try {
        const full = await fetchWordById(target.id);
        if (full) {
          setSelectedWord(full);
          window.history.replaceState({ screen: 'detail' }, '', `?word=${target.id}`);
        }
      } catch (err) {
        console.error('Failed to navigate to word:', err);
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

            {/* Loading state */}
            {loading && words.length === 0 && shimmerCards.length === 0 && (
              <div className={styles.emptyState}>
                <div className={styles.loadingDots}>
                  <span /><span /><span />
                </div>
                <div className={styles.emptyText}>Loading your words...</div>
              </div>
            )}

            {/* Error state */}
            {!loading && loadError && words.length === 0 && (
              <div className={styles.emptyState}>
                <div className={styles.emptyTitle}>Couldn&#39;t load words</div>
                <div className={styles.emptyText}>
                  Check your connection and try again.
                </div>
                <button className={styles.retryBtn} onClick={loadWords}>
                  Try again
                </button>
              </div>
            )}

            {/* Empty state */}
            {!loading && !loadError && words.length === 0 && shimmerCards.length === 0 && (
              <div className={styles.emptyState}>
                <div className={styles.emptyTitle}>No words yet</div>
                <div className={styles.emptyText}>
                  Add your first Korean word below to start building your vocabulary.
                </div>
              </div>
            )}
          </div>
        </div>

        {isMobile ? (
          <AddWordSheet
            open={sheetOpen}
            onOpenChange={(v) => {
              setSheetOpen(v);
              if (!v) { setPendingWord(null); setShimmerWord(''); setAddError(''); }
            }}
            value={inputValue}
            onChange={(v) => { setInputValue(v); setAddError(''); }}
            onSubmit={handleAddWord}
            onConfirm={handleConfirmAdd}
            disabled={adding}
            error={addError}
            shimmerWord={shimmerWord}
            resultWord={pendingWord}
            suggestions={suggestions}
            showSuggestions={showSuggestions}
            onSuggestionSelect={handleSuggestionSelect}
            onSuggestionDismiss={handleSuggestionDismiss}
          />
        ) : (
          <>
            <AddInput
              value={inputValue}
              onChange={(v) => { setInputValue(v); setAddError(''); }}
              onSubmit={handleAddWord}
              disabled={adding}
              error={addError}
            />

            <div className="content-wrap">
              <SuggestionBar
                suggestions={suggestions}
                visible={showSuggestions}
                onSelect={handleSuggestionSelect}
                onDismiss={handleSuggestionDismiss}
              />
            </div>
          </>
        )}
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
            {selectedWord && (() => {
              const morphemes = fixMorphemeKorean(selectedWord.morphemes, selectedWord.korean);
              return (
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
                <MorphemePills morphemes={morphemes} />
                <WordFamily
                  family={selectedWord.family}
                  morphemes={morphemes}
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
              );
            })()}
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
