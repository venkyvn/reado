/**
 * integration test — FR-08 Vocabulary List chạy trên SQLite thật: bộ test này
 * LẦN LƯỢT là ba criterion trong PRD (AGENTS mục 4: dùng criteria trực tiếp làm
 * test). Seed qua đúng đường sản phẩm saveVocabulary → buildDueQueue → gradeCard.
 */
import { describe, expect, it } from "vitest";
import { listLibrary } from "../../domain/usecases/library";
import { buildDueQueue, gradeCard } from "../../domain/usecases/review";
import { saveVocabulary } from "../../domain/usecases/save";
import type { LibraryFilter } from "../../domain/repositories";
import type { AppServices } from "../services";
import type { Cefr } from "../../domain/types";
import { createMemServices, sampleItem } from "../../testing/memServices";

const T0 = new Date("2026-09-10T02:00:00.000Z");
const ALL: LibraryFilter = { collectionId: null, cefr: null, state: null };

interface Seeded {
  svc: AppServices;
  defaultId: string;
  bookId: string;
}

/**
 * 5 từ ở 2 collection. Hai dòng CÙNG term "run" khác pos/nghĩa (nằm cùng kho
 * tạm) — đúng tình huống criterion 3. CEFR: staggering B2 (mặc định sampleItem),
 * run-verb A2, run-noun B1, beta NULL (nghĩa "chưa gán"), gamma B1.
 */
async function seed(): Promise<Seeded> {
  const svc = await createMemServices({ now: () => T0 });
  const def = await svc.repos.collections.getDefault();
  expect(def).not.toBeNull();
  const book = await svc.repos.collections.create("The Giver — ch.2", false, T0);

  await saveVocabulary(svc, {
    collectionId: def!.id,
    items: [
      sampleItem({ term: "staggering", cefr: "B2" }),
      sampleItem({ term: "run", pos: "verb", meaningVi: "chạy", example: "I run every morning.", cefr: "A2" }),
      sampleItem({ term: "run", pos: "noun", meaningVi: "buổi chạy", example: "a morning run.", cefr: "B1" }),
    ],
    now: T0,
  });
  await saveVocabulary(svc, {
    collectionId: book.id,
    items: [
      // CEFR null ĐƯỢC test: cột DB nullable theo schema, nhưng cổng sản phẩm
      // (AnalyzedItem) hiện bắt buộc CEFR (FR-06 chưa build) — cast runtime-correct.
      sampleItem({ term: "beta", example: "beta appears here.", pos: "noun", cefr: null as unknown as Cefr }),
      sampleItem({ term: "gamma", cefr: "B1", example: "gamma appears here." }),
    ],
    now: T0,
  });
  return { svc, defaultId: def!.id, bookId: book.id };
}

describe("FR-08 criterion 1 — mỗi dòng cho thấy đủ field + TÊN collection", () => {
  it("6 field của từ + tên collection + cardState khởi đầu là new", async () => {
    const { svc, bookId } = await seed();
    const rows = await listLibrary(svc, ALL);
    expect(rows).toHaveLength(5);

    const beta = rows.find((r) => r.term === "beta")!;
    expect(beta.pos).toBe("noun");
    expect(beta.ipa).toBe("/ˈstæɡərɪŋ/"); // default của sampleItem
    expect(beta.meaningVi).toBe("đáng kinh ngạc");
    expect(beta.example).toBe("beta appears here.");
    expect(beta.cefr).toBeNull(); // đã ghi null thật sự vào DB
    expect(beta.collectionName).toBe("The Giver — ch.2"); // TÊN, không phải id
    expect(beta.collectionId).toBe(bookId);
    expect(beta.cardState).toBe("new");
  });
});

describe("FR-08 criterion 3 — cùng term nhiều nghĩa: nhiều DÒNG nằm CẠNH NHAU, không gộp", () => {
  it("hai dòng 'run' đứng cạnh nhau và phân biệt được bằng pos + câu gốc", async () => {
    const { svc } = await seed();
    const rows = await listLibrary(svc, ALL);

    const runIdx = rows.map((r) => r.term.toLowerCase()).indexOf("run");
    expect(runIdx).toBeGreaterThanOrEqual(0);
    const first = rows[runIdx];
    const second = rows[runIdx + 1];
    expect(second.term.toLowerCase()).toBe("run"); // CẠNH NHAU

    // Trong cùng term: thứ tự lưu (created_at), run-verb ghi trước run-noun.
    expect([first.pos, second.pos]).toEqual(["verb", "noun"]);
    expect(first.example).not.toBe(second.example);
    expect(first.meaningVi).not.toBe(second.meaningVi); // "chạy" ≠ "buổi chạy"
    expect(rows.filter((r) => r.term.toLowerCase() === "run")).toHaveLength(2); // KHÔNG gộp
  });
});

describe("FR-08 criterion 2 — lọc theo collection / cefr / trạng thái ôn tập", () => {
  it("lọc collection: chỉ từ của collection đó", async () => {
    const { svc, bookId } = await seed();
    const book = await listLibrary(svc, { collectionId: bookId, cefr: null, state: null });
    expect(book.map((r) => r.term)).toEqual(["beta", "gamma"]);
    expect(book.every((r) => r.collectionName === "The Giver — ch.2")).toBe(true);
  });

  it("lọc cefr, và cefr NULL bị loại khi lọc theo giá trị cụ thể", async () => {
    const { svc } = await seed();
    const b1 = await listLibrary(svc, { collectionId: null, cefr: "B1", state: null });
    expect(b1.map((r) => r.term)).toEqual(["gamma", "run"]);
    expect(b1).toHaveLength(2);
    const b2 = await listLibrary(svc, { collectionId: null, cefr: "B2", state: null });
    expect(b2.map((r) => r.term)).toEqual(["staggering"]); // "beta" cefr NULL không lọt
  });

  it("lọc trạng thái ôn tập: sau khi chấm một card, filter review/new tách đúng", async () => {
    const { svc, defaultId } = await seed();
    const all = await listLibrary(svc, ALL);
    const runVerb = all.find((r) => r.pos === "verb" && r.term === "run")!;

    const queue = await buildDueQueue(svc, T0);
    const target = queue.cards.find((c) => c.vocabItemId === runVerb.id);
    expect(target).toBeDefined();
    await gradeCard(svc, { card: target!, rating: "Good", now: T0 });

    const reviews = await listLibrary(svc, { collectionId: null, cefr: null, state: "review" });
    expect(reviews.map((r) => r.term)).toEqual(["run"]);
    expect(reviews[0].pos).toBe("verb");
    expect(reviews[0].cardState).toBe("review");

    const news = await listLibrary(svc, { collectionId: null, cefr: null, state: "new" });
    expect(news).toHaveLength(4);

    // ba tiêu chí cùng lúc: review + kho tạm + không lọc cefr
    const combo = await listLibrary(svc, { collectionId: defaultId, cefr: null, state: "review" });
    expect(combo.map((r) => r.term)).toEqual(["run"]);
    const empty = await listLibrary(svc, { collectionId: null, cefr: "C1", state: "review" });
    expect(empty).toHaveLength(0);
  });

  it("collection rỗng: 0 dòng, không ném lỗi", async () => {
    const { svc } = await seed();
    const empty = await svc.repos.collections.create("Sách chưa đọc", false, T0);
    const rows = await listLibrary(svc, { collectionId: empty.id, cefr: null, state: null });
    expect(rows).toHaveLength(0);
  });
});