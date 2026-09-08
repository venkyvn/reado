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
import { VocabEditScreen } from "./screens/VocabEditScreen";
import { ReviewScreen } from "./screens/ReviewScreen";

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
          <VocabEditScreen analysis={screen.analysis} collectionId={screen.collectionId} navigate={navigate} />
        )}
        {screen.name === "review" && <ReviewScreen navigate={navigate} />}
        {screen.name === "storageCheck" && <StorageCheckScreen navigate={navigate} />}
      </main>
    </AppEnvContext.Provider>
  );
}