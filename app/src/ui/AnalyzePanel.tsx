/**
 * ui/AnalyzePanel.tsx — FR-02 phía người dùng: gửi ảnh một lần, chờ tiến trình
 * thật (NFR-01 p50 ≈ 19s — không được để màn hình đứng im), lỗi có mã → thông
 * điệp đúng + retry; BYOK chưa nhập → form ngay trong flow (hợp đồng DDL:
 * "null = chưa nhập; app nhắc khi capture đầu tiên") → LƯU VÀO settings, không
 * đi đâu khác.
 */
import { useCallback, useEffect, useRef, useState } from "react"
import type { AnalysisResult } from "../domain/types"
import type { PageImage } from "../domain/ai"
import { AnalysisError, SettingsError } from "../domain/errors"
import { DEFAULT_AI_BASE_URL, DEFAULT_AI_MODEL } from "../domain/settings"
import { analyzePage, recordAnalyzedPage } from "../domain/usecases/analyze"
import { updateSettings } from "../domain/usecases/settings"
import { useAppEnv } from "./context"

export function AnalyzePanel({
  image,
  onDone,
  onCancel,
}: {
  image: PageImage
  /** `analysisId` = id dòng analyses + reading_sessions ghi cùng lúc (task 3.15)
   *  — caller dùng neo phiên đọc. */
  onDone: (result: AnalysisResult, analysisId: string) => void
  onCancel: () => void
}) {
  const { services } = useAppEnv()
  const [busy, setBusy] = useState(true)
  const [error, setError] = useState<AnalysisError | null>(null)
  const [showKeyForm, setShowKeyForm] = useState(false)
  const [keyFormError, setKeyFormError] = useState<string | null>(null)
  const [key, setKey] = useState("")
  // Mặc định lấy từ domain/settings.ts (task 3.6) — màn Cài đặt dùng CÙNG hằng số,
  // để hai chỗ không trôi khỏi nhau.
  const [baseUrl, setBaseUrl] = useState(DEFAULT_AI_BASE_URL)
  const [model, setModel] = useState(DEFAULT_AI_MODEL)
  const runIdRef = useRef(0)

  // Nhồi sẵn baseUrl/model hiện có để form BYOK không bắt user gõ lại.
  useEffect(() => {
    void services.repos.settings.get().then((s) => {
      setBaseUrl(s.aiBaseUrl)
      if (s.aiModel) setModel(s.aiModel)
    })
  }, [services])

  // Phần lõi KHÔNG có setState đồng bộ — chạy được thẳng từ effect mà không
  // vi phạm react(set-state-in-effect): mọi setState nằm sau await.
  const attemptCore = useCallback(
    async (runId: number) => {
      try {
        const result = await analyzePage(services, image)
        if (runId !== runIdRef.current) return // đã huỷ / retry mới hơn
        // FR-14: ghi sự kiện "đã phân tích trang" SAU guard — StrictMode dev
        // chạy effect 2 lần, guard này chặn lần phản hồi cũ nên chỉ đếm 1 sự
        // kiện. Lỗi ghi không chặn đường chính (kết quả AI quan trọng hơn con
        // đếm) nhưng không nuốt im lặng — console.error vẫn lưu dấu vết.
        try {
          const analysisId = await recordAnalyzedPage(services, result)
          setBusy(false)
          onDone(result, analysisId)
        } catch (e) {
          // Không ghi được analyses/reading_sessions: kết quả AI vẫn cho user
          // xem (màn duyệt từ vẫn lưu được từ), nhưng phiên đọc không persist —
          // không nuốt im lặng, console.error lưu dấu vết.
          console.error("Không ghi được sự kiện phân tích/phiên đọc:", e)
          setBusy(false)
          onDone(result, "")
        }
      } catch (e) {
        if (runId !== runIdRef.current) return
        setBusy(false)
        const err = e instanceof AnalysisError ? e : new AnalysisError("network", String(e))
        setError(err)
        if (err.code === "missing_key") setShowKeyForm(true)
      }
    },
    [services, image, onDone],
  )

  // attempt dùng cho EVENT HANDLER (retry/lưu key): setState đồng bộ ở đây OK.
  const attempt = useCallback(async () => {
    setBusy(true)
    setError(null)
    await attemptCore(++runIdRef.current)
  }, [attemptCore])

  useEffect(() => {
    // Lần đầu: busy đã là true, error đã null — chỉ chạy phần async.
    void attemptCore(++runIdRef.current)
    // StrictMode dev: mount→unmount→mount chạy effect 2 lần — tăng runId ở cleanup
    // để response của lần effect trước không bao giờ được dùng (dev vẫn gửi 2
    // request; production không có).
    return () => {
      runIdRef.current += 1
    }
  }, [attemptCore])

  async function saveKeyAndRetry() {
    if (!key.trim()) return
    setKeyFormError(null)
    try {
      // Đi qua use-case (task 3.6) chứ không gọi repo: cổng kiểm tra settings nằm
      // ở domain — form này cũng phải chịu cùng luật (base URL/model rác bị chặn).
      await updateSettings(services, {
        aiApiKey: key.trim(),
        aiBaseUrl: baseUrl,
        aiModel: model,
      })
    } catch (e) {
      // Ghép câu từ code — không render e.message (conventions: message là cho log).
      setKeyFormError(e instanceof SettingsError ? keyFormMessageFor(e.code) : String(e))
      return
    }
    setShowKeyForm(false)
    void attempt()
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
            Reado không có server — key nằm trên chính máy bạn, chỉ gọi thẳng Gemini. Lưu trong cài
            đặt local, dùng lại cho mọi lần chụp sau.
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
          {keyFormError && <div className="errorbox">{keyFormError}</div>}
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
  )
}

function keyFormMessageFor(code: SettingsError["code"]): string {
  switch (code) {
    case "bad_base_url":
      return "Base URL không hợp lệ — cần địa chỉ http(s) đầy đủ. Xoá trống để dùng mặc định Gemini."
    case "bad_model":
      return "Tên model không hợp lệ. Xoá trống để dùng model mặc định."
    case "empty_key":
      return "API key rỗng — nhập key để tiếp tục."
    default:
      return "Cấu hình chưa hợp lệ — kiểm tra lại API key, base URL và model."
  }
}

function messageFor(code: AnalysisError["code"]): string {
  switch (code) {
    case "missing_key":
      return "Chưa có API key — nhập bên dưới để tiếp tục."
    case "network":
      return "Không có mạng hoặc không gọi được API AI."
    case "http":
      return "API AI trả lỗi HTTP — kiểm tra key/model/base URL."
    case "bad_envelope":
      return "AI trả cấu trúc lạ, thử lại."
    case "finish_reason":
      return "AI dừng giữa chừng (finishReason khác STOP), thử lại."
    case "bad_json":
      return "AI trả text không phải JSON, thử lại."
    case "schema":
      return "Output vỡ schema — không lưu bản ghi hỏng. Thử lại hoặc đổi ảnh rõ hơn."
    case "unreadable":
      return "Ảnh không đọc được hoặc không phải tiếng Anh — thử chụp lại rõ/nét hơn."
    default:
      return "Lỗi không rõ nguyên nhân — thử lại."
  }
}
