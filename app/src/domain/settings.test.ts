/**
 * Unit test domain/settings.ts — cổng kiểm tra patch settings (FR-15). Hàm thuần,
 * không DB: mỗi ca là một luật "không nuốt im lặng" của cổng.
 */
import { describe, expect, it } from "vitest";
import { SettingsError } from "./errors";
import {
  DEFAULT_AI_BASE_URL,
  DEFAULT_AI_MODEL,
  MAX_AI_MODEL_LENGTH,
  MAX_DAILY_NEW_LIMIT,
  normalizeSettingsPatch,
} from "./settings";

function codeOf(raw: Record<string, unknown>): string {
  try {
    normalizeSettingsPatch(raw);
  } catch (e) {
    if (e instanceof SettingsError) return e.code;
    throw e;
  }
  throw new Error(`không ném lỗi cho patch ${JSON.stringify(raw)}`);
}

describe("normalizeSettingsPatch — field người dùng được chỉnh", () => {
  it("nhận đủ 5 field editable và trim chuỗi", () => {
    const patch = normalizeSettingsPatch({
      cefrLevel: "C1",
      dailyNewLimit: 7,
      aiBaseUrl: "  https://gw.example/v1  ",
      aiModel: "  gemini-3.6-flash  ",
      aiApiKey: "  AIza-secret  ",
    });
    expect(patch).toEqual({
      cefrLevel: "C1",
      dailyNewLimit: 7,
      aiBaseUrl: "https://gw.example/v1",
      aiModel: "gemini-3.6-flash",
      aiApiKey: "AIza-secret",
    });
  });

  it("base URL rỗng → mặc định Gemini; model rỗng → model mặc định (hiện ngay trên form)", () => {
    expect(normalizeSettingsPatch({ aiBaseUrl: "   " }).aiBaseUrl).toBe(DEFAULT_AI_BASE_URL);
    expect(normalizeSettingsPatch({ aiModel: "" }).aiModel).toBe(DEFAULT_AI_MODEL);
  });

  it("chỉ gửi field có mặt — không field nào bị ghi kèm", () => {
    expect(Object.keys(normalizeSettingsPatch({ dailyNewLimit: 10 }))).toEqual(["dailyNewLimit"]);
  });

  it("hạn mức 0 là hợp lệ (tạm dừng thẻ mới), trần là " + MAX_DAILY_NEW_LIMIT, () => {
    expect(normalizeSettingsPatch({ dailyNewLimit: 0 }).dailyNewLimit).toBe(0);
    expect(normalizeSettingsPatch({ dailyNewLimit: MAX_DAILY_NEW_LIMIT }).dailyNewLimit).toBe(MAX_DAILY_NEW_LIMIT);
  });

  it("aiApiKey null = xoá key (khác hẳn chuỗi rỗng)", () => {
    expect(normalizeSettingsPatch({ aiApiKey: null })).toEqual({ aiApiKey: null });
  });
});

describe("normalizeSettingsPatch — giá trị sai bị TỪ CHỐI, không bỏ qua", () => {
  it("CEFR ngoài A2/B1/B2/C1", () => {
    expect(codeOf({ cefrLevel: "C2" })).toBe("bad_cefr");
    expect(codeOf({ cefrLevel: "b1" })).toBe("bad_cefr");
    expect(codeOf({ cefrLevel: 3 })).toBe("bad_cefr");
  });

  it("hạn mức thẻ mới: âm, thập phân, vượt trần, không phải số", () => {
    expect(codeOf({ dailyNewLimit: -1 })).toBe("bad_daily_limit");
    expect(codeOf({ dailyNewLimit: 1.5 })).toBe("bad_daily_limit");
    expect(codeOf({ dailyNewLimit: MAX_DAILY_NEW_LIMIT + 1 })).toBe("bad_daily_limit");
    expect(codeOf({ dailyNewLimit: "10" })).toBe("bad_daily_limit");
    expect(codeOf({ dailyNewLimit: Number.NaN })).toBe("bad_daily_limit");
  });

  it("base URL không parse được hoặc sai scheme", () => {
    expect(codeOf({ aiBaseUrl: "not-a-url" })).toBe("bad_base_url");
    expect(codeOf({ aiBaseUrl: "ftp://gw.example" })).toBe("bad_base_url");
  });

  it("model quá dài", () => {
    expect(codeOf({ aiModel: "x".repeat(MAX_AI_MODEL_LENGTH + 1) })).toBe("bad_model");
  });

  it("key rỗng/toàn khoảng trắng = lỗi (muốn xoá thì gửi null)", () => {
    expect(codeOf({ aiApiKey: "" })).toBe("empty_key");
    expect(codeOf({ aiApiKey: "   " })).toBe("empty_key");
  });

  it("patch rỗng", () => {
    expect(codeOf({})).toBe("empty_patch");
  });
});

describe("normalizeSettingsPatch — cột KHOÁ ở R1", () => {
  it.each([
    ["requestRetention", 0.8],
    ["maximumInterval", 100],
    ["enableFuzz", false],
    ["dayCutoffHour", 0],
    ["fsrsParams", "[1,2,3]"],
    ["fsrsVersion", "5.4.2"],
    ["aiProvider", "openai"],
  ])("%s bị chặn với mã readonly_field", (field, value) => {
    expect(codeOf({ [field]: value })).toBe("readonly_field");
  });

  it("field lạ hoàn toàn báo unknown_field (khác readonly_field)", () => {
    expect(codeOf({ vuiLong: true })).toBe("unknown_field");
  });

  it("có field khoá trong patch thì cả patch bị chặn — không lưu nửa vời", () => {
    expect(codeOf({ cefrLevel: "C1", requestRetention: 0.8 })).toBe("readonly_field");
  });
});
