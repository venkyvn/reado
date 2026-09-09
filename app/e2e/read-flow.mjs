/**
 * e2e/read-flow.mjs — smoke test MÀN ĐỌC SONG NGỮ (FR-05/FR-06, task 3.3) bằng
 * Chrome THẬT của hệ thống (puppeteer-core, không tải Chromium riêng).
 *
 * Không gọi Gemini thật: script tự dựng fake endpoint mô phỏng đúng envelope
 * `generateContent` (candidates[0].finishReason=STOP + parts[].text = JSON),
 * app được chỉ base URL tới endpoint này qua form BYOK — flow chạy nhanh và
 * tất định, không tốn key/tiền.
 *
 * Chứng minh chính xác điều owner báo thiếu 2026-09-09: sau khi phân tích
 * xong phải MỞ MÀN ĐỌC với đoạn song ngữ xen kẽ, KHÔNG nhảy thẳng qua duyệt từ.
 *
 * Chạy: npm run e2e:read   (cần dev server đang chạy ở localhost:5173)
 * Arg:  node e2e/read-flow.mjs [url] [ảnh]
 */
import { rmSync } from "node:fs";
import { createServer } from "node:http";
import { resolve } from "node:path";
import puppeteer from "puppeteer-core";

const URL = process.argv[2] ?? "http://localhost:5173/";
const SAMPLE = resolve(process.argv[3] ?? "../ref/sample/page-42.png");
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PROFILE = "/tmp/reado-e2e-read-profile";
// Profile cũ = DB cũ → số trang phiên đọc lệch (phiên giờ BỀN theo DB). Mỗi
// lượt chạy phải là DB mới — xoá profile ngay khi start.
rmSync(PROFILE, { recursive: true, force: true });
const FAKE_PORT = 59999;
const FAKE_BASE = `http://127.0.0.1:${FAKE_PORT}`;

// Payload AI giả — hợp lệ theo prompt-spec: example nằm THẬT trong segments
// (dòng verified), summary + 3 segment xen kẽ dịch.
const PAYLOAD = {
  segments: [
    {
      source_en: "The crowd went wildly enthusiastic when the lousy band finally stopped playing.",
      translation_vi: "Đám đông trở nên cuồng nhiệt khi ban nhạc tồi cuối cùng cũng ngừng chơi.",
    },
    {
      source_en: "Most readers, however, pushed their luck and left early.",
      translation_vi: "Tuy nhiên hầu hết người đọc đã thử vận may rồi bỏ về sớm.",
    },
    {
      source_en: "A plain third paragraph with no special words at all.",
      translation_vi: "Một đoạn thứ ba bình thường không có từ đặc biệt nào.",
    },
  ],
  vocabulary: [
    {
      term: "wildly",
      pos: "adv",
      ipa: "/ˈwaɪldli/",
      meaning_vi: "một cách cuồng nhiệt",
      cefr: "B2",
      example: "The crowd went wildly enthusiastic when the lousy band finally stopped playing.",
    },
    {
      term: "lousy",
      pos: "adj",
      ipa: "/ˈlaʊzi/",
      meaning_vi: "tồi tệ",
      cefr: "B1",
      example: "the lousy band finally stopped playing",
    },
  ],
  summary_vi: "Đám đông phản ứng trái chiều trước ban nhạc; nhiều người bỏ về sớm.",
};

const server = createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Headers", "content-type, x-goog-api-key");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  if (req.method === "OPTIONS") {
    res.writeHead(204);
    res.end();
    return;
  }
  if (req.method === "POST" && req.url.endsWith(":generateContent")) {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        JSON.parse(body);
      } catch {
        res.writeHead(400);
        res.end("bad json");
        return;
      }
      res.writeHead(200, { "content-type": "application/json" });
      res.end(
        JSON.stringify({
          candidates: [{ finishReason: "STOP", content: { parts: [{ text: JSON.stringify(PAYLOAD) }] } }],
          usageMetadata: { promptTokenCount: 42, candidatesTokenCount: 21 },
        }),
      );
    });
    return;
  }
  res.writeHead(404);
  res.end();
});

const startServer = async () => new Promise((r) => server.listen(FAKE_PORT, "127.0.0.1", r));

const results = [];
const check = (name, ok, detail = "") => {
  results.push({ name, ok, detail });
  console.log(`${ok ? "✅" : "❌"} ${name}${detail ? ` — ${detail}` : ""}`);
};

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  // --no-sandbox --disable-gpu (2026-09-09): Chrome trong DSH seatbelt chết process
  // con với "GPU process isn't usable / sandbox initialization failed" — môi trường,
  // không phải bug app (xem journal 3.5). Headless + profile /tmp dùng một lần.
  args: [
    "--no-first-run",
    "--disable-crash-reporter",
    "--no-sandbox",
    "--disable-gpu",
    `--user-data-dir=${PROFILE}`,
  ],
});

try {
  await startServer();
  const page = await browser.newPage();
  await page.setViewport({ width: 430, height: 900 });

  const consoleErrors = [];
  page.on("console", (msg) => {
    if (msg.type() === "error") consoleErrors.push(msg.text());
  });
  page.on("pageerror", (err) => consoleErrors.push(String(err)));

  await page.goto(URL, { waitUntil: "networkidle0", timeout: 30000 });

  const clickByText = async (text) => {
    const ok = await page.evaluate((t) => {
      const btn = [...document.querySelectorAll("button")].find((b) => b.textContent.includes(t));
      if (!btn) return false;
      btn.click();
      return true;
    }, text);
    if (!ok) throw new Error(`không tìm thấy nút chứa "${text}"`);
  };

  // 1. Home → capture → chọn ảnh → phân tích
  // Chờ Home render xong (boot DB Worker + OPFS mất vài trăm ms — networkidle0
  // không đảm bảo React đã render; race này lộ ra khi Chrome khởi động chậm).
  await page.waitForFunction(
    () => [...document.querySelectorAll("button")].some((b) => b.textContent.includes("Chụp trang sách")),
    { timeout: 15000 },
  );
  await clickByText("Chụp trang sách");
  await page.waitForSelector("#capture-gallery", { timeout: 5000 });
  await (await page.$("#capture-gallery")).uploadFile(SAMPLE);
  await page.waitForSelector(".crop-canvas", { timeout: 10000 });
  await clickByText("Phân tích trang");

  // 2. Chờ MỘT TRONG HAI trạng thái: form BYOK (profile mới — lỗi missing_key
//    xuất hiện sau vài giây) HOẶC đã tới màn đọc (profile đã lưu fake endpoint
//    của lần chạy trước). Tránh chờ selector không bao giờ xuất hiện.
  const gotForm = await page
    .waitForSelector('input[type="password"]', { timeout: 20000 })
    .then(() => true)
    .catch(() => false);
  if (gotForm) {
    await page.type('input[type="password"]', "fake-key");
    await page.evaluate(() => {
      const url = document.querySelector('input[type="url"]');
      url.value = "";
    });
    await page.type('input[type="url"]', FAKE_BASE);
    await clickByText("Lưu & phân tích ngay");
  }

  // 3. ĐIỀU KIỆN CHÍNH: sau phân tích phải MỞ MÀN ĐỌC, không phải duyệt từ
  await page.waitForFunction(
    () => document.querySelector("h1")?.textContent === "Đọc trang",
    { timeout: 30000 },
  );
  check("mở màn Đọc trang ngay sau phân tích (không nhảy thẳng sang duyệt từ)", true);

  // Task 3.15: màn đọc load phiên từ DB (async) — chờ trang render trước khi đo.
  await page.waitForFunction(() => document.querySelectorAll(".read-page").length >= 1, { timeout: 10000 });

  const snap = await page.evaluate(() => ({
    segs: document.querySelectorAll(".seg").length,
    trShown: [...document.querySelectorAll(".seg-tr")].filter(
      (el) => getComputedStyle(el).display !== "none",
    ).length,
    vocabBtns: document.querySelectorAll(".seg-vocab").length,
    srcText: document.querySelector(".seg-src")?.textContent ?? "",
    summaryOpen: document.querySelector("details.read-summary")?.open ?? null,
    summaryExists: !!document.querySelector("details.read-summary"),
    header: document.querySelector(".read-page-no")?.textContent ?? "",
    reviseBtn: [...document.querySelectorAll("button")].some((b) => b.textContent.includes("Chọn từ (2)")),
  }));
  check("3 đoạn song ngữ hiển thị", snap.segs === 3, `segs=${snap.segs}`);
  check("bản dịch mặc định HIỆN (UI-1: 0 thao tác thêm)", snap.trShown === 3, `trShown=${snap.trShown}`);
  check("đoạn gốc đúng văn bản AI trả", snap.srcText.startsWith("The crowd went wildly"), snap.srcText.slice(0, 40));
  check("2 từ vựng được tô trong đoạn", snap.vocabBtns === 2, `vocabBtns=${snap.vocabBtns}`);
  check("summary tồn tại và MẶC ĐỊNH THU GỌN (FR-06)", snap.summaryExists && snap.summaryOpen === false);
  check("header trang 1 hiển thị", snap.header.includes("Trang 1"), snap.header);
  check("nút Chọn từ (2) có trên mỗi trang", snap.reviseBtn, `have=${snap.reviseBtn}`);

  // 4. FR-05 c.3: chạm từ → gloss nghĩa + IPA tại chỗ
  await page.evaluate(() => document.querySelector(".seg-vocab").click());
  const gloss = await page.$eval(".seg-gloss", (el) => el.textContent);
  check("chạm từ → gloss nghĩa + IPA ngay tại chỗ", gloss.includes("cuồng nhiệt") && gloss.includes("/ˈwaɪldli/"), gloss);

  // 5. FR-05 c.2: toggle ẩn/hiện TOÀN BỘ bản dịch một chạm
  await clickByText("Ẩn toàn bộ bản dịch");
  const hiddenCount = await page.evaluate(() => [...document.querySelectorAll(".seg-tr")].filter(
    (el) => getComputedStyle(el).display !== "none",
  ).length);
  check("một chạm ẩn toàn bộ bản dịch", hiddenCount === 0, `còn ${hiddenCount}`);
  await clickByText("Hiện toàn bộ bản dịch");
  const shownCount = await page.evaluate(() => [...document.querySelectorAll(".seg-tr")].filter(
    (el) => getComputedStyle(el).display !== "none",
  ).length);
  check("một chạm hiện lại toàn bộ bản dịch", shownCount === 3, `còn ${shownCount}`);

  // 6. Chụp trang kế → buffer giữ 2 trang (FR-05 c.4: cuộn ngược xem được)
  await clickByText("Chụp trang kế");
  await page.waitForSelector("#capture-gallery", { timeout: 5000 });
  await (await page.$("#capture-gallery")).uploadFile(SAMPLE);
  await page.waitForSelector(".crop-canvas", { timeout: 10000 });
  await clickByText("Phân tích trang");
  await page.waitForFunction(
    () => document.querySelectorAll(".read-page").length === 2,
    { timeout: 30000 },
  );
  const pageNo = await page.$eval(".read-page-no", (el) => el.textContent);
  check("màn đọc giữ 2 trang sau lần chụp thứ hai (cũ → mới)", pageNo.includes("Trang 1"), pageNo);

  // 7. Home tạm → nút quay lại phiên đọc (buffer còn sống)
  await clickByText("Về trang chủ");
  const resumeOk = await page
    .waitForFunction(
      () => [...document.querySelectorAll("button")].some((b) => b.textContent.includes("Đọc lại trang đã chụp")),
      { timeout: 5000 },
    )
    .then(() => true)
    .catch(() => false);
  check("Home có nút Đọc lại trang đã chụp (phiên đọc bền theo DB)", resumeOk);
  await clickByText("Đọc lại trang đã chụp");
  await page.waitForFunction(() => document.querySelector("h1")?.textContent === "Đọc trang", { timeout: 5000 });
  check("bấm nút → quay lại đúng màn đọc với buffer nguyên vẹn", true);

  // 7b. Task 3.15 (Q-10-reopen): phiên đọc SỐNG QUA F5 — điều mà buffer cũ
  //      không bao giờ làm được (đây là điểm chính owner muốn khi đảo Q-10).
  await page.reload({ waitUntil: "networkidle0", timeout: 30000 });
  await page.waitForSelector(".home", { timeout: 15000 });
  await clickByText("Đọc lại trang đã chụp");
  await page.waitForFunction(() => document.querySelectorAll(".read-page").length === 2, { timeout: 10000 });
  check("phiên đọc SỐNG QUA F5 — 2 trang vẫn nguyên sau khi mở lại app", true);

  // 8. FR-09 chống lưu trùng (bug 2026-09-09): lưu trang 1 → chỉ ĐƯỢC LƯU MỘT
  //    LẦN — đọc lại phiên thì nút "Chọn từ" của trang đó bị làm mờ + khoá,
  //    trong khi trang 2 chưa lưu vẫn dùng được.
  await clickByText("Chọn từ (2)");
  await page.waitForFunction(() => document.querySelector("h1")?.textContent === "Duyệt từ trước khi lưu", { timeout: 10000 });
  await clickByText("Lưu 2 thẻ");
  await page.waitForFunction(() => document.querySelector("h1")?.textContent.includes("Đã lưu"), { timeout: 15000 });
  check("lưu 2 thẻ của trang 1 thành công lần đầu", true);
  await clickByText("Về trang chủ");
  await clickByText("Đọc lại trang đã chụp");
  await page.waitForFunction(() => document.querySelector("h1")?.textContent === "Đọc trang", { timeout: 5000 });
  // Màn đọc load pages từ DB (async) — chờ đủ 2 trang render trước khi đo.
  await page.waitForFunction(() => document.querySelectorAll(".read-page-head").length === 2, { timeout: 10000 });
  const dedup = await page.evaluate(() => {
    const heads = [...document.querySelectorAll(".read-page-head")];
    const first = heads[0]?.querySelector("button.read-revise");
    const second = heads[1]?.querySelector("button.read-revise");
    return {
      firstDisabled: !!first && first.disabled,
      firstText: first?.textContent ?? "",
      secondDisabled: !!second && second.disabled,
      secondText: second?.textContent ?? "",
    };
  });
  check(
    "trang ĐÃ lưu: nút Chọn từ bị KHOÁ + ghi 'Đã lưu' (không thể lưu trùng)",
    dedup.firstDisabled && dedup.firstText.includes("Đã lưu"),
    `disabled=${dedup.firstDisabled}, text="${dedup.firstText.trim()}"`,
  );
  check(
    "trang CHƯA lưu vẫn vào Chọn từ bình thường",
    !dedup.secondDisabled && dedup.secondText.includes("Chọn từ"),
    `disabled=${dedup.secondDisabled}, text="${dedup.secondText.trim()}"`,
  );

  // 9. Task 3.15 — Collection Detail View (2 tab): Home → bấm collection →
  //    tab "Phiên đọc" (thẻ tóm tắt, cờ đã lưu persist) → tab "Từ vựng" (2 từ
  //    đã lưu) → "Mở màn đọc" quay lại ReadScreen với đúng phiên (sessionId).
  await clickByText("Về trang chủ");
  await page.waitForSelector(".home", { timeout: 5000 });
  // Khối Collections render bất đồng bộ (list từ DB) — chờ nút xuất hiện.
  await page.waitForFunction(
    () => [...document.querySelectorAll("button")].some((b) => b.textContent.includes("Kho tạm")),
    { timeout: 10000 },
  );
  await clickByText("Kho tạm"); // nút collection trong khối Collections của Home
  await page.waitForFunction(() => document.querySelector("h1")?.textContent.includes("Kho tạm"), { timeout: 5000 });
  await page.waitForFunction(() => document.querySelectorAll(".session-card").length === 2, { timeout: 10000 });
  const cards = await page.evaluate(() => {
    const els = [...document.querySelectorAll(".session-card")];
    return els.map((c) => c.textContent ?? "");
  });
  check(
    "Collection Detail: tab Phiên đọc hiện 2 thẻ — thẻ cũ hơn ghi 'Đã lưu (2 từ)' persist theo DB",
    cards.length === 2 &&
      cards.some((t) => t.includes("chưa lưu từ")) &&
      cards.some((t) => t.includes("Đã lưu (2 từ)")) &&
      cards.some((t) => t.includes("Đám đông phản ứng trái chiều")),
    cards.map((t) => t.slice(0, 60)).join(" | "),
  );
  await clickByText("📚 Từ vựng"); // tab — Home không mount nên không lẫn nút khác
  await page.waitForFunction(() => document.querySelectorAll(".vocab-card").length === 2, { timeout: 10000 });
  check("Collection Detail: tab Từ vựng liệt kê đúng 2 từ của collection", true);
  await clickByText("📖 Phiên đọc");
  await page.waitForFunction(() => document.querySelectorAll(".session-card").length === 2, { timeout: 10000 });
  await clickByText("Mở màn đọc");
  await page.waitForFunction(() => document.querySelector("h1")?.textContent === "Đọc trang", { timeout: 5000 });
  await page.waitForFunction(() => document.querySelectorAll(".read-page").length >= 2, { timeout: 10000 });
  const focusExists = await page.evaluate(
    () => document.querySelectorAll("section.read-page[id^='session-']").length >= 2,
  );
  check("Mở màn đọc từ thẻ phiên → ReadScreen mở lại phiên (2 trang nguyên)", focusExists);

  check("0 lỗi console", consoleErrors.length === 0, consoleErrors.slice(0, 3).join(" | "));

  const failed = results.filter((r) => !r.ok);
  console.log(JSON.stringify(results, null, 2));
  console.log(failed.length === 0 ? "✅ read-flow PASS" : `❌ read-flow FAIL: ${failed.length} mục`);
  process.exitCode = failed.length === 0 ? 0 : 1;
} finally {
  server.close();
  await browser.close();
}