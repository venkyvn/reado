/**
 * testing/memServices.ts — dựng AppServices thật trên SQLite in-memory (không mock).
 *
 * Dùng cho test: use-case chạy trên storage THẬT (kernel in-memory + migrate +
 * seed + repos thật), chỉ AI provider là fake (network không vào test). Clock và
 * timezone injectable — kịch bản giờ giấc (day cutoff, due) chạy tất định.
 */
import type { AiProvider } from "../domain/ai";
import { createScheduler } from "../domain/scheduler";
import type { AppServices } from "../domain/services";
import { initAppDb } from "../storage/db";
import { openMemoryKernel } from "../storage/kernel";
import { createRepos } from "../storage/repos";

export interface MemServicesOptions {
  now?: () => Date;
  timeZone?: string;
  ai?: AiProvider;
}

/** Fake AI: trả kết quả cố định hoặc ném lỗi — test không bao giờ hit mạng. */
export function makeFakeAi(impl: AiProvider["analyzePage"]): AiProvider {
  return { analyzePage: impl };
}

export async function createMemServices(opts: MemServicesOptions = {}): Promise<AppServices> {
  const kernel = await openMemoryKernel();
  const appDb = initAppDb(kernel);
  const repos = createRepos(appDb);
  const settings = await repos.settings.get();
  const scheduler = createScheduler({
    requestRetention: settings.requestRetention,
    maximumInterval: settings.maximumInterval,
    // Tắt fuzz trong test: interval phải tất định để so được due_at chính xác.
    enableFuzz: false,
  });
  return {
    repos,
    scheduler,
    ai: opts.ai ?? makeFakeAi(async () => {
      throw new Error("fake AI chưa được cấu hình cho test này");
    }),
    now: opts.now ?? (() => new Date()),
    timeZone: () => opts.timeZone ?? "Asia/Ho_Chi_Minh",
  };
}

/** Sample item đã xác minh cho test save/queue — verification không quan trọng ở tầng này. */
export function sampleItem(overrides: Partial<import("../domain/types").AnalyzedItem> = {}): import("../domain/types").AnalyzedItem {
  return {
    term: "staggering",
    pos: "adj",
    ipa: "/ˈstæɡərɪŋ/",
    meaningVi: "đáng kinh ngạc",
    cefr: "B2",
    example: "The staggering scale of the problem.",
    verification: "verified",
    ...overrides,
  };
}