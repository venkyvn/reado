/**
 * integration test — FR-15 (Learning Settings) trên SQLite THẬT: mỗi describe là
 * một criterion Given/When/Then của PRD (AGENTS mục 4: criteria là test case).
 *
 * AI là fake có ghi lại config nhận được — test không hit mạng, nhưng chứng minh
 * được criterion "level mới có hiệu lực ở lần capture kế tiếp" ở đúng ranh giới
 * usecase → provider.
 */
import { describe, expect, it } from "vitest";
import type { AiCallConfig, PageImage } from "../../domain/ai";
import { SettingsError } from "../../domain/errors";
import { DEFAULT_AI_BASE_URL, DEFAULT_AI_MODEL } from "../../domain/settings";
import type { AnalysisResult } from "../../domain/types";
import { analyzePage } from "../../domain/usecases/analyze";
import { buildDueQueue } from "../../domain/usecases/review";
import { saveVocabulary } from "../../domain/usecases/save";
import { getSettings, updateSettings } from "../../domain/usecases/settings";
import { createMemServices, makeFakeAi, sampleItem } from "../../testing/memServices";

const T0 = new Date("2026-09-10T02:00:00.000Z");
const IMG: PageImage = { base64: "ZmFrZQ==", mime: "image/jpeg" };

/** Kết quả AI tối thiểu nhưng hợp lệ — đủ để usecase trả về nguyên vẹn. */
function fakeResult(): AnalysisResult {
  return {
    segments: [{ sourceEn: "The staggering scale of the problem.", translationVi: "Quy mô đáng kinh ngạc của vấn đề." }],
    vocabulary: [sampleItem({ cefr: "B2" })],
    summaryVi: "Tóm tắt thử.",
    usage: { promptTokens: 11, candidatesTokens: 22 },
    latencyMs: 13,
    promptVersion: 2,
  };
}

/** Services đã có BYOK tối thiểu để analyzePage chạy được (key + model). */
async function servicesWithKey(calls?: AiCallConfig[]) {
  const svc = await createMemServices({
    now: () => T0,
    ai: makeFakeAi(async (_img, cfg) => {
      calls?.push(cfg);
      return fakeResult();
    }),
  });
  await updateSettings(svc, { aiApiKey: "AIza-test-key", aiModel: DEFAULT_AI_MODEL });
  return svc;
}

describe("FR-15 criterion 1+2 — CEFR áp cho lần phân tích KẾ TIẾP, không phân tích lại trang cũ", () => {
  it("mặc định B1 → đổi sang C1 → lần gọi AI sau nhận C1; từ đã lưu giữ nguyên CEFR cũ", async () => {
    const calls: AiCallConfig[] = [];
    const svc = await servicesWithKey(calls);
    const def = await svc.repos.collections.getDefault();

    expect((await getSettings(svc)).cefrLevel).toBe("B1");

    const first = await analyzePage(svc, IMG);
    expect(calls[0]?.cefrLevel).toBe("B1");
    await saveVocabulary(svc, { collectionId: def!.id, items: first.vocabulary, now: T0 });

    await updateSettings(svc, { cefrLevel: "C1" });

    const second = await analyzePage(svc, IMG);
    expect(calls[1]?.cefrLevel).toBe("C1");
    expect(calls).toHaveLength(2); // không có lần gọi nào thêm cho trang đã phân tích

    // Trang đã phân tích KHÔNG bị phân tích lại: dữ liệu đã lưu không đổi.
    const saved = await svc.repos.vocabItems.listByCollection(def!.id);
    expect(saved).toHaveLength(1);
    expect(saved[0]?.cefr).toBe("B2");
    expect(second.vocabulary[0]?.cefr).toBe("B2");
  });
});

describe("FR-15 criterion 3 — daily_new_limit chỉnh được, mặc định 10, có hiệu lực ở hàng đợi", () => {
  it("12 thẻ mới: mặc định 10 vào phiên/2 tồn; đổi 3 → 3/9; đổi 0 → 0/12", async () => {
    const svc = await createMemServices({ now: () => T0 });
    const def = await svc.repos.collections.getDefault();
    expect((await getSettings(svc)).dailyNewLimit).toBe(10);

    await saveVocabulary(svc, {
      collectionId: def!.id,
      items: Array.from({ length: 12 }, (_, i) =>
        sampleItem({ term: `word${i}`, example: `word${i} appears on the page.` }),
      ),
      now: T0,
    });

    const before = await buildDueQueue(svc, T0);
    expect(before.total).toBe(10);
    expect(before.deferredNew).toBe(2);

    await updateSettings(svc, { dailyNewLimit: 3 });
    const after = await buildDueQueue(svc, T0);
    expect(after.total).toBe(3);
    expect(after.deferredNew).toBe(9);

    await updateSettings(svc, { dailyNewLimit: 0 });
    const paused = await buildDueQueue(svc, T0);
    expect(paused.total).toBe(0);
    expect(paused.deferredNew).toBe(12);
  });
});

describe("FR-15 criterion 4 — request_retention mặc định 0.9 và R1 KHÔNG mở cho người dùng", () => {
  it("đọc ra 0.9; mọi đường ghi qua usecase đều bị từ chối, DB không đổi", async () => {
    const svc = await createMemServices({ now: () => T0 });
    expect((await getSettings(svc)).requestRetention).toBe(0.9);

    await expect(updateSettings(svc, { requestRetention: 0.8 })).rejects.toBeInstanceOf(SettingsError);
    expect((await getSettings(svc)).requestRetention).toBe(0.9);
  });

  it("6 cột khoá còn lại cũng không ghi được qua usecase", async () => {
    const svc = await createMemServices({ now: () => T0 });
    for (const patch of [
      { maximumInterval: 100 },
      { enableFuzz: false },
      { dayCutoffHour: 0 },
      { fsrsParams: "[1,2,3]" },
      { fsrsVersion: "5.4.2" },
      { aiProvider: "openai" },
    ]) {
      await expect(updateSettings(svc, patch)).rejects.toBeInstanceOf(SettingsError);
    }
    const s = await getSettings(svc);
    expect(s.maximumInterval).toBe(36500);
    expect(s.enableFuzz).toBe(true);
    expect(s.dayCutoffHour).toBe(4);
    expect(s.aiProvider).toBe("gemini");
  });
});

describe("FR-15 criterion 5 — fsrs_params/fsrs_version để trống ở R1", () => {
  it("cả hai null sau seed và sau khi lưu các field khác", async () => {
    const svc = await createMemServices({ now: () => T0 });
    expect((await getSettings(svc)).fsrsParams).toBeNull();
    expect((await getSettings(svc)).fsrsVersion).toBeNull();

    await updateSettings(svc, { cefrLevel: "A2", dailyNewLimit: 5 });
    const s = await getSettings(svc);
    expect(s.fsrsParams).toBeNull();
    expect(s.fsrsVersion).toBeNull();
  });
});

describe("BYOK (Q-03) — 4 field lưu local, key xoá được, không rò sang field khác", () => {
  it("lưu key + base URL + model, đọc lại thấy đúng; các field khác không bị chạm", async () => {
    const svc = await createMemServices({ now: () => T0 });
    const before = await getSettings(svc);

    const after = await updateSettings(svc, {
      aiBaseUrl: "https://ai-box.vn/gemini",
      aiModel: "gemini-3.6-flash",
      aiApiKey: "AIza-owner-key",
    });
    expect(after.aiApiKey).toBe("AIza-owner-key");
    expect(after.aiBaseUrl).toBe("https://ai-box.vn/gemini");
    expect(after.aiModel).toBe("gemini-3.6-flash");
    // partial update: không cột nào ngoài patch bị đổi
    expect(after.cefrLevel).toBe(before.cefrLevel);
    expect(after.dailyNewLimit).toBe(before.dailyNewLimit);
    expect(after.requestRetention).toBe(before.requestRetention);
    expect(after.dayCutoffHour).toBe(before.dayCutoffHour);

    expect((await getSettings(svc)).aiApiKey).toBe("AIza-owner-key");
  });

  it("xoá key bằng null → analyzePage báo missing_key (app sẽ nhắc nhập lại)", async () => {
    const svc = await servicesWithKey();
    await updateSettings(svc, { aiApiKey: null });
    expect((await getSettings(svc)).aiApiKey).toBeNull();
    await expect(analyzePage(svc, IMG)).rejects.toMatchObject({ code: "missing_key" });
  });

  it("base URL rỗng quay về mặc định Gemini, model rỗng quay về model mặc định", async () => {
    const svc = await servicesWithKey();
    const after = await updateSettings(svc, { aiBaseUrl: "", aiModel: "" });
    expect(after.aiBaseUrl).toBe(DEFAULT_AI_BASE_URL);
    expect(after.aiModel).toBe(DEFAULT_AI_MODEL);
  });

  it("giá trị sai không ghi được: CEFR lạ / hạn mức âm / base URL rác đều giữ nguyên DB", async () => {
    const svc = await createMemServices({ now: () => T0 });
    const before = await getSettings(svc);
    for (const patch of [{ cefrLevel: "C2" }, { dailyNewLimit: -5 }, { aiBaseUrl: "khong-phai-url" }]) {
      await expect(updateSettings(svc, patch)).rejects.toBeInstanceOf(SettingsError);
    }
    expect(await getSettings(svc)).toEqual(before);
  });
});
