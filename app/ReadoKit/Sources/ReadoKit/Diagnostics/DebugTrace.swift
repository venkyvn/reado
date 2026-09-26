import Foundation
import os

/// Log chẩn đoán CHỈ BẢN DEBUG (ADR-037). Fen build thẳng bằng Xcode Run lên máy
/// thật — bản đó là Debug — nên các hàm ở đây được gọi VÔ ĐIỀU KIỆN từ code
/// thường (không phải bọc `#if DEBUG` ở từng chỗ gọi); thân mỗi hàm tự bọc
/// `#if DEBUG` nên bản Release/Archive không ghi gì, không tốn I/O. Không bao
/// giờ ghi API key / header Authorization vào đây — có `sanitize` chặn key
/// giống secret, nhưng đó là lưới an toàn thứ hai, không thay cho việc tự soát
/// ở chỗ gọi.
///
/// Layout trên đĩa (`Documents/Diagnostics/`):
///   events.jsonl              — mỗi dòng một sự kiện {ts, cat, name, fields}
///   events.1.jsonl            — bản cũ khi events.jsonl vượt `maxEventsFileBytes`
///   analyses/<ts>_<id8>/      — một thư mục mỗi lần phân tích, giữ tối đa `maxAnalysisFolders` gần nhất
///     page.jpg, ocr.json, page_ocr.txt, response_raw.txt, analysis.json, meta.json
///
/// Kéo về máy Mac: `scripts/pull_diagnostics.sh [sim|device]` rồi
/// `scripts/diag_summary.py <thư mục>`.
public enum DebugTrace {
    private static let logger = Logger(subsystem: "app.reado", category: "diagnostics")
    private static let maxEventsFileBytes = 2 * 1024 * 1024
    private static let maxAnalysisFolders = 30

    /// CHỈ TEST: đổi thư mục gốc thay vì `Documents` thật của app, để
    /// `DebugTraceTests` không đụng dữ liệu chẩn đoán thật trên simulator/máy.
    /// `nonisolated(unsafe)`: test set 1 lần trong `setUp`/`tearDown`, không có
    /// ghi đồng thời từ nhiều thread.
    public nonisolated(unsafe) static var documentsDirectoryOverride: URL?

    /// Ghi một sự kiện rời (không thuộc một lần phân tích cụ thể) — lỗi DB,
    /// quyền camera, lưu collection... `fields` chỉ nhận giá trị JSON-hoá được
    /// (String/Int/Double/Bool); giá trị khác bị bỏ qua thay vì làm crash log.
    public static func event(_ category: String, _ name: String, _ fields: [String: Any] = [:]) {
        #if DEBUG
        let sanitized = sanitize(fields)
        logger.debug(
            "[\(category, privacy: .public)] \(name, privacy: .public) \(describeFields(sanitized), privacy: .public)"
        )
        do {
            let line: [String: Any] = [
                "ts": ISOTimestamp.string(from: Date()),
                "cat": category,
                "name": name,
                "fields": sanitized,
            ]
            try appendEventLine(line)
        } catch {
            logger.debug("event write failed: \(String(describing: error), privacy: .public)")
        }
        #endif
    }

    /// Mở một thư mục mới cho lần phân tích này, rồi dọn các thư mục cũ quá
    /// `maxAnalysisFolders`. Gọi được từ code không phân biệt DEBUG/Release —
    /// bản Release trả về session rỗng (mọi `write`/`mergeMeta` không làm gì).
    public static func startAnalysis() -> AnalysisSession {
        let id = String(Identifier.uuid().prefix(8))
        let name = "\(ISOTimestamp.string(from: Date()).replacingOccurrences(of: ":", with: "-"))_\(id)"
        #if DEBUG
        pruneOldAnalyses()
        #endif
        return AnalysisSession(id: id, directory: analysesRoot().appendingPathComponent(name, isDirectory: true))
    }

    /// Một lần phân tích trang — gom mọi artifact (OCR, prompt, response, ảnh)
    /// vào một thư mục để đối chiếu khi chỉnh ngưỡng ngắt đoạn OCR. Mọi hàm ghi
    /// tự no-op ngoài bản DEBUG.
    public final class AnalysisSession: @unchecked Sendable {
        public let id: String
        private let directory: URL
        private let lock = NSLock()
        private var meta: [String: Any] = [:]

        fileprivate init(id: String, directory: URL) {
            self.id = id
            self.directory = directory
        }

        public func write(pageOCR text: String) {
            write(text, to: "page_ocr.txt")
        }

        public func write(image data: Data) {
            write(data, to: "page.jpg")
        }

        public func write(ocrDebug json: [String: Any]) {
            writeJSON(json, to: "ocr.json")
        }

        public func write(responseRaw text: String) {
            write(text, to: "response_raw.txt")
        }

        public func write(analysisJSON json: [String: Any]) {
            writeJSON(json, to: "analysis.json")
        }

        /// Merge thêm field vào meta.json (model, timing, lỗi...) — gọi nhiều lần,
        /// mỗi lần merge chồng lên chứ không ghi đè cả file.
        public func mergeMeta(_ fields: [String: Any]) {
            #if DEBUG
            lock.lock()
            for (key, value) in DebugTrace.sanitize(fields) { meta[key] = value }
            let snapshot = meta
            lock.unlock()
            writeJSON(snapshot, to: "meta.json")
            #endif
        }

        private func write(_ text: String, to filename: String) {
            #if DEBUG
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true)
                try text.write(
                    to: directory.appendingPathComponent(filename), atomically: true, encoding: .utf8)
            } catch {
                logger.debug(
                    "session write \(filename, privacy: .public) failed: \(String(describing: error), privacy: .public)"
                )
            }
            #endif
        }

        private func write(_ data: Data, to filename: String) {
            #if DEBUG
            do {
                try FileManager.default.createDirectory(
                    at: directory, withIntermediateDirectories: true)
                try data.write(to: directory.appendingPathComponent(filename))
            } catch {
                logger.debug(
                    "session write \(filename, privacy: .public) failed: \(String(describing: error), privacy: .public)"
                )
            }
            #endif
        }

        private func writeJSON(_ object: [String: Any], to filename: String) {
            #if DEBUG
            guard JSONSerialization.isValidJSONObject(object),
                  let data = try? JSONSerialization.data(
                    withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            else { return }
            write(data, to: filename)
            #endif
        }
    }

    // MARK: - Paths

    private static func diagnosticsRoot() -> URL {
        let documents = documentsDirectoryOverride
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Diagnostics", isDirectory: true)
    }

    private static func analysesRoot() -> URL {
        diagnosticsRoot().appendingPathComponent("analyses", isDirectory: true)
    }

    private static func eventsFile() -> URL {
        diagnosticsRoot().appendingPathComponent("events.jsonl")
    }

    // MARK: - events.jsonl

    #if DEBUG
    private static func appendEventLine(_ line: [String: Any]) throws {
        try FileManager.default.createDirectory(
            at: diagnosticsRoot(), withIntermediateDirectories: true)
        rotateEventsFileIfNeeded()
        var data = try JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])
        data.append(0x0A) // "\n"
        let url = eventsFile()
        if FileManager.default.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: url)
        }
    }

    private static func rotateEventsFileIfNeeded() {
        let url = eventsFile()
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int,
              size > maxEventsFileBytes
        else { return }
        let rotated = diagnosticsRoot().appendingPathComponent("events.1.jsonl")
        try? FileManager.default.removeItem(at: rotated)
        try? FileManager.default.moveItem(at: url, to: rotated)
    }

    // MARK: - analyses/ rotation

    private static func pruneOldAnalyses() {
        let root = analysesRoot()
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil)
        else { return }
        // Tên thư mục bắt đầu bằng timestamp ISO → sort theo tên = sort theo thời gian.
        let sorted = entries.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard sorted.count >= maxAnalysisFolders else { return }
        for old in sorted.prefix(sorted.count - maxAnalysisFolders + 1) {
            try? FileManager.default.removeItem(at: old)
        }
    }
    #endif

    // MARK: - sanitize

    /// Chặn key/value giống secret lọt vào log — lưới an toàn thứ hai, không
    /// thay cho việc tự soát ở chỗ gọi.
    private static let secretKeyHints = ["key", "authorization", "token", "secret", "password"]

    fileprivate static func sanitize(_ fields: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in fields {
            let lowered = key.lowercased()
            if secretKeyHints.contains(where: { lowered.contains($0) }) {
                result[key] = "<redacted>"
                continue
            }
            switch value {
            case is String, is Int, is Double, is Float, is Bool:
                result[key] = value
            default:
                result[key] = String(describing: value)
            }
        }
        return result
    }

    private static func describeFields(_ fields: [String: Any]) -> String {
        fields.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
    }
}
