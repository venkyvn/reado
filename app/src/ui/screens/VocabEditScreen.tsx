/**
 * ui/screens/VocabEditScreen.tsx — FR-03 (duyệt & sửa trước khi lưu) + FR-09
 * (chọn item thành review card) + phần FR-02 (item unverified đánh dấu rõ,
 * KHÔNG chọn sẵn; không item nào bị loại im lặng).
 *
 * Thiết kế theo UI-2 (owner chốt 2026-09-08): card RÚT GỌN (term + pos +
 * nghĩa tắt + chip + checkbox), chạm mở INLINE 6 field; unverified XẾP LÊN
 * ĐẦU danh sách + đánh dấu đỏ. Mặc định chọn TẤT CẢ trừ unverified (FR-02) —
 * bỏ chọn = item KHÔNG được lưu (FR-03 loại item; FR-09 bỏ item đã biết).
 *
 * Nghĩa của `verification` SAU phân tích chỉ còn là chip hiển thị — save không
 * đọc nó; item chỉnh tay không tự đổi nhãn (v0.3 PRD không có criterion đó).
 */
import { useEffect, useState } from "react";
import type { ReactNode } from "react";
import type { AnalysisResult, AnalyzedItem, Cefr, CollectionRow, Pos } from "../../domain/types";
import { CEFR_VALUES, POS_VALUES } from "../../domain/types";
import type { Screen } from "../AppRoot";
import { saveVocabulary } from "../../domain/usecases/save";
import type { SaveResult } from "../../domain/usecases/save";
import { useAppEnv } from "../context";

interface EditableItem {
  /** key ổn định theo vị trí GỐC trong analysis.vocabulary (trước khi sort). */
  key: string;
  item: AnalyzedItem;
  selected: boolean;
  expanded: boolean;
}

const RANK: Record<AnalyzedItem["verification"], number> = {
  unverified: 0,
  suspect: 1,
  verified: 2,
};

const CHIP_LABEL: Record<AnalyzedItem["verification"], string> = {
  verified: "✓ xác minh",
  suspect: "nghi vấn",
  unverified: "chưa xác minh",
};

function initialState(analysis: AnalysisResult): EditableItem[] {
  return analysis.vocabulary
    .map((item, i) => ({
      key: `i${i}`,
      item,
      selected: item.verification !== "unverified",
      expanded: false,
    }))
    .sort((a, b) => RANK[a.item.verification] - RANK[b.item.verification]);
}

export function VocabEditScreen({ analysis, collectionId, navigate }: {
  analysis: AnalysisResult;
  collectionId: string;
  navigate: (s: Screen) => void;
}) {
  const { services } = useAppEnv();
  const [items, setItems] = useState<EditableItem[]>(() => initialState(analysis));
  const [collectionName, setCollectionName] = useState<string | null>(null);
  const [phase, setPhase] = useState<"editing" | "saving" | "saved">("editing");
  const [saveResult, setSaveResult] = useState<SaveResult | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  // Tên collection chỉ để hiển thị tiêu đề — tra một lần.
  useEffect(() => {
    let cancelled = false;
    void services.repos.collections
      .list()
      .then((list: CollectionRow[]) => {
        if (!cancelled) setCollectionName(list.find((c) => c.id === collectionId)?.name ?? null);
      })
      .catch(() => {
        if (!cancelled) setCollectionName(null);
      });
    return () => {
      cancelled = true;
    };
  }, [services, collectionId]);

  const selectedCount = items.filter((i) => i.selected).length;
  const unverifiedCount = items.filter((i) => i.item.verification === "unverified").length;

  function patchItem(key: string, patch: Partial<AnalyzedItem>) {
    setItems((list) => list.map((it) => (it.key === key ? { ...it, item: { ...it.item, ...patch } } : it)));
  }

  function toggleSelect(key: string) {
    setItems((list) => list.map((it) => (it.key === key ? { ...it, selected: !it.selected } : it)));
  }

  function toggleExpand(key: string) {
    setItems((list) => list.map((it) => (it.key === key ? { ...it, expanded: !it.expanded } : it)));
  }

  function setAllSelected(selected: boolean) {
    setItems((list) => list.map((it) => ({ ...it, selected })));
  }

  /** FR-03: thoát khi chưa xác nhận → cảnh báo trước khi mất kết quả analysis. */
  function confirmBack() {
    if (phase === "saved") {
      navigate({ name: "home" });
      return;
    }
    const ok = window.confirm(
      "Kết quả phân tích CHƯA được lưu — rời đi là mất luôn kết quả này. Chắc chắn rời đi?",
    );
    if (ok) navigate({ name: "home" });
  }

  async function save() {
    if (phase !== "editing" || selectedCount === 0) return;
    setPhase("saving");
    setSaveError(null);
    try {
      const chosen = items.filter((i) => i.selected).map((i) => i.item);
      const result = await saveVocabulary(services, { collectionId, items: chosen, now: new Date() });
      setSaveResult(result);
      setPhase("saved");
    } catch (err) {
      setSaveError(err instanceof Error ? err.message : String(err));
      setPhase("editing");
    }
  }

  if (phase === "saved" && saveResult) {
    return (
      <div className="pad">
        <h1>Đã lưu {saveResult.saved} thẻ ✅</h1>
        <p className="muted">
          Vào {collectionName ? `“${collectionName}”` : "collection"} · thẻ `new` đến hạn NGAY hôm nay —
          mở ôn tập là gặp liền.
        </p>
        <button type="button" className="primary" onClick={() => navigate({ name: "review" })}>
          🃏 Ôn tập hôm nay
        </button>
        <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
          Về trang chủ
        </button>
      </div>
    );
  }

  return (
    <div className="pad">
      <h1>Duyệt từ trước khi lưu</h1>
      <p className="muted">
        {items.length} từ · {unverifiedCount} chưa xác minh (đỏ — mặc định KHÔNG chọn) · vào{" "}
        {collectionName ? `“${collectionName}”` : "collection"}
      </p>
      <p className="hint" title="NFR-02: đo & ghi lại mỗi lần gọi">
        {Number.isFinite(analysis.latencyMs) ? `${(analysis.latencyMs / 1000).toFixed(1)}s` : "?"} ·{" "}
        {analysis.usage.promptTokens + analysis.usage.candidatesTokens} tokens · prompt v
        {analysis.promptVersion} — chạm thẻ để mở sửa; bỏ chọn = không lưu item đó.
      </p>

      {saveError && <div className="banner banner-error">{saveError}</div>}

      <div className="btn-row">
        <button type="button" className="secondary" onClick={() => setAllSelected(true)} disabled={selectedCount === items.length}>
          Chọn tất cả
        </button>
        <button type="button" className="secondary" onClick={() => setAllSelected(false)} disabled={selectedCount === 0}>
          Bỏ chọn hết
        </button>
      </div>

      <ul className="vocab-list">
        {items.map((it) => (
          <li key={it.key} className={`vocab-card ${!it.selected ? "vocab-off" : ""} ${it.item.verification === "unverified" ? "vocab-alert" : ""}`}>
            <div className="vocab-head" onClick={() => toggleExpand(it.key)} role="button" tabIndex={0}
              onKeyDown={(e) => {
                if (e.key === "Enter" || e.key === " ") {
                  e.preventDefault();
                  toggleExpand(it.key);
                }
              }}>
              <input
                type="checkbox"
                checked={it.selected}
                aria-label={`giữ lại ${it.item.term}`}
                onClick={(e) => e.stopPropagation()}
                onChange={() => toggleSelect(it.key)}
              />
              <span className="vocab-term">{it.item.term}</span>
              <span className="fine">{it.item.pos}</span>
              <span className={`chip chip-${it.item.verification}`}>{CHIP_LABEL[it.item.verification]}</span>
              <span className="vocab-chev">{it.expanded ? "▴" : "▾"}</span>
            </div>
            <p className={"vocab-meaning" + (it.expanded ? " hidden" : "")}>{it.item.meaningVi}</p>
            {it.expanded && (
              <div className="vocab-edit">
                <Field label="term">
                  <input value={it.item.term} onChange={(e) => patchItem(it.key, { term: e.target.value })} />
                </Field>
                <div className="grid2">
                  <Field label="pos">
                    <select value={it.item.pos} onChange={(e) => patchItem(it.key, { pos: e.target.value as Pos })}>
                      {POS_VALUES.map((p) => (
                        <option key={p} value={p}>{p}</option>
                      ))}
                    </select>
                  </Field>
                  <Field label="CEFR">
                    <select value={it.item.cefr} onChange={(e) => patchItem(it.key, { cefr: e.target.value as Cefr })}>
                      {CEFR_VALUES.map((c) => (
                        <option key={c} value={c}>{c}</option>
                      ))}
                    </select>
                  </Field>
                </div>
                <Field label="ipa">
                  <input value={it.item.ipa} onChange={(e) => patchItem(it.key, { ipa: e.target.value })} />
                </Field>
                <Field label="nghĩa tiếng Việt">
                  <textarea rows={2} value={it.item.meaningVi} onChange={(e) => patchItem(it.key, { meaningVi: e.target.value })} />
                </Field>
                <Field label="câu gốc trên trang (example)">
                  <textarea rows={3} value={it.item.example} onChange={(e) => patchItem(it.key, { example: e.target.value })} />
                </Field>
              </div>
            )}
          </li>
        ))}
      </ul>

      <button
        type="button"
        className="primary"
        disabled={phase !== "editing" || selectedCount === 0}
        onClick={() => void save()}
      >
        {phase === "saving" ? "Đang lưu…" : `💾 Lưu ${selectedCount} thẻ — đến hạn ngay`}
      </button>
      <button type="button" className="secondary" onClick={confirmBack} disabled={phase === "saving"}>
        ← Bỏ kết quả, về trang chủ
      </button>
    </div>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return (
    <label>
      {label}
      {children}
    </label>
  );
}