/**
 * ui/context.tsx — môi trường chạy app (services + cảnh báo storage) cho React.
 *
 * AppRoot (một trình duy nhất) lắp BootstrapResult vào context; màn hình chỉ
 * dùng useAppEnv() — không screen nào tự dựng dependencies.
 */
/* oxlint-disable react/only-export-components — hook + context object đi cặp, tách file = thêm indirection vô ích */
import { createContext, useContext } from "react"
import type { AppServices } from "../domain/services"

export interface AppEnv {
  services: AppServices
  storageWarnings: string[]
  storageMode: "opfs" | "memory"
  /** Marker lần mở trước — bằng chứng dữ liệu sống qua reload (null = chưa persist). */
  previousBootAt: string | null
}

const AppEnvContext = createContext<AppEnv | null>(null)

export function useAppEnv(): AppEnv {
  const env = useContext(AppEnvContext)
  if (!env) throw new Error("useAppEnv phải chạy trong AppEnvContext.Provider (AppRoot)")
  return env
}

export { AppEnvContext }
