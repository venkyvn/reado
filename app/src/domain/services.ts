/**
 * domain/services.ts — "service container" UI cầm trong tay.
 *
 * Bootstrap (app/bootstrap.ts) lắp ráp đúng dependency rule: repos thật từ
 * storage, scheduler thật từ domain, provider thật từ ai — rồi UI chỉ nhìn
 * thấy object này. Test (node) lắp ráp bằng repo SQLite in-memory thật, nên
 * use-case gần như không cần mock.
 */
import type { AiProvider } from "./ai"
import type { ReadoRepos } from "./repositories"
import type { Scheduler } from "./scheduler"

export interface AppServices {
  repos: ReadoRepos
  scheduler: Scheduler
  ai: AiProvider
  /** Clock injectable — mọi phép tính "hôm nay" phải đi qua đây (test được). */
  now: () => Date
  /** Múi giờ thiết bị — chỗ duy nhất đụng giờ địa phương (solution-design mục 6). */
  timeZone: () => string
}
