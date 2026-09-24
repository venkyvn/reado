import Foundation

enum ExampleStatus: Equatable {
    case verified
    case suspect
    case unverified
}

enum ExampleVerifier {
    static func status(term: String, example: String, segments: [AnalysisSegment]) -> ExampleStatus {
        let page = segments.map(\.sourceEn).joined(separator: " ")
        let exampleN = normalize(example)
        let pageN = normalize(page)
        let termN = normalize(term)
        let verified = !exampleN.isEmpty && pageN.contains(exampleN)
        let hasTerm = !termN.isEmpty && exampleN.contains(termN)
        if verified && hasTerm { return .verified }
        if verified { return .suspect }
        return .unverified
    }

    static func normalize(_ text: String) -> String {
        var value = text.precomposedStringWithCompatibilityMapping
        let quotes: [(String, String)] = [
            ("\u{2018}", "'"), ("\u{2019}", "'"),
            ("\u{201C}", "\""), ("\u{201D}", "\""),
        ]
        for (from, to) in quotes {
            value = value.replacingOccurrences(of: from, with: to)
        }
        value = value.replacingOccurrences(of: "\u{2013}", with: "-")
        value = value.replacingOccurrences(of: "\u{2014}", with: "-")
        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct AnalysisSegment: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var sourceEn: String
    var translationVi: String
}

struct AnalysisVocabulary: Codable, Equatable {
    var term: String
    var pos: String
    var ipa: String
    var meaningVi: String
    var cefr: String
    var example: String
}

struct AnalysisResult: Equatable {
    var segments: [AnalysisSegment]
    var vocabulary: [PickerItem]
    var summaryVi: String
}

protocol AnalysisClient: Sendable {
    func analyze(imageJPEG: Data, cefrLevels: [String]) async throws -> AnalysisResult
}

struct MockAnalysisClient: AnalysisClient {
    func analyze(imageJPEG: Data, cefrLevels: [String]) async throws -> AnalysisResult {
        try await Task.sleep(nanoseconds: 700_000_000)
        _ = imageJPEG
        let segments = MockPage.segments
        let vocab = MockPage.vocabulary.map { item -> PickerItem in
            let status = ExampleVerifier.status(term: item.term, example: item.example, segments: segments)
            let verified = status == .verified
            return PickerItem(
                id: IDs.uuid(),
                term: item.term,
                pos: item.pos,
                ipa: item.ipa,
                meaningVi: item.meaningVi,
                cefr: item.cefr,
                example: item.example,
                verified: verified,
                suspect: status == .suspect,
                selected: verified && cefrLevels.contains(item.cefr)
            )
        }
        return AnalysisResult(segments: segments, vocabulary: vocab, summaryVi: MockPage.summaryVi)
    }
}

enum MockPage {
    static let summaryVi =
        "Trang lập luận rằng thói quen hoạt động như lãi kép: kết quả hôm nay kém quan trọng hơn quỹ đạo. Những lựa chọn nhỏ lặp lại sẽ định hình vị trí của bạn sau nhiều năm."

    static let segments: [AnalysisSegment] = [
        .init(
            id: "s1",
            sourceEn: "Habits are the compound interest of self-improvement. The same way that money multiplies through compound interest, the effects of your habits multiply as you repeat them.",
            translationVi: "Thói quen là lãi kép của việc tự hoàn thiện. Cũng như tiền nhân lên nhờ lãi kép, hiệu quả của thói quen nhân lên khi bạn lặp lại chúng."
        ),
        .init(
            id: "s2",
            sourceEn: "It does not matter how successful or unsuccessful you are right now. What matters is whether your habits are putting you on the path toward success.",
            translationVi: "Bạn đang thành công hay thất bại lúc này không quan trọng. Điều quan trọng là thói quen đang đặt bạn trên đường tới thành công hay không."
        ),
        .init(
            id: "s3",
            sourceEn: "You should be far more concerned with your current trajectory than with your current results.",
            translationVi: "Bạn nên quan tâm quỹ đạo hiện tại nhiều hơn kết quả hiện tại."
        ),
        .init(
            id: "s4",
            sourceEn: "If you want to predict where you will end up in life, all you have to do is follow the curve of tiny gains or tiny losses, and see how your daily choices will compound ten or twenty years down the line.",
            translationVi: "Muốn đoán mình sẽ đi tới đâu, hãy nhìn đường cong của những lợi nhỏ hoặc mất mát nhỏ, rồi xem lựa chọn hằng ngày sẽ cộng dồn sau mười hay hai mươi năm."
        ),
    ]

    static let vocabulary: [AnalysisVocabulary] = [
        .init(term: "compound interest", pos: "noun", ipa: "/ˈkɒmpaʊnd ˈɪntrəst/", meaningVi: "lãi kép", cefr: "B2", example: "Habits are the compound interest of self-improvement."),
        .init(term: "multiply", pos: "verb", ipa: "/ˈmʌltɪplaɪ/", meaningVi: "nhân lên, tăng lên nhiều lần", cefr: "B1", example: "the effects of your habits multiply as you repeat them"),
        .init(term: "trajectory", pos: "noun", ipa: "/trəˈdʒektəri/", meaningVi: "quỹ đạo, hướng đi", cefr: "C1", example: "You should be far more concerned with your current trajectory than with your current results."),
        .init(term: "concerned with", pos: "adj", ipa: "/kənˈsɜːnd wɪð/", meaningVi: "quan tâm tới", cefr: "B2", example: "You should be far more concerned with your current trajectory"),
        .init(term: "tiny gains", pos: "noun", ipa: "/ˈtaɪni ɡeɪnz/", meaningVi: "lợi ích nhỏ", cefr: "B2", example: "follow the curve of tiny gains or tiny losses"),
        .init(term: "compound", pos: "verb", ipa: "/kəmˈpaʊnd/", meaningVi: "cộng dồn, tích lũy", cefr: "B2", example: "see how your daily choices will compound ten or twenty years down the line"),
        .init(term: "down the line", pos: "phrase", ipa: "/daʊn ðə laɪn/", meaningVi: "về sau, trong tương lai", cefr: "B2", example: "ten or twenty years down the line"),
        .init(term: "resilient", pos: "adj", ipa: "/rɪˈzɪliənt/", meaningVi: "kiên cường (AI bịa — không có trên trang)", cefr: "B2", example: "A resilient person bounces back quickly from failure."),
    ]
}
