/**
 * ui/screens/ReviewScreen.tsx — FR-11 (hàng đợi hai nhánh, biết còn bao nhiêu
 * card hôm nay, hết thì nói rõ "đã xong" KHÔNG lấp chỗ bằng card chưa tới hạn)
 * + FR-12 (mặt trước CHỈ term + pos; mặt sau meaning_vi + ipa + câu gốc + tên
 * collection; 4 mức chấm; undo MỘT bước khôi phục đúng trạng thái trước chấm).
 *
 * Chuẩn vuốt (chủ chốt 2026-09-09): quẹt TRÁI = Easy (4) · quẹt PHẢI = Good (3)
 * · chạm = lật. Vuốt đi thẳng qua gradeCard — FSRS nhận đúng điểm, log vẫn là
 * ảnh chụp TRƯỚC khi chấm, nút Undo nổi kéo thẻ về snapshot y như nút bấm.
 * Toàn bộ luật chấm/vuốt nằm trong ui/swipe.ts (hàm thuần, có test máy).
 *
 * Undo lưu snapshot ĐẦY ĐỦ (CardWithContext trước lúc chấm) trong memory phiên
 * ôn rồi gọi undoGrade — đúng thiết kế solution-design mục 8.2 (log theo
 * research schema không chứa reps/lapses).
 */
import { useEffect, useRef, useState } from "react"
import type { CardWithContext } from "../../domain/types"
import type { Screen } from "../AppRoot"
import type { DueQueueResult, UndoInput } from "../../domain/usecases/review"
import { buildDueQueue, gradeCard, undoGrade } from "../../domain/usecases/review"
import { useAppEnv } from "../context"
import { SWIPE_COMMIT_PX, isTap, shouldLockDrag, swipeVerdict, type SwipeVerdict } from "../swipe"

type Rating = "Again" | "Hard" | "Good" | "Easy"

// kbd: phím tắt bàn phím (ADR-022) — 1 Lại, 2 Khó, 3 Tốt, 4 Dễ.
const RATING_OPTIONS: { rating: Rating; label: string; cls: string; kbd: string }[] = [
  { rating: "Again", label: "Lại", cls: "grade-again", kbd: "1" },
  { rating: "Hard", label: "Khó", cls: "grade-hard", kbd: "2" },
  { rating: "Good", label: "Tốt", cls: "grade-good", kbd: "3" },
  { rating: "Easy", label: "Dễ", cls: "grade-easy", kbd: "4" },
]

// Màu kéo theo ĐÚNG màu nút chấm trong index.css: Good = xanh lá, Easy = xanh dương.
const EASY_BG = "#dbeafe"
const EASY_INK = "#1e40af"
const GOOD_BG = "#dcfce7"
const GOOD_INK = "#166534"

interface DragState {
  x: number
  y: number
  pointerId: number
  locked: boolean
  el: HTMLDivElement
}

export function ReviewScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services } = useAppEnv()
  const [queue, setQueue] = useState<DueQueueResult | null>(null)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [index, setIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [undo, setUndo] = useState<UndoInput | null>(null)
  const [busy, setBusy] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)

  // Trạng thái kéo chỉ sống trong ref — pointermove 60Hz không đụng React render.
  const dragRef = useRef<DragState | null>(null)
  const tintRef = useRef<HTMLDivElement | null>(null)
  const badgeRef = useRef<HTMLDivElement | null>(null)
  const commitRef = useRef(false) // đang bay ra + chờ grade — chặn input chồng lấn
  const suppressClickRef = useRef(false) // vuốt xong chặn sự kiện click lật nhầm
  const flyTimerRef = useRef<number | null>(null)

  useEffect(() => {
    let cancelled = false
    buildDueQueue(services, new Date())
      .then((q) => {
        if (!cancelled) setQueue(q)
      })
      .catch((err: unknown) => {
        if (!cancelled) setLoadError(err instanceof Error ? err.message : String(err))
      })
    return () => {
      cancelled = true
      if (flyTimerRef.current !== null) window.clearTimeout(flyTimerRef.current)
    }
  }, [services])

  const current: CardWithContext | null = queue?.cards[index] ?? null
  const remaining = queue ? queue.total - index : 0

  async function grade(rating: Rating) {
    if (!current || busy) return
    setBusy(true)
    setActionError(null)
    try {
      // current là ảnh chụp TRƯỚC khi chấm — giữ nguyên object này cho undo.
      const snapshot = current
      const { log } = await gradeCard(services, { card: current, rating, now: new Date() })
      setUndo({ logId: log.id, restoreCard: snapshot })
      setFlipped(false)
      setIndex((i) => i + 1)
    } catch (err) {
      setActionError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusy(false)
    }
  }

  async function undoOnce() {
    if (!undo || busy) return
    setBusy(true)
    setActionError(null)
    try {
      await undoGrade(services, { logId: undo.logId, restoreCard: undo.restoreCard })
      setUndo(null)
      setFlipped(false)
      setIndex((i) => Math.max(0, i - 1)) // card vừa chấm nhầm quay lại
    } catch (err) {
      setActionError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusy(false)
    }
  }

  // --- Chuẩn vuốt mặt trước: trái = Easy, phải = Good, chạm = lật. ---

  function paintDirection(dx: number) {
    const easy = dx < 0
    const bg = easy ? EASY_BG : GOOD_BG
    if (tintRef.current) tintRef.current.style.background = bg
    if (badgeRef.current) {
      badgeRef.current.textContent = easy ? "Dễ" : "Tốt"
      badgeRef.current.style.background = bg
      badgeRef.current.style.color = easy ? EASY_INK : GOOD_INK
    }
  }

  function resetOverlays() {
    if (tintRef.current) tintRef.current.style.opacity = "0"
    if (badgeRef.current) badgeRef.current.style.opacity = "0"
  }

  /** Nhả tay dưới ngưỡng → thẻ bật về chỗ cũ, không chấm (an toàn cho lỡ tay). */
  function springBack(el: HTMLDivElement) {
    el.style.transition = "transform 180ms ease"
    el.style.transform = "none"
    resetOverlays()
  }

  /** Qua ngưỡng → thẻ bay ra rồi mới gọi grade qua đúng pipeline sẵn có. */
  function commitSwipe(el: HTMLDivElement, verdict: SwipeVerdict) {
    suppressClickRef.current = true
    commitRef.current = true
    const dir = verdict === "easy" ? -1 : 1
    el.style.transition = "transform 200ms ease, opacity 200ms ease"
    el.style.transform = `translateX(${dir * 120}%) rotate(${dir * 15}deg)`
    el.style.opacity = "0.4"
    if (tintRef.current) tintRef.current.style.opacity = "0.9"
    flyTimerRef.current = window.setTimeout(() => {
      commitRef.current = false
      void grade(verdict === "easy" ? "Easy" : "Good")
    }, 190)
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
    )
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
    )
  }

  if (!current) {
    // Hết phiên — FR-11: nói rõ đã xong, KHÔNG tự lấp card chưa tới hạn.
    return (
      <div className="pad">
        <h1>{queue.total === 0 ? "Hôm nay đã xong 🎉" : "Xong lượt hôm nay 💪"}</h1>
        {queue.total === 0 ? (
          <p className="muted">
            Chưa có card nào đến hạn — những thẻ chưa tới hạn sẽ tự trở lại đúng ngày của nó.
          </p>
        ) : (
          <p className="muted">
            Đã đi qua cả {queue.total} thẻ của ngày {queue.dayLabel}.
          </p>
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
        <button type="button" className="secondary" onClick={() => navigate({ name: "cram" })}>
          🏷️ Ôn theo chủ đề
        </button>
        <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
          Về trang chủ
        </button>
      </div>
    )
  }

  return (
    <div className="pad">
      <p className="review-meta" aria-live="polite">
        {queue.dayLabel} · còn {remaining}/{queue.total} thẻ
        {queue.deferredNew > 0 ? ` · ${queue.deferredNew} thẻ mới hoãn` : ""}
      </p>

      {actionError && <div className="banner banner-error">{actionError}</div>}

      {/* Nút Undo NỔI (chủ chốt 2026-09-09): nằm trên màn hình, không chiếm dòng
          layout — kéo thẻ vừa chấm (kể cả chấm bằng vuốt) về snapshot 100%. */}
      {undo && (
        <button
          type="button"
          className="undo-pill"
          style={{
            position: "fixed",
            left: "50%",
            bottom: 92,
            transform: "translateX(-50%)",
            margin: 0,
            zIndex: 40,
            background: "var(--card)",
            boxShadow: "0 8px 24px rgba(15, 23, 42, 0.25)",
          }}
          onClick={() => void undoOnce()}
          disabled={busy}
        >
          ↩ Hoàn tác lần chấm vừa rồi
        </button>
      )}

      <div
        key={current.id}
        className={flipped ? "review-card flipped" : "review-card"}
        style={{ position: "relative", overflow: "hidden", touchAction: "pan-y" }}
        role="button"
        tabIndex={0}
        aria-keyshortcuts="Space Enter"
        aria-label={
          flipped
            ? "mặt sau thẻ — bàn phím: 1 Lại, 2 Khó, 3 Tốt, 4 Dễ"
            : "mặt trước thẻ — Space/Enter để lật, vuốt trái: Dễ, vuốt phải: Tốt"
        }
        onClick={() => {
          if (suppressClickRef.current) {
            suppressClickRef.current = false
            return
          }
          if (!flipped && !busy) setFlipped(true)
        }}
        onKeyDown={(e) => {
          if (!flipped) {
            if (e.key === "Enter" || e.key === " ") {
              e.preventDefault()
              setFlipped(true)
            }
            return
          }
          // Mặt sau: chấm bằng bàn phím (ADR-022) — số 1-4 + mũi tên theo đúng
          // chuẩn vuốt (trái = Dễ/Easy, phải = Tốt/Good).
          if (busy) return
          const r: Rating | undefined = (
            {
              "1": "Again",
              "2": "Hard",
              "3": "Good",
              "4": "Easy",
              ArrowLeft: "Easy",
              ArrowRight: "Good",
            } as Record<string, Rating>
          )[e.key]
          if (r) {
            e.preventDefault()
            void grade(r)
          }
        }}
        onPointerDown={(e) => {
          if (flipped || busy || commitRef.current) return
          if (e.pointerType === "mouse" && e.button !== 0) return
          if (!e.isPrimary) return
          const el = e.currentTarget
          el.setPointerCapture(e.pointerId)
          dragRef.current = {
            x: e.clientX,
            y: e.clientY,
            pointerId: e.pointerId,
            locked: false,
            el,
          }
          suppressClickRef.current = false
        }}
        onPointerMove={(e) => {
          const d = dragRef.current
          if (!d || d.pointerId !== e.pointerId) return
          const dx = e.clientX - d.x
          const dy = e.clientY - d.y
          if (!shouldLockDrag(dx, dy, d.locked)) return // ngón lăn dọc → để trang cuộn
          if (!d.locked) {
            d.locked = true
            paintDirection(dx)
          }
          const intensity = Math.min(1, Math.abs(dx) / SWIPE_COMMIT_PX)
          d.el.style.transition = "none"
          d.el.style.transform = `translateX(${dx}px) rotate(${dx * 0.05}deg)`
          if (tintRef.current) tintRef.current.style.opacity = String(0.75 * intensity)
          if (badgeRef.current) badgeRef.current.style.opacity = String(intensity)
        }}
        onPointerUp={(e) => {
          const d = dragRef.current
          if (!d || d.pointerId !== e.pointerId) return
          dragRef.current = null
          if (!d.locked) return // chưa thành cú kéo — để click xử lý tap/lật
          const dx = e.clientX - d.x
          const verdict = swipeVerdict(dx)
          if (!verdict) {
            if (!isTap(dx)) suppressClickRef.current = true // kéo chơi → không lật nhầm
            springBack(d.el)
            return
          }
          commitSwipe(d.el, verdict)
        }}
        onPointerCancel={() => {
          const d = dragRef.current
          if (!d) return
          dragRef.current = null
          if (d.locked) springBack(d.el) // trình duyệt giành gesture (cuộn) → trả thẻ về
        }}
      >
        {!flipped ? (
          <>
            {/* Lớp phủ hướng kéo — chỉ hiện khi đang kéo, không phải nội dung thẻ
                (FR-12: mặt trước vẫn CHỈ term + pos). */}
            <div
              ref={tintRef}
              aria-hidden="true"
              style={{
                position: "absolute",
                inset: 0,
                background: "transparent",
                opacity: 0,
                transition: "opacity 130ms",
                pointerEvents: "none",
              }}
            />
            <div
              ref={badgeRef}
              aria-hidden="true"
              style={{
                position: "absolute",
                top: 12,
                left: "50%",
                transform: "translateX(-50%)",
                opacity: 0,
                transition: "opacity 130ms",
                padding: "4px 16px",
                borderRadius: 999,
                fontSize: 15,
                fontWeight: 700,
                whiteSpace: "nowrap",
                pointerEvents: "none",
              }}
            />
            <div className="review-term">{current.term}</div>
            <div className="review-pos">{current.pos}</div>
            <p className="review-flip-hint">vuốt ◀: Dễ · vuốt ▶: Tốt · chạm: lật</p>
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
            {/* Khối "Mở rộng" (3.12, RV-4: BẬT mặc định) — bổ trợ, KHÔNG sinh
                thẻ, KHÔNG bắt học. Chỉ hiện khi item có dữ liệu (mặt trước vẫn
                nguyên vẹn FR-12: chỉ term + pos). */}
            {(current.tags.length > 0 ||
              current.synonyms.length > 0 ||
              current.antonyms.length > 0) && (
              <div className="review-extras">
                {current.tags.length > 0 && (
                  <div className="chip-row">
                    {current.tags.map((t) => (
                      <span key={t} className="chip chip-tag">
                        {t}
                      </span>
                    ))}
                  </div>
                )}
                {current.synonyms.length > 0 && (
                  <p className="review-extra-line">
                    <span className="review-label">đồng nghĩa</span> {current.synonyms.join(" · ")}
                  </p>
                )}
                {current.antonyms.length > 0 && (
                  <p className="review-extra-line">
                    <span className="review-label">trái nghĩa</span> {current.antonyms.join(" · ")}
                  </p>
                )}
              </div>
            )}
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
              aria-keyshortcuts={o.kbd}
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
      <p style={{ textAlign: "center" }}>
        <a className="dim" href="#cram" onClick={() => navigate({ name: "cram" })}>
          🏷️ Ôn theo chủ đề (không đổi lịch ôn)
        </a>
      </p>
    </div>
  )
}
