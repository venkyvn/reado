import Foundation
import ReadoKit

// Báo lỗi cho người dùng thay vì nuốt bằng `try?` (refactor-r3 #1).
//
// Ba mức, chọn theo việc đang làm:
// - `attempt` — người dùng VỪA bấm một hành động (đổi tên, xoá, ghim…): lỗi hiện
//   alert + ghi DebugTrace.
// - `read` — nạp dữ liệu để vẽ màn: lỗi ghi DebugTrace, trả `fallback` để màn vẫn
//   vẽ được, và hiện alert MỘT lần cho tới khi lần đọc đó thành công trở lại
//   (không bật lại mỗi lần `reloadOverview`).
// - `readQuietly` — phần phụ trợ có thể thiếu mà không hại (gạch chân từ cũ, nhãn
//   xem trước): chỉ ghi DebugTrace.

extension AppModel {
    /// Lỗi của một HÀNH ĐỘNG người dùng — alert "Không <action> được: …".
    func report(_ error: Error, while action: String) {
        let detail = Self.userMessage(for: error)
        alertMessage = "Không \(action) được: \(detail)"
        DebugTrace.event("error", action, ["error": String(describing: error)])
    }

    /// Chạy một hành động người dùng vừa bấm; lỗi → `report`, trả `nil`.
    @discardableResult
    func attempt<T>(_ action: String, _ body: () throws -> T) -> T? {
        do {
            return try body()
        } catch {
            report(error, while: action)
            return nil
        }
    }

    /// Nạp dữ liệu để vẽ màn. Lỗi → DebugTrace + `fallback`; alert một lần/`what`
    /// tới khi đọc lại thành công.
    func read<T>(_ what: String, fallback: T, _ body: () throws -> T) -> T {
        do {
            let value = try body()
            failingReads.remove(what)
            return value
        } catch {
            DebugTrace.event("error", "read:\(what)", ["error": String(describing: error)])
            if failingReads.insert(what).inserted {
                alertMessage = "Không đọc được \(what): \(Self.userMessage(for: error))"
            }
            return fallback
        }
    }

    /// Như `read` nhưng không alert — chỉ cho thứ phụ trợ.
    func readQuietly<T>(_ what: String, fallback: T, _ body: () throws -> T) -> T {
        do {
            return try body()
        } catch {
            DebugTrace.event("error", "read:\(what)", ["error": String(describing: error)])
            return fallback
        }
    }

    static func userMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? String(describing: error)
    }
}
