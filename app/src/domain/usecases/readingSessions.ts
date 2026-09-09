/**
 * domain/usecases/readingSessions.ts — task 3.15 (Q-10-reopen): kho phiên đọc
 * bền theo collection.
 *
 * - `persistReadingSession` — gọi NGAY SAU một lần phân tích thành công (cùng
 *   lúc với `recordAnalyzedPage`, chung `analysisId`): tự ghi, KHÔNG cần user
 *   bấm gì. Đúng triết lý "AI sinh kèm capture" của rich vocab — dữ liệu nằm
 *   sẵn, user chỉ thu hoạch.
 * - `listRecentReadingSessions` — nguồn của màn đọc (thay buffer in-memory):
 *   mới nhất trước, mọi collection, tối đa `limit` (màn đọc dùng 10).
 * - `listCollectionSessions` — tab "Phiên đọc" của Collection Detail View.
 * - `markReadingSessionSaved` — persist luật "lưu 1 lần" (bug 6723302): trước
 *   đây cờ chết theo phiên nên mở lại app mất cờ; giờ nằm trong DB.
 *
 * Không có usecase xoá riêng: trim chạy trong repo.insert; xoá collection là
 * cascade (task 3.8 sẽ nối vào).
 */
import type { AnalysisResult, ReadingSessionRow } from "../types";
import type { AppServices } from "../services";
import { toUtcIso } from "../utils";

/** Màn đọc hiện tối đa bao nhiêu phiên gần nhất (Q-10-reopen: 10/collection —
 *  cross-collection thì limit này chỉ là mặt cắt hiển thị). */
export const READ_SCREEN_SESSIONS = 10;

export async function persistReadingSession(
  svc: AppServices,
  analysisId: string,
  collectionId: string,
  result: AnalysisResult,
): Promise<void> {
  const row: ReadingSessionRow = {
    id: analysisId,
    collectionId,
    segments: result.segments,
    // Vocabulary nguyên vẹn: gloss tô từ ở màn đọc + "Chọn từ" của trang CHƯA
    // lưu cần nó. Có thể stale sau khi user sửa — chấp nhận, xem migration v4.
    vocabulary: result.vocabulary,
    summaryVi: result.summaryVi,
    vocabCount: result.vocabulary.length,
    createdAt: toUtcIso(svc.now()),
    savedAt: null,
    savedCount: 0,
  };
  await svc.repos.readingSessions.insert(row);
}

export async function listRecentReadingSessions(
  svc: AppServices,
  limit: number = READ_SCREEN_SESSIONS,
): Promise<ReadingSessionRow[]> {
  return svc.repos.readingSessions.listRecent(limit);
}

export async function listCollectionSessions(
  svc: AppServices,
  collectionId: string,
): Promise<ReadingSessionRow[]> {
  return svc.repos.readingSessions.listByCollection(collectionId);
}

export async function getReadingSession(
  svc: AppServices,
  id: string,
): Promise<ReadingSessionRow | null> {
  return svc.repos.readingSessions.getById(id);
}

export async function markReadingSessionSaved(
  svc: AppServices,
  id: string,
  savedCount: number,
): Promise<void> {
  await svc.repos.readingSessions.markSaved(id, toUtcIso(svc.now()), savedCount);
}
