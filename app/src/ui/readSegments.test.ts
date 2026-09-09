/**
 * test thuần cho readSegments.ts — chuyển hoá FR-05 criterion 1 & 3 thành
 * trường hợp máy chấm được: segment giữ thứ tự gốc, từ vựng khớp theo token
 * (không khớp lồng nhau), ghép node lại LUÔN bằng chuỗi gốc.
 */
import { describe, expect, it } from "vitest";
import type { AnalyzedItem } from "../domain/types";
import { appendSessionPage, buildGlossIndex, glossIndexMap, splitWithGloss } from "./readSegments";
import type { SessionPage } from "./readSegments";

function item(term: string, meaningVi = "nghĩa", ipa = "/x/"): AnalyzedItem {
  return {
    term,
    pos: "noun",
    ipa,
    meaningVi,
    cefr: "B2",
    example: `${term} appears here.`,
    verification: "verified",
    tags: [],
    synonyms: [],
    antonyms: [],
  };
}

/** Ghép node lại thành chuỗi — bất biến bắt buộc của splitWithGloss. */
function joinNodes(nodes: ReturnType<typeof splitWithGloss>): string {
  return nodes.map((n) => n.text).join("");
}

describe("readSegments.splitWithGloss", () => {
  it("khớp từ đơn giữ nguyên chính tả gốc trong node (case-insensitive)", () => {
    const entries = buildGlossIndex([item("wildly")]);
    const nodes = splitWithGloss("The crowd went WILDLY enthusiastic.", entries);
    const vocab = nodes.filter((n) => n.kind === "vocab");
    expect(vocab).toHaveLength(1);
    expect(vocab[0].text).toBe("WILDLY");
    expect(vocab[0].kind === "vocab" && vocab[0].matchKey).toBe("v0");
    expect(joinNodes(nodes)).toBe("The crowd went WILDLY enthusiastic.");
  });

  it("dấu câu và khoảng trắng nằm ngoài node vocab nhưng không mất ký tự nào", () => {
    const entries = buildGlossIndex([item("unforgiving")]);
    const nodes = splitWithGloss("It was unforgiving, cold and hard.\nNext line.", entries);
    const vocab = nodes.filter((n) => n.kind === "vocab");
    expect(vocab.map((n) => (n.kind === "vocab" ? n.text : ""))).toEqual(["unforgiving"]);
    expect(joinNodes(nodes)).toBe("It was unforgiving, cold and hard.\nNext line.");
  });

  it("KHÔNG khớp phần thân của từ dài hơn (textile ≠ textiles)", () => {
    const entries = buildGlossIndex([item("textile")]);
    const nodes = splitWithGloss("The textiles are fine.", entries);
    expect(nodes.every((n) => n.kind === "text")).toBe(true);
  });

  it("term nhiều từ khớp cửa sổ token thành MỘT node, không khớp lồng từ lẻ bên trong", () => {
    const entries = buildGlossIndex([item("to account for"), item("account")]);
    const nodes = splitWithGloss("We need to account for the cost.", entries);
    const vocab = nodes.filter((n) => n.kind === "vocab");
    expect(vocab).toHaveLength(1);
    expect(vocab[0].kind === "vocab" && vocab[0].text).toBe("to account for");
    expect(joinNodes(nodes)).toBe("We need to account for the cost.");
  });

  it("nháy cong (’ ) khớp nháy thẳng của term nhờ cùng normalizePageText", () => {
    const entries = buildGlossIndex([item("don't")]);
    const nodes = splitWithGloss("They don’t like it.", entries);
    const vocab = nodes.filter((n) => n.kind === "vocab");
    expect(vocab.map((n) => (n.kind === "vocab" ? n.text : ""))).toEqual(["don’t"]);
  });

  it("gạch nối giữa token được tính là một token (mid-19th)", () => {
    const entries = buildGlossIndex([item("mid-19th")]);
    const nodes = splitWithGloss("a mid-19th notion", entries);
    expect(nodes.filter((n) => n.kind === "vocab")).toHaveLength(1);
  });

  it("từ không có trong vocabulary → toàn bộ là text nguyên văn", () => {
    const entries = buildGlossIndex([item("autre")]);
    const nodes = splitWithGloss("Nothing matches here.", entries);
    expect(nodes).toEqual([{ kind: "text", text: "Nothing matches here." }]);
  });

  it("chuỗi rỗng → không có node", () => {
    expect(splitWithGloss("", buildGlossIndex([item("x")]))).toEqual([]);
  });

  it("ghép node lại LUÔN tái tạo đúng chuỗi gốc với nhiều khớp liền nhau", () => {
    const entries = buildGlossIndex([item("pass"), item("by"), item("time")]);
    const src = "\u201CAs time passes, we pass by…\u201D";
    expect(joinNodes(splitWithGloss(src, entries))).toBe(src);
  });
});

describe("readSegments.buildGlossIndex", () => {
  it("cùng term chuẩn hoá nhiều dòng → giữ dòng ĐẦU (gloss 1 nghĩa, không lồng)", () => {
    const entries = buildGlossIndex([item("rock", "đá"), item("Rock", "nhạc rock")]);
    expect(entries).toHaveLength(1);
    expect(entries[0].term).toBe("rock");
    expect(entries[0].meaningVi).toBe("đá");
  });

  it("term nhiều từ xếp TRƯỚC term một từ (cửa sổ to ưu tiên)", () => {
    const entries = buildGlossIndex([item("account"), item("to account for")]);
    expect(entries[0].term).toBe("to account for");
  });

  it("prefix làm key không đụng giữa hai trang (buffer FR-05)", () => {
    const a = buildGlossIndex([item("wildly")], "p0:");
    const b = buildGlossIndex([item("wildly")], "p1:");
    expect(glossIndexMap(a).get("p0:v0")?.term).toBe("wildly");
    expect(glossIndexMap(b).get("p1:v0")?.term).toBe("wildly");
    expect(glossIndexMap(a).has("p1:v0")).toBe(false);
  });

  it("term rỗng sau chuẩn hoá bị bỏ", () => {
    expect(buildGlossIndex([item("...")])).toHaveLength(0);
  });
});

describe("readSegments.appendSessionPage — FR-05 c.4 buffer", () => {
  const page = (n: number): SessionPage => ({
    analysis: { segments: [], vocabulary: [], summaryVi: "", usage: { promptTokens: 0, candidatesTokens: 0 }, latencyMs: 0, promptVersion: 1 },
    collectionId: `c${n}`,
  });

  it("nối trang mới vào CUỐI, giữ thứ tự cũ → trang nào mới nhất nằm cuối", () => {
    const out = appendSessionPage([page(1), page(2)], page(3));
    expect(out.map((p) => p.collectionId)).toEqual(["c1", "c2", "c3"]);
  });

  it("không đột biến mảng đầu vào", () => {
    const input = [page(1)];
    appendSessionPage(input, page(2));
    expect(input).toHaveLength(1);
  });

  it("quá 10 trang → nhỏ dần chỉ giữ 10 trang GẦN NHẤT (Q-10 chốt)", () => {
    let pages: SessionPage[] = [];
    for (let i = 1; i <= 12; i++) pages = appendSessionPage(pages, page(i));
    expect(pages).toHaveLength(10);
    expect(pages[0].collectionId).toBe("c3");
    expect(pages[9].collectionId).toBe("c12");
  });
});