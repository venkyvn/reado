import Foundation

/// FR-20 — nhập CSV gộp (scope v2, không JSON). Chiều ngược của FR-16: nhận file
/// cùng 7 cột (`term, pos, ipa, meaning_vi, cefr, example, collection`), preview rồi
/// GỘP vào kho — không thay toàn bộ, không khôi phục FSRS/review log (card sinh mới
/// `state = 'new'`, `due_at` hôm nay). `term` trùng → cảnh báo, user tự bỏ chọn
/// (không `unique` trên vocab_items — chống trùng là việc FR-10). File hỏng → lỗi,
/// không merge một phần.
public enum CSVImport {

    /// Một dòng nhập (đã parse). `lineNumber` đếm từ 1 (header) — dòng dữ liệu từ 2.
    public struct CSVRow: Equatable, Identifiable, Sendable {
        public let lineNumber: Int
        public var term: String
        public var pos: String
        public var ipa: String
        public var meaningVI: String
        public var cefr: String
        public var example: String
        public var collection: String
        public var isSelected: Bool
        public var duplicateTerm: Bool

        public var id: Int { lineNumber }

        public init(
            lineNumber: Int,
            term: String,
            pos: String,
            ipa: String,
            meaningVI: String,
            cefr: String,
            example: String,
            collection: String,
            isSelected: Bool = true,
            duplicateTerm: Bool = false
        ) {
            self.lineNumber = lineNumber
            self.term = term
            self.pos = pos
            self.ipa = ipa
            self.meaningVI = meaningVI
            self.cefr = cefr
            self.example = example
            self.collection = collection
            self.isSelected = isSelected
            self.duplicateTerm = duplicateTerm
        }
    }

    /// Kết quả gộp (atomic — hoặc ghi trọn, hoặc không ghi gì).
    public struct ImportSummary: Equatable, Sendable {
        public let newItems: Int
        public let newCollections: Int
        public let skipped: Int

        public init(newItems: Int, newCollections: Int, skipped: Int) {
            self.newItems = newItems
            self.newCollections = newCollections
            self.skipped = skipped
        }
    }

    public enum ImportError: Error, LocalizedError, Equatable {
        case emptyFile
        case missingHeader
        case malformedRow(line: Int, columnCount: Int)

        public var errorDescription: String? {
            switch self {
            case .emptyFile:
                "File rỗng hoặc không có dòng dữ liệu"
            case .missingHeader:
                "Thiếu dòng header (cần 7 cột: term, pos, ipa, meaning_vi, cefr, example, collection)"
            case let .malformedRow(line, columnCount):
                "Dòng \(line): số cột \(columnCount) không khớp header"
            }
        }
    }

    /// Các cột bắt buộc theo FR-16 (map theo tên, không theo vị trí).
    public static let requiredColumns = [
        "term", "pos", "ipa", "meaning_vi", "cefr", "example", "collection",
    ]

    /// Gập hoa thường tiếng Việt (chốt 2026-09-24): trim + `lowercased()` Unicode —
    /// `"SÁCH"→"sách"`, `"Đá"→"đá"`, nhưng `"Đá" ≠ "Đã"` (giữ thanh điệu).
    /// Tiếp nối `normalizedTerm` (SQLite NOCASE không gập được Đ/Á/Ở).
    public static func fold(_ value: String) -> String {
        VocabRepository.normalizedTerm(value)
    }

    // MARK: — Parse

    /// Parse nội dung file → dòng. Tự nhận delimiter từ header (`\t` → TSV FR-16,
    /// ngược lại comma → CSV thường). Lỗi header / dòng → throw, KHÔNG trả phần nào.
    public static func parse(_ text: String) throws -> [CSVRow] {
        // KHÔNG trim toàn text (tab `\t` ∈ whitespaces — sẽ ăn cột rỗng cuối dòng).
        guard text.contains(where: { !$0.isWhitespace }) else { throw ImportError.emptyFile }

        var lines = text.split(
            omittingEmptySubsequences: false,
            whereSeparator: { $0 == "\n" || $0 == "\r" }).map(String.init)
        // Bỏ các dòng trống ở cuối (file thường kết thúc bằng newline).
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        guard let headerLine = lines.first, !headerLine.trimmingCharacters(in: .whitespaces).isEmpty
        else { throw ImportError.emptyFile }

        let delimiter: Character = headerLine.contains("\t") ? "\t" : ","
        let header = split(headerLine, delimiter: delimiter)
        var columnIndex: [String: Int] = [:]
        for (i, name) in header.enumerated() {
            columnIndex[name.trimmingCharacters(in: .whitespaces).lowercased()] = i
        }
        guard requiredColumns.allSatisfy({ columnIndex[$0] != nil }) else {
            throw ImportError.missingHeader
        }

        var rows: [CSVRow] = []
        for (offset, line) in lines.dropFirst().enumerated() {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let fields = split(line, delimiter: delimiter)
            guard fields.count == header.count else {
                throw ImportError.malformedRow(line: offset + 2, columnCount: fields.count)
            }
            func field(_ column: String) -> String {
                guard let i = columnIndex[column], i < fields.count else { return "" }
                return fields[i].trimmingCharacters(in: .whitespaces)
            }
            rows.append(CSVRow(
                lineNumber: offset + 2,
                term: field("term"),
                pos: field("pos"),
                ipa: field("ipa"),
                meaningVI: field("meaning_vi"),
                cefr: field("cefr"),
                example: field("example"),
                collection: field("collection")))
        }
        guard !rows.isEmpty else { throw ImportError.emptyFile }
        return rows
    }

    /// Tách một dòng theo delimiter, tôn trọng dấu nháy CSV (`"a,b"`, `""` = trích dẫn).
    private static func split(_ line: String, delimiter: Character) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        let chars = Array(line)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        current.append("\"")
                        i += 2
                    } else {
                        inQuotes = false
                        i += 1
                    }
                } else {
                    current.append(c)
                    i += 1
                }
            } else if c == "\"" {
                inQuotes = true
                i += 1
            } else if c == delimiter {
                fields.append(current)
                current = ""
                i += 1
            } else {
                current.append(c)
                i += 1
            }
        }
        fields.append(current)
        return fields
    }

    // MARK: — Trùng term (cảnh báo, không tự loại)

    /// Tập `term_normalized` hiện có — để đánh dấu dòng trùng ở preview.
    public static func existingTermNormalizedSet(on db: SQLiteDatabase) throws -> Set<String> {
        let rows = try db.rows("SELECT term_normalized FROM vocab_items;", [])
        return Set(rows.compactMap { $0.first?.textValue })
    }

    /// Đánh dấu `duplicateTerm` cho dòng có `fold(term)` đã tồn tại (FR-20: không
    /// loại im lặng — user tự bỏ chọn).
    public static func markDuplicateTerms(
        _ rows: [CSVRow], existing: Set<String>
    ) -> [CSVRow] {
        rows.map { row in
            var r = row
            r.duplicateTerm = existing.contains(fold(r.term))
            return r
        }
    }

    // MARK: — Gộp (atomic)

    /// Gộp các dòng được chọn vào kho — MỘT transaction. Khớp collection theo tên
    /// (không hoa thường, giữ dấu) → trống → kho tạm → lạ → tạo mới. Card sinh ra
    /// mirror `saveCapture` (`receptive`/`new`/due hôm nay). Dòng chọn mà `term`
    /// rỗng → bỏ qua (tính vào `skipped`).
    public static func importRows(
        on db: SQLiteDatabase, rows: [CSVRow], now: Date
    ) throws -> ImportSummary {
        var newItems = 0
        var newCollections = 0
        var skipped = rows.reduce(0) { $0 + ($1.isSelected ? 0 : 1) }

        try db.inTransaction {
            let collections = try VocabRepository.allCollections(on: db)
            var byFold: [String: String] = [:]
            var inboxID: String?
            for c in collections {
                if byFold[fold(c.name)] == nil { byFold[fold(c.name)] = c.id }
                if c.isDefault { inboxID = c.id }
            }
            var createdInBatch: [String: String] = [:]
            let nowIso = ISOTimestamp.string(from: now)

            for row in rows where row.isSelected {
                let rawTerm = row.term.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !rawTerm.isEmpty else {
                    skipped += 1
                    continue
                }

                // Resolve collection đích.
                let name = row.collection.trimmingCharacters(in: .whitespacesAndNewlines)
                let targetID: String
                if name.isEmpty {
                    guard let inbox = inboxID else {
                        throw DatabaseError.failed("thiếu kho tạm seed", statement: nil)
                    }
                    targetID = inbox
                } else {
                    let key = fold(name)
                    if let existing = byFold[key] {
                        targetID = existing
                    } else if let created = createdInBatch[key] {
                        targetID = created
                    } else if let created = try VocabRepository.createCollection(
                        on: db, name: name, now: now
                    ) {
                        targetID = created
                        createdInBatch[key] = created
                        byFold[key] = created
                        newCollections += 1
                    } else {
                        throw DatabaseError.failed(
                            "không tạo được collection: \(name)", statement: nil)
                    }
                }

                let vocabID = Identifier.uuid()
                try db.run(
                    """
                    INSERT INTO vocab_items (
                      id, collection_id, term, term_normalized, pos,
                      ipa, meaning_vi, example, cefr, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                    """,
                    [
                        .text(vocabID),
                        .text(targetID),
                        .text(rawTerm),
                        .text(fold(rawTerm)),
                        .text(row.pos.isEmpty ? "other" : row.pos),
                        row.ipa.isEmpty ? .null : .text(row.ipa),
                        .text(row.meaningVI),
                        .text(row.example),
                        row.cefr.isEmpty ? .null : .text(row.cefr),
                        .text(nowIso),
                    ])
                try db.run(
                    """
                    INSERT INTO cards (
                      id, vocab_item_id, direction, state,
                      stability, difficulty, reps, lapses, learning_steps,
                      scheduled_days, last_review_at, due_at, suspended_at
                    ) VALUES (?, ?, 'receptive', 'new', 0, 0, 0, 0, 0, 0, NULL, ?, NULL);
                    """,
                    [
                        .text(Identifier.uuid()),
                        .text(vocabID),
                        .text(nowIso),
                    ])
                newItems += 1
            }
        }
        return ImportSummary(
            newItems: newItems, newCollections: newCollections, skipped: skipped)
    }
}