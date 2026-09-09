/**
 * ui/screens/HomeScreen.tsx — FR-14: trang chủ hiện ba con số đúng hợp đồng:
 *
 * - số card đến hạn hôm nay = số SẼ được ôn hôm nay (đã áp daily_new_limit) —
 *   dùng chung usecase getHomeStats nên LUÔN bằng `total` của màn ôn tập, không
 *   có đường đếm thứ hai (criterion 2);
 * - phần tồn (thẻ mới bị hoãn vì hết hạn mức) là con số RIÊNG, nhãn RIÊNG
 *   (criterion 3) — chỉ hiện khi > 0, không gộp vào con số trên.
 * - số trang đã phân tích (bảng analyses) + streak ngày ôn liên tục (giờ
 *   chuyển ngày của FR-11 — criterion cuối).
 *
 * Màn này mount lại mỗi lần quay về home (router state) nên số tự làm mới sau
 * mỗi phiên ôn/analyse. NFR-08: nút chụp vẫn là chạm thứ nhất.
 */
import { useEffect, useState } from "react";
import type { Screen } from "../AppRoot";
import type { HomeStats } from "../../domain/usecases/homeStats";
import { getHomeStats } from "../../domain/usecases/homeStats";
import { useAppEnv } from "../context";

export function HomeScreen({ navigate }: { navigate: (s: Screen) => void }) {
  const { services } = useAppEnv();
  const [stats, setStats] = useState<HomeStats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let alive = true;
    void getHomeStats(services)
      .then((s) => {
        if (alive) setStats(s);
      })
      .catch((e) => {
        if (alive) setError(e instanceof Error ? e.message : String(e));
      });
    return () => {
      alive = false;
    };
  }, [services]);

  return (
    <div className="home pad">
      <h1 className="brand">Reado</h1>
      <p className="muted">Ảnh trang sách → song ngữ + từ vựng ôn tập cách quãng (FSRS).</p>

      <button type="button" className="primary big" onClick={() => navigate({ name: "capture" })}>
        📷 Chụp trang sách
      </button>
      <button type="button" className="primary big alt" onClick={() => navigate({ name: "review" })}>
        🃏 Ôn tập hôm nay{stats ? ` (${stats.dueToday})` : ""}
      </button>
      <button type="button" className="secondary big" onClick={() => navigate({ name: "vocabLibrary" })}>
        📚 Kho từ vựng
      </button>

      <section className="stats" aria-label="Tiến độ hôm nay">
        {stats === null ? (
          <p className="muted">Đang tính tiến độ…</p>
        ) : (
          <>
            <div className="stat-row">
              <span className="stat-label">Đến hạn hôm nay</span>
              <span className="stat-value">{stats.dueToday}</span>
              <span className="stat-unit">card</span>
            </div>
            {stats.backlog > 0 && (
              <div className="stat-row stat-deferred">
                <span className="stat-label">Còn tồn — chờ ngày sau (hết hạn mức thẻ mới)</span>
                <span className="stat-value">{stats.backlog}</span>
                <span className="stat-unit">card</span>
              </div>
            )}
            <div className="stat-row">
              <span className="stat-label">Trang đã phân tích</span>
              <span className="stat-value">{stats.analyzedPages}</span>
              <span className="stat-unit">trang</span>
            </div>
            <div className="stat-row">
              <span className="stat-label">Streak ôn tập</span>
              <span className="stat-value">{stats.streakDays}</span>
              <span className="stat-unit">ngày liên tiếp</span>
            </div>
          </>
        )}
        {error && <p className="errorbox">Không đọc được tiến độ — {error}</p>}
      </section>

      <p style={{ marginTop: 24 }}>
        <a className="dim" href="#export" onClick={() => navigate({ name: "export" })}>
          ⬇︎ Xuất dữ liệu (Anki / JSON)
        </a>
        {" · "}
        <a className="dim" href="#storage" onClick={() => navigate({ name: "storageCheck" })}>
          Kiểm tra lưu trữ (SPIKE)
        </a>
      </p>
    </div>
  );
}