/**
 * App skeleton — task 1.3 (Phase 1).
 * Mục tiêu duy nhất: PWA chạy được, mở được OFFLINE (NFR-03). Chưa có feature nào —
 * màn hình Home thật (FR-01 capture, FR-18 con số nợ...) nằm ở Phase 2.
 */
import './App.css'

function App() {
  return (
    <main style={{ padding: 24, maxWidth: 480, margin: '0 auto', flex: 1 }}>
      <h1 style={{ margin: '24px 0 4px' }}>Reado</h1>
      <p style={{ margin: 0, opacity: 0.7 }}>
        Skeleton Phase 1 — PWA &amp; offline shell đã lên.
      </p>
      <p style={{ margin: '8px 0 24px', opacity: 0.7 }}>
        Chụp trang → song ngữ → từ vựng → ôn tập: bắt đầu từ Phase 2.
      </p>
      <button type="button" disabled title="Sẽ nối ở Phase 2 (FR-01)">
        📷 Chụp trang sách
      </button>
    </main>
  )
}

export default App