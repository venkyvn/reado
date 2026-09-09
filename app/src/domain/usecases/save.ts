/**
 * domain/usecases/save.ts — FR-09: item được chọn → vocab_items + card `new`,
 * đến hạn NGAY trong ngày (due_at = now). Một lô = MỘT transaction (trong storage).
 *
 * term_normalized tính ở CLIENT: lowercase + trim, KHÔNG lemmatize (Q-06).
 * ipa rỗng → null (prompt-spec mục 5).
 */
import type { AppServices } from "../services";
import type { AnalyzedItem, CardRow, VocabItemRow } from "../types";
import { newId, toUtcIso } from "../utils";

export interface SaveInput {
  collectionId: string;
  /** Chỉ gồm item đã CHỌN ở màn duyệt (FR-09: mặc định chọn tất cả). */
  items: AnalyzedItem[];
  now: Date;
}

export interface SaveResult {
  saved: number;
  cardIds: string[];
}

export async function saveVocabulary(svc: AppServices, input: SaveInput): Promise<SaveResult> {
  const nowIso = toUtcIso(input.now);
  const vocabRows: VocabItemRow[] = [];
  const cardRows: CardRow[] = [];
  for (const item of input.items) {
    const vocabId = newId();
    vocabRows.push({
      id: vocabId,
      collectionId: input.collectionId,
      term: item.term,
      termNormalized: item.term.toLowerCase().trim(),
      pos: item.pos,
      ipa: item.ipa.trim() === "" ? null : item.ipa,
      meaningVi: item.meaningVi,
      example: item.example,
      cefr: item.cefr,
      // Rich vocab (3.12): thường là AI sinh, user đã có thể sửa ở màn duyệt.
      tags: item.tags,
      synonyms: item.synonyms,
      antonyms: item.antonyms,
      createdAt: nowIso,
    });
    cardRows.push({
      id: newId(),
      vocabItemId: vocabId,
      direction: "receptive",
      state: "new",
      stability: 0,
      difficulty: 0,
      reps: 0,
      lapses: 0,
      learningSteps: 0,
      scheduledDays: 0,
      lastReviewAt: null,
      dueAt: nowIso, // FR-09: đến hạn ngay trong ngày
      suspendedAt: null,
    });
  }
  if (vocabRows.length === 0) return { saved: 0, cardIds: [] };
  await svc.repos.vocabItems.persistCapture(vocabRows, cardRows);
  return { saved: vocabRows.length, cardIds: cardRows.map((c) => c.id) };
}