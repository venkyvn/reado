/**
 * ui/AppRoot.tsx — shell + router màn hình kiểu state machine (không cần
 * react-router cho R1). Màn hình Phase 2: home / capture / vocabEdit / review /
 * storageCheck (?screen=storage-check cho SPIKE iPhone). Phase 3: export (FR-16,
 * task 3.7) + vocabLibrary (FR-08, task 3.4) + settings (FR-15, task 3.6) +
 * collectionDetail (task 3.15).
 *
 * Một điểm THẬT duy nhất giữ state điều hướng; mỗi màn hình chỉ nhận navigate
 * + payload hẹp — không màn nào tự ý biết màn khác.
 *
 * Task 3.15 (Q-10-reopen 2026-09-09): buffer phiên đọc in-memory đã BỎ — phiên
 * đọc là dữ liệu bền trong bảng `reading_sessions` (10 mới nhất mỗi collection),
 * AnalyzePanel tự ghi sau khi phân tích thành công nên AppRoot không giữ trang
 * nào trong state nữa. Luật "lưu 1 lần" (bug 6723302) giờ persist qua
 * `saved_at` trong DB — mở lại app vẫn nhớ trang nào đã lưu.
 */
import { useCallback, useState } from "react";
import type { BootstrapResult } from "../app/bootstrap";
import type { AnalysisResult } from "../domain/types";
import { markReadingSessionSaved, persistReadingSession } from "../domain/usecases/readingSessions";
import { AppEnvContext } from "./context";
import type { AppEnv } from "./context";
import { CaptureScreen } from "./screens/CaptureScreen";
import { CollectionDetailScreen } from "./screens/CollectionDetailScreen";
import { CramScreen } from "./screens/CramScreen";
import { ExportScreen } from "./screens/ExportScreen";
import { HomeScreen } from "./screens/HomeScreen";
import { ReadScreen } from "./screens/ReadScreen";
import { SettingsScreen } from "./screens/SettingsScreen";
import { StorageCheckScreen } from "./screens/StorageCheckScreen";
import { VocabEditScreen } from "./screens/VocabEditScreen";
import { VocabLibraryScreen } from "./screens/VocabLibraryScreen";
import { ReviewScreen } from "./screens/ReviewScreen";

export type Screen =
  | { name: "home" }
  | { name: "capture" }
  | { name: "vocabEdit"; analysis: AnalysisResult; collectionId: string; pageId: string }
  | { name: "readSession"; sessionId?: string }
  | { name: "review" }
  | { name: "cram" }
  | { name: "storageCheck" }
  | { name: "export" }
  | { name: "settings" }
  | { name: "vocabLibrary" }
  | { name: "collectionDetail"; collectionId: string };

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

  // Task 3.15 (Q-10-reopen): sau khi AnalyzePanel đã ghi analyses (analysisId),
  // persist PHIÊN ĐỌC vào reading_sessions (text + dịch — ảnh vẫn cấm) rồi mở
  // màn đọc. Ghi hỏng không chặn người dùng xem kết quả (màn duyệt từ vẫn lưu
  // được từ) nhưng phải lưu dấu vết — không nuốt im lặng.
  const handleAnalyzed = useCallback(
    (analysis: AnalysisResult, collectionId: string, analysisId: string) => {
      if (analysisId !== "") {
        void persistReadingSession(boot.services, analysisId, collectionId, analysis).catch((e: unknown) => {
          console.error("Không persist được phiên đọc:", e);
        });
      }
      setScreen({ name: "readSession" });
      window.scrollTo(0, 0);
    },
    [boot.services],
  );

  // FR-09 + chống lưu trùng (bug owner báo 2026-09-09): ngay khi màn duyệt từ
  // save xong, PERSIST cờ "đã lưu" vào reading_sessions (task 3.15 — trước đây
  // chỉ ở state, chết theo phiên). Màn đọc đọc lại từ DB nên khoá theo người
  // dùng cả sau khi F5.
  const handlePageSaved = useCallback(
    (pageId: string, savedCount: number) => {
      void markReadingSessionSaved(boot.services, pageId, savedCount).catch((e: unknown) => {
        // Không nuốt im lặng: cờ hỏng = user có thể lưu trùng lần sau.
        console.error("Không persist được cờ 'đã lưu' của phiên đọc:", e);
      });
    },
    [boot.services],
  );

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
        {screen.name === "capture" && <CaptureScreen navigate={navigate} onAnalyzed={handleAnalyzed} />}
        {screen.name === "readSession" && <ReadScreen navigate={navigate} sessionId={screen.sessionId} />}
        {screen.name === "vocabEdit" && (
          <VocabEditScreen
            analysis={screen.analysis}
            collectionId={screen.collectionId}
            pageId={screen.pageId}
            onSaved={handlePageSaved}
            navigate={navigate}
          />
        )}
        {screen.name === "review" && <ReviewScreen navigate={navigate} />}
        {screen.name === "cram" && <CramScreen navigate={navigate} />}
        {screen.name === "storageCheck" && <StorageCheckScreen navigate={navigate} />}
        {screen.name === "export" && <ExportScreen navigate={navigate} />}
        {screen.name === "settings" && <SettingsScreen navigate={navigate} />}
        {screen.name === "vocabLibrary" && <VocabLibraryScreen navigate={navigate} />}
        {screen.name === "collectionDetail" && (
          <CollectionDetailScreen collectionId={screen.collectionId} navigate={navigate} />
        )}
      </main>
    </AppEnvContext.Provider>
  );
}
