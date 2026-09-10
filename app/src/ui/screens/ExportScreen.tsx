/**
 * ui/screens/ExportScreen.tsx — FR-16: xuất dữ liệu (task 3.7).
 *
 * Owner chốt 2026-09-08: làm SỚM trong Phase 3, làm phao cứu sinh trước rủi ro
 * iOS xoá storage của web app sau ~7 ngày không mở (MVP_PLAN mục 5). Vì nó là
 * phao, tiêu chí cứng là NFR-05: bấm nút thì PHẢI ra file — nên màn này luôn
 * kèm đường thủ công (textarea + copy) dù share/download thành công hay không.
 *
 * Ranh giới: screen chỉ gọi use-case `exportData` (domain) và `deliverTextFile`
 * (trình duyệt) — không SQL, không tự dựng nội dung file (conventions mục 2).
 */
import { useEffect, useState } from "react"
import type { Screen } from "../AppRoot"
import { exportData } from "../../domain/usecases/exportData"
import type { ExportCounts, ExportScope } from "../../domain/export"
import type { CollectionRow } from "../../domain/types"
import { useAppEnv } from "../context"
import { deliverTextFile } from "../fileDelivery"
import type { DeliveryOutcome } from "../fileDelivery"

const TSV_MIME = "text/tab-separated-values;charset=utf-8"
const JSON_MIME = "application/json;charset=utf-8"

interface LastExport {
  kind: "tsv" | "json"
  filename: string
  content: string
  counts: ExportCounts
  scope: ExportScope
  outcome: DeliveryOutcome
}

/** Tên file an toàn: bỏ dấu tiếng Việt, chỉ giữ [a-z0-9-], cắt 40 ký tự. */
function slug(input: string): string {
  const ascii = input
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
  const cleaned = ascii.replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  return (cleaned || "kho").slice(0, 40)
}

/** yyyymmdd theo clock injectable của app (không tự gọi Date — test được). */
function dateStamp(now: Date): string {
  return now.toISOString().slice(0, 10).replace(/-/g, "")
}

function outcomeText(o: DeliveryOutcome, filename: string): string {
  switch (o.method) {
    case "share":
      return `Đã mở bảng chia sẻ — chọn "Lưu vào Tệp" để giữ ${filename}.`
    case "download":
      // Không khẳng định "đã tải xong": trên iOS standalone a[download] có thể im
      // lặng không làm gì. Nói đúng mức mình biết + chỉ đường dự phòng.
      return `Đã yêu cầu tải ${filename}. Không thấy file? Mở ô nội dung bên dưới để copy.`
    case "cancelled":
      return "Bạn đã huỷ bảng chia sẻ — chưa lưu file. Nội dung vẫn ở ô bên dưới nếu cần copy."
    case "manual":
      return `Trình duyệt không cho tải tự động (${o.reason}) — copy nội dung ở ô bên dưới.`
  }
}

export function ExportScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services } = useAppEnv()
  const [collections, setCollections] = useState<CollectionRow[] | null>(null)
  const [scopeId, setScopeId] = useState<string>("all")
  const [busy, setBusy] = useState<null | "tsv" | "json">(null)
  const [error, setError] = useState<string | null>(null)
  const [last, setLast] = useState<LastExport | null>(null)

  useEffect(() => {
    let alive = true
    services.repos.collections
      .list()
      .then((rows) => {
        if (alive) setCollections(rows)
      })
      .catch((e: unknown) => {
        if (alive) setError(e instanceof Error ? e.message : String(e))
      })
    return () => {
      alive = false
    }
  }, [services])

  async function run(kind: "tsv" | "json"): Promise<void> {
    setBusy(kind)
    setError(null)
    try {
      const collectionId = scopeId === "all" ? null : scopeId
      const bundle = await exportData(services, collectionId)
      const scopeName = bundle.scope.collectionName ?? "tat-ca"
      const filename = `reado-${dateStamp(services.now())}-${slug(scopeName)}.${kind}`
      const content = kind === "tsv" ? bundle.tsv : bundle.json
      const outcome = await deliverTextFile(
        filename,
        content,
        kind === "tsv" ? TSV_MIME : JSON_MIME,
      )
      setLast({ kind, filename, content, counts: bundle.counts, scope: bundle.scope, outcome })
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e))
    } finally {
      setBusy(null)
    }
  }

  return (
    <div className="pad">
      <h1>Xuất dữ liệu</h1>
      <p className="muted">
        Mang từ vựng đi nơi khác (NFR-05: không lock-in). Hai định dạng theo FR-16: TSV nhập vào
        Anki, JSON giữ nguyên trạng thái FSRS + lịch ôn. API key không bao giờ nằm trong file.
      </p>

      <label className="fine" htmlFor="export-scope">
        Phạm vi
      </label>
      <select
        id="export-scope"
        value={scopeId}
        onChange={(e) => setScopeId(e.target.value)}
        disabled={collections === null}
      >
        <option value="all">Toàn bộ kho</option>
        {(collections ?? []).map((c) => (
          <option key={c.id} value={c.id}>
            {c.name}
            {c.isDefault ? " (mặc định)" : ""}
          </option>
        ))}
      </select>

      {error && <div className="banner banner-error">Lỗi: {error}</div>}

      <div className="btn-row" style={{ marginTop: 12 }}>
        <button
          type="button"
          className="primary"
          disabled={busy !== null}
          onClick={() => void run("tsv")}
        >
          {busy === "tsv" ? "Đang xuất…" : "⬇︎ TSV cho Anki"}
        </button>
        <button
          type="button"
          className="secondary"
          disabled={busy !== null}
          onClick={() => void run("json")}
        >
          {busy === "json" ? "Đang xuất…" : "⬇︎ JSON đầy đủ"}
        </button>
      </div>

      {last && (
        <>
          <div className={`banner ${last.outcome.method === "manual" ? "banner-warn" : ""}`}>
            {outcomeText(last.outcome, last.filename)}
          </div>
          <table className="kv">
            <tbody>
              <tr>
                <td className="kv-k">Phạm vi</td>
                <td className="kv-v">{last.scope.collectionName ?? "Toàn bộ kho"}</td>
              </tr>
              <tr>
                <td className="kv-k">Từ vựng</td>
                <td className="kv-v">{last.counts.vocabItems}</td>
              </tr>
              <tr>
                <td className="kv-k">Card</td>
                <td className="kv-v">{last.counts.cards}</td>
              </tr>
              <tr>
                <td className="kv-k">Review log</td>
                <td className="kv-v">{last.counts.reviewLogs}</td>
              </tr>
              <tr>
                <td className="kv-k">File</td>
                <td className="kv-v">{last.filename}</td>
              </tr>
            </tbody>
          </table>

          {/* Đường thủ công: luôn có, kể cả khi share/download đã thành công. */}
          <details style={{ marginTop: 12 }}>
            <summary className="dim">Không tải được? Mở nội dung để copy</summary>
            <textarea
              className="dump"
              readOnly
              value={last.content}
              rows={10}
              onFocus={(e) => e.currentTarget.select()}
              aria-label="Nội dung file export"
            />
            <button
              type="button"
              className="secondary"
              onClick={() => void navigator.clipboard?.writeText(last.content)}
            >
              📋 Copy nội dung
            </button>
          </details>

          {last.counts.vocabItems === 0 && (
            <p className="fine">
              Phạm vi này chưa có từ nào — file vẫn hợp lệ (chỉ có header), không phải lỗi.
            </p>
          )}
        </>
      )}

      <p className="fine">
        Anki: File → Import, chọn file `.tsv`. Cột theo thứ tự term · pos · ipa · meaning_vi · cefr
        · example · collection — map vào note type của bạn trong hộp thoại import.
      </p>

      <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
        ← Về trang chủ
      </button>
    </div>
  )
}
