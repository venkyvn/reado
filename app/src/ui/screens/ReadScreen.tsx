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
 * - FR-05 c.4: buffer − 10 trang GẦN NHẤT của phiên, xoá khi hết phiên
 *   (Q-10 chốt). Phiên sống ở state AppRoot (chết khi F5/đóng tab — đúng
 *   "xoá hết phiên"); các trang xếp cũ → mới, cuộn ngược xem được.
 * - FR-06: summary_vi thu gọn MẶC ĐỊNH (design principle 6 — không phá tự đọc).
 * - FR-09 chống lưu trùng (bug owner báo 2026-09-09): trang ĐÃ lưu vào kho thì
 *   nút "Chọn từ" bị LÀM MỜ + KHOÁ — "Lưu" chỉ xảy ra một lần mỗi trang trong
 *   phiên (AppRoot đánh dấu `savedAt`/`savedCount` ngay khi save xong).
 *
 * Nằm NGOÀI phạm vi bản này (ghi nhận ở MVP_PLAN mục 4): cảnh báo trang sắp
 * trôi khỏi buffer khi chưa chọn từ nào (FR-05 c.5 — task ghi rõ để R2 được).
 */
import { Fragment, useEffect, useMemo, useRef, useState } from "react";
import type { ReactNode } from "react";
import type { CollectionRow } from "../../domain/types";
import type { Screen } from "../AppRoot";
import { buildGlossIndex, glossIndexMap, splitWithGloss } from "../readSegments";
import type { GlossEntry, ReadNode, SessionPage } from "../readSegments";
import { READ_SESSION_MAX } from "../readSegments";
import { useAppEnv } from "../context";

export type { SessionPage } from "../readSegments";
export { READ_SESSION_MAX } from "../readSegments";

export function ReadScreen({ pages, navigate }: {
  pages: SessionPage[];
  navigate: (s: Screen) => void;
}) {
  const { services } = useAppEnv();
  const [showTranslations, setShowTranslations] = useState(true);
  /** key dạng `p{pageIndex}:{matchKey}` — gloss mở 1 cái mỗi lần, không đụng trang khác. */
  const [openGloss, setOpenGloss] = useState<string | null>(null);
  const [collectionNames, setCollectionNames] = useState<Map<string, string>>(new Map());
  /** Neo cuối buffer để auto-cuộn tới trang MỚI NHẤT khi mở màn đọc. */
  const endRef = useRef<HTMLDivElement | null>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ block: "end" });
  }, [pages.length]);

  useEffect(() => {
    let alive = true;
    void services.repos.collections.list().then((list: CollectionRow[]) => {
      if (!alive) setCollectionNames(new Map(list.map((c) => [c.id, c.name])));
    });
    return () => {
      alive = false;
    };
  }, [services]);

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

      {pages.length === 0 ? (
        <p className="muted">Phiên đọc trống — chụp một trang để bắt đầu.</p>
      ) : (
        pages.map((page, pi) => (
          <PageBlock
            key={`p${pi}`}
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
        Phiên giữ {pages.length}/{READ_SESSION_MAX} trang gần nhất — khi F5 hoặc đóng tab là hết phiên,
        buffer xoá. Trang KHÔNG được lưu (NFR-04); từ vựng đi tiếp khi bạn bấm “Chọn từ”.
      </p>
      <div ref={endRef} />
    </div>
  );
}

function PageBlock({ pageIndex, page, collectionName, showTranslations, openGloss, onToggleGloss, navigate }: {
  pageIndex: number;
  page: SessionPage;
  collectionName: string | null;
  showTranslations: boolean;
  openGloss: string | null;
  onToggleGloss: (key: string) => void;
  navigate: (s: Screen) => void;
}) {
  const { analysis } = page;
  const entries = useMemo(() => buildGlossIndex(analysis.vocabulary), [analysis.vocabulary]);
  const glossByKey = useMemo(() => glossIndexMap(entries), [entries]);

  const glossKey = (matchKey: string) => `p${pageIndex}:${matchKey}`;

  return (
    <section className="read-page">
      <header className="read-page-head">
        <span className="read-page-no">
          Trang {pageIndex + 1} {collectionName ? `· ${collectionName}` : ""}
        </span>
        {page.savedCount != null ? (
          <button
            type="button"
            className="read-revise saved"
            disabled
            title="Trang này đã lưu vào kho từ — mở 📚 Kho từ vựng để xem"
          >
            ✅ Đã lưu ({page.savedCount} từ)
          </button>
        ) : (
          <button
            type="button"
            className="read-revise"
            onClick={() =>
              navigate({ name: "vocabEdit", analysis, collectionId: page.collectionId, pageId: page.pageId })
            }
          >
            📝 Chọn từ ({analysis.vocabulary.length}) →
          </button>
        )}
      </header>

      {analysis.summaryVi.trim() !== "" && (
        <details className="read-summary">
          <summary>📌 Tóm tắt trang</summary>
          <p>{analysis.summaryVi}</p>
        </details>
      )}

      {analysis.segments.map((s, si) => (
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