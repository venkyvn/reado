/**
 * integration test — task 3.15 (Q-10-reopen): kho phiên đọc bền theo collection,
 * chạy trên SQLite thật (memServices — cùng migrate/seed như browser).
 *
 * Ba hành vi chủ: (1) invariant "tối đa 10 phiên mới nhất mỗi collection" với
 * insert liên tục; (2) list đúng thứ tự + đúng phạm vi collection; (3) luật
 * "lưu 1 lần" persist qua markSaved. Cộng: JSON hỏng không làm sập đọc; xoá
 * collection xoá kèm phiên (cascade).
 */
import { describe, expect, it } from "vitest";
import { createMemServicesBundle } from "../../testing/memServices";
import type { MemServicesBundle } from "../../testing/memServices";
import type { AppServices } from "../services";
import { SESSIONS_PER_COLLECTION } from "../../storage/repos/readingSessions";
import {
  listCollectionSessions,
  listRecentReadingSessions,
  markReadingSessionSaved,
  persistReadingSession,
} from "./readingSessions";
import type { AnalysisResult } from "../types";

const T0 = new Date("2026-09-10T02:00:00.000Z");

function resultOf(n: number): AnalysisResult {
  return {
    segments: [
      { sourceEn: `Page ${n} — the staggering scale of the problem.`, translationVi: `Trang ${n} — quy mô đáng kinh ngạc.` },
    ],
    vocabulary: [
      {
        term: `staggering${n}`,
        pos: "adj",
        ipa: "/ˈstæɡərɪŋ/",
        meaningVi: "đáng kinh ngạc",
        cefr: "B2",
        example: "The staggering scale of the problem.",
        verification: "verified",
        tags: [],
        synonyms: [],
        antonyms: [],
      },
    ],
    summaryVi: `Tóm tắt trang ${n}.`,
    usage: { promptTokens: 10, candidatesTokens: 20 },
    latencyMs: 15,
    promptVersion: 2,
  };
}

/**
 * Clock TĂNG DẦN theo lượt gọi — created_at phải phân biệt được thứ tự insert
 * (điều kiện để "10 mới nhất" có nghĩa). T0 + i phút cho lần gọi thứ i.
 */
function makeTickingClock(start: Date): () => Date {
  let tick = 0;
  return () => new Date(start.getTime() + tick++ * 60_000);
}

async function svcWithDefault(): Promise<{ svc: AppServices; appDb: MemServicesBundle["appDb"]; defaultId: string }> {
  const bundle = await createMemServicesBundle({ now: makeTickingClock(T0) });
  const def = await bundle.services.repos.collections.getDefault();
  if (!def) throw new Error("seed phải tạo collection mặc định");
  return { svc: bundle.services, appDb: bundle.appDb, defaultId: def.id };
}

describe("invariant 10 phiên/collection — trim trong cùng transaction với insert", () => {
  it("ghi 25 phiên liên tục → collection giữ đúng 10 MỚI NHẤT, theo created_at", async () => {
    const { svc, appDb, defaultId } = await svcWithDefault();
    for (let i = 1; i <= 25; i++) {
      await persistReadingSession(svc, `analysis-${i}`, defaultId, resultOf(i));
    }
    const rows = await listCollectionSessions(svc, defaultId);
    expect(rows).toHaveLength(SESSIONS_PER_COLLECTION);
    // DESC: mới nhất trước — analysis-25 đứng đầu, analysis-16 cuối.
    expect(rows[0]?.id).toBe("analysis-25");
    expect(rows[SESSIONS_PER_COLLECTION - 1]?.id).toBe("analysis-16");
    // Trim là XOÁ thật khỏi DB, không chỉ lọc lúc list.
    const total = await appDb.get<{ c: number | bigint }>(
      "select count(*) as c from reading_sessions",
    );
    expect(Number(total?.c)).toBe(SESSIONS_PER_COLLECTION);
  });

  it("hai collection độc lập — trim ở collection này không đụng collection kia", async () => {
    const { svc, defaultId } = await svcWithDefault();
    const book = await svc.repos.collections.create("The Giver — ch.2", false, T0);
    for (let i = 1; i <= 12; i++) await persistReadingSession(svc, `d-${i}`, defaultId, resultOf(i));
    for (let i = 1; i <= 3; i++) await persistReadingSession(svc, `b-${i}`, book.id, resultOf(i));
    expect(await listCollectionSessions(svc, defaultId)).toHaveLength(SESSIONS_PER_COLLECTION);
    const bookRows = await listCollectionSessions(svc, book.id);
    expect(bookRows).toHaveLength(3);
    expect(bookRows.map((r) => r.id)).toEqual(["b-3", "b-2", "b-1"]);
  });
});

describe("nội dung phiên đọc — vòng đời đầy đủ qua JSON", () => {
  it("persist → đọc lại đủ segments/vocabulary/summary, đúng thứ tự đoạn", async () => {
    const { svc, defaultId } = await svcWithDefault();
    await persistReadingSession(svc, "analysis-1", defaultId, resultOf(1));
    const [row] = await listCollectionSessions(svc, defaultId);
    expect(row?.segments).toHaveLength(1);
    expect(row?.segments[0]?.sourceEn).toContain("Page 1");
    expect(row?.segments[0]?.translationVi).toContain("Trang 1");
    expect(row?.vocabulary).toHaveLength(1);
    expect(row?.vocabulary[0]?.term).toBe("staggering1");
    expect(row?.summaryVi).toBe("Tóm tắt trang 1.");
    expect(row?.vocabCount).toBe(1);
    expect(row?.savedAt).toBeNull();
  });

  it("dòng JSON hỏng (ghi lệch qua appDb) → segments/vocabulary rỗng, KHÔNG ném, metadata còn", async () => {
    const { svc, appDb, defaultId } = await svcWithDefault();
    await persistReadingSession(svc, "analysis-1", defaultId, resultOf(1));
    await appDb.exec("update reading_sessions set segments = '{khong-phai-json', vocabulary = '[{huh}]' where id = 'analysis-1'");
    const [row] = await listCollectionSessions(svc, defaultId);
    expect(row?.segments).toEqual([]);
    expect(row?.vocabulary).toEqual([]);
    expect(row?.summaryVi).toBe("Tóm tắt trang 1.");
    expect(row?.vocabCount).toBe(1);
  });
});

describe("luật 'lưu 1 lần' (bug 6723302) — persist theo DB thay vì chết theo phiên", () => {
  it("markSaved ghi saved_at + saved_count; getById thấy", async () => {
    const { svc, defaultId } = await svcWithDefault();
    await persistReadingSession(svc, "analysis-1", defaultId, resultOf(1));
    await markReadingSessionSaved(svc, "analysis-1", 7);
    const row = await svc.repos.readingSessions.getById("analysis-1");
    // Clock tick: persist lúc 02:00 (tick 0), markSaved lúc 02:01 (tick 1) —
    // saved_at PHẢI là thời điểm markSaved, không phải thời điểm phân tích.
    expect(row?.savedAt).toBe("2026-09-10T02:01:00.000Z");
    expect(row?.savedCount).toBe(7);
  });
});

describe("listRecent — mặt cắt mọi collection cho màn đọc", () => {
  it("mới nhất trước, giới hạn bởi limit", async () => {
    const { svc, defaultId } = await svcWithDefault();
    const book = await svc.repos.collections.create("Book", false, T0);
    for (let i = 1; i <= 6; i++) await persistReadingSession(svc, `d-${i}`, defaultId, resultOf(i));
    await persistReadingSession(svc, "b-1", book.id, resultOf(99));
    const top3 = await listRecentReadingSessions(svc, 3);
    expect(top3.map((r) => r.id)).toEqual(["b-1", "d-6", "d-5"]);
  });
});

describe("cascade — xoá collection xoá kèm phiên đọc", () => {
  it("collection biến mất → reading_sessions của nó biến mất", async () => {
    const { svc, appDb, defaultId } = await svcWithDefault();
    const book = await svc.repos.collections.create("Sách sẽ xoá", false, T0);
    await persistReadingSession(svc, "b-1", book.id, resultOf(1));
    await persistReadingSession(svc, "d-1", defaultId, resultOf(2));
    // Repo collections R1 chưa có delete (thuộc 3.8) — xoá thẳng SQL qua appDb
    // để chứng minh FK cascade của DDL, đúng cơ chế DB sẽ chạy.
    await appDb.exec("delete from collections where id = ?", [book.id]);
    const left = await listRecentReadingSessions(svc, 50);
    expect(left.map((r) => r.id)).toEqual(["d-1"]);
  });
});
