/**
 * ui/imageToolkit.ts — thao tác ảnh trước khi gửi AI (FR-01: crop/xoay được).
 *
 * Nguyên tắc chất lượng (M-03, OCR sống nhờ pixel thật):
 * - KHÔNG crop KHÔNG xoay → gửi NGUYÊN bytes gốc, không re-encode lần nào.
 * - Có xoay/crop → re-encode JPEG 0.95 (đủ cho OCR, nhỏ gọn cho base64).
 * - EXIF orientation được browser tự flatten khi drawImage (modern iOS/Mac OK).
 */

export type Rotation = 0 | 90 | 180 | 270;

export interface CropRect {
  /** Pixel trong không gian canvas — số nguyên, đã clamp. */
  x: number;
  y: number;
  w: number;
  h: number;
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  const CHUNK = 0x8000;
  for (let i = 0; i < bytes.length; i += CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + CHUNK));
  }
  return btoa(binary);
}

export async function blobToBase64(blob: Blob): Promise<string> {
  const buf = new Uint8Array(await blob.arrayBuffer());
  return bytesToBase64(buf);
}

function requireCtx(canvas: HTMLCanvasElement): CanvasRenderingContext2D {
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("không lấy được canvas 2d context");
  return ctx;
}

/** Ảnh gốc → canvas (đã flatten EXIF orientation). */
export async function fileToCanvas(file: File): Promise<HTMLCanvasElement> {
  const url = URL.createObjectURL(file);
  try {
    const img = new Image();
    img.src = url;
    await img.decode();
    const canvas = document.createElement("canvas");
    canvas.width = img.naturalWidth;
    canvas.height = img.naturalHeight;
    requireCtx(canvas).drawImage(img, 0, 0);
    return canvas;
  } finally {
    URL.revokeObjectURL(url);
  }
}

/** Xoay canvas 90° × n (kim đồng hồ). n=0 trả chính canvas cũ. */
export function rotateCanvas(src: HTMLCanvasElement, quarterTurns: number): HTMLCanvasElement {
  const t = ((quarterTurns % 4) + 4) % 4;
  if (t === 0) return src;
  const swap = t % 2 === 1;
  const out = document.createElement("canvas");
  out.width = swap ? src.height : src.width;
  out.height = swap ? src.width : src.height;
  const ctx = requireCtx(out);
  ctx.translate(out.width / 2, out.height / 2);
  ctx.rotate((t * Math.PI) / 2);
  ctx.drawImage(src, -src.width / 2, -src.height / 2);
  return out;
}

/** Cắt rect (pixel) khỏi canvas thành canvas mới. */
export function cropCanvas(src: HTMLCanvasElement, rect: CropRect): HTMLCanvasElement {
  const out = document.createElement("canvas");
  out.width = rect.w;
  out.height = rect.h;
  requireCtx(out).drawImage(src, rect.x, rect.y, rect.w, rect.h, 0, 0, rect.w, rect.h);
  return out;
}

export function canvasToJpegBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("toBlob trả null"))),
      "image/jpeg",
      0.95,
    );
  });
}

export interface PreparedImage {
  base64: string;
  mime: string;
  /** true = đã qua re-encode (có xoay/crop) — chỉ để debug, không đổi hành vi. */
  reencoded: boolean;
}

/**
 * Chốt ảnh cuối gửi AI:
 * - canvas = ảnh ĐANG hiển thị (đã áp xoay nếu có)
 * - rect   = khung crop người dùng kéo (pixel canvas), null = nguyên tấm
 * - cùng null/null → bytes gốc
 */
export async function prepareForAnalysis(
  canvas: HTMLCanvasElement,
  rect: CropRect | null,
  originalFile: File,
  rotation: Rotation,
): Promise<PreparedImage> {
  const needsReencode = rect !== null || rotation !== 0;
  if (!needsReencode) {
    const buf = new Uint8Array(await originalFile.arrayBuffer());
    return { base64: bytesToBase64(buf), mime: originalFile.type || "image/jpeg", reencoded: false };
  }
  const source = rect ? cropCanvas(canvas, rect) : canvas;
  const blob = await canvasToJpegBlob(source);
  return { base64: await blobToBase64(blob), mime: "image/jpeg", reencoded: true };
}