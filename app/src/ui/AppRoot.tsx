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
import { newId, toUtcIso } from "../domain/utils";
import { AppEnvContext } from "./context";
import type { AppEnv } from "./context";
import { CaptureScreen } from "./screens/CaptureScreen";
import { CramScreen } from "./screens/CramScreen";
import { ExportScreen } from "./screens/ExportScreen";
import { HomeScreen } from "./screens/HomeScreen";
import { ReadScreen } from "./screens/ReadScreen";
import type { SessionPage } from "./screens/ReadScreen";
import { appendSessionPage, markPageSaved } from "./readSegments";
import { StorageCheckScreen } from "./screens/StorageCheckScreen";
import { VocabEditScreen } from "./screens/VocabEditScreen";
import { VocabLibraryScreen } from "./screens/VocabLibraryScreen";
import { ReviewScreen } from "./screens/ReviewScreen";

export type Screen =
  | { name: "home" }
  | { name: "capture" }
  | { name: "vocabEdit"; analysis: AnalysisResult; collectionId: string; pageId: string }
  | { name: "readSession" }
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

  // FR-05 c.4 (Q-10 chốt): buffer phiên đọc — 10 trang GẦN NHẤT, sống ở state
  // AppRoot nên F5/đóng tab = hết phiên = buffer xoá. Trang KHÔNG bao giờ ghi
  // xuống DB (NFR-04: không lưu ảnh, không lưu văn bản trang).
  const [sessionPages, setSessionPages] = useState<SessionPage[]>([]);
  const handleAnalyzed = useCallback((analysis: AnalysisResult, collectionId: string) => {
    setSessionPages((prev) => appendSessionPage(prev, { pageId: newId(), analysis, collectionId }));
    setScreen({ name: "readSession" });
    window.scrollTo(0, 0);
  }, []);

  // FR-09 + chống lưu trùng (bug owner báo 2026-09-09): ngay khi màn duyệt từ
  // save xong, đánh dấu trang gốc trong buffer là "đã lưu" → màn đọc làm mờ +
  // khoá nút "Chọn từ" của trang đó, không thể lưu lại lần hai trong phiên.
  const handlePageSaved = useCallback((pageId: string, savedCount: number) => {
    setSessionPages((prev) => markPageSaved(prev, pageId, toUtcIso(new Date()), savedCount));
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
        {screen.name === "home" && (
          <HomeScreen
            navigate={navigate}
            onResumeReading={
              sessionPages.length > 0
                ? { pageCount: sessionPages.length, onClick: () => navigate({ name: "readSession" }) }
                : null
            }
          />
        )}
        {screen.name === "capture" && <CaptureScreen navigate={navigate} onAnalyzed={handleAnalyzed} />}
        {screen.name === "readSession" && <ReadScreen pages={sessionPages} navigate={navigate} />}
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
        {screen.name === "vocabLibrary" && <VocabLibraryScreen navigate={navigate} />}
      </main>
    </AppEnvContext.Provider>
  );
}