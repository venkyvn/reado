/**
 * ui/screens/ReviewScreen.tsx — FR-11 (hàng đợi hai nhánh, biết còn bao nhiêu
 * card hôm nay, hết thì nói rõ "đã xong" KHÔNG lấp chỗ bằng card chưa tới hạn)
 * + FR-12 (mặt trước CHỈ term + pos; mặt sau meaning_vi + ipa + câu gốc + tên
 * collection; 4 mức chấm; undo MỘT bước khôi phục đúng trạng thái trước chấm).
 *
 * Undo lưu snapshot ĐẦY ĐỦ (CardWithContext trước lúc chấm) trong memory phiên
 * ôn rồi gọi undoGrade — đúng thiết kế solution-design mục 8.2 (log theo
 * research schema không chứa reps/lapses).
 */
import { useEffect, useState } from "react";
import type { CardWithContext } from "../../domain/types";
import type { Screen } from "../AppRoot";
import type { DueQueueResult, UndoInput } from "../../domain/usecases/review";
import { buildDueQueue, gradeCard, undoGrade } from "../../domain/usecases/review";
import { useAppEnv } from "../context";

type Rating = "Again" | "Hard" | "Good" | "Easy";

const RATING_OPTIONS: { rating: Rating; label: string; cls: string }[] = [
  { rating: "Again", label: "Lại", cls: "grade-again" },
  { rating: "Hard", label: "Khó", cls: "grade-hard" },
  { rating: "Good", label: "Tốt", cls: "grade-good" },
  { rating: "Easy", label: "Dễ", cls: "grade-easy" },
];

export function ReviewScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services } = useAppEnv();
  const [queue, setQueue] = useState<DueQueueResult | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [index, setIndex] = useState(0);
  const [flipped, setFlipped] = useState(false);
  const [undo, setUndo] = useState<UndoInput | null>(null);
  const [busy, setBusy] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    buildDueQueue(services, new Date())
      .then((q) => {
        if (!cancelled) setQueue(q);
      })
      .catch((err: unknown) => {
        if (!cancelled) setLoadError(err instanceof Error ? err.message : String(err));
      });
    return () => {
      cancelled = true;
    };
  }, [services]);

  const current: CardWithContext | null = queue?.cards[index] ?? null;
  const remaining = queue ? queue.total - index : 0;

  async function grade(rating: Rating) {
    if (!current || busy) return;
    setBusy(true);
    setActionError(null);
    try {
      // current là ảnh chụp TRƯỚC khi chấm — giữ nguyên object này cho undo.
      const snapshot = current;
      const { log } = await gradeCard(services, { card: current, rating, now: new Date() });
      setUndo({ logId: log.id, restoreCard: snapshot });
      setFlipped(false);
      setIndex((i) => i + 1);
    } catch (err) {
      setActionError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  async function undoOnce() {
    if (!undo || busy) return;
    setBusy(true);
    setActionError(null);
    try {
      await undoGrade(services, { logId: undo.logId, restoreCard: undo.restoreCard });
      setUndo(null);
      setFlipped(false);
      setIndex((i) => Math.max(0, i - 1)); // card vừa chấm nhầm quay lại
    } catch (err) {
      setActionError(err instanceof Error ? err.message : String(err));
    } finally {
      setBusy(false);
    }
  }

  if (loadError) {
    return (
      <div className="pad">
        <h1>Ôn tập</h1>
        <div className="banner banner-error">{loadError}</div>
        <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
          ← Về trang chủ
        </button>
      </div>
    );
  }

  if (!queue) {
    return (
      <div className="pad">
        <h1>Ôn tập</h1>
        <div className="analyzing">
          <div className="spinner" aria-hidden="true" />
          <p className="muted">Đang dựng hàng đợi…</p>
        </div>
      </div>
    );
  }

  if (!current) {
    // Hết phiên — FR-11: nói rõ đã xong, KHÔNG tự lấp card chưa tới hạn.
    return (
      <div className="pad">
        <h1>{queue.total === 0 ? "Hôm nay đã xong 🎉" : "Xong lượt hôm nay 💪"}</h1>
        {queue.total === 0 ? (
          <p className="muted">Chưa có card nào đến hạn — những thẻ chưa tới hạn sẽ tự trở lại đúng ngày của nó.</p>
        ) : (
          <p className="muted">Đã đi qua cả {queue.total} thẻ của ngày {queue.dayLabel}.</p>
        )}
        {queue.deferredNew > 0 && (
          <p className="muted">
            {queue.deferredNew} thẻ MỚI chưa vào lượt này (hạn mức {queue.plan.dailyNewLimit} thẻ
            mới/ngày) — sẽ tới hạn khi có suất.
          </p>
        )}
        <button type="button" className="primary" onClick={() => navigate({ name: "capture" })}>
          📷 Chụp trang nữa
        </button>
        <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
          Về trang chủ
        </button>
      </div>
    );
  }

  return (
    <div className="pad">
      <p className="review-meta">
        {queue.dayLabel} · còn {remaining}/{queue.total} thẻ
        {queue.deferredNew > 0 ? ` · ${queue.deferredNew} thẻ mới hoãn` : ""}
      </p>

      {actionError && <div className="banner banner-error">{actionError}</div>}

      {undo && (
        <button type="button" className="undo-pill" onClick={() => void undoOnce()} disabled={busy}>
          ↩ Hoàn tác lần chấm vừa rồi
        </button>
      )}

      <div
        className={flipped ? "review-card flipped" : "review-card"}
        role="button"
        tabIndex={0}
        aria-label={flipped ? "mặt sau thẻ" : "mặt trước thẻ — chạm để lật"}
        onClick={() => !flipped && setFlipped(true)}
        onKeyDown={(e) => {
          if ((e.key === "Enter" || e.key === " ") && !flipped) {
            e.preventDefault();
            setFlipped(true);
          }
        }}
      >
        {!flipped ? (
          <>
            {/* FR-12 criterion: mặt trước CHỈ có term và pos — không thêm gì khác. */}
            <div className="review-term">{current.term}</div>
            <div className="review-pos">{current.pos}</div>
            <p className="review-flip-hint">chạm để lật</p>
          </>
        ) : (
          <>
            <div className="review-back-head">
              <span className="review-back-term">{current.term}</span>
              <span className="fine">({current.pos})</span>
            </div>
            {current.ipa && <p className="review-ipa">{current.ipa}</p>}
            <p className="review-meaning">{current.meaningVi}</p>
            <div className="review-example">
              <span className="review-label">câu gốc</span>
              <p>{current.example}</p>
            </div>
            <p className="review-collection">
              <span className="review-label">gặp trong</span> {current.collectionName}
            </p>
          </>
        )}
      </div>

      {flipped && (
        <div className="grade-grid">
          {RATING_OPTIONS.map((o) => (
            <button
              key={o.rating}
              type="button"
              className={`grade-btn ${o.cls}`}
              disabled={busy}
              onClick={() => void grade(o.rating)}
            >
              {o.label}
            </button>
          ))}
        </div>
      )}

      <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
        ← Về trang chủ
      </button>
    </div>
  );
}