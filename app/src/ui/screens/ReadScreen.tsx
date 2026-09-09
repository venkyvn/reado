/**
 * ui/screens/ReadScreen.tsx — FR-05 Bilingual Parallel Reading View + FR-06
 * Page Summary (task 3.3 — trước đây chưa build, owner báo thiếu 2026-09-09).
 *
 * Hợp đồng hiển thị:
 * - UI-1 chốt 2026-09-08: XEN KẼ theo đoạn — source_en rồi translation_vi
 *   ngay dưới từng đoạn, đúng thứ tự gốc, 0 thao tác thêm (bản dịch mặc định
 *   HIỆN).
 * - FR-05 c.2: nút MỘT chạm ẩn/hiện TOÀN BỘ bản dịch trên mọi trang của phiên.
 * - FR-05 c.3: từ vựng của trang xuất hiện trong đoạn được tô nền; chạm →
 *   nghĩa + IPA hiện NGAY TẠI CHỖ (inline) — xem readSegments.ts.
 * - FR-05 c.4 (Q-10-reopen, task 3.15): phiên đọc là dữ liệu BỀN trong bảng
 *   `reading_sessions` — 10 phiên mới nhất mỗi collection, mở lại app vẫn còn.
 *   Màn này chỉ là mặt cắt: 10 phiên gần nhất MỌI collection (cũ → mới); xem
 *   đầy đủ theo collection ở Collection Detail View.
 * - FR-06: summary_vi thu gọn MẶC ĐỊNH (design principle 6 — không phá tự đọc).
 * - FR-09 chống lưu trùng (bug owner báo 2026-09-09): trang ĐÃ lưu vào kho thì
 *   nút "Chọn từ" bị LÀM MỜ + KHOÁ — "Lưu" chỉ xảy ra một lần mỗi trang. Cờ
 *   `saved_at`/`saved_count` PERSIST trong `reading_sessions` (task 3.15) nên
 *   khoá vẫn đúng cả sau khi F5/mở lại app.
 *
 * Nằm NGOÀI phạm vi bản này (ghi nhận ở MVP_PLAN mục 4): cảnh báo trang sắp
 * trôi khỏi buffer khi chưa chọn từ nào (FR-05 c.5 — task ghi rõ để R2 được).
 */
import { Fragment, useEffect, useMemo, useRef, useState } from "react";
import type { ReactNode } from "react";
import type { CollectionRow, ReadingSessionRow } from "../../domain/types";
import type { Screen } from "../AppRoot";
import { analysisFromSession, buildGlossIndex, glossIndexMap, splitWithGloss } from "../readSegments";
import type { GlossEntry, ReadNode } from "../readSegments";
import { getReadingSession, listRecentReadingSessions, READ_SCREEN_SESSIONS } from "../../domain/usecases/readingSessions";
import { useAppEnv } from "../context";

export function ReadScreen({ navigate, sessionId }: {
  navigate: (s: Screen) => void;
  /** sessionId = phiên bấm "Mở màn đọc" ở Collection Detail — bảo đảm phiên đó
   *  hiện ra kể cả khi đã trôi khỏi 10 phiên gần nhất TOÀN CỤC (màn này chỉ
   *  liệt kê 10 cái), và auto-cuộn tới đúng nó. Undefined = mở thường từ
   *  Home/Capture: liệt kê 10 phiên gần nhất mọi collection. */
  sessionId?: string;
}) {
  const { services } = useAppEnv();
  // Nguồn duy nhất là DB (task 3.15): mới nhất TRƯỚC từ query, hiển thị cũ → mới.
  const [pages, setPages] = useState<ReadingSessionRow[] | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [showTranslations, setShowTranslations] = useState(true);
  /** key dạng `p{pageIndex}:{matchKey}` — gloss mở 1 cái mỗi lần, không đụng trang khác. */
  const [openGloss, setOpenGloss] = useState<string | null>(null);
  const [collectionNames, setCollectionNames] = useState<Map<string, string>>(new Map());
  /** Neo cuối dãy để auto-cuộn tới trang MỚI NHẤT khi mở màn đọc thường. */
  const endRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    let alive = true;
    void (async () => {
      const rows = await listRecentReadingSessions(services, READ_SCREEN_SESSIONS);
      if (!alive) return;
      let list = rows;
      // Phiên được yêu cầu riêng mà đã trôi khỏi 10 phiên gần nhất toàn cục:
      // kéo thêm nó vào (sau reverse nó nằm đầu dãy cũ → mới, đúng "phiên cũ").
      if (sessionId && !rows.some((r) => r.id === sessionId)) {
        const focus = await getReadingSession(services, sessionId);
        if (focus) list = [...rows, focus];
      }
      setPages([...list].reverse()); // cũ → mới cho thứ tự đọc
    })().catch((e: unknown) => {
      if (alive) setLoadError(e instanceof Error ? e.message : String(e));
    });
    void services.repos.collections.list().then((list: CollectionRow[]) => {
      if (alive) setCollectionNames(new Map(list.map((c) => [c.id, c.name])));
    });
    return () => {
      alive = false;
    };
  }, [services, sessionId]);

  useEffect(() => {
    if (pages === null) return;
    if (sessionId) {
      document.getElementById(`session-${sessionId}`)?.scrollIntoView({ block: "start" });
    } else {
      endRef.current?.scrollIntoView({ block: "end" });
    }
  }, [pages, sessionId]);

  return (
    <div className="pad read-screen">
      <h1>Đọc trang</h1>
      <p className="muted">
        Song ngữ xen kẽ theo đoạn · chạm từ tô vàng để xem nghĩa ngay tại chỗ.
      </p>

      <button
        type="button"
        className="secondary toggle"
        onClick={() => setShowTranslations((v) => !v)}
        aria-pressed={showTranslations}
      >
        {showTranslations ? "🙈 Ẩn toàn bộ bản dịch" : "👁 Hiện toàn bộ bản dịch"}
      </button>

      {loadError && <div className="errorbox">Không đọc được phiên đọc — {loadError}</div>}
      {pages === null ? (
        !loadError && <p className="muted">Đang đọc phiên…</p>
      ) : pages.length === 0 ? (
        <p className="muted">Chưa có trang nào — chụp một trang để bắt đầu.</p>
      ) : (
        pages.map((page, pi) => (
          <PageBlock
            key={page.id}
            pageIndex={pi}
            page={page}
            collectionName={collectionNames.get(page.collectionId) ?? null}
            showTranslations={showTranslations}
            openGloss={openGloss}
            onToggleGloss={(k) => setOpenGloss((cur) => (cur === k ? null : k))}
            navigate={navigate}
          />
        ))
      )}

      <div className="btn-row">
        <button type="button" className="primary" onClick={() => navigate({ name: "capture" })}>
          📷 Chụp trang kế
        </button>
        <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
          ← Về trang chủ
        </button>
      </div>

      <p className="hint">
        {pages === null ? "" : `Đang hiện ${pages.length} phiên đọc gần nhất — mỗi collection giữ tối đa ${READ_SCREEN_SESSIONS} phiên, cũ nhất tự trôi khi có trang mới. Ảnh trang không lưu; chỉ text + dịch.`}
      </p>
      <div ref={endRef} />
    </div>
  );
}

function PageBlock({ pageIndex, page, collectionName, showTranslations, openGloss, onToggleGloss, navigate }: {
  pageIndex: number;
  page: ReadingSessionRow;
  collectionName: string | null;
  showTranslations: boolean;
  openGloss: string | null;
  onToggleGloss: (key: string) => void;
  navigate: (s: Screen) => void;
}) {
  const entries = useMemo(() => buildGlossIndex(page.vocabulary), [page.vocabulary]);
  const glossByKey = useMemo(() => glossIndexMap(entries), [entries]);

  const glossKey = (matchKey: string) => `p${pageIndex}:${matchKey}`;
  const savedAt = page.savedAt;
  const savedCount = page.savedCount;

  return (
    <section className="read-page" id={`session-${page.id}`}>
      <header className="read-page-head">
        <span className="read-page-no">
          Trang {pageIndex + 1} {collectionName ? `· ${collectionName}` : ""}
        </span>
        {savedAt != null ? (
          <button
            type="button"
            className="read-revise saved"
            disabled
            title="Trang này đã lưu vào kho từ — mở 📚 Kho từ vựng để xem"
          >
            ✅ Đã lưu ({savedCount} từ)
          </button>
        ) : (
          <button
            type="button"
            className="read-revise"
            onClick={() =>
              navigate({
                name: "vocabEdit",
                analysis: analysisFromSession(page),
                collectionId: page.collectionId,
                pageId: page.id,
              })
            }
          >
            📝 Chọn từ ({page.vocabCount}) →
          </button>
        )}
      </header>

      {page.summaryVi.trim() !== "" && (
        <details className="read-summary">
          <summary>📌 Tóm tắt trang</summary>
          <p>{page.summaryVi}</p>
        </details>
      )}

      {page.segments.map((s, si) => (
        <SegmentBlock
          key={si}
          sourceEn={s.sourceEn}
          translationVi={s.translationVi}
          entries={entries}
          showTranslations={showTranslations}
        >
          {(node) => <SegNode node={node} gloss={openGloss === glossKey(node.matchKey)} onTap={() => onToggleGloss(glossKey(node.matchKey))} glossOf={glossByKey.get(node.matchKey)} />}
        </SegmentBlock>
      ))}
    </section>
  );
}

function SegmentBlock({ sourceEn, translationVi, entries, showTranslations, children }: {
  sourceEn: string;
  translationVi: string;
  entries: GlossEntry[];
  showTranslations: boolean;
  children: (node: ReadNode & { matchKey: string }) => ReactNode;
}) {
  const nodes = useMemo(() => splitWithGloss(sourceEn, entries), [sourceEn, entries]);
  return (
    <div className="seg">
      <p className="seg-src">
        {nodes.map((n, i) =>
          n.kind === "vocab" ? (
            <Fragment key={`v${i}`}>{children({ ...n, matchKey: n.matchKey })}</Fragment>
          ) : (
            <span key={`t${i}`}>{n.text}</span>
          ),
        )}
      </p>
      {showTranslations && translationVi.trim() !== "" && <p className="seg-tr">{translationVi}</p>}
    </div>
  );
}

function SegNode({ node, gloss, onTap, glossOf }: {
  node: ReadNode & { matchKey: string };
  gloss: boolean;
  onTap: () => void;
  glossOf: GlossEntry | undefined;
}) {
  return (
    <span className="seg-vocabwrap">
      <button type="button" className="seg-vocab" onClick={onTap}>
        {node.text}
      </button>
      {gloss && glossOf && (
        <span className="seg-gloss">
          {glossOf.term} · {glossOf.ipa || "—"} · {glossOf.meaningVi}
        </span>
      )}
    </span>
  );
}