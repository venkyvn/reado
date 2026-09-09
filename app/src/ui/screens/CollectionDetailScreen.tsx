/**
 * ui/screens/CollectionDetailScreen.tsx — task 3.15 (Q-10-reopen): Chi tiết
 * Collection với 2 tab, đúng cấu trúc owner chốt 2026-09-09:
 *
 * - Tab "Từ vựng": danh sách từ của collection (dùng lại listLibrary với filter
 *   collection — CÙNG nguồn dữ liệu FR-08, không có đường đếm thứ hai).
 * - Tab "Phiên đọc": tối đa 10 phiên gần nhất của collection (created_at DESC,
 *   trim nằm ở repo), mỗi bản ghi là thẻ tóm tắt: thời gian đọc + số từ đã
 *   trích xuất + đoạn summary ngắn + trạng thái đã lưu. Bấm "Mở màn đọc" →
 *   ReadScreen với `sessionId` — phiên đó được bảo đảm hiển thị (kể cả khi đã
 *   trôi khỏi 10 phiên gần nhất toàn cục) và auto-cuộn tới đúng nó.
 *
 * 3.8 (xoá/đổi tên/chuyển từ) CHƯA nằm ở đây — chỉ phần XEM.
 */
import { useEffect, useState } from "react";
import type { CollectionRow, LibraryItemRow, ReadingSessionRow } from "../../domain/types";
import type { Screen } from "../AppRoot";
import { listLibrary } from "../../domain/usecases/library";
import { listCollectionSessions } from "../../domain/usecases/readingSessions";
import { useAppEnv } from "../context";

type Tab = "vocab" | "sessions";

/** "5 phút trước" kiểu thân thiện — đủ dùng, không kéo thư viện. */
function timeAgo(iso: string, now: Date): string {
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return iso;
  const diffMs = Math.max(0, now.getTime() - then);
  const mins = Math.floor(diffMs / 60000);
  if (mins < 1) return "vừa xong";
  if (mins < 60) return `${mins} phút trước`;
  const hours = Math.floor(mins / 60);
  if (hours < 24) return `${hours} giờ trước`;
  const days = Math.floor(hours / 24);
  return `${days} ngày trước`;
}

export function CollectionDetailScreen({ collectionId, navigate }: {
  collectionId: string;
  navigate: (s: Screen) => void;
}) {
  const { services } = useAppEnv();
  const [tab, setTab] = useState<Tab>("sessions");
  const [collection, setCollection] = useState<CollectionRow | null>(null);
  const [vocab, setVocab] = useState<LibraryItemRow[] | null>(null);
  const [sessions, setSessions] = useState<ReadingSessionRow[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    void services.repos.collections.list().then((list) => {
      if (alive) setCollection(list.find((c) => c.id === collectionId) ?? null);
    });
    void listLibrary(services, { collectionId, cefr: null, state: null })
      .then((rows) => {
        if (alive) setVocab(rows);
      })
      .catch((e: unknown) => {
        if (alive) setError(e instanceof Error ? e.message : String(e));
      });
    void listCollectionSessions(services, collectionId)
      .then((rows) => {
        if (alive) setSessions(rows);
      })
      .catch((e: unknown) => {
        if (alive) setError(e instanceof Error ? e.message : String(e));
      });
    return () => {
      alive = false;
    };
  }, [services, collectionId]);

  const now = new Date();

  return (
    <div className="pad collection-detail">
      <p className="fine">
        <a
          href="#home"
          onClick={() => navigate({ name: "home" })}
        >
          ← Trang chủ
        </a>
      </p>
      <h1>{collection ? `${collection.isDefault ? "📥" : "📖"} ${collection.name}` : "Collection"}</h1>

      <div className="btn-row" role="tablist" aria-label="Tab collection">
        <button
          type="button"
          className={tab === "sessions" ? "primary" : "secondary"}
          role="tab"
          aria-selected={tab === "sessions"}
          onClick={() => setTab("sessions")}
        >
          📖 Phiên đọc{sessions ? ` (${sessions.length})` : ""}
        </button>
        <button
          type="button"
          className={tab === "vocab" ? "primary" : "secondary"}
          role="tab"
          aria-selected={tab === "vocab"}
          onClick={() => setTab("vocab")}
        >
          📚 Từ vựng{vocab ? ` (${vocab.length})` : ""}
        </button>
      </div>

      {error && <div className="errorbox">Lỗi đọc dữ liệu — {error}</div>}

      {tab === "sessions" && (
        <section>
          {sessions === null ? (
            <p className="muted">Đang đọc phiên…</p>
          ) : sessions.length === 0 ? (
            <p className="muted">
              Collection này chưa có phiên đọc nào — chụp trang và chọn collection này để bắt đầu.
            </p>
          ) : (
            sessions.map((s) => (
              <article key={s.id} className="read-page session-card">
                <header className="read-page-head">
                  <span className="read-page-no">{timeAgo(s.createdAt, now)}</span>
                  {s.savedAt != null ? (
                    <span className="chip chip-verified">✅ Đã lưu ({s.savedCount} từ)</span>
                  ) : (
                    <span className="chip">chưa lưu từ</span>
                  )}
                </header>
                {s.summaryVi.trim() !== "" && (
                  <p className="vocab-meaning">{s.summaryVi}</p>
                )}
                <p className="fine">{s.vocabCount} từ được trích xuất · {s.segments.length} đoạn</p>
                <button
                  type="button"
                  className="secondary"
                  onClick={() => navigate({ name: "readSession", sessionId: s.id })}
                >
                  👁 Mở màn đọc
                </button>
              </article>
            ))
          )}
          <p className="hint">Tối đa 10 phiên gần nhất mỗi collection — phiên cũ nhất tự trôi khi có trang mới. Ảnh trang không lưu, chỉ text + dịch.</p>
        </section>
      )}

      {tab === "vocab" && (
        <section className="vocab-list">
          {vocab === null ? (
            <p className="muted">Đang đọc kho từ…</p>
          ) : vocab.length === 0 ? (
            <p className="muted">Collection này chưa có từ nào.</p>
          ) : (
            vocab.map((item) => (
              <article key={item.id} className="vocab-card">
                <div className="vocab-head">
                  <span className="vocab-term">{item.term}</span>
                  <span className="fine">{item.pos}</span>
                </div>
                <p className="vocab-meaning">{item.meaningVi}</p>
              </article>
            ))
          )}
        </section>
      )}
    </div>
  );
}
