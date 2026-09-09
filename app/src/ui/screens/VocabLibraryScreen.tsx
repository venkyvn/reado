/**
 * ui/screens/VocabLibraryScreen.tsx — FR-08 (task 3.4): danh sách kho từ vựng.
 *
 * Đúng ba criterion trong PRD, mỗi cái một phần của màn hình:
 * - C1: card rút gọn thấy term/pos/nghĩa tắt; chạm mở INLINE đủ ipa, nghĩa, câu
 *   gốc, CEFR và TÊN collection (cùng ngôn ngữ thiết kế task 2.3 — owner chốt).
 * - C2: ba bộ lọc collection / cefr / trạng thái ôn tập, kết hợp tự do.
 * - C3: cùng term nhiều nghĩa là NHIỀU dòng nằm cạnh nhau (repo đã sort theo
 *   term) — màn này không gộp gì cả.
 *
 * Empty-state nói thẳng việc đã tốn một buổi 2026-09-08 mới rõ: dữ liệu nằm
 * THEO ORIGIN — kho ở địa chỉ này trống không có nghĩa từ đã mất (có thể chúng
 * đang nằm ở địa chỉ/thiết bị khác), và restart server không bao giờ xoá dữ liệu
 * trên máy người dùng.
 */
import { useEffect, useState } from "react";
import type { Screen } from "../AppRoot";
import { listLibrary } from "../../domain/usecases/library";
import { updateVocabRichFields } from "../../domain/usecases/richVocab";
import { CARD_STATES, CEFR_VALUES } from "../../domain/types";
import type { CardState, CollectionRow, LibraryItemRow, RichVocabFields } from "../../domain/types";
import { useAppEnv } from "../context";
import { RichFieldsEditor } from "../RichFieldsEditor";

const STATE_LABEL: Record<CardState, string> = {
  new: "Mới",
  learning: "Đang học",
  review: "Đang ôn",
  relearning: "Học lại",
};

interface Filters {
  collectionId: string;
  cefr: string;
  state: string;
}

const NONE: Filters = { collectionId: "all", cefr: "all", state: "all" };

const sameStrings = (a: string[], b: string[]) =>
  a.length === b.length && a.every((x, i) => x === b[i]);

/**
 * Khối sửa 3 field rich vocab của MỘT dòng trong kho (task 3.12).
 * Draft giữ local; chỉ gọi usecase khi bấm Lưu — giữ đúng ranh giới
 * "UI không chạm repo trực tiếp". Sau lưu, báo cha reload để danh sách
 * (và tag gợi ý ở nơi khác) phản ánh ngay.
 */
function LibraryRichEditor({
  item,
  tagSuggestions,
  onSaved,
}: {
  item: LibraryItemRow;
  tagSuggestions: string[];
  onSaved: () => void;
}) {
  const { services } = useAppEnv();
  const [fields, setFields] = useState<RichVocabFields>(() => ({
    tags: item.tags,
    synonyms: item.synonyms,
    antonyms: item.antonyms,
  }));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const dirty =
    !sameStrings(fields.tags, item.tags) ||
    !sameStrings(fields.synonyms, item.synonyms) ||
    !sameStrings(fields.antonyms, item.antonyms);

  async function save() {
    if (!dirty || saving) return;
    setSaving(true);
    setError(null);
    try {
      await updateVocabRichFields(services, { vocabItemId: item.id, fields });
      onSaved();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
      setSaving(false);
    }
  }

  return (
    <div className="rich-editor">
      <RichFieldsEditor fields={fields} tagSuggestions={tagSuggestions} onChange={setFields} />
      {error && <div className="banner banner-error">{error}</div>}
      <button type="button" className="primary" disabled={!dirty || saving} onClick={() => void save()}>
        {saving ? "Đang lưu…" : "💾 Lưu chủ đề & từ liên quan"}
      </button>
    </div>
  );
}

export function VocabLibraryScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services } = useAppEnv();
  const [collections, setCollections] = useState<CollectionRow[]>([]);
  const [filters, setFilters] = useState<Filters>(NONE);
  const [items, setItems] = useState<LibraryItemRow[] | null>(null);
  // Bắt đầu ở true: lần nạp đầu tiên luôn là "đang tải"; các lần sau bật ở event
  // handler (React Compiler cấm setState đồng bộ trong effect — lint đã chỉ chỗ).
  const [loading, setLoading] = useState(true);
  const [expanded, setExpanded] = useState<ReadonlySet<string>>(new Set());
  const [error, setError] = useState<string | null>(null);
  // RV-2: gợi ý tag từ nhãn đã có trong kho — tải một lần, dùng cho mọi editor.
  const [tagSuggestions, setTagSuggestions] = useState<string[]>([]);

  useEffect(() => {
    let alive = true;
    void services.repos.vocabItems
      .listAllTags()
      .then((tcs) => {
        if (alive) setTagSuggestions(tcs.map((tc) => tc.tag));
      })
      .catch(() => {
        // gợi ý chỉ là tiện ích — nhập tự do vẫn hoạt động
      });
    return () => {
      alive = false;
    };
  }, [services]);

  /** Nạp lại danh sách theo filter hiện tại (dùng sau khi sửa rich fields). */
  const reload = () => {
    setLoading(true);
    void listLibrary(services, {
      collectionId: filters.collectionId === "all" ? null : filters.collectionId,
      cefr: filters.cefr === "all" ? null : filters.cefr,
      state: filters.state === "all" ? null : (filters.state as CardState),
    })
      .then((rows) => {
        setItems(rows);
        // Tag gợi ý sau khi sửa cũng đổi theo (thêm/bớt tag mới).
        return services.repos.vocabItems.listAllTags().then((tcs) => setTagSuggestions(tcs.map((tc) => tc.tag)));
      })
      .catch((e: unknown) => {
        setError(e instanceof Error ? e.message : String(e));
      })
      .finally(() => {
        setLoading(false);
      });
  };

  useEffect(() => {
    let alive = true;
    services.repos.collections
      .list()
      .then((rows) => {
        if (alive) setCollections(rows);
      })
      .catch((e: unknown) => {
        if (alive) setError(e instanceof Error ? e.message : String(e));
      });
    return () => {
      alive = false;
    };
  }, [services]);

  useEffect(() => {
    let alive = true;
    listLibrary(services, {
      collectionId: filters.collectionId === "all" ? null : filters.collectionId,
      cefr: filters.cefr === "all" ? null : filters.cefr,
      state: filters.state === "all" ? null : (filters.state as CardState),
    })
      .then((rows) => {
        if (alive) setItems(rows);
      })
      .catch((e: unknown) => {
        if (alive) setError(e instanceof Error ? e.message : String(e));
      })
      .finally(() => {
        if (alive) setLoading(false);
      });
    return () => {
      alive = false;
    };
  }, [services, filters]);

  function applyFilter(patch: Partial<Filters>) {
    setFilters((prev) => ({ ...prev, ...patch }));
    setLoading(true);
  }

  function toggle(id: string) {
    setExpanded((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  const filterActive = filters !== NONE;
  const originAwareBanner = !filterActive && items !== null && items.length === 0;

  return (
    <div className="pad">
      <h1>Kho từ vựng</h1>
      <p className="muted">
        {loading ? "Đang tải…" : `${items?.length ?? 0} từ${filterActive ? " (đã lọc)" : ""}`}
      </p>

      <div className="grid2">
        <label className="fine" htmlFor="lib-collection">
          Collection
          <select
            id="lib-collection"
            value={filters.collectionId}
            onChange={(e) => applyFilter({ collectionId: e.target.value })}
          >
            <option value="all">Tất cả</option>
            {collections.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
                {c.isDefault ? " (mặc định)" : ""}
              </option>
            ))}
          </select>
        </label>
        <label className="fine" htmlFor="lib-cefr">
          CEFR
          <select id="lib-cefr" value={filters.cefr} onChange={(e) => applyFilter({ cefr: e.target.value })}>
            <option value="all">Tất cả</option>
            {CEFR_VALUES.map((c) => (
              <option key={c} value={c}>
                {c}
              </option>
            ))}
          </select>
        </label>
        <label className="fine" htmlFor="lib-state">
          Trạng thái ôn tập
          <select id="lib-state" value={filters.state} onChange={(e) => applyFilter({ state: e.target.value })}>
            <option value="all">Tất cả</option>
            {CARD_STATES.map((s) => (
              <option key={s} value={s}>
                {STATE_LABEL[s]}
              </option>
            ))}
          </select>
        </label>
      </div>

      {error && <div className="banner banner-error">Lỗi: {error}</div>}

      {originAwareBanner && (
        <div className="banner banner-warn">
          Chưa có từ nào ở địa chỉ này. Kho nằm TRONG thiết bị, theo địa chỉ
          (origin) — từ lưu ở địa chỉ/thiết bị khác không hiện ở đây (không phải
          bị xoá), và việc khởi động lại server không bao giờ đụng tới dữ liệu
          trên máy bạn.
        </div>
      )}
      {!originAwareBanner && items !== null && items.length === 0 && (
        <p className="muted">Không có từ nào khớp bộ lọc — bỏ bớt điều kiện thử xem.</p>
      )}

      <ul className="vocab-list">
        {(items ?? []).map((it) => {
          const open = expanded.has(it.id);
          return (
            <li key={it.id} className="vocab-card">
              <div
                className="vocab-head"
                onClick={() => toggle(it.id)}
                role="button"
                tabIndex={0}
                onKeyDown={(e) => {
                  if (e.key === "Enter" || e.key === " ") {
                    e.preventDefault();
                    toggle(it.id);
                  }
                }}
              >
                <span className="vocab-term">{it.term}</span>
                <span className="fine">{it.pos}</span>
                <span className={`chip chip-state-${it.cardState}`}>{STATE_LABEL[it.cardState]}</span>
                <span className="vocab-chev">{open ? "▴" : "▾"}</span>
              </div>
              <p className={"vocab-meaning" + (open ? " hidden" : "")}>{it.meaningVi}</p>
              {open && (
                <div className="vocab-edit">
                  <table className="kv">
                    <tbody>
                      <tr>
                        <td className="kv-k">phiên âm</td>
                        <td className="kv-v">{it.ipa ?? "—"}</td>
                      </tr>
                      <tr>
                        <td className="kv-k">nghĩa</td>
                        <td className="kv-v">{it.meaningVi}</td>
                      </tr>
                      <tr>
                        <td className="kv-k">câu gốc</td>
                        <td className="kv-v">{it.example}</td>
                      </tr>
                      <tr>
                        <td className="kv-k">CEFR</td>
                        <td className="kv-v">{it.cefr ?? "—"}</td>
                      </tr>
                      <tr>
                        <td className="kv-k">collection</td>
                        <td className="kv-v">{it.collectionName}</td>
                      </tr>
                    </tbody>
                  </table>
                  {/* Rich vocab (3.12): hiển thị + sửa được tại chỗ — lưu đi qua
                      usecase, không đụng FSRS. */}
                  <LibraryRichEditor item={it} tagSuggestions={tagSuggestions} onSaved={reload} />
                </div>
              )}
            </li>
          );
        })}
      </ul>

      <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
        ← Về trang chủ
      </button>
    </div>
  );
}