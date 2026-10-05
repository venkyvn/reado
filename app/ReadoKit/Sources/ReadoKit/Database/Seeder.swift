import Foundation

/// Seed lúc cài đặt — MỘT transaction (db.md A.2.1):
/// 1. collection kho tạm `is_default = 1`
/// 2. analysis_agent placeholder "chưa chọn agent" (id cố định, không xoá được)
/// 3. settings id = 1 với timezone IANA của device
public enum Seeder {
    /// db.md A.2.1 — id cố định, hàng này không xoá được (FR-21 app-rule).
    /// ADR-049: kind lưu DB vẫn là chuỗi `reado_proxy` (CHECK cột, đổi = migration)
    /// nhưng không còn nghĩa "proxy" — chỉ giữ chỗ cho `active_agent_id` NOT NULL
    /// trước khi user thêm agent BYOK thật. `AnalysisAgentStore`/`AnalyzerFactory`
    /// lọc/ẩn hàng này khỏi UI và báo lỗi rõ nếu lọt vào `analyze()`.
    public static let placeholderAgentID = "00000000-0000-4000-a000-000000000001"
    public static let placeholderAgentName = "Chưa chọn agent"
    /// apple-ai-r1 T5 (ADR-063) — hàng builtin Apple Intelligence, id cố định,
    /// không xoá/sửa được (`AnalysisAgentStore`). Migration v6 tạo hàng này
    /// (cả DB cũ nâng cấp lẫn cài mới — cài mới chạy hết migration trước khi
    /// `Seeder.seed` chạy, xem `Migration.v6Statements`), không phải ở đây.
    public static let appleAgentID = "00000000-0000-4000-a000-000000000002"
    public static let appleAgentName = "Apple Intelligence"
    /// PRD FR-17 gọi collection mặc định là "kho tạm" — chọn tên hiển thị đơn giản.
    public static let defaultCollectionName = "Kho tạm"
    /// db.md A.2.1: ghi 'fsrs-6' kể cả khi fsrs_params null (default = defaultWv6 lúc gọi FSRS).
    public static let fsrsVersionValue = "fsrs-6"
    /// FR-19 — ngưỡng leech mặc định R1. 🔶 TẠM = 6, CHƯA CHỐT — thuộc nhóm Q-08.
    /// PRD FR-19: "ngưỡng cụ thể chưa chốt… nếu 'thẻ sai' đúng thì nên thấp hơn Anki 8".
    /// Chờ owner chốt số; đổi đây + literal trong LeechTests cùng lúc.
    /// Owner chốt 2026-09-24: suspend khi lapses >= 6. Không phải placeholder.
    public static let defaultLeechLapses = 6

    public static func isSeeded(on db: SQLiteDatabase) throws -> Bool {
        let count = try db.scalarInt64(
            "SELECT COUNT(*) FROM collections WHERE is_default = 1;")
        return (count ?? 0) > 0
    }

    /// Idempotent — seed dở chừng bị rollback cả cụm (một transaction).
    public static func seed(
        on db: SQLiteDatabase, timezone: String, now: Date = Date()
    ) throws {
        // Kiểm tra TRƯỚC transaction: seed xong thì không seed lại.
        if try isSeeded(on: db) { return }
        let nowIso = ISOTimestamp.string(from: now)
        try db.inTransaction {
            try db.run(
                """
                INSERT INTO collections (id, name, is_default, created_at)
                VALUES (?, ?, 1, ?);
                """,
                [
                    .text(Identifier.uuid()),
                    .text(defaultCollectionName),
                    .text(nowIso),
                ])
            try db.run(
                """
                INSERT INTO analysis_agents (id, kind, name, base_url, model, created_at)
                VALUES (?, 'reado_proxy', ?, NULL, NULL, ?);
                """,
                [
                    .text(placeholderAgentID),
                    .text(placeholderAgentName),
                    .text(nowIso),
                ])
            // Q-12 CHỐT: enable_short_term = 0 (learning steps tắt).
            try db.run(
                """
                INSERT INTO settings (
                  id, cefr_level, daily_new_limit, request_retention,
                  maximum_interval, enable_fuzz, day_cutoff_hour, timezone,
                  enable_short_term, known_stability, leech_lapses,
                  fsrs_params, fsrs_version, home_shortcut_1_id,
                  home_shortcut_2_id, active_agent_id
                ) VALUES (
                  1, 'B2', 10, 0.9, 36500, 1, 4, ?, 0,
                  NULL, ?, NULL, ?, NULL, NULL, ?
                );
                """,
                [
                    .text(timezone),
                    .int(Int64(defaultLeechLapses)),
                    .text(fsrsVersionValue),
                    .text(placeholderAgentID),
                ])
        }
    }
}