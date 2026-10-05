import Foundation
import ImageIO
import ReadoKit
import XCTest

#if canImport(FoundationModels)
import FoundationModels
#endif

/// apple-ai-r1 T1 — SPIKE đo Apple Intelligence trên OCR thật (diagnostics, không commit dữ
/// liệu). Mặc định SKIP; chạy theo lệnh trong `docs/plans/apple-ai-r1.md` T1:
/// ```
/// TEST_RUNNER_READO_AI_SPIKE=1 \
/// TEST_RUNNER_READO_AI_SPIKE_DIR="$PWD/.tmp/diagnostics" \
/// TEST_RUNNER_READO_AI_SPIKE_OUT="$PWD/.tmp/ai-spike" \
/// TEST_RUNNER_READO_AI_SPIKE_LIMIT=5 \
/// scripts/test.sh test -only-testing:ReadoTests/AppleIntelligenceSpikeTests
/// ```
/// ĐẶT TRONG `ReadoTests` (app target trên Simulator), KHÔNG phải `ReadoKitTests` (lane `kit`,
/// macOS, SwiftPM CLI xctest): thử chạy trong `kit` trước (2026-10-05) ra lỗi IPC
/// "Operation not permitted" / `ModelManagerError 1046` ngay khi mở `LanguageModelSession` —
/// xctest bundle trần chạy qua `xcodebuild test -destination platform=macOS` không phải một
/// app đã ký/sandbox đúng cách nên Model Manager từ chối. `Reado.app` (ReadoTests chạy lồng
/// trong app đó trên Simulator) có chữ ký + sandbox như app thật, đúng môi trường agent sẽ
/// chạy thật. Không phải test hồi quy — không assert chất lượng, chỉ ghi `report.md` để fen
/// đọc và chốt (a) model cho agent, (b) sửa OCR text hay ảnh, (c) guided hay
/// String+permissive, (d) Apple có đủ tốt làm agent mặc định. KHÔNG dùng lại prototype ở đây
/// cho T3+ — T3 viết lại sạch.
final class AppleIntelligenceSpikeTests: XCTestCase {
    func testSpike() async throws {
        let env = ProcessInfo.processInfo.environment
        guard env["READO_AI_SPIKE"] == "1" else {
            throw XCTSkip("spike: đặt READO_AI_SPIKE=1 (xem docs/plans/apple-ai-r1.md T1)")
        }
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else {
            throw XCTSkip("cần iOS 26+ cho FoundationModels")
        }
        try await AppleIntelligenceSpike.run(env: env)
        #else
        throw XCTSkip("SDK không có FoundationModels framework")
        #endif
    }
}

#if canImport(FoundationModels)

// MARK: - Spike runner

@available(iOS 26.0, *)
enum AppleIntelligenceSpike {
    static func run(env: [String: String]) async throws {
        guard let dir = env["READO_AI_SPIKE_DIR"] else {
            throw XCTSkip("thiếu READO_AI_SPIKE_DIR")
        }
        guard let outDir = env["READO_AI_SPIKE_OUT"] else {
            throw XCTSkip("thiếu READO_AI_SPIKE_OUT")
        }
        let limit = Int(env["READO_AI_SPIKE_LIMIT"] ?? "5") ?? 5
        let pages = try loadPages(dir: dir, limit: limit)
        guard !pages.isEmpty else {
            throw XCTSkip("không thấy trang nào trong \(dir) (cần page_ocr.txt)")
        }
        // Mặc định TẮT: gọi PCC (construct/access `PrivateCloudComputeLanguageModel`) khi app
        // chưa có entitlement `com.apple.developer.private-cloud-compute` ném `fatalError`
        // KHÔNG bắt được (crash cả xctest, không phải throw) — xác nhận thật trên máy này
        // 2026-10-05. Chỉ bật khi fen đã thêm capability PCC trong Xcode (nhờ fen làm, không
        // phải việc sửa được qua CLI/pbxproj).
        let includePCC = env["READO_AI_SPIKE_PCC"] == "1"

        let outURL = URL(fileURLWithPath: outDir)
        var report = Report()
        report.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        report.environment = await measureEnvironment(includePCC: includePCC)
        report.pages = pages
        try report.write(to: outURL) // ghi sớm — fatalError sau đó (nếu có) vẫn còn bản này

        for page in pages {
            report.ocrFix.append(contentsOf: await measureOCRFix(page))
            report.oneShot.append(contentsOf: await measureOneShot(page, includePCC: includePCC))
            try report.write(to: outURL) // ghi lại sau MỖI trang — sống sót qua crash cứng
        }

        let onDeviceOneShots = report.oneShot.filter { $0.variant.hasPrefix("onDevice") }
        let overflowed = onDeviceOneShots.filter { $0.isContextOverflow }
        if !onDeviceOneShots.isEmpty, overflowed.count * 2 >= onDeviceOneShots.count {
            report.chunkedTriggered = true
            for page in pages {
                report.chunked.append(await measureChunked(page))
                try report.write(to: outURL)
            }
        }

        try report.write(to: outURL)
    }

    // MARK: Page loading

    struct Page {
        let id: String
        let ocr: String
        let imageURL: URL?
        let groundTruth: String?
        let byokAnalysis: [String: Any]?
        let cefr: String
    }

    static func loadPages(dir: String, limit: Int) throws -> [Page] {
        let fm = FileManager.default
        let root = URL(fileURLWithPath: dir)
        guard let runs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        var candidates: [(hasGroundTruth: Bool, page: Page)] = []
        var seenIDs: Set<String> = []
        for run in runs {
            let analysesDir = run.appendingPathComponent("analyses")
            guard let ids = try? fm.contentsOfDirectory(at: analysesDir, includingPropertiesForKeys: nil) else {
                continue
            }
            for idDir in ids {
                let id = idDir.lastPathComponent
                guard !seenIDs.contains(id) else { continue }
                let ocrFile = idDir.appendingPathComponent("page_ocr.txt")
                guard let ocr = try? String(contentsOf: ocrFile, encoding: .utf8),
                      !ocr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                seenIDs.insert(id)
                let gtFile = idDir.appendingPathComponent("groundtruth.txt")
                let groundTruth = try? String(contentsOf: gtFile, encoding: .utf8)
                let imageFile = idDir.appendingPathComponent("page.jpg")
                let imageURL = fm.fileExists(atPath: imageFile.path) ? imageFile : nil
                let analysisFile = idDir.appendingPathComponent("analysis.json")
                var byokAnalysis: [String: Any]?
                if let data = try? Data(contentsOf: analysisFile) {
                    byokAnalysis = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                }
                let metaFile = idDir.appendingPathComponent("meta.json")
                var cefr = "B2"
                if let data = try? Data(contentsOf: metaFile),
                   let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let metaCefr = meta["cefr"] as? String
                {
                    cefr = metaCefr
                }
                let page = Page(
                    id: id, ocr: ocr, imageURL: imageURL,
                    groundTruth: groundTruth, byokAnalysis: byokAnalysis, cefr: cefr)
                candidates.append((groundTruth != nil, page))
            }
        }
        candidates.sort { lhs, rhs in
            if lhs.hasGroundTruth != rhs.hasGroundTruth { return lhs.hasGroundTruth }
            return false
        }
        return Array(candidates.prefix(limit).map(\.page))
    }

    // MARK: §1 Môi trường

    struct EnvRow: Sendable {
        let property: String
        let onDevice: String
        let pcc: String
    }

    static func measureEnvironment(includePCC: Bool) async -> [EnvRow] {
        var rows: [EnvRow] = []
        let model = SystemLanguageModel.default

        func availabilityText(_ availability: SystemLanguageModel.Availability) -> String {
            switch availability {
            case .available: return "available"
            case .unavailable(let reason): return "unavailable(\(String(describing: reason)))"
            @unknown default: return "unavailable(unknown)"
            }
        }

        rows.append(EnvRow(property: "availability", onDevice: availabilityText(model.availability), pcc: "—"))
        rows.append(EnvRow(property: "contextSize", onDevice: String(model.contextSize), pcc: "—"))
        rows.append(EnvRow(
            property: "supportsLocale(vi_VN)",
            onDevice: String(model.supportsLocale(Locale(identifier: "vi_VN"))), pcc: "—"))
        rows.append(EnvRow(
            property: "supportsLocale(en_US)",
            onDevice: String(model.supportsLocale(Locale(identifier: "en_US"))), pcc: "—"))

        if #available(iOS 26.4, *) {
            if let tokens = try? await model.tokenCount(for: "Hello world") {
                rows.append(EnvRow(property: "tokenCount(\"Hello world\")", onDevice: String(tokens), pcc: "—"))
            }
        }

        if #available(iOS 27.0, *) {
            rows.append(EnvRow(property: "variant.displayName", onDevice: model.variant.displayName, pcc: "—"))
            rows.append(EnvRow(
                property: "capabilities.vision",
                onDevice: String(model.capabilities.contains(.vision)), pcc: "—"))
            rows.append(EnvRow(
                property: "capabilities.reasoning",
                onDevice: String(model.capabilities.contains(.reasoning)), pcc: "—"))
        }

        guard includePCC else {
            return rows
        }
        if #available(iOS 27.0, *) {
            let pcc = PrivateCloudComputeLanguageModel()
            func pccAvailabilityText(_ availability: PrivateCloudComputeLanguageModel.Availability) -> String {
                switch availability {
                case .available: return "available"
                case .unavailable(let reason): return "unavailable(\(String(describing: reason)))"
                @unknown default: return "unavailable(unknown)"
                }
            }
            rows.append(EnvRow(property: "availability", onDevice: "—", pcc: pccAvailabilityText(pcc.availability)))
            if let pccContextSize = try? await pcc.contextSize {
                rows.append(EnvRow(property: "contextSize", onDevice: "—", pcc: String(pccContextSize)))
            }
            if let supportsVI = try? await pcc.supportsLocale(Locale(identifier: "vi_VN")) {
                rows.append(EnvRow(property: "supportsLocale(vi_VN)", onDevice: "—", pcc: String(supportsVI)))
            }
            let quota = pcc.quotaUsage
            rows.append(EnvRow(
                property: "quotaUsage",
                onDevice: "—",
                pcc: "status=\(String(describing: quota.status)) limitReached=\(quota.isLimitReached)"))
        }

        return rows
    }

    // MARK: §2 Sửa OCR

    @Generable(description: "OCR misreads found in an English book page")
    struct OCRFixList {
        @Guide(description: "Each misread. Empty array if the text has no OCR errors.", .maximumCount(30))
        var fixes: [OCRFixItem]
    }

    @Generable
    struct OCRFixItem {
        @Guide(description: "The misread word or 2-3 word span, copied EXACTLY from the text")
        var wrong: String
        @Guide(description: "What the printed book most likely says")
        var right: String
    }

    private static let ocrFixInstructions = """
    You fix OCR recognition errors in text scanned from a printed English book.
    Report ONLY character-level misreads made by the OCR engine:
    - confused letters or digits (rn/m, cl/d, li/h, l/I/1, 0/O, 5/S, vv/w)
    - a word wrongly split or merged by the OCR ("some thing" -> "something")
    - stray symbols inside a word
    NEVER change word choice, grammar, tense, style, spelling variants (British/American),
    punctuation style, capitalisation of correct words, or names you are not sure about.
    If a word is a valid English word in its context, leave it.
    If you are unsure, leave it. Most pages need 0 to 5 fixes; many need none.
    "wrong" must be copied exactly from the text, character for character.
    """

    struct OCRFixRow: Sendable {
        let pageID: String
        let mode: String
        let proposed: Int
        let applied: Int
        let rejected: [(wrong: String, right: String, reason: String)]
        let ms: Int
        let werBefore: Double?
        let werAfter: Double?
        let error: String?
    }

    static func measureOCRFix(_ page: Page) async -> [OCRFixRow] {
        var rows: [OCRFixRow] = []
        rows.append(await runOCRFix(page, mode: "text"))

        var visionAvailable = false
        if #available(iOS 27.0, *) {
            visionAvailable = SystemLanguageModel.default.capabilities.contains(.vision)
        }
        if visionAvailable, let imageURL = page.imageURL {
            rows.append(await runOCRFix(page, mode: "image+text", imageURL: imageURL))
        }
        return rows
    }

    private static func runOCRFix(_ page: Page, mode: String, imageURL: URL? = nil) async -> OCRFixRow {
        let clock = ContinuousClock()
        let start = clock.now
        do {
            let session = LanguageModelSession(instructions: ocrFixInstructions)
            let options = GenerationOptions(samplingMode: .greedy, maximumResponseTokens: 600)
            let response: LanguageModelSession.Response<OCRFixList>
            if let imageURL, #available(iOS 27.0, *),
               let cgImage = loadCGImage(imageURL)
            {
                response = try await session.respond(
                    generating: OCRFixList.self, options: options
                ) {
                    "OCR text:\n\(page.ocr)"
                    Attachment(cgImage)
                }
            } else {
                response = try await session.respond(
                    to: page.ocr, generating: OCRFixList.self, options: options)
            }
            let ms = millisecondsSince(start, clock: clock)
            let fixes = response.content.fixes.map { (wrong: $0.wrong, right: $0.right) }
            let outcome = draftApplyFixes(fixes, to: page.ocr)
            var werBefore: Double?
            var werAfter: Double?
            if let gt = page.groundTruth {
                werBefore = wordErrorRate(hypothesis: page.ocr, reference: gt)
                werAfter = wordErrorRate(hypothesis: outcome.text, reference: gt)
            }
            return OCRFixRow(
                pageID: page.id, mode: mode, proposed: fixes.count, applied: outcome.applied.count,
                rejected: outcome.rejected, ms: ms, werBefore: werBefore, werAfter: werAfter, error: nil)
        } catch {
            let ms = millisecondsSince(start, clock: clock)
            return OCRFixRow(
                pageID: page.id, mode: mode, proposed: 0, applied: 0, rejected: [],
                ms: ms, werBefore: nil, werAfter: nil, error: String(describing: error))
        }
    }

    /// Prototype luật T3 `OCRFixApplier` — chỉ dùng trong spike, T3 viết bản thật riêng.
    private static func draftApplyFixes(
        _ fixes: [(wrong: String, right: String)], to text: String
    ) -> (text: String, applied: [(wrong: String, right: String)], rejected: [(wrong: String, right: String, reason: String)]) {
        let maxFixes = 30
        let maxTouchedWordRatio = 0.15
        guard fixes.count <= maxFixes else {
            return (text, [], fixes.map { ($0.wrong, $0.right, "tooMany") })
        }

        var applied: [(wrong: String, right: String)] = []
        var rejected: [(wrong: String, right: String, reason: String)] = []
        var totalTouchedWords = 0
        let totalWords = max(1, text.split(whereSeparator: \.isWhitespace).count)

        func wordCount(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }

        for fix in fixes {
            let wrong = fix.wrong.trimmingCharacters(in: .whitespacesAndNewlines)
            let right = fix.right.trimmingCharacters(in: .whitespacesAndNewlines)
            if wrong.isEmpty || right.isEmpty { rejected.append((wrong, right, "empty")); continue }
            if wrong == right { rejected.append((wrong, right, "identical")); continue }
            if wrong.contains("\n") || right.contains("\n") {
                rejected.append((wrong, right, "containsNewline")); continue
            }
            if wordCount(wrong) > 3 { rejected.append((wrong, right, "tooManyWords")); continue }
            if abs(wordCount(right) - wordCount(wrong)) > 1 {
                rejected.append((wrong, right, "wordCountChanged")); continue
            }
            let distance = levenshtein(Array(wrong), Array(right))
            let threshold = max(1, min(3, wrong.count / 3))
            if distance > threshold { rejected.append((wrong, right, "editTooLarge")); continue }
            guard text.range(of: wrong) != nil else {
                rejected.append((wrong, right, "notFound")); continue
            }
            applied.append((wrong, right))
            totalTouchedWords += wordCount(wrong)
        }

        if Double(totalTouchedWords) > maxTouchedWordRatio * Double(totalWords) {
            return (text, [], (applied.map { ($0.wrong, $0.right, "tooMany") }) + rejected)
        }

        var result = text
        for fix in applied.reversed() {
            if let range = result.range(of: fix.wrong) {
                result.replaceSubrange(range, with: fix.right)
            }
        }
        return (result, applied, rejected)
    }

    // MARK: §3 FR-02 một lượt

    @Generable
    struct SpikeWire {
        var segments: [SpikeSegment]
        @Guide(description: "Từ vựng đáng học, xếp theo giá trị học giảm dần", .maximumCount(20))
        var vocabulary: [SpikeVocab]
        var summary_vi: String
    }

    @Generable
    struct SpikeSegment {
        var source_en: String
        var translation_vi: String
        @Guide(.maximumCount(6)) var phrases: [SpikePhrase]
    }

    @Generable
    struct SpikePhrase { var en: String; var vi: String }

    @Generable
    struct SpikeVocab {
        var term: String
        @Guide(.anyOf(["noun", "verb", "adj", "adv", "phrase", "other"])) var pos: String
        var ipa: String
        var meaning_vi: String
        @Guide(.anyOf(["A2", "B1", "B2", "C1"])) var cefr: String
        var example: String
    }

    struct OneShotRow: Sendable {
        let pageID: String
        let variant: String
        let ok: Bool
        let errorKind: String?
        let ms: Int
        let tokens: Int?
        let segments: Int
        let vocabCount: Int
        let verifiedPct: Double?
        let ipaPct: Double?
        let phrases: Int
        let rawJSON: String?

        var isContextOverflow: Bool {
            guard let kind = errorKind else { return false }
            return kind.localizedCaseInsensitiveContains("context")
        }
    }

    static func measureOneShot(_ page: Page, includePCC: Bool) async -> [OneShotRow] {
        let prompt = Prompt.text(cefrLevel: page.cefr, pageOCR: page.ocr)
        var rows: [OneShotRow] = []
        rows.append(await runOneShotGuided(page: page, prompt: prompt, variant: "onDevice-G") {
            LanguageModelSession(model: SystemLanguageModel.default)
        })
        rows.append(await runOneShotString(page: page, prompt: prompt, variant: "onDevice-S") {
            LanguageModelSession(model: SystemLanguageModel(
                useCase: .general, guardrails: .permissiveContentTransformations))
        })

        guard includePCC else { return rows }
        if #available(iOS 27.0, *) {
            let pcc = PrivateCloudComputeLanguageModel()
            if case .available = pcc.availability {
                rows.append(await runOneShotGuided(page: page, prompt: prompt, variant: "PCC-G") {
                    LanguageModelSession(model: pcc)
                })
                rows.append(await runOneShotString(page: page, prompt: prompt, variant: "PCC-S") {
                    LanguageModelSession(model: pcc)
                })
            }
        }
        return rows
    }

    private static func runOneShotGuided(
        page: Page, prompt: String, variant: String, makeSession: @Sendable () -> LanguageModelSession
    ) async -> OneShotRow {
        let clock = ContinuousClock()
        let start = clock.now
        var tokens: Int?
        if #available(iOS 26.4, *) {
            tokens = try? await SystemLanguageModel.default.tokenCount(for: prompt)
        }
        do {
            let session = makeSession()
            let options = GenerationOptions(samplingMode: .greedy)
            let response = try await session.respond(to: prompt, generating: SpikeWire.self, options: options)
            let json = response.rawContent.jsonString
            let ms = millisecondsSince(start, clock: clock)
            return decodeOneShot(pageID: page.id, variant: variant, json: json, ms: ms, tokens: tokens)
        } catch {
            let ms = millisecondsSince(start, clock: clock)
            return OneShotRow(
                pageID: page.id, variant: variant, ok: false, errorKind: String(describing: error),
                ms: ms, tokens: tokens, segments: 0, vocabCount: 0, verifiedPct: nil, ipaPct: nil,
                phrases: 0, rawJSON: nil)
        }
    }

    private static func runOneShotString(
        page: Page, prompt: String, variant: String, makeSession: @Sendable () -> LanguageModelSession
    ) async -> OneShotRow {
        let clock = ContinuousClock()
        let start = clock.now
        var tokens: Int?
        if #available(iOS 26.4, *) {
            tokens = try? await SystemLanguageModel.default.tokenCount(for: prompt)
        }
        do {
            let session = makeSession()
            let response = try await session.respond(to: prompt)
            let raw = response.content
            guard let start1 = raw.firstIndex(of: "{"), let end1 = raw.lastIndex(of: "}") else {
                let ms = millisecondsSince(start, clock: clock)
                return OneShotRow(
                    pageID: page.id, variant: variant, ok: false, errorKind: "noJSONFound",
                    ms: ms, tokens: tokens, segments: 0, vocabCount: 0, verifiedPct: nil, ipaPct: nil,
                    phrases: 0, rawJSON: raw)
            }
            let json = String(raw[start1...end1])
            let ms = millisecondsSince(start, clock: clock)
            return decodeOneShot(pageID: page.id, variant: variant, json: json, ms: ms, tokens: tokens)
        } catch {
            let ms = millisecondsSince(start, clock: clock)
            return OneShotRow(
                pageID: page.id, variant: variant, ok: false, errorKind: String(describing: error),
                ms: ms, tokens: tokens, segments: 0, vocabCount: 0, verifiedPct: nil, ipaPct: nil,
                phrases: 0, rawJSON: nil)
        }
    }

    private static func decodeOneShot(pageID: String, variant: String, json: String, ms: Int, tokens: Int?) -> OneShotRow {
        do {
            let normalized = try AnalysisResponseNormalizer.normalize(Data(json.utf8))
            let analysis = try AnalysisResponseDecoder.decode(normalized)
            let verifiedCount = analysis.vocabulary.filter { $0.verification == .verified }.count
            let ipaCount = analysis.vocabulary.filter { ($0.ipa?.isEmpty == false) }.count
            let phraseCount = analysis.segments.reduce(0) { $0 + $1.phrases.count }
            let vocabCount = analysis.vocabulary.count
            return OneShotRow(
                pageID: pageID, variant: variant, ok: true, errorKind: nil, ms: ms, tokens: tokens,
                segments: analysis.segments.count, vocabCount: vocabCount,
                verifiedPct: vocabCount > 0 ? Double(verifiedCount) / Double(vocabCount) * 100 : nil,
                ipaPct: vocabCount > 0 ? Double(ipaCount) / Double(vocabCount) * 100 : nil,
                phrases: phraseCount, rawJSON: json)
        } catch {
            return OneShotRow(
                pageID: pageID, variant: variant, ok: false, errorKind: String(describing: error),
                ms: ms, tokens: tokens, segments: 0, vocabCount: 0, verifiedPct: nil, ipaPct: nil,
                phrases: 0, rawJSON: json)
        }
    }

    // MARK: §4 Chia nhỏ

    struct ChunkedRow: Sendable {
        let pageID: String
        let approach: String
        let totalMs: Int
        let error: String?
    }

    static func measureChunked(_ page: Page) async -> ChunkedRow {
        let clock = ContinuousClock()
        let start = clock.now
        let paragraphs = page.ocr.components(separatedBy: "\n\n")
            .map { $0.components(separatedBy: "\n").joined(separator: " ") }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        do {
            let session = LanguageModelSession(model: SystemLanguageModel(
                useCase: .general, guardrails: .permissiveContentTransformations))
            for paragraph in paragraphs {
                let prompt = """
                Dịch đoạn sau sang tiếng Việt tự nhiên theo cụm và nhịp câu, không word-by-word. \
                Chỉ trả bản dịch.

                \(paragraph)
                """
                _ = try await session.respond(to: prompt)
            }
            let ms = millisecondsSince(start, clock: clock)
            return ChunkedRow(pageID: page.id, approach: "onDevice-S paragraph-by-paragraph", totalMs: ms, error: nil)
        } catch {
            let ms = millisecondsSince(start, clock: clock)
            return ChunkedRow(pageID: page.id, approach: "onDevice-S paragraph-by-paragraph", totalMs: ms, error: String(describing: error))
        }
    }

    // MARK: - Helpers

    static func millisecondsSince(_ start: ContinuousClock.Instant, clock: ContinuousClock) -> Int {
        let duration = clock.now - start
        let components = duration.components
        return Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }

    private static func loadCGImage(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    static func levenshtein<T: Equatable>(_ a: [T], _ b: [T]) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                if a[i - 1] == b[j - 1] {
                    current[j] = previous[j - 1]
                } else {
                    current[j] = min(previous[j - 1] + 1, previous[j] + 1, current[j - 1] + 1)
                }
            }
            previous = current
        }
        return previous[b.count]
    }

    static func normalizedWords(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map { word -> String in
            word.lowercased().trimmingCharacters(in: .punctuationCharacters)
        }.filter { !$0.isEmpty }
    }

    static func wordErrorRate(hypothesis: String, reference: String) -> Double {
        let refWords = normalizedWords(reference)
        guard !refWords.isEmpty else { return 0 }
        let hypWords = normalizedWords(hypothesis)
        let distance = levenshtein(hypWords, refWords)
        return Double(distance) / Double(refWords.count)
    }
}

// MARK: - Report

@available(iOS 26.0, *)
struct Report {
    var osVersion = ""
    var environment: [AppleIntelligenceSpike.EnvRow] = []
    var ocrFix: [AppleIntelligenceSpike.OCRFixRow] = []
    var oneShot: [AppleIntelligenceSpike.OneShotRow] = []
    var chunkedTriggered = false
    var chunked: [AppleIntelligenceSpike.ChunkedRow] = []
    var pages: [AppleIntelligenceSpike.Page] = []

    func write(to outDir: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: outDir, withIntermediateDirectories: true)

        var md = "# Apple Intelligence spike — \(ISO8601DateFormatter().string(from: Date())) — \(osVersion)\n\n"

        md += "## 1. Môi trường\n\n| thuộc tính | on-device | PCC |\n|---|---|---|\n"
        for row in environment {
            md += "| \(row.property) | \(row.onDevice) | \(row.pcc) |\n"
        }

        md += "\n## 2. Sửa OCR\n\n| trang | mode | đề xuất | áp | loại | ms | WER gốc | WER sau |\n|---|---|---|---|---|---|---|---|\n"
        for row in ocrFix {
            let werBefore = row.werBefore.map { String(format: "%.3f", $0) } ?? "—"
            let werAfter = row.werAfter.map { String(format: "%.3f", $0) } ?? "—"
            let note = row.error.map { " (lỗi: \($0))" } ?? ""
            md += "| \(row.pageID) | \(row.mode)\(note) | \(row.proposed) | \(row.applied) | \(row.rejected.count) | \(row.ms) | \(werBefore) | \(werAfter) |\n"
        }

        md += "\n## 3. FR-02 một lượt\n\n| trang | biến thể | kết quả | ms | tokens | seg | vocab | verified% | IPA% | phrases |\n|---|---|---|---|---|---|---|---|---|---|\n"
        for row in oneShot {
            let result = row.ok ? "ok" : "lỗi: \(row.errorKind ?? "?")"
            let tokens = row.tokens.map(String.init) ?? "—"
            let verified = row.verifiedPct.map { String(format: "%.0f", $0) } ?? "—"
            let ipa = row.ipaPct.map { String(format: "%.0f", $0) } ?? "—"
            md += "| \(row.pageID) | \(row.variant) | \(result) | \(row.ms) | \(tokens) | \(row.segments) | \(row.vocabCount) | \(verified) | \(ipa) | \(row.phrases) |\n"
        }

        if chunkedTriggered {
            md += "\n## 4. Chia nhỏ (đã kích hoạt — ≥1/2 onDevice một lượt bị context overflow)\n\n| trang | cách dịch | tổng ms | lỗi |\n|---|---|---|---|\n"
            for row in chunked {
                md += "| \(row.pageID) | \(row.approach) | \(row.totalMs) | \(row.error ?? "—") |\n"
            }
        } else {
            md += "\n## 4. Chia nhỏ\n\nKhông kích hoạt (dưới 1/2 số trang onDevice một lượt bị context overflow).\n"
        }

        md += "\n## 5. Chi tiết từng trang (KHÔNG commit — bản quyền sách)\n\n"
        for page in pages {
            md += "### \(page.id)\n\n"
            md += "- OCR gốc (500 ký tự đầu): \(String(page.ocr.prefix(500)).replacingOccurrences(of: "\n", with: "⏎"))\n"
            let fixesForPage = ocrFix.filter { $0.pageID == page.id }
            for fix in fixesForPage {
                md += "- Sửa OCR (\(fix.mode)): \(fix.applied) áp / \(fix.rejected.count) loại\n"
                for rejected in fix.rejected {
                    md += "  - ✗ `\(rejected.wrong)` → `\(rejected.right)` (\(rejected.reason))\n"
                }
            }
            if let byok = page.byokAnalysis, let segments = byok["segments"] as? [[String: Any]] {
                md += "- BYOK (analysis.json) — 3 segment đầu:\n"
                for seg in segments.prefix(3) {
                    let en = seg["source_en"] as? String ?? ""
                    let vi = seg["translation_vi"] as? String ?? ""
                    md += "  - EN: \(en)\n  - VI: \(vi)\n"
                }
            }
            for row in oneShot.filter({ $0.pageID == page.id && $0.ok }) {
                md += "- \(row.variant): \(row.segments) segment, \(row.vocabCount) vocab, \(row.phrases) phrases\n"
            }
            md += "\n"
        }

        try md.write(to: outDir.appendingPathComponent("report.md"), atomically: true, encoding: .utf8)

        let rawDir = outDir.appendingPathComponent("raw")
        for row in oneShot {
            guard let json = row.rawJSON else { continue }
            let pageDir = rawDir.appendingPathComponent(row.pageID)
            try fm.createDirectory(at: pageDir, withIntermediateDirectories: true)
            try json.write(to: pageDir.appendingPathComponent("\(row.variant).json"), atomically: true, encoding: .utf8)
        }
    }
}

#endif
