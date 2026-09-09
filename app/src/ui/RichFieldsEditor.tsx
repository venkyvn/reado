/**
 * ui/RichFieldsEditor.tsx — editor 3 field rich vocab (task 3.12):
 * tags (kèm autocomplete từ nhãn đã có trong kho — RV-2) + synonyms + antonyms.
 *
 * Component CONTROLLED: chỉ nhận giá trị + onChange, không tự đọc repo, không
 * tự lưu — màn duyệt từ (VocabEditScreen) patch thẳng item chưa lưu, màn kho
 * (VocabLibraryScreen) giữ draft rồi gọi usecase updateVocabRichFields. Nhờ
 * vậy một bộ UI phục vụ hai đường dữ liệu khác nhau mà không trùng logic sửa.
 */
import { useId, useState } from "react";
import type { RichVocabFields } from "../domain/types";

interface RichGroupConfig {
  key: keyof RichVocabFields;
  label: string;
  placeholder: string;
  withSuggestions: boolean;
}

const GROUPS: RichGroupConfig[] = [
  { key: "tags", label: "Chủ đề (tags)", placeholder: "thêm tag, vd: business", withSuggestions: true },
  { key: "synonyms", label: "Đồng nghĩa", placeholder: "thêm từ đồng nghĩa", withSuggestions: false },
  { key: "antonyms", label: "Trái nghĩa", placeholder: "thêm từ trái nghĩa", withSuggestions: false },
];

/** Chuẩn hoá khi THÊM: trim, bỏ rỗng, chặn trùng (không phân biệt hoa thường). */
function addItem(items: string[], value: string): string[] {
  const v = value.trim();
  if (v === "") return items;
  if (items.some((x) => x.toLowerCase() === v.toLowerCase())) return items;
  return [...items, v];
}

function RichGroup({
  items,
  label,
  placeholder,
  suggestions,
  onChange,
}: {
  items: string[];
  label: string;
  placeholder: string;
  suggestions?: string[];
  onChange: (next: string[]) => void;
}) {
  const [draft, setDraft] = useState("");
  const uid = useId();
  // Datalist phải unique trên toàn trang — có thể nhiều card cùng mở
  // editor cùng lúc (kho từ), useId đảm bảo không trùng id.
  const listId = `${uid}-${label.replace(/\W+/g, "-")}`;

  function commit() {
    const next = addItem(items, draft);
    setDraft("");
    if (next !== items) onChange(next);
  }

  return (
    <div className="rich-group">
      <span className="rich-label">{label}</span>
      {items.length > 0 && (
        <div className="rich-chips">
          {items.map((item) => (
            <span key={item} className="chip chip-tag">
              {item}
              <button
                type="button"
                className="chip-remove"
                aria-label={`gỡ ${item}`}
                onClick={() => onChange(items.filter((x) => x !== item))}
              >
                ×
              </button>
            </span>
          ))}
        </div>
      )}
      <div className="rich-input-row">
        <input
          list={suggestions ? listId : undefined}
          value={draft}
          placeholder={placeholder}
          aria-label={`${label} — nhập rồi nhấn Thêm`}
          onChange={(e) => setDraft(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") {
              e.preventDefault();
              commit();
            }
          }}
        />
        {suggestions && suggestions.length > 0 && (
          <datalist id={listId}>
            {suggestions.map((s) => (
              <option key={s} value={s} />
            ))}
          </datalist>
        )}
        <button type="button" className="secondary rich-add" disabled={draft.trim() === ""} onClick={commit}>
          Thêm
        </button>
      </div>
    </div>
  );
}

export function RichFieldsEditor({
  fields,
  tagSuggestions,
  onChange,
}: {
  fields: RichVocabFields;
  tagSuggestions: string[];
  onChange: (f: RichVocabFields) => void;
}) {
  return (
    <div className="rich-editor">
      {GROUPS.map((g) => (
        <RichGroup
          key={g.key}
          label={g.label}
          placeholder={g.placeholder}
          items={fields[g.key]}
          suggestions={g.withSuggestions ? tagSuggestions : undefined}
          onChange={(next) => onChange({ ...fields, [g.key]: next })}
        />
      ))}
    </div>
  );
}