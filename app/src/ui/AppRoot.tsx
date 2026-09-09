/**
 * ui/AppRoot.tsx — shell + router màn hình kiểu state machine (không cần
 * react-router cho R1). Màn hình Phase 2: home / capture / vocabEdit / review /
 * storageCheck (?screen=storage-check cho SPIKE iPhone). Phase 3: export (FR-16,
 * task 3.7) + vocabLibrary (FR-08, task 3.4).
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
import { CramScreen } from "./screens/CramScreen";
import { ExportScreen } from "./screens/ExportScreen";
import { HomeScreen } from "./screens/HomeScreen";
import { StorageCheckScreen } from "./screens/StorageCheckScreen";
import { VocabEditScreen } from "./screens/VocabEditScreen";
import { VocabLibraryScreen } from "./screens/VocabLibraryScreen";
import { ReviewScreen } from "./screens/ReviewScreen";

export type Screen =
  | { name: "home" }
  | { name: "capture" }
  | { name: "vocabEdit"; analysis: AnalysisResult; collectionId: string }
  | { name: "review" }
  | { name: "cram" }
  | { name: "storageCheck" }
  | { name: "export" }
  | { name: "vocabLibrary" };

function initialScreen(): Screen {
  if (typeof window !== "undefined" && new URLSearchParams(window.location.search).get("screen") === "storage-check") {
    return { name: "storageCheck" };
  }
  return { name: "home" };
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
    previousBootAt: boot.previousBootAt,
  };

  return (
    <AppEnvContext.Provider value={env}>
      {!globalThis.isSecureContext && (
        <div className="banner banner-error">
          Trang này mở qua http:// + IP LAN nên trình duyệt chặn lưu trữ (OPFS) và
          offline — dữ liệu sẽ mất khi đóng tab. Mở app bằng <b>https://</b> cùng địa
          chỉ (xem màn{" "}
          <a href="#storageweb" onClick={() => navigate({ name: "storageCheck" })}>
            Kiểm tra lưu trữ
          </a>{" "}
          để có URL chính xác).
        </div>
      )}
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
          <VocabEditScreen analysis={screen.analysis} collectionId={screen.collectionId} navigate={navigate} />
        )}
        {screen.name === "review" && <ReviewScreen navigate={navigate} />}
        {screen.name === "cram" && <CramScreen navigate={navigate} />}
        {screen.name === "storageCheck" && <StorageCheckScreen navigate={navigate} />}
        {screen.name === "export" && <ExportScreen navigate={navigate} />}
        {screen.name === "vocabLibrary" && <VocabLibraryScreen navigate={navigate} />}
      </main>
    </AppEnvContext.Provider>
  );
}