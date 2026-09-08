/**
 * domain/verify.test.ts — kiểm schema (prompt-spec mục 4) + ba nhánh xác minh
 * (mục 6). Đây chính là các criterion kiểm được bằng máy của FR-02.
 */
import { describe, expect, it } from "vitest";
import { normalizePageText, validateAiPayload, verificationOf } from "./verify";

describe("normalizePageText (mục 6)", () => {
  it("đưa nháy cong về nháy thẳng, gạch – — về gạch -", () => {
    expect(normalizePageText("He said “hello” — it’s fine – really")).toBe(
      `he said "hello" - it's fine - really`,
    );
  });

  it("gộp whitespace dòng mới thành khoảng trắng đơn, lowercase, trim", () => {
    expect(normalizePageText("  The   Cat\n\nSat  ")).toBe("the cat sat");
  });
});

describe("verificationOf — ba nhánh (mục 6)", () => {
  const page = normalizePageText(
    "The staggering scale of the problem. He proved remarkably resilient.",
  );

  it("example có thật và chứa term → verified", () => {
    expect(verificationOf(page, "staggering", "The staggering scale of the problem.")).toBe("verified");
  });

  it("example có thật nhưng KHÔNG chứa term → suspect", () => {
    expect(verificationOf(page, "resilient", "The staggering scale of the problem.")).toBe("suspect");
  });

  it("example không đối chiếu được → unverified (AI tự bịa câu)", () => {
    expect(verificationOf(page, "staggering", "Prices were staggering last year.")).toBe("unverified");
  });

  it("khác biệt hoa thường và khoảng trắng không làm sai nhánh", () => {
    expect(verificationOf(page, "  STAGGERING ", " The staggering  scale of the problem. ")).toBe("verified");
  });
});

describe("validateAiPayload (mục 4 — additionalProperties:false mọi cấp)", () => {
  const base = {
    segments: [{ source_en: "Hello.", translation_vi: "Xin chào." }],
    vocabulary: [
      { term: "hello", pos: "noun", ipa: "/həˈloʊ/", meaning_vi: "xin chào", cefr: "A2", example: "Hello." },
    ],
    summary_vi: "Lời chào.",
  };

  it("payload đúng chuẩn → 0 vi phạm", () => {
    expect(validateAiPayload(structuredClone(base))).toEqual([]);
  });

  it("key lạ ở root bị bắt (additionalProperties:false)", () => {
    const bad = { ...structuredClone(base), extra: 1 };
    expect(validateAiPayload(bad).join("\n")).toContain("key lạ \"extra\"");
  });

  it("key lạ trong item vocabulary bị bắt", () => {
    const bad = structuredClone(base);
    (bad.vocabulary[0] as Record<string, unknown>).extra = "x";
    expect(validateAiPayload(bad).join("\n")).toContain("vocabulary[0]: key lạ");
  });

  it("thiếu field bắt buộc bị bắt", () => {
    const bad = structuredClone(base);
    delete (bad.vocabulary[0] as Record<string, unknown>).example;
    expect(validateAiPayload(bad).join("\n")).toContain("thiếu \"example\"");
  });

  it("pos ngoài enum bị bắt", () => {
    const bad = structuredClone(base);
    (bad.vocabulary[0] as Record<string, unknown>).pos = "conjunction";
    expect(validateAiPayload(bad).join("\n")).toContain("pos: ngoài enum");
  });

  it("field rỗng bị bắt bởi minLength (ipa là ngoại lệ duy nhất)", () => {
    const bad = structuredClone(base);
    bad.segments[0].source_en = "";
    const bad2 = structuredClone(base);
    bad2.vocabulary[0].ipa = ""; // được phép rỗng
    expect(validateAiPayload(bad).join("\n")).toContain("source_en: độ dài < 1");
    expect(validateAiPayload(bad2)).toEqual([]);
  });
});