/**
 * ui/store/navigationStore.ts — store Zustand giữ điều hướng (ADR-017: setup
 * architecture, đây là store ví dụ đầu tiên — KHÔNG refactor toàn bộ app sang
 * Zustand một phát).
 *
 * Chuyển từ `useState` trong AppRoot sang đây: một điểm THẬT duy nhất giữ state
 * điều hướng, mọi màn hình đọc cùng một nguồn. `navigate` tự scroll về đầu trang
 * (đúng hành vi cũ), nên không cần nhớ scroll mỗi chỗ gọi.
 *
 * Kiểu `Screen` chuyển hẳn về đây; AppRoot re-export để các màn hình import
 * `../AppRoot` không phải sửa.
 */
import { create } from "zustand"
import type { AnalysisResult } from "../../domain/types"

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
  | { name: "collectionDetail"; collectionId: string }

function initialScreen(): Screen {
  if (
    typeof window !== "undefined" &&
    new URLSearchParams(window.location.search).get("screen") === "storage-check"
  ) {
    return { name: "storageCheck" }
  }
  return { name: "home" }
}

interface NavigationState {
  screen: Screen
  navigate(s: Screen): void
}

export const useNavigationStore = create<NavigationState>((set) => ({
  screen: initialScreen(),
  navigate: (s) => {
    set({ screen: s })
    if (typeof window !== "undefined") window.scrollTo(0, 0)
  },
}))
