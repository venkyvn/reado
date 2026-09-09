/**
 * ui/screens/SettingsScreen.tsx — FR-15 (Learning Settings) + BYOK (Q-03, task 3.6).
 *
 * Ba nhóm trên màn này KHÁC nhau về quyền ghi, và màn hình nói rõ điều đó thay vì
 * để người dùng đoán:
 *
 * 1. Chỉnh được: `cefr_level` (áp cho lần phân tích KẾ TIẾP — criterion 1/2),
 *    `daily_new_limit` (mặc định 10, có hiệu lực ngay ở hàng đợi FR-11 — criterion 3),
 *    và 4 field BYOK (key · base URL · model · provider hiển thị).
 * 2. Chỉ đọc ở R1: `request_retention` (0.9 — FR-15 criterion 4 nói để mặc định),
 *    `day_cutoff_hour`, `fsrs_params`/`fsrs_version` (criterion 5: R1 để trống),
 *    `maximum_interval`, `enable_fuzz`, `ai_provider` (R1 chỉ có adapter Gemini).
 *    Cổng chặn thật nằm ở `domain/settings.ts`; màn này chỉ hiển thị, không gửi.
 * 3. Ô API key là GHI-ONLY: không bao giờ đổ key đã lưu vào DOM (điều cấm #9).
 *    Trạng thái chỉ là "đã có key / chưa có key"; muốn xoá thì có nút riêng.
 *
 * Screen chỉ gọi use-case (getSettings/updateSettings) — không SQL, không tự đọc
 * bảng settings (conventions mục 2).
 */
import { useCallback, useEffect, useState } from "react";
import type { Screen } from "../AppRoot";
import { SettingsError } from "../../domain/errors";
import { DEFAULT_AI_BASE_URL, DEFAULT_AI_MODEL } from "../../domain/settings";
import type { Settings } from "../../domain/types";
import { CEFR_VALUES } from "../../domain/types";
import type { Cefr } from "../../domain/types";
import { getSettings, updateSettings } from "../../domain/usecases/settings";
import { useAppEnv } from "../context";

/** Nhãn CEFR cho người đọc (giá trị lưu vẫn là A2/B1/B2/C1). */
const CEFR_LABEL: Record<Cefr, string> = {
  A2: "A2 — sơ cấp",
  B1: "B1 — trung cấp",
  B2: "B2 — trung cao cấp",
  C1: "C1 — cao cấp",
};

function messageFor(e: unknown): string {
  // SettingsError: ghép câu từ code + field — KHÔNG render e.message (message
  // là cho log, conventions mục 1/3). Lỗi lạ ngoài SettingsError thì giữ nguyên
  // thông điệp lỗi hệ thống như các màn khác (ExportScreen/HomeScreen cùng kiểu).
  if (e instanceof SettingsError) {
    return messageForCode(e.code, e.field);
  }
  return e instanceof Error ? e.message : String(e);
}

function messageForCode(code: SettingsError["code"], field: string | null): string {
  const name = field ?? "field";
  switch (code) {
    case "bad_cefr":
      return "CEFR phải là A2, B1, B2 hoặc C1.";
    case "bad_daily_limit":
      return "Hạn mức thẻ mới phải là số nguyên từ 0 đến 999 (0 = tạm dừng thẻ mới).";
    case "bad_base_url":
      return `Base URL không hợp lệ — cần địa chỉ http(s) đầy đủ (mặc định ${DEFAULT_AI_BASE_URL}).`;
    case "bad_model":
      return "Tên model không hợp lệ (quá dài).";
    case "empty_key":
      return 'Ô API key đang trống — gõ key mới, hoặc dùng nút "Xoá key" nếu muốn bỏ key đã lưu.';
    case "empty_patch":
      return "Chưa có thay đổi nào để lưu.";
    case "readonly_field":
      return `Không lưu được — "${name}" là cột bị khoá ở R1 (phần "Thuật toán ôn tập" bên trên chỉ xem được).`;
    case "unknown_field":
      return `Không lưu được — "${name}" không phải field cài đặt hợp lệ.`;
  }
}

/** Ô hạn mức: rỗng/gõ chữ → NaN để cổng domain từ chối, KHÔNG âm thầm thành 0. */
function parseLimit(input: string): number {
  const trimmed = input.trim();
  return trimmed === "" ? Number.NaN : Number(trimmed);
}

export function SettingsScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services } = useAppEnv();
  const [loaded, setLoaded] = useState<Settings | null>(null);
  const [loadError, setLoadError] = useState<string | null>(null);

  const [cefr, setCefr] = useState<Cefr>("B1");
  const [limitInput, setLimitInput] = useState("10");
  const [baseUrl, setBaseUrl] = useState("");
  const [model, setModel] = useState("");
  const [keyInput, setKeyInput] = useState("");

  const [busy, setBusy] = useState(false);
  const [saveError, setSaveError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  /** Đổ settings đã lưu vào form. Ô key LUÔN để rỗng (ghi-only). */
  const apply = useCallback((s: Settings) => {
    setLoaded(s);
    setCefr(s.cefrLevel);
    setLimitInput(String(s.dailyNewLimit));
    setBaseUrl(s.aiBaseUrl);
    setModel(s.aiModel ?? "");
  }, []);

  useEffect(() => {
    let alive = true;
    getSettings(services)
      .then((s) => {
        if (alive) apply(s);
      })
      .catch((e: unknown) => {
        if (alive) setLoadError(e instanceof Error ? e.message : String(e));
      });
    return () => {
      alive = false;
    };
  }, [services, apply]);

  async function save(): Promise<void> {
    setBusy(true);
    setSaveError(null);
    setNotice(null);
    try {
      const patch: Record<string, unknown> = {
        cefrLevel: cefr,
        dailyNewLimit: parseLimit(limitInput),
        aiBaseUrl: baseUrl,
        aiModel: model,
      };
      // Ô key rỗng = "không đổi key" (khác hẳn xoá key — có nút riêng).
      if (keyInput.trim() !== "") patch.aiApiKey = keyInput;

      const saved = await updateSettings(services, patch);
      apply(saved);
      setKeyInput("");
      setNotice(
        saved.aiApiKey
          ? "✅ Đã lưu. Cấu hình AI dùng cho lần chụp tiếp theo."
          : "✅ Đã lưu. Lưu ý: chưa có API key nên chưa phân tích được trang nào.",
      );
    } catch (e) {
      setSaveError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  async function clearKey(): Promise<void> {
    if (!window.confirm("Xoá API key đã lưu trên máy này? Lần chụp sau sẽ phải nhập lại.")) return;
    setBusy(true);
    setSaveError(null);
    setNotice(null);
    try {
      const saved = await updateSettings(services, { aiApiKey: null });
      apply(saved);
      setKeyInput("");
      setNotice("Đã xoá API key khỏi máy này.");
    } catch (e) {
      setSaveError(messageFor(e));
    } finally {
      setBusy(false);
    }
  }

  if (loadError) {
    return (
      <div className="pad">
        <h1>Cài đặt</h1>
        <div className="errorbox">Không đọc được cài đặt — {loadError}</div>
        <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
          ← Về trang chủ
        </button>
      </div>
    );
  }

  if (!loaded) {
    return (
      <div className="pad">
        <h1>Cài đặt</h1>
        <p className="muted">Đang đọc cài đặt…</p>
      </div>
    );
  }

  const hasKey = loaded.aiApiKey !== null && loaded.aiApiKey !== "";

  return (
    <div className="pad settings">
      <h1>Cài đặt</h1>

      <section className="card">
        <h2>Học tập</h2>
        <label>
          Trình độ CEFR (áp cho lần chụp TIẾP THEO)
          <select value={cefr} onChange={(e) => setCefr(e.target.value as Cefr)}>
            {CEFR_VALUES.map((v) => (
              <option key={v} value={v}>
                {CEFR_LABEL[v]}
              </option>
            ))}
          </select>
        </label>
        <p className="fine">
          Đổi mức này chỉ ảnh hưởng các trang phân tích SAU đó — trang đã phân tích không
          bị phân tích lại.
        </p>

        <label>
          Hạn mức thẻ mới mỗi ngày
          <input
            type="number"
            min={0}
            max={999}
            step={1}
            inputMode="numeric"
            value={limitInput}
            onChange={(e) => setLimitInput(e.target.value)}
          />
        </label>
        <p className="fine">
          Mặc định 10. Thẻ ôn lại KHÔNG bị giới hạn — hạn mức chỉ áp cho thẻ mới. Đặt 0 để
          tạm dừng thẻ mới (thẻ mới sẽ nằm ở phần "Còn tồn" trên Trang chủ).
        </p>
      </section>

      <section className="card">
        <h2>Cấu hình AI (BYOK)</h2>
        <p className="muted">
          Reado không có server trung gian: key nằm trên chính máy bạn và chỉ gọi thẳng
          nhà cung cấp. Key không bao giờ được ghi vào file export.
        </p>

        <p className="fine">
          Trạng thái key: <b>{hasKey ? "đã có key lưu trên máy này" : "chưa có key"}</b>
        </p>

        <label>
          API key {hasKey ? "(nhập để thay key cũ)" : ""}
          <input
            type="password"
            autoComplete="off"
            spellCheck={false}
            placeholder={hasKey ? "•••• (để trống nếu giữ nguyên)" : "AIza…"}
            value={keyInput}
            onChange={(e) => setKeyInput(e.target.value)}
          />
        </label>
        {hasKey && (
          <button type="button" className="secondary" disabled={busy} onClick={() => void clearKey()}>
            🗑 Xoá key đã lưu
          </button>
        )}

        <label>
          Base URL (mặc định Gemini)
          <input
            type="url"
            value={baseUrl}
            placeholder={DEFAULT_AI_BASE_URL}
            onChange={(e) => setBaseUrl(e.target.value)}
          />
        </label>

        <label>
          Model
          <input
            type="text"
            value={model}
            placeholder={DEFAULT_AI_MODEL}
            onChange={(e) => setModel(e.target.value)}
          />
        </label>
        <p className="fine">
          Để trống Base URL / Model = dùng mặc định ({DEFAULT_AI_BASE_URL} · {DEFAULT_AI_MODEL}).
          Gateway tương thích Gemini (vd ai-box.vn) thì đổi Base URL, giữ nguyên dạng đường dẫn.
        </p>
      </section>

      <section className="card">
        <h2>Thuật toán ôn tập (R1 để mặc định)</h2>
        <table className="kv">
          <tbody>
            <tr>
              <td className="kv-k">Tỉ lệ ghi nhớ mục tiêu (request_retention)</td>
              <td className="kv-v">{loaded.requestRetention}</td>
            </tr>
            <tr>
              <td className="kv-k">Giờ chuyển ngày (day_cutoff_hour)</td>
              <td className="kv-v">{loaded.dayCutoffHour}</td>
            </tr>
            <tr>
              <td className="kv-k">Khoảng cách tối đa (ngày)</td>
              <td className="kv-v">{loaded.maximumInterval}</td>
            </tr>
            <tr>
              <td className="kv-k">Fuzz lịch ôn</td>
              <td className="kv-v">{loaded.enableFuzz ? "bật" : "tắt"}</td>
            </tr>
            <tr>
              <td className="kv-k">Tham số FSRS / version</td>
              <td className="kv-v">
                {loaded.fsrsParams ?? "mặc định"} · {loaded.fsrsVersion ?? "chưa ghi"}
              </td>
            </tr>
            <tr>
              <td className="kv-k">Provider</td>
              <td className="kv-v">{loaded.aiProvider} (adapter duy nhất ở R1)</td>
            </tr>
          </tbody>
        </table>
        <p className="fine">
          R1 cố ý không mở các núm này: chúng đổi lịch ôn của toàn bộ kho và cần dữ liệu
          thật trước khi cho chỉnh (FR-15). Xem "vì sao" trong docs/prd.md mục 7.
        </p>
      </section>

      {saveError && <div className="errorbox">{saveError}</div>}
      {notice && <div className="banner">{notice}</div>}

      <div className="btn-row">
        <button type="button" className="primary" disabled={busy} onClick={() => void save()}>
          {busy ? "Đang lưu…" : "💾 Lưu cài đặt"}
        </button>
        <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
          ← Về trang chủ
        </button>
      </div>
    </div>
  );
}
