/**
 * ui/AnalyzePanel.tsx — FR-02 phía người dùng: gửi ảnh một lần, chờ tiến trình
 * thật (NFR-01 p50 ≈ 19s — không được để màn hình đứng im), lỗi có mã → thông
 * điệp đúng + retry; BYOK chưa nhập → form ngay trong flow (hợp đồng DDL:
 * "null = chưa nhập; app nhắc khi capture đầu tiên") → LƯU VÀO settings, không
 * đi đâu khác.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import type { AnalysisResult } from "../domain/types";
import type { PageImage } from "../domain/ai";
import { AnalysisError } from "../domain/errors";
import { analyzePage } from "../domain/usecases/analyze";
import { useAppEnv } from "./context";

export function AnalyzePanel({ image, onDone, onCancel }: {
  image: PageImage;
  onDone: (result: AnalysisResult) => void;
  onCancel: () => void;
}) {
  const { services } = useAppEnv();
  const [busy, setBusy] = useState(true);
  const [error, setError] = useState<AnalysisError | null>(null);
  const [showKeyForm, setShowKeyForm] = useState(false);
  const [key, setKey] = useState("");
  const [baseUrl, setBaseUrl] = useState("https://generativelanguage.googleapis.com");
  const [model, setModel] = useState("gemini-3.6-flash");
  const runIdRef = useRef(0);

  // Nhồi sẵn baseUrl/model hiện có để form BYOK không bắt user gõ lại.
  useEffect(() => {
    void services.repos.settings.get().then((s) => {
      setBaseUrl(s.aiBaseUrl);
      if (s.aiModel) setModel(s.aiModel);
    });
  }, [services]);

  // Phần lõi KHÔNG có setState đồng bộ — chạy được thẳng từ effect mà không
  // vi phạm react(set-state-in-effect): mọi setState nằm sau await.
  const attemptCore = useCallback(
    async (runId: number) => {
      try {
        const result = await analyzePage(services, image);
        if (runId !== runIdRef.current) return; // đã huỷ / retry mới hơn
        setBusy(false);
        onDone(result);
      } catch (e) {
        if (runId !== runIdRef.current) return;
        setBusy(false);
        const err = e instanceof AnalysisError ? e : new AnalysisError("network", String(e));
        setError(err);
        if (err.code === "missing_key") setShowKeyForm(true);
      }
    },
    [services, image, onDone],
  );

  // attempt dùng cho EVENT HANDLER (retry/lưu key): setState đồng bộ ở đây OK.
  const attempt = useCallback(async () => {
    setBusy(true);
    setError(null);
    await attemptCore(++runIdRef.current);
  }, [attemptCore]);

  useEffect(() => {
    // Lần đầu: busy đã là true, error đã null — chỉ chạy phần async.
    void attemptCore(++runIdRef.current);
    // StrictMode dev: mount→unmount→mount chạy effect 2 lần — tăng runId ở cleanup
    // để response của lần effect trước không bao giờ được dùng (dev vẫn gửi 2
    // request; production không có).
    return () => {
      runIdRef.current += 1;
    };
  }, [attemptCore]);

  async function saveKeyAndRetry() {
    if (!key.trim()) return;
    await services.repos.settings.updatePartial({
      aiApiKey: key.trim(),
      aiBaseUrl: baseUrl.trim() || "https://generativelanguage.googleapis.com",
      aiModel: model.trim() || "gemini-3.6-flash",
    });
    setShowKeyForm(false);
    void attempt();
  }

  return (
    <div className="pad">
      <h1>Đang phân tích trang</h1>

      {busy && (
        <div className="analyzing">
          <div className="spinner" aria-hidden="true" />
          <p className="muted">
            OCR + dịch + trích từ vựng trong một lần gọi — thường 15–30 giây, cứ để yên.
          </p>
        </div>
      )}

      {error && error.code !== "missing_key" && (
        <div className="errorbox">
          <p>
            <strong>{messageFor(error.code)}</strong>
          </p>
          {error.message && <p className="fine">{error.message.slice(0, 320)}</p>}
          <button type="button" className="primary" onClick={() => void attempt()}>
            🔁 Thử lại
          </button>
        </div>
      )}

      {showKeyForm && (
        <div className="card">
          <h2>Config AI của bạn (BYOK)</h2>
          <p className="muted">
            Reado không có server — key nằm trên chính máy bạn, chỉ gọi thẳng Gemini.
            Lưu trong cài đặt local, dùng lại cho mọi lần chụp sau.
          </p>
          <label>
            API key Gemini
            <input
              type="password"
              value={key}
              autoComplete="off"
              placeholder="AIza…"
              onChange={(e) => setKey(e.target.value)}
            />
          </label>
          <label>
            Base URL (mặc định Gemini)
            <input type="url" value={baseUrl} onChange={(e) => setBaseUrl(e.target.value)} />
          </label>
          <label>
            Model (gợi ý mặc định cho app)
            <input type="text" value={model} onChange={(e) => setModel(e.target.value)} />
          </label>
          <button
            type="button"
            className="primary"
            disabled={key.trim() === ""}
            onClick={() => void saveKeyAndRetry()}
          >
            Lưu &amp; phân tích ngay
          </button>
        </div>
      )}

      {!busy && (
        <button type="button" className="secondary" onClick={onCancel}>
          ← Huỷ, quay lại
        </button>
      )}
    </div>
  );
}

function messageFor(code: AnalysisError["code"]): string {
  switch (code) {
    case "missing_key":
      return "Chưa có API key — nhập bên dưới để tiếp tục.";
    case "network":
      return "Không có mạng hoặc không gọi được API AI.";
    case "http":
      return "API AI trả lỗi HTTP — kiểm tra key/model/base URL.";
    case "bad_envelope":
      return "AI trả cấu trúc lạ, thử lại.";
    case "finish_reason":
      return "AI dừng giữa chừng (finishReason khác STOP), thử lại.";
    case "bad_json":
      return "AI trả text không phải JSON, thử lại.";
    case "schema":
      return "Output vỡ schema — không lưu bản ghi hỏng. Thử lại hoặc đổi ảnh rõ hơn.";
    case "unreadable":
      return "Ảnh không đọc được hoặc không phải tiếng Anh — thử chụp lại rõ/nét hơn.";
    default:
      return "Lỗi không rõ nguyên nhân — thử lại.";
  }
}