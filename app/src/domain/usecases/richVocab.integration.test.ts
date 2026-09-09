/**
 * integration test — task 3.12 Rich Vocab chạy trên SQLite thật:
 * save qua đường sản phẩm (AI tag gắn kèm capture) → đọc lại từng repo →
 * user sửa ba field qua usecase → JSON hỏng không bao giờ đọc ra hỏng.
 * Hợp đồng: docs/rich-vocab-cram-ddl.md mục 2 & 4.
 */
import { describe, expect, it } from "vitest";
import { buildDueQueue } from "./review";
import { saveVocabulary } from "./save";
import { updateVocabRichFields } from "./richVocab";
import type { AppServices } from "../services";
import { createMemServices, sampleItem } from "../../testing/memServices";

const T0 = new Date("2026-09-09T09:00:00.000Z");

interface Seeded {
  svc: AppServices;
  defaultId: string;
  /** CardWithContext của từ đã lưu — dữ liệu hiển thị mặt sau thẻ. */
  card: { tags: string[]; synonyms: string[]; antonyms: string[] };
  itemId: string;
}

async function seed(): Promise<Seeded> {
  const svc = await createMemServices({ now: () => T0 });
  const def = await svc.repos.collections.getDefault();
  expect(def).not.toBeNull();

  await saveVocabulary(svc, {
    collectionId: def!.id,
    items: [
      sampleItem({
        term: "lend",
        example: "Could you lend me a hand?",
        tags: ["idiom", "everyday"],
        synonyms: ["loan", "give"],
        antonyms: ["borrow"],
      }),
    ],
    now: T0,
  });

  const queue = await buildDueQueue(svc, T0);
  expect(queue.cards).toHaveLength(1);
  return {
    svc,
    defaultId: def!.id,
    card: queue.cards[0],
    itemId: queue.cards[0].vocabItemId,
  };
}

describe("3.12 — save giữ 3 field AI gắn kèm capture", () => {
  it("lưu qua saveVocabulary rồi đọc lại từ kho: tags/synonyms/antonyms nguyên vẹn", async () => {
    const { svc, defaultId } = await seed();
    const items = await svc.repos.vocabItems.listByCollection(defaultId);
    expect(items).toHaveLength(1);
    expect(items[0].tags).toEqual(["idiom", "everyday"]);
    expect(items[0].synonyms).toEqual(["loan", "give"]);
    expect(items[0].antonyms).toEqual(["borrow"]);
  });

  it("item AI không gắn field nào → lưu '[]' chứ không phải null/hỏng", async () => {
    const { svc, defaultId } = await seed();
    await saveVocabulary(svc, {
      collectionId: defaultId,
      items: [sampleItem({ term: "plain", example: "plain appears here.", tags: [], synonyms: [], antonyms: [] })],
      now: T0,
    });
    const items = await svc.repos.vocabItems.listByCollection(defaultId);
    const plain = items.find((i) => i.term === "plain")!;
    expect(plain.tags).toEqual([]);
    expect(plain.synonyms).toEqual([]);
    expect(plain.antonyms).toEqual([]);
  });

  it("mặt sau thẻ (loadWithContext qua hàng đợi) mang đủ 3 field", async () => {
    const { card } = await seed();
    expect(card.tags).toEqual(["idiom", "everyday"]);
    expect(card.synonyms).toEqual(["loan", "give"]);
    expect(card.antonyms).toEqual(["borrow"]);
  });
});

describe("3.12 — user sửa 3 field sau khi đã vào kho", () => {
  it("updateVocabRichFields ghi mảng mới, đọc lại đúng", async () => {
    const { svc, itemId } = await seed();
    await updateVocabRichFields(svc, {
      vocabItemId: itemId,
      fields: { tags: ["idiom"], synonyms: [], antonyms: ["borrow", "take"] },
    });
    const items = await svc.repos.vocabItems.listByScope(null);
    expect(items[0].tags).toEqual(["idiom"]);
    expect(items[0].synonyms).toEqual([]);
    expect(items[0].antonyms).toEqual(["borrow", "take"]);
  });

  it("repo tự trim + dedupe trước khi ghi (tránh JSON bẩn làm sai phép đếm cram)", async () => {
    const { svc, itemId } = await seed();
    await updateVocabRichFields(svc, {
      vocabItemId: itemId,
      fields: { tags: [" Idiom ", "idiom"], synonyms: [], antonyms: [] },
    });
    const items = await svc.repos.vocabItems.listByScope(null);
    expect(items[0].tags).toEqual(["Idiom"]);
  });
});

describe("3.12 — JSON hỏng trong DB không được bò ra ngoài", () => {
  it("cột tags bị ghi thủ công bằng JSON hỏng → mọi đường đọc trả [] (guard lúc đọc)", async () => {
    // Dựng storage thật (kernel in-memory + migrate + repos production) rồi ghi
    // MỘT dòng hỏng thẳng vào SQL — mô phỏng dữ liệu cũ/provider lạ, không đi
    // qua đường sản phẩm. Hợp đồng doc mục 2: không bao giờ đọc ra JSON hỏng.
    const { openMemoryKernel } = await import("../../storage/kernel");
    const { initSyncDb } = await import("../../storage/syncDb");
    const { createLocalAppDb } = await import("../../storage/db");
    const { createRepos } = await import("../../storage/repos");

    const kernel = await openMemoryKernel();
    const appDb = createLocalAppDb(initSyncDb(kernel).db);
    const repos = createRepos(appDb);
    const def = await repos.collections.getDefault();
    expect(def).not.toBeNull();

    await appDb.exec(
      `insert into vocab_items (id, collection_id, term, term_normalized, pos, ipa, meaning_vi, example, cefr, tags, synonyms, antonyms, created_at)
       values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        "broken01",
        def!.id,
        "broken",
        "broken",
        "noun",
        null,
        "hỏng",
        "broken appears here.",
        null,
        "{not json", // JSON hỏng thật sự trong DB
        "[]",
        "[]",
        "2026-09-09T09:00:00.000Z",
      ],
    );

    const rows = await repos.vocabItems.listByCollection(def!.id);
    const broken = rows.find((r) => r.id === "broken01");
    expect(broken).toBeDefined();
    expect(broken!.tags).toEqual([]);
    expect(broken!.synonyms).toEqual([]);

    // loadWithContext (mặt sau thẻ) cũng phải an toàn trên cùng dòng hỏng.
    await appDb.exec(
      `insert into cards (id, vocab_item_id, direction, state, stability, difficulty, reps, lapses,
                          learning_steps, scheduled_days, last_review_at, due_at, suspended_at)
       values ('cardbroken01', 'broken01', 'receptive', 'new', 0, 0, 0, 0, 0, 0, null, ?, null)`,
      ["2026-09-09T09:00:00.000Z"],
    );
    const withContext = await repos.cards.loadWithContext(["cardbroken01"]);
    expect(withContext).toHaveLength(1);
    expect(withContext[0].tags).toEqual([]);
    expect(withContext[0].antonyms).toEqual([]);
  });
});