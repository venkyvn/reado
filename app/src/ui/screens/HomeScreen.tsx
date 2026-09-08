/**
 * ui/screens/HomeScreen.tsx — hub tối giản cho walking skeleton (chưa phải
 * FR-14 — số nợ/counters là quyết định UI-3 phase 3). NFR-08: chụp = 1 chạm từ đây.
 */
import type { Screen } from "../AppRoot";

export function HomeScreen({ navigate }: { navigate: (s: Screen) => void }) {
  return (
    <div className="home pad">
      <h1 className="brand">Reado</h1>
      <p className="muted">Ảnh trang sách → song ngữ + từ vựng ôn tập cách quãng (FSRS).</p>

      <button type="button" className="primary big" onClick={() => navigate({ name: "capture" })}>
        📷 Chụp trang sách
      </button>
      <button type="button" className="primary big alt" onClick={() => navigate({ name: "review" })}>
        🃏 Ôn tập hôm nay
      </button>

      <p style={{ marginTop: 24 }}>
        <a className="dim" href="#export" onClick={() => navigate({ name: "export" })}>
          ⬇︎ Xuất dữ liệu (Anki / JSON)
        </a>
        {" · "}
        <a className="dim" href="#storage" onClick={() => navigate({ name: "storageCheck" })}>
          Kiểm tra lưu trữ (SPIKE)
        </a>
      </p>
    </div>
  );
}