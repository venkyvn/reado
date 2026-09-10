/**
 * ui/screens/CramScreen.tsx — task 3.13: Targeted review — ôn theo chủ đề (tag).
 *
 * Vào từ màn Ôn tập ("🏷️ Ôn theo chủ đề"). Ba giai đoạn:
 *  1. CHỌN TAG: mọi tag trong kho kèm số card (repo listAllTags); chọn 1..n.
 *  2. PHIÊN CRAM: thẻ của các tag đã chọn, KHÔNG lọc due_at, KHÔNG giới hạn
 *     hạn mức thẻ mới. Tương tác giữ NGUYÊN chuẩn vuốt của màn ôn thường
 *     (chốt 2026-09-09): vuốt TRÁI = Easy(4) · vuốt PHẢI = Good(3) · chạm =
 *     lật; mặt sau giữ 4 nút FSRS; undo NỔI một bước.
 *  3. XONG: nói rõ buổi cram KHÔNG đổi lịch ôn dài hạn (D-3).
 *
 * Khác biệt CỐT LÕI so với ReviewScreen: chấm gọi `gradeCram` → chỉ insert
 * review_logs mode='cram' (ảnh chụp TRƯỚC), cards KHÔNG đổi một cột nào; undo
 * chỉ xoá log (không cần restore card — nó chưa từng đổi).
 *
 * Phần gesture copy từ ReviewScreen (task 3.14) — cấu trúc pointer events
 * giữ nguyên để hành vi nhất quán; nếu sửa chuẩn vuốt thì sửa CẢ hai màn.
 */
import { useEffect, useRef, useState } from "react"
import type { CardWithContext, TagCount } from "../../domain/types"
import type { Screen } from "../AppRoot"
import { buildCramSession, gradeCram, listCramTags, undoCram } from "../../domain/usecases/cram"
import { useAppEnv } from "../context"
import { SWIPE_COMMIT_PX, isTap, shouldLockDrag, swipeVerdict, type SwipeVerdict } from "../swipe"

type Rating = "Again" | "Hard" | "Good" | "Easy"

const RATING_OPTIONS: { rating: Rating; label: string; cls: string }[] = [
  { rating: "Again", label: "Lại", cls: "grade-again" },
  { rating: "Hard", label: "Khó", cls: "grade-hard" },
  { rating: "Good", label: "Tốt", cls: "grade-good" },
  { rating: "Easy", label: "Dễ", cls: "grade-easy" },
]

// Trùng màu ReviewScreen: Good = xanh lá, Easy = xanh dương.
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

type Phase = "tags" | "session" | "done"

export function CramScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services } = useAppEnv()
  const [phase, setPhase] = useState<Phase>("tags")
  const [tagCounts, setTagCounts] = useState<TagCount[] | null>(null)
  const [selected, setSelected] = useState<ReadonlySet<string>>(new Set())
  const [loadError, setLoadError] = useState<string | null>(null)

  const [cards, setCards] = useState<CardWithContext[]>([])
  const [index, setIndex] = useState(0)
  const [flipped, setFlipped] = useState(false)
  const [undoLogId, setUndoLogId] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [actionError, setActionError] = useState<string | null>(null)

  const dragRef = useRef<DragState | null>(null)
  const tintRef = useRef<HTMLDivElement | null>(null)
  const badgeRef = useRef<HTMLDivElement | null>(null)
  const commitRef = useRef(false)
  const suppressClickRef = useRef(false)
  const flyTimerRef = useRef<number | null>(null)

  useEffect(() => {
    let alive = true
    listCramTags(services)
      .then((tcs) => {
        if (alive) setTagCounts(tcs)
      })
      .catch((e: unknown) => {
        if (alive) setLoadError(e instanceof Error ? e.message : String(e))
      })
    return () => {
      alive = false
      if (flyTimerRef.current !== null) window.clearTimeout(flyTimerRef.current)
    }
  }, [services])

  function toggleTag(tag: string) {
    setSelected((prev) => {
      const next = new Set(prev)
      if (next.has(tag)) next.delete(tag)
      else next.add(tag)
      return next
    })
  }

  async function startSession() {
    if (selected.size === 0 || busy) return
    setBusy(true)
    setActionError(null)
    try {
      const sessionCards = await buildCramSession(services, [...selected])
      setCards(sessionCards)
      setIndex(0)
      setFlipped(false)
      setUndoLogId(null)
      if (sessionCards.length === 0) setPhase("done")
      else setPhase("session")
    } catch (e) {
      setActionError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(false)
    }
  }

  const current: CardWithContext | null = phase === "session" ? (cards[index] ?? null) : null

  async function grade(rating: Rating) {
    if (!current || busy) return
    setBusy(true)
    setActionError(null)
    try {
      const { log } = await gradeCram(services, { card: current, rating, now: new Date() })
      setUndoLogId(log.id)
      setFlipped(false)
      setIndex((i) => i + 1)
    } catch (err) {
      setActionError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusy(false)
    }
  }

  async function undoOnce() {
    if (!undoLogId || busy) return
    setBusy(true)
    setActionError(null)
    try {
      // Cram: card không đổi nên undo chỉ xoá log; card chấm nhầm quay lại chơi.
      await undoCram(services, undoLogId)
      setUndoLogId(null)
      setFlipped(false)
      setIndex((i) => Math.max(0, i - 1))
    } catch (err) {
      setActionError(err instanceof Error ? err.message : String(err))
    } finally {
      setBusy(false)
    }
  }

  // --- Chuẩn vuốt giống ReviewScreen (3.14): trái = Easy, phải = Good, chạm = lật. ---

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

  function springBack(el: HTMLDivElement) {
    el.style.transition = "transform 180ms ease"
    el.style.transform = "none"
    resetOverlays()
  }

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

  // --- Render: chọn tag ---

  if (phase === "tags") {
    const totalCards = tagCounts ? tagCounts.reduce((acc, t) => acc + t.cardCount, 0) : 0
    return (
      <div className="pad">
        <h1>Ôn theo chủ đề</h1>
        <p className="muted">
          Chọn chủ đề muốn ôn ngay — không phụ thuộc lịch ôn hằng ngày, chấm xong KHÔNG thay đổi
          lịch (chỉ ghi lại thành tích, thẻ vẫn tới đúng ngày của nó).
        </p>

        {loadError && <div className="banner banner-error">{loadError}</div>}
        {actionError && <div className="banner banner-error">{actionError}</div>}

        {tagCounts === null ? (
          <p className="muted">Đang đọc các chủ đề trong kho…</p>
        ) : totalCards === 0 ? (
          <p className="muted">
            Trong kho chưa có tag nào — hãy chụp trang mới (AI sẽ gắn chủ đề) hoặc gắn tag cho từ
            trong Kho từ vựng trước.
          </p>
        ) : (
          <ul className="vocab-list">
            {tagCounts.map((tc) => (
              <li key={tc.tag} className="vocab-card">
                <label className="cram-tag-row">
                  <input
                    type="checkbox"
                    checked={selected.has(tc.tag)}
                    onChange={() => toggleTag(tc.tag)}
                    aria-label={`chọn chủ đề ${tc.tag}`}
                  />
                  <span className="vocab-term">{tc.tag}</span>
                  <span className="fine">{tc.cardCount} thẻ</span>
                </label>
              </li>
            ))}
          </ul>
        )}

        <button
          type="button"
          className="primary"
          disabled={selected.size === 0 || busy || totalCards === 0}
          onClick={() => void startSession()}
        >
          {busy ? "Đang dựng phiên…" : `Bắt đầu ôn (${selected.size} chủ đề)`}
        </button>
        <button type="button" className="secondary" onClick={() => navigate({ name: "review" })}>
          ← Về ôn tập hằng ngày
        </button>
      </div>
    )
  }

  // --- Render: xong phiên ---

  if (phase === "done" || !current) {
    return (
      <div className="pad">
        <h1>Xong buổi ôn theo chủ đề 💪</h1>
        <p className="muted">
          Đã xem hết {cards.length} thẻ. Buổi này KHÔNG đổi lịch ôn dài hạn của thẻ nào — thẻ vẫn
          tới đúng hẹn trong ôn tập hằng ngày.
        </p>
        <button type="button" className="primary" onClick={() => setPhase("tags")}>
          🏷️ Chọn chủ đề khác
        </button>
        <button type="button" className="secondary" onClick={() => navigate({ name: "review" })}>
          ← Về ôn tập hằng ngày
        </button>
      </div>
    )
  }

  // --- Render: phiên cram (giống màn ôn thường, khác usecase chấm) ---

  const remaining = cards.length - index

  return (
    <div className="pad">
      <p className="review-meta">
        Ôn theo chủ đề · còn {remaining}/{cards.length} thẻ · không đổi lịch ôn
      </p>

      {actionError && <div className="banner banner-error">{actionError}</div>}

      {undoLogId && (
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
        aria-label={
          flipped ? "mặt sau thẻ" : "mặt trước thẻ — chạm để lật, vuốt trái: Dễ, vuốt phải: Tốt"
        }
        onClick={() => {
          if (suppressClickRef.current) {
            suppressClickRef.current = false
            return
          }
          if (!flipped && !busy) setFlipped(true)
        }}
        onKeyDown={(e) => {
          if ((e.key === "Enter" || e.key === " ") && !flipped) {
            e.preventDefault()
            setFlipped(true)
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
          if (!shouldLockDrag(dx, dy, d.locked)) return
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
          if (!d.locked) return
          const dx = e.clientX - d.x
          const verdict = swipeVerdict(dx)
          if (!verdict) {
            if (!isTap(dx)) suppressClickRef.current = true
            springBack(d.el)
            return
          }
          commitSwipe(d.el, verdict)
        }}
        onPointerCancel={() => {
          const d = dragRef.current
          if (!d) return
          dragRef.current = null
          if (d.locked) springBack(d.el)
        }}
      >
        {!flipped ? (
          <>
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
              onClick={() => void grade(o.rating)}
            >
              {o.label}
            </button>
          ))}
        </div>
      )}

      <button type="button" className="secondary" onClick={() => setPhase("tags")}>
        ← Đổi chủ đề
      </button>
    </div>
  )
}
