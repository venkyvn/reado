/**
 * ui/screens/CaptureScreen.tsx — FR-01: chọn/chụp ảnh, crop + xoay TRƯỚC khi
 * gửi AI, chọn collection hoặc tạo mới NGAY TRONG flow (không rời màn), không
 * chọn → rơi vào collection mặc định. NFR-08: từ Home tới chụp = 1 chạm.
 *
 * Chất lượng ảnh (quyết định 2026-09-09, xem imageToolkit.ts): LUÔN chuẩn hoá —
 * crop/xoay (nếu có) → cạnh dài ≤ 1600px (không upscale) → JPEG q0.80.
 */
import { useCallback, useEffect, useRef, useState } from "react";
import type { ChangeEvent, PointerEvent } from "react";
import type { AnalysisResult, CollectionRow } from "../../domain/types";
import type { PageImage } from "../../domain/ai";
import type { Screen } from "../AppRoot";
import { useAppEnv } from "../context";
import { AnalyzePanel } from "../AnalyzePanel";
import { fileToCanvas, prepareForAnalysis, rotateCanvas } from "../imageToolkit";
import type { CropRect, Rotation } from "../imageToolkit";

interface DragState {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
}

export function CaptureScreen({ navigate, onAnalyzed }: {
  navigate: (s: Screen) => void;
  /** FR-05: kết quả phân tích đi qua AppRoot — task 3.15 (Q-10-reopen):
   *  AppRoot PERSIST phiên đọc vào reading_sessions rồi mở màn đọc (PRD mục 6:
   *  Analyze → Đọc song ngữ → Summary → Chọn từ), không nhảy thẳng sang duyệt từ.
   *  `analysisId` = id dòng analyses + reading_sessions ("" nếu ghi DB hỏng). */
  onAnalyzed: (analysis: AnalysisResult, collectionId: string, analysisId: string) => void;
}) {
  const { services } = useAppEnv();

  const [collections, setCollections] = useState<CollectionRow[]>([]);
  const [selectedCollectionId, setSelectedCollectionId] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState("");

  const [file, setFile] = useState<File | null>(null);
  const [canvas, setCanvas] = useState<HTMLCanvasElement | null>(null);
  const [rotation, setRotation] = useState<Rotation>(0);
  const [crop, setCrop] = useState<CropRect | null>(null);
  const [drag, setDrag] = useState<DragState | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [busySubmit, setBusySubmit] = useState(false);

  const [payload, setPayload] = useState<{ image: PageImage; collectionId: string } | null>(null);

  // BUG ĐÃ GẶP THẬT (owner test 2026-09-08: upload ảnh xong KHÔNG thấy hình):
  // React set attribute width/height lên <canvas> khi mount/đổi giá trị, và theo
  // spec HTML việc đó XOÁ bitmap — canvas còn đúng kích thước nhưng trong suốt.
  // Ảnh vẫn gửi được vì lúc đó prepareForAnalysis đọc bytes gốc của File, nên flow
  // chạy mà preview thì trắng (từ 2026-09-09 ảnh luôn encode từ canvas — xem header
  // imageToolkit — nên preview hỏng sẽ ĐÙN luôn flow thay vì lặng lẽ gửi đen). Sửa:
  // giữ canvas NGUỒN trong state, vẽ lại vào canvas
  // do React quản lý (viewRef) SAU mỗi lần DOM cập nhật.
  const viewRef = useRef<HTMLCanvasElement | null>(null);

  useEffect(() => {
    const view = viewRef.current;
    if (!view || !canvas) return;
    const ctx = view.getContext("2d");
    if (ctx) ctx.drawImage(canvas, 0, 0);
  }, [canvas]);

  // payloadRef cho handleAnalysisDone đọc collectionId mà KHÔNG phụ thuộc
  // render — handleAnalysisDone phải giữ identity ổn định (dep của AnalyzePanel).
  const payloadRef = useRef<{ image: PageImage; collectionId: string } | null>(null);

  const handleAnalysisDone = useCallback(
    (r: AnalysisResult, analysisId: string) => {
      const current = payloadRef.current;
      if (current) onAnalyzed(r, current.collectionId, analysisId);
    },
    [onAnalyzed],
  );

  useEffect(() => {
    void services.repos.collections.list().then((list) => {
      setCollections(list);
      setSelectedCollectionId((current) => current ?? list.find((c) => c.isDefault)?.id ?? null);
    });
  }, [services]);

  const targetCollectionId = selectedCollectionId ?? collections.find((c) => c.isDefault)?.id ?? null;

  async function onFilePicked(e: ChangeEvent<HTMLInputElement>) {
    const picked = e.target.files?.[0];
    e.target.value = "";
    if (!picked) return;
    try {
      const c = await fileToCanvas(picked);
      setFile(picked);
      setCanvas(c);
      setRotation(0);
      setCrop(null);
      setDrag(null);
      setFormError(null);
    } catch (err) {
      setFormError(`Không đọc được ảnh này — ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  function rotate() {
    if (!canvas) return;
    setCanvas(rotateCanvas(canvas, 1));
    setRotation((r) => (((r + 90) % 360) as Rotation));
    setCrop(null);
    setDrag(null);
  }

  function toPixel(e: PointerEvent<HTMLCanvasElement>): { x: number; y: number } {
    const c = e.currentTarget;
    const rect = c.getBoundingClientRect();
    const clamp = (v: number, max: number) => Math.max(0, Math.min(max, v));
    return {
      x: clamp(((e.clientX - rect.left) / rect.width) * c.width, c.width),
      y: clamp(((e.clientY - rect.top) / rect.height) * c.height, c.height),
    };
  }

  function onPointerDown(e: PointerEvent<HTMLCanvasElement>) {
    e.preventDefault();
    e.currentTarget.setPointerCapture(e.pointerId);
    const p = toPixel(e);
    setDrag({ x0: p.x, y0: p.y, x1: p.x, y1: p.y });
  }

  function onPointerMove(e: PointerEvent<HTMLCanvasElement>) {
    if (!drag) return;
    const p = toPixel(e);
    setDrag({ ...drag, x1: p.x, y1: p.y });
  }

  function onPointerUp() {
    if (!drag || !canvas) return;
    const x = Math.min(drag.x0, drag.x1);
    const y = Math.min(drag.y0, drag.y1);
    const w = Math.abs(drag.x1 - drag.x0);
    const h = Math.abs(drag.y1 - drag.y0);
    const tiny = canvas.width * canvas.height * 0.02;
    setCrop(w * h < tiny ? null : { x: Math.round(x), y: Math.round(y), w: Math.round(w), h: Math.round(h) });
    setDrag(null);
  }

  const liveRect = drag
    ? {
        x: Math.min(drag.x0, drag.x1),
        y: Math.min(drag.y0, drag.y1),
        w: Math.abs(drag.x1 - drag.x0),
        h: Math.abs(drag.y1 - drag.y0),
      }
    : crop;

  async function submit() {
    if (!canvas || !file || busySubmit) return;
    const collectionId = targetCollectionId;
    if (!collectionId) return;
    setBusySubmit(true);
    setFormError(null);
    try {
      const prepared = await prepareForAnalysis(canvas, crop);
      const next = { image: { base64: prepared.base64, mime: prepared.mime }, collectionId };
      payloadRef.current = next;
      setPayload(next);
    } catch (err) {
      setFormError(`Xử lý ảnh lỗi — ${err instanceof Error ? err.message : String(err)}`);
    } finally {
      setBusySubmit(false);
    }
  }

  async function createCollection() {
    const name = newName.trim();
    if (!name) return;
    setFormError(null);
    try {
      const created = await services.repos.collections.create(name, false, new Date());
      const list = await services.repos.collections.list();
      setCollections(list);
      setSelectedCollectionId(created.id);
      setCreating(false);
      setNewName("");
    } catch (err) {
      setFormError(`Tạo collection lỗi — ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  function resetAll() {
    setFile(null);
    setCanvas(null);
    setRotation(0);
    setCrop(null);
    setDrag(null);
    setFormError(null);
  }

  if (payload) {
    return <AnalyzePanel image={payload.image} onDone={handleAnalysisDone} onCancel={() => setPayload(null)} />;
  }

  return (
    <div className="pad">
      <h1>Chụp trang</h1>

      {formError && <div className="banner banner-error">{formError}</div>}

      {!canvas && (
        <>
          <input
            type="file"
            accept="image/*"
            capture="environment"
            style={{ display: "none" }}
            id="capture-camera"
            onChange={(e) => void onFilePicked(e)}
          />
          <input
            type="file"
            accept="image/*"
            style={{ display: "none" }}
            id="capture-gallery"
            onChange={(e) => void onFilePicked(e)}
          />
          <button
            type="button"
            className="primary"
            onClick={() => document.getElementById("capture-camera")?.click()}
          >
            📷 Chụp bằng máy ảnh
          </button>
          <button
            type="button"
            className="secondary"
            onClick={() => document.getElementById("capture-gallery")?.click()}
          >
            🖼 Chọn ảnh có sẵn
          </button>
        </>
      )}

      {canvas && (
        <>
          <p className="hint">Kéo (drag) trên ảnh để chọn vùng cần giữ — không bắt buộc.</p>
          <div className="crop-wrap">
            <canvas
              ref={viewRef}
              className="crop-canvas"
              width={canvas.width}
              height={canvas.height}
              onPointerDown={onPointerDown}
              onPointerMove={onPointerMove}
              onPointerUp={onPointerUp}
            />
            {liveRect && (
              <div
                className="crop-box"
                style={{
                  left: `${(liveRect.x / canvas.width) * 100}%`,
                  top: `${(liveRect.y / canvas.height) * 100}%`,
                  width: `${(liveRect.w / canvas.width) * 100}%`,
                  height: `${(liveRect.h / canvas.height) * 100}%`,
                }}
              />
            )}
          </div>
          <div className="btn-row">
            <button type="button" className="secondary" onClick={rotate}>
              🔄 Xoay 90°
            </button>
            <button type="button" className="secondary" onClick={() => setCrop(null)} disabled={!crop}>
              ✂ Xoá khung
            </button>
          </div>
          <button type="button" className="secondary" onClick={resetAll}>
            ↔ Đổi ảnh
          </button>
          {rotation !== 0 && <p className="hint">Đã xoay {rotation}° — ảnh gửi đi là ảnh đang thấy.</p>}

          <h2>Vào collection</h2>
          <p className="hint">Không chọn gì → tự về “Kho tạm”, vẫn ôn tập bình thường.</p>
          {!creating ? (
            <>
              <select
                value={targetCollectionId ?? ""}
                onChange={(e) => setSelectedCollectionId(e.target.value)}
              >
                {collections.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                    {c.isDefault ? " (mặc định)" : ""}
                  </option>
                ))}
              </select>
              <button
                type="button"
                className="secondary"
                onClick={() => setCreating(true)}
                style={{ marginBottom: 12 }}
              >
                ＋ Tạo collection mới
              </button>
            </>
          ) : (
            <>
              <input
                type="text"
                value={newName}
                placeholder="Tên collection, vd: The Giver — ch.2"
                onChange={(e) => setNewName(e.target.value)}
              />
              <div className="btn-row">
                <button
                  type="button"
                  className="primary"
                  disabled={newName.trim() === ""}
                  onClick={() => void createCollection()}
                >
                  Tạo
                </button>
                <button type="button" className="secondary" onClick={() => setCreating(false)}>
                  Thôi
                </button>
              </div>
            </>
          )}

          <button
            type="button"
            className="primary"
            disabled={!targetCollectionId || busySubmit}
            onClick={() => void submit()}
          >
            🔍 Phân tích trang
          </button>
        </>
      )}

      <button type="button" className="secondary" onClick={() => navigate({ name: "home" })}>
        ← Về trang chủ
      </button>
    </div>
  );
}