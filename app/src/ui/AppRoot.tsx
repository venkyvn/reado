/**
 * ui/AppRoot.tsx — shell + router màn hình kiểu state machine (không cần
 * react-router cho R1). Màn hình Phase 2: home / capture / vocabEdit / review /
 * storageCheck (?screen=storage-check cho SPIKE iPhone).
 *
 * Một điểm THẬT duy nhất giữ state điều hướng; mỗi màn hình chỉ nhận navigate
 * + payload hẹp — không màn nào tự ý biết màn khác.
 */
import { useCallback, useState } from "react";
import type { BootstrapResult } from "../app/bootstrap";
import type { AnalysisResult } from "../domain/types";
import { AppEnvContext } from "./context";
import type { AppEnv } from "./context";
import { CaptureScreen } from "./screens/CaptureScreen";
import { HomeScreen } from "./screens/HomeScreen";
import { StorageCheckScreen } from "./screens/StorageCheckScreen";

export type Screen =
  | { name: "home" }
  | { name: "capture" }
  | { name: "vocabEdit"; analysis: AnalysisResult; collectionId: string }
  | { name: "review" }
  | { name: "storageCheck" };

function initialScreen(): Screen {
  if (typeof window !== "undefined" && new URLSearchParams(window.location.search).get("screen") === "storage-check") {
    return { name: "storageCheck" };
  }
  return { name: "home" };
}

/** Màn duyệt từ chưa có ở step UI-1 — placeholder để capture flow đứng vững;
 *  step UI-2 thay bằng màn hình FR-03/FR-09 thật. */
function VocabEditPlaceholder({ analysis, collectionId, navigate }: {
  analysis: AnalysisResult;
  collectionId: string;
  navigate: (s: Screen) => void;
}) {
  void collectionId;
  return (
    <div className="pad">
      <h1>Kết quả phân tích (tạm — màn duyệt từ ở step kế)</h1>
      <p className="muted">{analysis.vocabulary.length} từ trích xuất · {analysis.segments.length} đoạn.</p>
      <ul className="dump">
        {analysis.vocabulary.slice(0, 20).map((v, i) => (
          <li key={i}>
            <strong>{v.term}</strong> ({v.pos}) — {v.meaningVi} ·{" "}
            <span className={`chip chip-${v.verification}`}>{v.verification}</span>
          </li>
        ))}
      </ul>
      {analysis.vocabulary.length > 20 && <p className="muted">… còn {analysis.vocabulary.length - 20} từ</p>}
      <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
        ← Về trang chủ
      </button>
    </div>
  );
}

export function AppRoot({ boot }: { boot: BootstrapResult }) {
  const [screen, setScreen] = useState<Screen>(initialScreen);
  const navigate = useCallback((s: Screen) => {
    setScreen(s);
    window.scrollTo(0, 0);
  }, []);

  const env: AppEnv = {
    services: boot.services,
    storageWarnings: boot.storageWarnings,
    storageMode: boot.storageMode,
  };

  return (
    <AppEnvContext.Provider value={env}>
      {env.storageMode !== "opfs" && (
        <div className="banner banner-warn">
          Không mở được kho lưu trữ OPFS — dữ liệu SẼ MẤT khi đóng tab.{" "}
          <a href="#storageweb" onClick={() => navigate({ name: "storageCheck" })}>
            Xem chi tiết
          </a>
        </div>
      )}
      <main className="shell">
        {screen.name === "home" && <HomeScreen navigate={navigate} />}
        {screen.name === "capture" && <CaptureScreen navigate={navigate} />}
        {screen.name === "vocabEdit" && (
          <VocabEditPlaceholder analysis={screen.analysis} collectionId={screen.collectionId} navigate={navigate} />
        )}
        {screen.name === "review" && (
          // step UI-3 thay bằng màn ôn thật (FR-11/FR-12)
          <div className="pad">
            <h1>Ôn tập</h1>
            <p className="muted">Màn ôn tập sẽ đến ở step kế.</p>
            <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
              ← Về trang chủ
            </button>
          </div>
        )}
        {screen.name === "storageCheck" && <StorageCheckScreen navigate={navigate} />}
      </main>
    </AppEnvContext.Provider>
  );
}