/**
 * ui/imageToolkit.ts — thao tác ảnh trước khi gửi AI (FR-01: crop/xoay được).
 *
 * Quy tắc chất lượng (quyết định owner 2026-09-09, sau A/B `scripts/verify/ab-compress.mjs`):
 * - LUÔN chuẩn hoá ảnh gửi AI: crop/xoay (nếu có) → thu về cạnh dài ≤ 1600px
 *   (KHÔNG bao giờ upscale) → JPEG q0.80.
 * - Vì sao đảo quyết định cũ "không chỉnh → gửi bytes gốc": Gemini tính token ảnh
 *   theo PIXEL (≈ W×H/258) — ảnh photo 3024×4032 ăn ~27k token mỗi lần Analyze,
 *   resize 1600 còn ~7.4k; A/B đo được JPEG q0.80 làm lệch đúng 0–1 từ/trang
 *   (CER 0–0.19%) nên tầng đọc không mất gì. Kèm theo: mime không còn tin
 *   `File.type` (HEIC khai jpeg giả trước đây) — ảnh hiển thị được là encode được.
 * - EXIF orientation được browser tự flatten khi drawImage (modern iOS/Mac OK).
 */

/** Cạnh dài tối đa của ảnh gửi AI — chốt 2026-09-09 (A/B + ước lượng cap-height chữ). */
export const AI_IMAGE_MAX_DIMENSION = 1600
/** Chất lượng JPEG gửi AI — chốt 2026-09-09 (A/B: 0.80 không làm hỏng OCR, 0.75 chưa đo). */
export const AI_IMAGE_JPEG_QUALITY = 0.8

export type Rotation = 0 | 90 | 180 | 270

export interface CropRect {
  /** Pixel trong không gian canvas — số nguyên, đã clamp. */
  x: number
  y: number
  w: number
  h: number
}

export function bytesToBase64(bytes: Uint8Array): string {
  let binary = ""
  const CHUNK = 0x8000
  for (let i = 0; i < bytes.length; i += CHUNK) {
    binary += String.fromCharCode(...bytes.subarray(i, i + CHUNK))
  }
  return btoa(binary)
}

export async function blobToBase64(blob: Blob): Promise<string> {
  const buf = new Uint8Array(await blob.arrayBuffer())
  return bytesToBase64(buf)
}

function requireCtx(canvas: HTMLCanvasElement): CanvasRenderingContext2D {
  const ctx = canvas.getContext("2d")
  if (!ctx) throw new Error("không lấy được canvas 2d context")
  return ctx
}

/** Ảnh gốc → canvas (đã flatten EXIF orientation). */
export async function fileToCanvas(file: File): Promise<HTMLCanvasElement> {
  const url = URL.createObjectURL(file)
  try {
    const img = new Image()
    img.src = url
    await img.decode()
    const canvas = document.createElement("canvas")
    canvas.width = img.naturalWidth
    canvas.height = img.naturalHeight
    requireCtx(canvas).drawImage(img, 0, 0)
    return canvas
  } finally {
    URL.revokeObjectURL(url)
  }
}

/** Xoay canvas 90° × n (kim đồng hồ). n=0 trả chính canvas cũ. */
export function rotateCanvas(src: HTMLCanvasElement, quarterTurns: number): HTMLCanvasElement {
  const t = ((quarterTurns % 4) + 4) % 4
  if (t === 0) return src
  const swap = t % 2 === 1
  const out = document.createElement("canvas")
  out.width = swap ? src.height : src.width
  out.height = swap ? src.width : src.height
  const ctx = requireCtx(out)
  ctx.translate(out.width / 2, out.height / 2)
  ctx.rotate((t * Math.PI) / 2)
  ctx.drawImage(src, -src.width / 2, -src.height / 2)
  return out
}

/** Cắt rect (pixel) khỏi canvas thành canvas mới. */
export function cropCanvas(src: HTMLCanvasElement, rect: CropRect): HTMLCanvasElement {
  const out = document.createElement("canvas")
  out.width = rect.w
  out.height = rect.h
  requireCtx(out).drawImage(src, rect.x, rect.y, rect.w, rect.h, 0, 0, rect.w, rect.h)
  return out
}

export function canvasToJpegBlob(
  canvas: HTMLCanvasElement,
  quality = AI_IMAGE_JPEG_QUALITY,
): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("toBlob trả null"))),
      "image/jpeg",
      quality,
    )
  })
}

/**
 * Kích thước đích khi thu về cạnh dài ≤ maxDimension — hàm THUẦN để unit test.
 * Ảnh đã nhỏ hơn giữ nguyên (không upscale); làm tròn và chặn về ≥ 1px.
 */
export function scaledSize(
  w: number,
  h: number,
  maxDimension: number,
): { w: number; h: number; scaled: boolean } {
  const longest = Math.max(w, h)
  if (longest <= maxDimension) return { w, h, scaled: false }
  const scale = maxDimension / longest
  return {
    w: Math.max(1, Math.round(w * scale)),
    h: Math.max(1, Math.round(h * scale)),
    scaled: true,
  }
}

/**
 * Thu canvas về cạnh dài ≤ maxDimension — KHÔNG bao giờ upscale (ảnh nhỏ giữ nguyên).
 * `imageSmoothingQuality: "high"`: canvas mặc định "medium" làm nhoè viền chữ khi thu.
 */
export function downscaleCanvas(src: HTMLCanvasElement, maxDimension: number): HTMLCanvasElement {
  const size = scaledSize(src.width, src.height, maxDimension)
  if (!size.scaled) return src
  const out = document.createElement("canvas")
  out.width = size.w
  out.height = size.h
  const ctx = requireCtx(out)
  ctx.imageSmoothingEnabled = true
  ctx.imageSmoothingQuality = "high"
  ctx.drawImage(src, 0, 0, size.w, size.h)
  return out
}

export interface PreparedImage {
  base64: string
  mime: string
  /** Luôn true từ 2026-09-09 (mọi ảnh đều qua encode JPEG) — giữ để debug/telemetry. */
  reencoded: boolean
}

/**
 * Chốt ảnh cuối gửi AI:
 * - canvas = ảnh ĐANG hiển thị (đã áp xoay nếu có — caller lo xoay qua rotateCanvas)
 * - rect   = khung crop người dùng kéo (pixel canvas), null = nguyên tấm
 * Luôn crop (nếu có) → downscale 1600 → JPEG q0.80 (xem header quyết định 2026-09-09).
 */
export async function prepareForAnalysis(
  canvas: HTMLCanvasElement,
  rect: CropRect | null,
): Promise<PreparedImage> {
  const source = rect ? cropCanvas(canvas, rect) : canvas
  const scaled = downscaleCanvas(source, AI_IMAGE_MAX_DIMENSION)
  const blob = await canvasToJpegBlob(scaled)
  return { base64: await blobToBase64(blob), mime: "image/jpeg", reencoded: true }
}
