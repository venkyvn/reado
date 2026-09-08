/**
 * ui/fileDelivery.ts — giao một file text xuống máy người dùng.
 *
 * Ba tầng, thứ tự phụ thuộc thiết bị — và thứ tự đó có lý do:
 * - **Touch (iPhone/iPad/Android)**: ưu tiên Web Share API. Trong PWA standalone
 *   của iOS, `a[download]` thường **im lặng không làm gì cả** (không ném lỗi) —
 *   thất bại im lặng là loại tệ nhất với một cái phao cứu sinh dữ liệu, nên trên
 *   mobile phải đi đường share ("Lưu vào Tệp") trước.
 * - **Desktop**: ưu tiên Blob + `a[download]` — tải thẳng, tự nhiên hơn là mở
 *   sheet chia sẻ của hệ điều hành.
 * - **manual**: trả nội dung về cho UI hiện textarea + nút copy. Không phụ thuộc
 *   API nào nên không thể fail.
 *
 * NFR-05: export PHẢI luôn hoạt động (điều kiện để owner dám dồn dữ liệu nhiều
 * năm vào app) — nên mọi lỗi đều rơi xuống tầng kế, không bao giờ ném ra UI.
 *
 * Phân biệt lỗi (bug đã gặp, e2e/export-flow.mjs bắt được): `AbortError` = người
 * dùng THẬT SỰ huỷ sheet → báo "đã huỷ". `NotAllowedError` (thiếu user activation,
 * trình duyệt chặn) KHÔNG phải huỷ → phải rơi xuống tầng tải, nếu không người
 * dùng bị báo sai và mất file.
 */
export type DeliveryOutcome =
  | { method: "share" }
  | { method: "download" }
  | { method: "cancelled" }
  | { method: "manual"; reason: string };

/** Navigator có Web Share API level 2 (chia sẻ file) — không trình duyệt nào cũng có. */
type ShareCapableNavigator = Navigator & {
  canShare?: (data: { files?: File[] }) => boolean;
  share?: (data: { files?: File[] }) => Promise<void>;
};

function isUserDismiss(e: unknown): boolean {
  // CHỈ AbortError. NotAllowedError là "không được phép", không phải "người dùng huỷ".
  return e instanceof Error && e.name === "AbortError";
}

function reason(e: unknown): string {
  return e instanceof Error ? `${e.name}: ${e.message}` : String(e);
}

async function tryShare(nav: ShareCapableNavigator, filename: string, text: string, mime: string) {
  if (typeof nav.canShare !== "function" || typeof nav.share !== "function" || typeof File !== "function") {
    return null;
  }
  try {
    const file = new File([text], filename, { type: mime });
    if (!nav.canShare({ files: [file] })) return null;
    await nav.share({ files: [file] });
    return { method: "share" } as const;
  } catch (e) {
    if (isUserDismiss(e)) return { method: "cancelled" } as const;
    return null; // lỗi khác → để tầng kế lo
  }
}

function tryDownload(filename: string, text: string, mime: string): DeliveryOutcome | null {
  try {
    const blob = new Blob([text], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = filename;
    a.rel = "noopener";
    document.body.appendChild(a);
    a.click();
    a.remove();
    // Revoke trễ: tải lớn có thể chưa kịp bắt đầu nếu revoke ngay sau click.
    setTimeout(() => URL.revokeObjectURL(url), 10_000);
    return { method: "download" };
  } catch (e) {
    return { method: "manual", reason: reason(e) };
  }
}

export async function deliverTextFile(
  filename: string,
  text: string,
  mime: string,
): Promise<DeliveryOutcome> {
  const nav = globalThis.navigator as ShareCapableNavigator | undefined;
  const isTouch = typeof nav?.maxTouchPoints === "number" && nav.maxTouchPoints > 0;

  if (nav && isTouch) {
    const shared = await tryShare(nav, filename, text, mime);
    if (shared) return shared;
  }

  const downloaded = tryDownload(filename, text, mime);
  if (downloaded && downloaded.method === "download") return downloaded;

  // Desktop mà a[download] ném lỗi → thử nốt share trước khi chịu thua.
  if (nav && !isTouch) {
    const shared = await tryShare(nav, filename, text, mime);
    if (shared) return shared;
  }

  return downloaded ?? { method: "manual", reason: "không có đường giao file nào khả dụng" };
}
