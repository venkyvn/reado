import Foundation

/// Cặp (timezone, giờ chuyển ngày) đọc từ `settings` id = 1 — nguồn duy nhất cho
/// mọi phép "hôm nay" (hàng đợi FR-11, tiến độ FR-14, streak). Trước đây ba nơi
/// tự chép cùng đoạn đọc này. Lỗi/thiếu dữ liệu → UTC (rồi `.current` nếu id
/// không hợp lệ) và 4 giờ, đúng như bản chép cũ.
public enum DayContext {
    public static func read(
        on db: SQLiteDatabase
    ) -> (timezone: TimeZone, cutoffHour: Int) {
        let timezoneID: String = (try? db.scalarString(
            "SELECT timezone FROM settings WHERE id = 1;")) ?? "UTC"
        let cutoffHour: Int = {
            if let v = try? db.scalarInt64(
                "SELECT day_cutoff_hour FROM settings WHERE id = 1;") {
                return Int(v)
            }
            return 4
        }()
        let timezone = TimeZone(identifier: timezoneID) ?? .current
        return (timezone, cutoffHour)
    }
}
