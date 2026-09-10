/**
 * ui/AppRoot.tsx — shell + router màn hình kiểu state machine (không cần
 * react-router cho R1). Màn hình Phase 2: home / capture / vocabEdit / review /
 * storageCheck (?screen=storage-check cho SPIKE iPhone). Phase 3: export (FR-16,
 * task 3.7) + vocabLibrary (FR-08, task 3.4) + settings (FR-15, task 3.6) +
 * collectionDetail (task 3.15).
 *
 * Enhancement 2026-09-10 (ADR-017 + ADR-021 + ADR-020 + ADR-015):
 * - điều hướng chuyển sang Zustand (ui/store/navigationStore.ts) — AppRoot chỉ
 *   còn là shell; `Screen` re-export ở đây để các màn hình import "../AppRoot"
 *   không phải sửa;
 * - màn hình import bằng React.lazy + Suspense (tách chunk, PWA vẫn precache);
 * - lỗi nền (persist phiên đọc / cờ đã-lưu) báo bằng TOAST thay vì console.error;
 * - banner "ngoại tuyến" khi mất mạng (capture cần mạng, ôn tập thì không).
 *
 * Task 3.15 (Q-10-reopen 2026-09-09): buffer phiên đọc in-memory đã BỎ — phiên
 * đọc là dữ liệu bền trong bảng `reading_sessions` (10 mới nhất mỗi collection),
 * AnalyzePanel tự ghi sau khi phân tích thành công nên AppRoot không giữ trang
 * nào trong state nữa. Luật "lưu 1 lần" (bug 6723302) giờ persist qua
 * `saved_at` trong DB — mở lại app vẫn nhớ trang nào đã lưu.
 */
import { lazy, Suspense, useCallback, useEffect, useState } from "react"
import type { BootstrapResult } from "../app/bootstrap"
import type { AnalysisResult } from "../domain/types"
import { markReadingSessionSaved, persistReadingSession } from "../domain/usecases/readingSessions"
import { AppEnvContext } from "./context"
import type { AppEnv } from "./context"
import { useNavigationStore } from "./store/navigationStore"
import { useToast } from "./toast"

export type { Screen } from "./store/navigationStore"

// React.lazy (ADR-021): mỗi màn hình một chunk riêng, chỉ tải khi navigate tới.
const CaptureScreen = lazy(() =>
  import("./screens/CaptureScreen").then((m) => ({ default: m.CaptureScreen })),
)
const CollectionDetailScreen = lazy(() =>
  import("./screens/CollectionDetailScreen").then((m) => ({ default: m.CollectionDetailScreen })),
)
const CramScreen = lazy(() =>
  import("./screens/CramScreen").then((m) => ({ default: m.CramScreen })),
)
const ExportScreen = lazy(() =>
  import("./screens/ExportScreen").then((m) => ({ default: m.ExportScreen })),
)
const HomeScreen = lazy(() =>
  import("./screens/HomeScreen").then((m) => ({ default: m.HomeScreen })),
)
const ReadScreen = lazy(() =>
  import("./screens/ReadScreen").then((m) => ({ default: m.ReadScreen })),
)
const ReviewScreen = lazy(() =>
  import("./screens/ReviewScreen").then((m) => ({ default: m.ReviewScreen })),
)
const SettingsScreen = lazy(() =>
  import("./screens/SettingsScreen").then((m) => ({ default: m.SettingsScreen })),
)
const StorageCheckScreen = lazy(() =>
  import("./screens/StorageCheckScreen").then((m) => ({ default: m.StorageCheckScreen })),
)
const VocabEditScreen = lazy(() =>
  import("./screens/VocabEditScreen").then((m) => ({ default: m.VocabEditScreen })),
)
const VocabLibraryScreen = lazy(() =>
  import("./screens/VocabLibraryScreen").then((m) => ({ default: m.VocabLibraryScreen })),
)

export function AppRoot({ boot }: { boot: BootstrapResult }) {
  const screen = useNavigationStore((s) => s.screen)
  const navigate = useNavigationStore((s) => s.navigate)
  const toast = useToast()

  // Offline indicator (ADR-015): ôn tập chạy offline; chụp + phân tích cân mạng.
  const [online, setOnline] = useState<boolean>(() => globalThis.navigator?.onLine ?? true)
  useEffect(() => {
    const go = () => setOnline(true)
    const off = () => setOnline(false)
    window.addEventListener("online", go)
    window.addEventListener("offline", off)
    return () => {
      window.removeEventListener("online", go)
      window.removeEventListener("offline", off)
    }
  }, [])

  // Task 3.15 (Q-10-reopen): sau khi AnalyzePanel đã ghi analyses (analysisId),
  // persist PHIÊN ĐỌC vào reading_sessions (text + dịch — ảnh vẫn cấm) rồi mở
  // màn đọc. Ghi hỏng không chặn người dùng xem kết quả (màn duyệt từ vẫn lưu
  // được từ) nhưng phải HIỆN TOAST — không nuốt im lặng (ADR-020).
  const handleAnalyzed = useCallback(
    (analysis: AnalysisResult, collectionId: string, analysisId: string) => {
      if (analysisId !== "") {
        void persistReadingSession(boot.services, analysisId, collectionId, analysis).catch(() => {
          toast.error(
            "Không lưu được phiên đọc này — trang vẫn xem được, nhưng sẽ không còn sau khi đóng ứng dụng.",
          )
        })
      }
      navigate({ name: "readSession" })
    },
    [boot.services, navigate, toast],
  )

  // FR-09 + chống lưu trùng (bug owner báo 2026-09-09): ngay khi màn duyệt từ
  // save xong, PERSIST cờ "đã lưu" vào reading_sessions (task 3.15 — trước đây
  // chỉ ở state, chết theo phiên). Màn đọc đọc lại từ DB nên khoá theo người
  // dùng cả sau khi F5.
  const handlePageSaved = useCallback(
    (pageId: string, savedCount: number) => {
      void markReadingSessionSaved(boot.services, pageId, savedCount).catch(() => {
        // Cờ hỏng = user có thể lưu trùng lần sau — phải được thấy.
        toast.error(
          "Không đánh dấu được trang đã lưu — bạn có thể lưu trùng trang này vào lần mở sau.",
        )
      })
    },
    [boot.services, toast],
  )

  const env: AppEnv = {
    services: boot.services,
    storageWarnings: boot.storageWarnings,
    storageMode: boot.storageMode,
    previousBootAt: boot.previousBootAt,
  }

  const screenLoading = (
    <div className="pad">
      <div className="analyzing">
        <div className="spinner" aria-hidden="true" />
        <p className="muted">Đang mở màn hình…</p>
      </div>
    </div>
  )

  return (
    <AppEnvContext.Provider value={env}>
      {!globalThis.isSecureContext && (
        <div className="banner banner-error">
          Trang này mở qua http:// + IP LAN nên trình duyệt chặn lưu trữ (OPFS) và offline — dữ liệu
          sẽ mất khi đóng tab. Mở app bằng <b>https://</b> cùng địa chỉ (xem màn{" "}
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
      {!online && (
        <div className="banner banner-warn">
          Bạn đang ngoại tuyến — ôn tập vẫn chạy bình thường, nhưng chụp & phân tích trang cần mạng.
        </div>
      )}
      <main className="shell">
        <Suspense fallback={screenLoading}>
          {screen.name === "home" && <HomeScreen navigate={navigate} />}
          {screen.name === "capture" && (
            <CaptureScreen navigate={navigate} onAnalyzed={handleAnalyzed} />
          )}
          {screen.name === "readSession" && (
            <ReadScreen navigate={navigate} sessionId={screen.sessionId} />
          )}
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
        </Suspense>
      </main>
    </AppEnvContext.Provider>
  )
}
