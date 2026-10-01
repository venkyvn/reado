import Foundation
import XCTest
import ReadoKit

/// Fixtures + helper dùng chung cho các file `Analysis*Tests`/`ReadoProxyClientTests`/
/// `ReviewDraftBuilderTests` (refactor-r4 T3, tách khỏi `AnalysisTests.swift` cũ).
enum AnalysisFixtures {
    static func validResponseJSON() -> [String: Any] {
        [
            "segments": [
                [
                    "source_en": "The old lighthouse stood on the cliff, battered by winter storms.",
                    "translation_vi": "Ngọn hải đăng cũ đứng trên vách đá, bị bão mùa đông dày vò.",
                ]
            ],
            "vocabulary": [
                [
                    "term": "battered",
                    "pos": "adj",
                    "ipa": "/ˈbætərd/",
                    "meaning_vi": "dày vò",
                    "cefr": "B2",
                    "example": "The old lighthouse stood on the cliff, battered by winter storms.",
                ]
            ],
            "summary_vi": "Mô tả ngọn hải đăng cổ trên vách đá.",
        ]
    }

    static func jsonData(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }
}

/// `OpenAICompatClient`/`ReadoProxyClient` gọi `DebugTrace.event` — override thư
/// mục tạm (như `DebugTraceTests`) để không ghi vào `Documents/Diagnostics` thật.
class AnalysisNetworkTestCase: XCTestCase {
    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AnalysisTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        DebugTrace.documentsDirectoryOverride = tempRoot
    }

    override func tearDown() {
        DebugTrace.documentsDirectoryOverride = nil
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
        super.tearDown()
    }
}

struct FixedPageOCR: PageTextRecognizer {
    let text: String
    func recognize(imageData: Data) async throws -> String { text }
}

final class MemorySecrets: AgentSecretStore, @unchecked Sendable {
    private var keys: [String: String] = [:]

    func save(agentID: String, apiKey: String) throws {
        keys[agentID] = apiKey
    }

    func contains(agentID: String) -> Bool {
        keys[agentID]?.isEmpty == false
    }

    func delete(agentID: String) {
        keys.removeValue(forKey: agentID)
    }

    func key(agentID: String) -> String? {
        keys[agentID]
    }
}

// MARK: - URLProtocol stub (offline test wire)

/// URLSession với custom URLProtocol chuyển httpBody sang httpBodyStream
/// cho data task — đọc body phải đi qua stream (bẫy test đã gặp 2026-09-19).
func bodyData(of request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 4096
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        guard read > 0 else { break }
        data.append(buffer, count: read)
    }
    return data
}

final class RequestCapture: @unchecked Sendable {
    var request: URLRequest?
}

/// Đếm số lần handler được gọi — `StubURLProtocol.handler` chạy trên thread
/// loading của URLProtocol nên cần khoá, không bắt `var` thường trực tiếp.
final class AttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    @discardableResult
    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}

/// Gom `AnalysisProgress` phát ra qua `onProgress` — closure là `@Sendable`
/// nên không thể bắt biến `var` thường (test AnalysisTests §2.7 kế hoạch AI-Box).
final class ProgressCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [AnalysisProgress] = []

    func append(_ event: AnalysisProgress) {
        lock.lock()
        defer { lock.unlock() }
        events.append(event)
    }

    var all: [AnalysisProgress] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }
}

/// Một dòng SSE `data: {...}` cho `choices[0].delta` — escaping đúng qua
/// JSONSerialization thay vì nối chuỗi tay.
func sseLine(content: String? = nil, reasoning: String? = nil) throws -> String {
    var delta: [String: Any] = [:]
    if let content { delta["content"] = content }
    if let reasoning { delta["reasoning_content"] = reasoning }
    let object: [String: Any] = ["choices": [["delta": delta]]]
    let data = try JSONSerialization.data(withJSONObject: object)
    return "data: " + String(decoding: data, as: UTF8.self)
}

final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
