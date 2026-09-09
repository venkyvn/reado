/**
 * e2e/seed.mjs — script chạy trong e2e/seed.html: gieo 2 thẻ "new" đến hạn ngay
 * vào kho OPFS của origin test, qua ĐÚNG đường repo sản phẩm (persistCapture =
 * vocab_items + cards trong một transaction), xong chấm dứt worker để app boot
 * sau đó mở connection duy nhất.
 */
import { openWorkerStorage } from "../src/storage/workerStorage.ts";
import { createRepos } from "../src/storage/repos/index.ts";
import { newId, toUtcIso } from "../src/domain/utils.ts";

const status = document.querySelector("#status");

try {
  const storage = await openWorkerStorage();
  const repos = createRepos(storage.appDb);
  const def = await repos.collections.getDefault();
  if (!def) throw new Error("không có collection mặc định (seed collection chưa chạy?)");

  const nowIso = toUtcIso(new Date());
  const items = [
    {
      term: "staggering",
      pos: "adj",
      ipa: "/ˈstæɡərɪŋ/",
      meaningVi: "đáng kinh ngạc",
      example: "The staggering scale of the problem.",
      cefr: "B2",
      // Tags cố ý đa dạng: e2e:swipe dùng bình thường; e2e:cram chọn "business"
      // (1 thẻ) hoặc "shared" (2 thẻ) để kiểm màn chọn tag.
      tags: ["business", "shared"],
      synonyms: ["astonishing"],
      antonyms: [],
    },
    {
      term: "eloquence",
      pos: "noun",
      ipa: "/ˈeləkwəns/",
      meaningVi: "tài hùng biện",
      example: "She spoke with eloquence.",
      cefr: "C1",
      tags: ["speech", "shared"],
      synonyms: [],
      antonyms: [],
    },
  ];

  const vocabRows = items.map((it) => ({
    id: newId(),
    collectionId: def.id,
    term: it.term,
    termNormalized: it.term.toLowerCase().trim(),
    pos: it.pos,
    ipa: it.ipa,
    meaningVi: it.meaningVi,
    example: it.example,
    cefr: it.cefr,
    tags: it.tags,
    synonyms: it.synonyms,
    antonyms: it.antonyms,
    createdAt: nowIso,
  }));
  const cardRows = vocabRows.map((v) => ({
    id: newId(),
    vocabItemId: v.id,
    direction: "receptive",
    state: "new",
    stability: 0,
    difficulty: 0,
    reps: 0,
    lapses: 0,
    learningSteps: 0,
    scheduledDays: 0,
    lastReviewAt: null,
    dueAt: nowIso, // FR-09: thẻ mới đến hạn ngay
    suspendedAt: null,
  }));

  await repos.vocabItems.persistCapture(vocabRows, cardRows);
  storage.terminate();
  status.textContent = "SEEDED " + vocabRows.map((v) => v.term).join(", ");
} catch (e) {
  status.textContent = "FAIL: " + (e instanceof Error ? e.message : String(e));
}