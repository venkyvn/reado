/**
 * ui/screens/StorageCheckScreen.tsx — trang SPIKE storage (mở bằng
 * ?screen=storage-check): bằng chứng OPFS trên iPhone — secure context,
 * crossOriginIsolated, mode, Service Worker, cảnh báo, write/read round-trip,
 * marker sống qua reload, số liệu kho.
 *
 * Bài học 2026-09-08: iPhone mở qua http:// + IP LAN → KHÔNG secure context →
 * OPFS + Service Worker bị trình duyệt chặn toàn bộ (ba cảnh báo fallback, nhìn
 * như lỗi code nhưng là ràng buộc nền tảng). Hàng "Secure context" đứng ĐẦU để
 * lần sau nhìn một phát là biết. Cách sửa: mở https:// (dev: `npm run cert` +
 * `npm run dev:https`) — cert tự ký nên iOS hỏi chấp nhận MỘT lần.
 *
 * Hàng "Sống qua F5" là phép thử quyết định cho bug lưu từ xong F5 mất sạch:
 * nó đọc marker của LẦN MỞ TRƯỚC. DB memory thì hàng này không bao giờ xanh,
 * dù mọi phép ghi trong phiên đều thành công.
 */
import { useEffect, useState } from "react"
import type { Screen } from "../AppRoot"
import { useAppEnv } from "../context"

interface CheckInfo {
  collections: number
  vocabInDefault: number
  dueCards: number
  keyConfigured: boolean
}

// Cổng https của `dev:https` (package.json) — server https DUY NHẤT ở chế độ dev.
// Không phải giá trị đoán; nếu đổi script thì đổi cả đây.
const HTTPS_DEV_PORT = 5174

/** ISO → giờ địa phương dễ đọc; chuỗi lạ thì trả nguyên văn thay vì "Invalid Date". */
function formatLocal(iso: string): string {
  const d = new Date(iso)
  return Number.isNaN(d.getTime()) ? iso : d.toLocaleString()
}

export function StorageCheckScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services, storageMode, storageWarnings, previousBootAt } = useAppEnv()
  const [info, setInfo] = useState<CheckInfo | null>(null)
  const [writeTest, setWriteTest] = useState<"idle" | "ok" | "fail">("idle")
  const [fatal, setFatal] = useState<string | null>(null)

  const secureContext = globalThis.isSecureContext === true
  const crossOriginIsolated = globalThis.crossOriginIsolated === true
  const origin = window.location.origin
  const hostname = new URL(origin).hostname
  const httpsSuggestion = `https://${hostname}:${HTTPS_DEV_PORT}/`
  const swActive = "serviceWorker" in navigator && navigator.serviceWorker.controller !== null

  useEffect(() => {
    void (async () => {
      try {
        const [cols, def, settings] = await Promise.all([
          services.repos.collections.list(),
          services.repos.collections.getDefault(),
          services.repos.settings.get(),
        ])
        const vocabInDefault = def
          ? (await services.repos.vocabItems.listByCollection(def.id)).length
          : 0
        const nowUtc = new Date().toISOString()
        const base = { nowUtc, scopeCollectionIds: null, limit: null }
        const dueCards =
          (await services.repos.cards.listDueReviews(base)).length +
          (await services.repos.cards.listDueNews(base)).length

        // Write/read round-trip thật — ghi LẠI giá trị hiện có (không đổi data).
        await services.repos.settings.updatePartial({ requestRetention: settings.requestRetention })
        await services.repos.settings.get()
        setWriteTest("ok")

        setInfo({
          collections: cols.length,
          vocabInDefault,
          dueCards,
          keyConfigured: Boolean(settings.aiApiKey),
        })
      } catch (err) {
        setWriteTest("fail")
        setFatal(err instanceof Error ? err.message : String(err))
      }
    })()
  }, [services])

  return (
    <div className="pad">
      <h1>Kiểm tra lưu trữ</h1>

      <table className="kv">
        <tbody>
          <Row
            label="Secure context"
            ok={secureContext}
            value={
              secureContext
                ? `Có — ${origin}`
                : `KHÔNG — trình duyệt chặn OPFS & offline ở ${origin}. Mở: ${httpsSuggestion}`
            }
          />
          <Row
            label="crossOriginIsolated"
            ok={crossOriginIsolated}
            value={
              crossOriginIsolated ? "Có (SharedArrayBuffer OK)" : "KHÔNG — VFS opfs không dùng được"
            }
          />
          <Row
            label="OPFS active"
            ok={storageMode === "opfs"}
            value={storageMode === "opfs" ? "Có — lưu thật trên máy" : "KHÔNG — mất khi đóng tab"}
          />
          <Row
            label="Service Worker"
            ok={swActive}
            value={
              swActive
                ? "Đang điều khiển trang — offline được"
                : "Chưa có (dev server không phục vụ SW — test offline cần build + preview:https, rồi reload lần nữa)"
            }
          />
          <Row
            label="Write/read SQLite"
            ok={writeTest === "ok"}
            value={writeTest === "ok" ? "Ghi + đọc lại OK" : writeTest === "fail" ? "LỖI" : "…"}
          />
          <Row
            label="Sống qua F5"
            ok={Boolean(previousBootAt)}
            value={
              previousBootAt
                ? `Có — lần mở trước lúc ${formatLocal(previousBootAt)}`
                : "Chưa thấy lần mở trước — đây là lần mở đầu, hoặc DB đang là bộ nhớ tạm"
            }
          />
          <Row
            label="API key AI"
            ok={false}
            value={
              info ? (info.keyConfigured ? "Đã cấu hình" : "Chưa cấu hình (sẽ nhắc khi chụp)") : "…"
            }
          />
          <Row label="Collection" ok={false} value={info ? String(info.collections) : "…"} />
          <Row
            label="Từ trong Kho tạm"
            ok={false}
            value={info ? String(info.vocabInDefault) : "…"}
          />
          <Row label="Card đến hạn" ok={false} value={info ? String(info.dueCards) : "…"} />
        </tbody>
      </table>

      {fatal && <div className="banner banner-error">Lỗi: {fatal}</div>}
      {storageWarnings.length > 0 && (
        <div className="banner banner-warn">
          Cảnh báo vận hành:
          <ul style={{ margin: "4px 0", paddingLeft: 18 }}>
            {storageWarnings.map((w, i) => (
              <li key={i}>{w}</li>
            ))}
          </ul>
        </div>
      )}
      {!storageWarnings.length && writeTest === "ok" && (
        <p className="muted">Không cảnh báo vận hành nào — storage chạy bình thường.</p>
      )}

      <p className="fine">
        SPIKE task 2.4-đi-kiện (solution-design 14.2): trên iPhone mở {httpsSuggestion}
        và xem hàng “OPFS active”. Muốn chắc dữ liệu không mất: F5 thêm MỘT lần nữa — hàng “Sống qua
        F5” phải hiện giờ của lần mở vừa rồi. Lưu ý: dữ liệu nằm THEO origin — mở bằng http hay
        https là hai kho khác nhau, không thấy từ cũ là vì đó (không phải mất).
      </p>

      <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
        ← Về trang chủ
      </button>
    </div>
  )
}

function Row({ label, value, ok }: { label: string; value: string; ok: boolean }) {
  return (
    <tr>
      <td className="kv-k">{label}</td>
      <td className={`kv-v ${ok ? "kv-ok" : ""}`}>{value}</td>
    </tr>
  )
}
