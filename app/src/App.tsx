/**
 * App.tsx — điểm vào React duy nhất: chờ bootstrap (SQLite + services) rồi giao
 * quyền render cho AppRoot. Giai đoạn chờ hiện màn "Đang mở kho dữ liệu…"; lỗi
 * bootstrap là lỗi HIỂN THỊ ĐƯỢC, không phải màn hình trắng.
 */
import { useEffect, useState } from "react";
import { bootstrap } from "./app/bootstrap";
import type { BootstrapResult } from "./app/bootstrap";
import { AppRoot } from "./ui/AppRoot";

function App() {
  const [boot, setBoot] = useState<BootstrapResult | null>(null);
  const [bootError, setBootError] = useState<string | null>(null);

  useEffect(() => {
    // StrictMode (dev) mount 2 lần: dùng cờ cancell để lần đầu bị bỏ, không
    // để bootstrap chạy đè nhau.
    let cancelled = false;
    bootstrap()
      .then((result) => {
        if (!cancelled) setBoot(result);
      })
      .catch((err: unknown) => {
        if (!cancelled) setBootError(err instanceof Error ? err.message : String(err));
      });
    return () => {
      cancelled = true;
    };
  }, []);

  if (bootError) {
    return (
      <main className="shell">
        <div className="banner banner-error">
          Không khởi động được kho dữ liệu: {bootError}
        </div>
      </main>
    );
  }
  if (!boot) {
    return (
      <main className="shell">
        <div className="boot-loading">
          <div className="spinner" aria-hidden="true" />
          <p>Đang mở kho dữ liệu…</p>
        </div>
      </main>
    );
  }
  return <AppRoot boot={boot} />;
}

export default App;