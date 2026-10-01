import Foundation

/// Một dòng từ vựng trong "từ điển" để dò khi đọc (FR-22) — đủ trường cho
/// popover: nghĩa, IPA, "đã gặp ở ‹collection›".
public struct EncounterLexiconEntry: Equatable, Sendable, Identifiable {
    public let vocabItemID: String
    public let term: String
    public let pos: String
    public let ipa: String?
    public let meaningVI: String
    public let collectionID: String
    public let collectionName: String

    public var id: String { vocabItemID }

    public init(
        vocabItemID: String,
        term: String,
        pos: String,
        ipa: String?,
        meaningVI: String,
        collectionID: String,
        collectionName: String
    ) {
        self.vocabItemID = vocabItemID
        self.term = term
        self.pos = pos
        self.ipa = ipa
        self.meaningVI = meaningVI
        self.collectionID = collectionID
        self.collectionName = collectionName
    }
}

/// Một chỗ trong văn bản trùng với từ/cụm đã có trong kho.
public struct EncounterMatch: Equatable, Sendable {
    /// Khoảng trong chuỗi gốc (để gạch chân) — từ chữ đầu đến chữ cuối của cụm.
    public let range: Range<String.Index>
    /// ≥ 1 dòng; một term nhiều dòng (nhiều nghĩa / nhiều collection) → đủ cả,
    /// theo thứ tự lexicon, để popover liệt kê hết.
    public let entries: [EncounterLexiconEntry]
    /// Số chữ của cụm (1 = từ đơn).
    public let tokenCount: Int
}

/// Dò từ đã có trong kho xuyên mọi collection trong một đoạn văn (FR-22).
/// Hàm thuần — không DB, không I/O.
///
/// Luật (reencounter-r1 HLD):
/// - Đơn vị là **chữ** (chuỗi chữ/số; `'` và `-` nối giữa hai chữ vẫn là một chữ:
///   `don't`, `well-known`). Khớp theo chữ nên có **biên từ** sẵn: `cat` không
///   khớp trong `category`.
/// - Không phân biệt hoa/thường; `'`/`’` và các dấu gạch nối Unicode coi như nhau.
/// - Hậu tố sở hữu `'s` tách khỏi chữ (`author's` → `author`) — đó là ranh giới,
///   không phải lemmatize.
/// - **Không lemmatize** (Q-06): `runs` không khớp `run`.
/// - Cụm nhiều chữ chỉ khớp khi các chữ liền nhau, chỉ cách bằng khoảng trắng —
///   dấu câu chen giữa (`well, known`) cắt cụm.
/// - Chồng nhau: **cụm dài thắng** (hoà thì cụm đứng trước); kết quả không chồng.
public struct EncounterMatcher: Sendable {
    private let index: [String: [EncounterLexiconEntry]]
    private let maxTokens: Int

    public init(lexicon: [EncounterLexiconEntry]) {
        var index: [String: [EncounterLexiconEntry]] = [:]
        var maxTokens = 0
        for entry in lexicon {
            let tokens = Self.tokens(in: entry.term)
            guard !tokens.isEmpty else { continue }
            let key = tokens.map(\.key).joined(separator: " ")
            index[key, default: []].append(entry)
            maxTokens = max(maxTokens, tokens.count)
        }
        self.index = index
        self.maxTokens = maxTokens
    }

    public var isEmpty: Bool { index.isEmpty }

    public func matches(in text: String) -> [EncounterMatch] {
        guard !index.isEmpty else { return [] }
        let tokens = Self.tokens(in: text)
        guard !tokens.isEmpty else { return [] }

        // Mọi ứng viên (vị trí đầu, số chữ, khoá) có trong lexicon.
        var candidates: [(start: Int, count: Int, key: String)] = []
        for start in tokens.indices {
            var key = tokens[start].key
            if index[key] != nil { candidates.append((start, 1, key)) }
            var count = 1
            while count < maxTokens, start + count < tokens.count,
                  Self.isWhitespaceOnly(
                      text,
                      from: tokens[start + count - 1].range.upperBound,
                      to: tokens[start + count].range.lowerBound)
            {
                key += " " + tokens[start + count].key
                count += 1
                if index[key] != nil { candidates.append((start, count, key)) }
            }
        }

        // Dài thắng; hoà thì đứng trước. Bỏ ứng viên chạm chữ đã bị lấy.
        let ordered = candidates.sorted {
            $0.count != $1.count ? $0.count > $1.count : $0.start < $1.start
        }
        var taken = [Bool](repeating: false, count: tokens.count)
        var accepted: [(start: Int, count: Int, key: String)] = []
        for candidate in ordered {
            let span = candidate.start..<(candidate.start + candidate.count)
            if span.contains(where: { taken[$0] }) { continue }
            for position in span { taken[position] = true }
            accepted.append(candidate)
        }
        accepted.sort { $0.start < $1.start }

        return accepted.map { candidate in
            let first = tokens[candidate.start]
            let last = tokens[candidate.start + candidate.count - 1]
            return EncounterMatch(
                range: first.range.lowerBound..<last.range.upperBound,
                entries: index[candidate.key] ?? [],
                tokenCount: candidate.count)
        }
    }

    /// Id của mọi vocab có từ/cụm xuất hiện trong `texts` (mỗi id một lần, theo thứ
    /// tự gặp đầu tiên). Một term nhiều dòng → cả các dòng. Dùng khi lưu trang để
    /// ghi `seen` (FR-22).
    public func vocabItemIDs(in texts: [String]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for text in texts {
            for match in matches(in: text) {
                for entry in match.entries where seen.insert(entry.vocabItemID).inserted {
                    ordered.append(entry.vocabItemID)
                }
            }
        }
        return ordered
    }

    // MARK: — Tokenizer

    struct Token: Equatable {
        let key: String
        let range: Range<String.Index>
    }

    static func tokens(in text: String) -> [Token] {
        var result: [Token] = []
        var index = text.startIndex
        while index < text.endIndex {
            guard isWordCharacter(text[index]) else {
                index = text.index(after: index)
                continue
            }
            let start = index
            var end = index
            var cursor = index
            var resume: String.Index?   // sau hậu tố `'s` (bỏ hẳn, không thành chữ riêng)
            scan: while cursor < text.endIndex {
                let character = text[cursor]
                if isWordCharacter(character) {
                    cursor = text.index(after: cursor)
                    end = cursor
                } else if isJoiner(character),
                          let next = text.index(cursor, offsetBy: 1, limitedBy: text.endIndex),
                          next < text.endIndex,
                          isWordCharacter(text[next])
                {
                    if isApostrophe(character), isPossessiveSuffix(text, apostrophe: cursor) {
                        resume = text.index(cursor, offsetBy: 2)
                        break scan
                    }
                    cursor = next
                } else {
                    break scan
                }
            }
            result.append(Token(key: normalizedKey(String(text[start..<end])), range: start..<end))
            index = resume ?? end
        }
        return result
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber
    }

    private static func isApostrophe(_ character: Character) -> Bool {
        character == "'" || character == "\u{2019}"
    }

    private static func isJoiner(_ character: Character) -> Bool {
        isApostrophe(character) || character == "-" || character == "\u{2010}" || character == "\u{2011}"
    }

    /// `'s` / `’s` rồi hết chữ (cuối chuỗi hoặc ký tự không phải chữ).
    private static func isPossessiveSuffix(_ text: String, apostrophe: String.Index) -> Bool {
        let sIndex = text.index(after: apostrophe)
        guard sIndex < text.endIndex, text[sIndex] == "s" || text[sIndex] == "S" else {
            return false
        }
        let after = text.index(after: sIndex)
        return after == text.endIndex || !isWordCharacter(text[after])
    }

    private static func normalizedKey(_ raw: String) -> String {
        var key = raw.lowercased()
        key = key.replacingOccurrences(of: "\u{2019}", with: "'")
        key = key.replacingOccurrences(of: "\u{2010}", with: "-")
        key = key.replacingOccurrences(of: "\u{2011}", with: "-")
        return key
    }

    private static func isWhitespaceOnly(
        _ text: String, from: String.Index, to: String.Index
    ) -> Bool {
        text[from..<to].allSatisfy { $0.isWhitespace }
    }
}
