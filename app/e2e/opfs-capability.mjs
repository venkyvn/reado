/**
 * e2e/opfs-capability.mjs — đo năng lực OPFS THẬT của browser đang chạy (bằng
 * chứng cho SPIKE storage). Trả lời ba câu hỏi quyết định kiến trúc:
 *
 *   1. crossOriginIsolated / SharedArrayBuffer có không (VFS "opfs" cần)
 *   2. createSyncAccessHandle có dùng được ở MAIN THREAD không (VFS
 *      "opfs-sahpool" cần; sqlite-wasm không chặn main-thread với VFS này)
 *   3. OPFS ghi/đọc thật có sống qua reload không
 *
 * Chạy: npm run e2e:opfs   (cần dev server; không cần app render gì cả)
 */
import puppeteer from "puppeteer-core";

const BASE = process.argv[2] ?? "http://localhost:5173/";
const CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const PROFILE = "/tmp/reado-e2e-profile";

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: true,
  args: [
    "--no-first-run",
    "--disable-crash-reporter",
    `--user-data-dir=${PROFILE}`,
    `--crash-dumps-dir=${PROFILE}`,
  ],
});

/** Thử SAH ngay trên main thread: tạo file, ghi, đọc lại, đóng, xoá. */
const probeMainThreadSAH = async () => {
  const out = { apiPresent: false, worked: false, error: null };
  try {
    out.apiPresent =
      typeof globalThis.FileSystemFileHandle?.prototype?.createSyncAccessHandle === "function";
    if (!out.apiPresent) return out;
    const root = await navigator.storage.getDirectory();
    const fh = await root.getFileHandle("reado-sah-probe.bin", { create: true });
    const sah = await fh.createSyncAccessHandle();
    sah.write(new Uint8Array([1, 2, 3, 4]));
    sah.flush?.();
    sah.close();
    const sah2 = await fh.createSyncAccessHandle();
    const buf = new Uint8Array(4);
    sah2.read(buf, { at: 0 });
    sah2.close();
    await root.removeEntry("reado-sah-probe.bin");
    out.worked = buf[0] === 1 && buf[3] === 4;
  } catch (e) {
    out.error = e instanceof Error ? `${e.name}: ${e.message}` : String(e);
  }
  return out;
};

const probeOpfsReload = async () => {
  const root = await navigator.storage.getDirectory();
  const fh = await root.getFileHandle("reado-opfs-probe.txt", { create: true });
  const w = await fh.createWritable();
  await w.write("alive");
  await w.close();
  return true;
};

const readOpfsReload = async () => {
  try {
    const root = await navigator.storage.getDirectory();
    const fh = await root.getFileHandle("reado-opfs-probe.txt");
    const text = await (await fh.getFile()).text();
    await root.removeEntry("reado-opfs-probe.txt");
    return text;
  } catch {
    return null;
  }
};

try {
  const page = await browser.newPage();
  await page.goto(BASE, { waitUntil: "networkidle0", timeout: 30000 });

  const env = await page.evaluate(() => ({
    crossOriginIsolated: globalThis.crossOriginIsolated === true,
    hasSharedArrayBuffer: typeof globalThis.SharedArrayBuffer === "function",
    hasAtomics: typeof globalThis.Atomics === "object",
    isWorkerScope: typeof globalThis.WorkerGlobalScope !== "undefined",
    hasGetDirectory: typeof navigator.storage?.getDirectory === "function",
    userAgent: navigator.userAgent,
  }));

  const sah = await page.evaluate(probeMainThreadSAH);
  await page.evaluate(probeOpfsReload);
  await page.reload({ waitUntil: "networkidle0", timeout: 30000 });
  const survived = (await page.evaluate(readOpfsReload)) === "alive";

  const result = {
    env,
    mainThreadSyncAccessHandle: sah,
    opfsSurvivesReload: survived,
    // VFS "opfs" của sqlite-wasm: bị lib chặn ở main thread (WorkerGlobalScope).
    vfsOpfsUsableHere: env.isWorkerScope && env.hasSharedArrayBuffer && env.hasGetDirectory,
    // VFS "opfs-sahpool": lib KHÔNG check WorkerGlobalScope → dùng được nếu SAH chạy.
    vfsSahpoolUsableHere: sah.worked === true,
  };
  console.log(JSON.stringify(result, null, 2));
  process.exitCode = result.opfsSurvivesReload ? 0 : 1;
} finally {
  await browser.close();
}
