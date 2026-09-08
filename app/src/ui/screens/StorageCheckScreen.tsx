/**
 * ui/screens/StorageCheckScreen.tsx — trang SPIKE storage (mở bằng
 * ?screen=storage-check): bằng chứng OPFS trên iPhone — mode, crossOriginIsolated,
 * cảnh báo, write/read round-trip, số liệu kho. KHÔNG hiện giá trị API key —
 * chỉ hiện "đã/chưa cấu hình".
 */
import { useEffect, useState } from "react";
import type { Screen } from "../AppRoot";
import { useAppEnv } from "../context";

interface CheckInfo {
  collections: number;
  vocabInDefault: number;
  dueCards: number;
  keyConfigured: boolean;
}

export function StorageCheckScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services, storageMode, storageWarnings } = useAppEnv();
  const [info, setInfo] = useState<CheckInfo | null>(null);
  const [writeTest, setWriteTest] = useState<"idle" | "ok" | "fail">("idle");
  const [fatal, setFatal] = useState<string | null>(null);

  const crossOriginIsolated =
    typeof (globalThis as { crossOriginIsolated?: boolean }).crossOriginIsolated === "boolean"
      ? (globalThis as { crossOriginIsolated: boolean }).crossOriginIsolated
      : false;

  useEffect(() => {
    void (async () => {
      try {
        const [cols, def, settings] = await Promise.all([
          services.repos.collections.list(),
          services.repos.collections.getDefault(),
          services.repos.settings.get(),
        ]);
        const vocabInDefault = def
          ? (await services.repos.vocabItems.listByCollection(def.id)).length
          : 0;
        const nowUtc = new Date().toISOString();
        const base = { nowUtc, scopeCollectionIds: null, limit: null };
        const dueCards =
          (await services.repos.cards.listDueReviews(base)).length +
          (await services.repos.cards.listDueNews(base)).length;

        // Write/read round-trip thật — ghi LẠI giá trị hiện có (không đổi data).
        await services.repos.settings.updatePartial({ requestRetention: settings.requestRetention });
        await services.repos.settings.get();
        setWriteTest("ok");

        setInfo({
          collections: cols.length,
          vocabInDefault,
          dueCards,
          keyConfigured: Boolean(settings.aiApiKey),
        });
      } catch (err) {
        setWriteTest("fail");
        setFatal(err instanceof Error ? err.message : String(err));
      }
    })();
  }, [services]);

  return (
    <div className="pad">
      <h1>Kiểm tra lưu trữ</h1>

      <table className="kv">
        <tbody>
          <Row label="OPFS active" ok={storageMode === "opfs"} value={storageMode === "opfs" ? "Có — lưu thật trên máy" : "KHÔNG — mất khi đóng tab"} />
          <Row
            label="crossOriginIsolated"
            ok={crossOriginIsolated}
            value={crossOriginIsolated ? "Có (SharedArrayBuffer OK)" : "KHÔNG — OPFS không dùng được"}
          />
          <Row label="Write/read SQLite" ok={writeTest === "ok"} value={writeTest === "ok" ? "Ghi + đọc lại OK" : writeTest === "fail" ? "LỖI" : "…"} />
          <Row label="API key AI" ok={false} value={info ? (info.keyConfigured ? "Đã cấu hình" : "Chưa cấu hình (sẽ nhắc khi chụp)") : "…"} />
          <Row label="Collection" ok={false} value={info ? String(info.collections) : "…"} />
          <Row label="Từ trong Kho tạm" ok={false} value={info ? String(info.vocabInDefault) : "…"} />
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
        SPIKE task 2.4-đi-kiện (solution-design 14.2): trên iPhone mở ⓐ và xem hàng “OPFS
        active”. Nếu KHÔNG có kèm theo cảnh báo WAL — app giữ dữ liệu qua các lần mở.
      </p>

      <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
        ← Về trang chủ
      </button>
    </div>
  );
}

function Row({ label, value, ok }: { label: string; value: string; ok: boolean }) {
  return (
    <tr>
      <td className="kv-k">{label}</td>
      <td className={`kv-v ${ok ? "kv-ok" : ""}`}>{value}</td>
    </tr>
  );
}