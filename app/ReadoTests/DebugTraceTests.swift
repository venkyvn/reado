import XCTest
import ReadoKit

/// T-diag: DebugTrace (ADR-037) — kho log chẩn đoán DEBUG-only. Chạy trong thư
/// mục tạm riêng (`documentsDirectoryOverride`) — KHÔNG đụng `Documents/Diagnostics`
/// thật của app trên simulator.
final class DebugTraceTests: XCTestCase {
    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("DebugTraceTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        DebugTrace.documentsDirectoryOverride = tempRoot
    }

    override func tearDown() {
        DebugTrace.documentsDirectoryOverride = nil
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        super.tearDown()
    }

    private var diagnosticsDir: URL { tempRoot.appendingPathComponent("Diagnostics", isDirectory: true) }
    private var analysesDir: URL { diagnosticsDir.appendingPathComponent("analyses", isDirectory: true) }
    private var eventsFile: URL { diagnosticsDir.appendingPathComponent("events.jsonl") }

    func testEventWritesJSONLine() throws {
        DebugTrace.event("camera", "running", ["width": 1080, "ok": true])

        let content = try String(contentsOf: eventsFile, encoding: .utf8)
        let lines = content.split(separator: "\n")
        XCTAssertEqual(lines.count, 1)
        let object = try JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? [String: Any]
        XCTAssertEqual(object?["cat"] as? String, "camera")
        XCTAssertEqual(object?["name"] as? String, "running")
        let fields = object?["fields"] as? [String: Any]
        XCTAssertEqual(fields?["width"] as? Int, 1080)
        XCTAssertEqual(fields?["ok"] as? Bool, true)
        XCTAssertNotNil(object?["ts"] as? String)
    }

    func testEventRedactsSecretLikeFields() throws {
        DebugTrace.event("agent", "sent", ["apiKey": "sk-super-secret", "Authorization": "Bearer xyz"])

        let content = try String(contentsOf: eventsFile, encoding: .utf8)
        XCTAssertFalse(content.contains("sk-super-secret"))
        XCTAssertFalse(content.contains("Bearer xyz"))
        XCTAssertTrue(content.contains("<redacted>"))
    }

    func testAnalysisSessionWritesArtifactsAndRedactsMeta() throws {
        let session = DebugTrace.startAnalysis()
        session.write(pageOCR: "Hello world\n\nSecond paragraph")
        session.write(image: Data([0xFF, 0xD8, 0xFF]))
        session.write(ocrDebug: ["lines": [["text": "Hello world", "breakBefore": false]]])
        session.write(analysisJSON: ["segments": [], "vocabulary": []])
        session.mergeMeta(["model": "test-model", "apiKey": "should-not-appear"])
        session.mergeMeta(["totalMs": 42])

        let entries = try FileManager.default.contentsOfDirectory(
            at: analysesDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(entries.count, 1)
        let folder = entries[0]

        let pageOCR = try String(contentsOf: folder.appendingPathComponent("page_ocr.txt"), encoding: .utf8)
        XCTAssertEqual(pageOCR, "Hello world\n\nSecond paragraph")

        let image = try Data(contentsOf: folder.appendingPathComponent("page.jpg"))
        XCTAssertEqual(image, Data([0xFF, 0xD8, 0xFF]))

        let meta = try JSONSerialization.jsonObject(
            with: Data(contentsOf: folder.appendingPathComponent("meta.json"))) as? [String: Any]
        XCTAssertEqual(meta?["model"] as? String, "test-model")
        XCTAssertEqual(meta?["totalMs"] as? Int, 42)
        XCTAssertEqual(meta?["apiKey"] as? String, "<redacted>")

        let ocrDebugContent = try String(
            contentsOf: folder.appendingPathComponent("ocr.json"), encoding: .utf8)
        XCTAssertFalse(ocrDebugContent.isEmpty)
    }

    func testAnalysisFoldersRotateToMostRecentThirty() throws {
        for _ in 0..<35 {
            let session = DebugTrace.startAnalysis()
            session.write(pageOCR: "marker")
        }
        let entries = try FileManager.default.contentsOfDirectory(
            at: analysesDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(entries.count, 30)
    }
}
