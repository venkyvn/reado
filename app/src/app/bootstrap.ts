/**
 * app/bootstrap.ts — lắp ráp dependencies thật theo dependency rule
 * (solution-design mục 3.1): storage thật + scheduler thật + Gemini thật → AppServices.
 *
 * Kết quả là thứ DUY NHẤT UI được cầm; UI không bao giờ import storage/ai trực tiếp.
 */
import { createGeminiProvider } from "../ai/gemini";
import { createScheduler } from "../domain/scheduler";
import type { AppServices } from "../domain/services";
import { initAppDb } from "../storage/db";
import { openKernel } from "../storage/kernel";
import { createRepos } from "../storage/repos";

export interface BootstrapResult {
  services: AppServices;
  /** Cảnh báo vận hành (VFS/OPFS/WAL) — app phải HIỂN THỊ, không nuốt. */
  storageWarnings: string[];
  /** "opfs" = lưu thật; "memory" = mất khi đóng — app phải cảnh báo rõ. */
  storageMode: "opfs" | "memory";
}

export async function bootstrap(): Promise<BootstrapResult> {
  const kernel = await openKernel();
  const appDb = initAppDb(kernel);
  const repos = createRepos(appDb);
  const settings = await repos.settings.get();

  const services: AppServices = {
    repos,
    scheduler: createScheduler({
      requestRetention: settings.requestRetention,
      maximumInterval: settings.maximumInterval,
      enableFuzz: settings.enableFuzz,
    }),
    ai: createGeminiProvider(),
    now: () => new Date(),
    timeZone: () => Intl.DateTimeFormat().resolvedOptions().timeZone,
  };

  return { services, storageWarnings: kernel.warnings, storageMode: kernel.mode };
}