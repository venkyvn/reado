import Foundation

// MARK: - FR-16 Data Export — phao cứu sinh Phase 3.1 (ROADMAP 3.1)
//  - CSV/TSV theo collection (Nhập được Anki) + JSON FSRS backup.
//  - Không xuất key (NFR-07): settings chỉ xuất whitelist, không có ai_api_key.
//  - FR-20 là scope v2: CSV merge, không JSON (chú thích cho người đọc).

// MARK: - Types

/// Dòng export — 1:1 với TSV 7 cột (J-R1-D + 3bis + prd.md FR-16).
/// Thứ tự cột: term · pos · ipa · meaning_vi · cefr · example · collection
public struct ExportRow: Equatable, Sendable {
    public let term: String
    public let pos: String
    public let ipa: String
    public let meaningVI: String
    public let cefr: String
    public let example: String
    public let collectionName: String
}

/// Bundle export JSON — whitelist settings + toàn bộ domain (backup máy).
/// Không chứa key user (Keychain), không chứa apiKey/baseUrl của analysis_agents.
public struct ExportBundle: Codable, Equatable, Sendable {
    public let format: String       // "reado-export"
    public let version: Int         // 1
    public let exportedAt: String   // ISOTimestamp UTC Z
    public let scope: ExportScope
    public let counts: ExportCounts
    public let settings: ExportSettings
    public let collections: [ExportCollection]
    public let vocabItems: [ExportVocabItem]
    public let cards: [ExportCard]
    public let reviewLogs: [ExportReviewLog]
}

/// Phạm vi xuất — TSV lọc được, JSON luôn toàn máy (prd.md FR-16; J-R1-D #4).
public struct ExportScope: Codable, Equatable, Sendable {
    /// nil = toàn bộ máy; non-nil = chỉ những collection được chọn.
    public let collectionIDs: [String]?
    /// Tên tương ứng cho dễ đọc khi debug ngoài máy.
    public let collectionNames: [String]?
}

public struct ExportCounts: Codable, Equatable, Sendable {
    public let collections: Int
    public let vocabItems: Int
    public let cards: Int
    public let reviewLogs: Int
}

public struct ExportSettings: Codable, Equatable, Sendable {
    public let cefrLevel: String
    public let dailyNewLimit: Int
    public let requestRetention: Double
    public let maximumInterval: Int
    public let enableFuzz: Bool
    public let dayCutoffHour: Int
    public let timezone: String
    public let enableShortTerm: Bool
    public let fsrsVersion: String?
    public let fsrsParams: [Double]?
}

public struct ExportCollection: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let isDefault: Bool
    public let createdAt: String
}

public struct ExportVocabItem: Codable, Equatable, Sendable {
    public let id: String
    public let collectionID: String
    public let term: String
    public let termNormalized: String
    public let pos: String
    public let ipa: String?
    public let meaningVI: String
    public let example: String
    public let cefr: String?
    public let createdAt: String
}

public struct ExportCard: Codable, Equatable, Sendable {
    public let id: String
    public let vocabItemID: String
    public let direction: String
    public let state: String
    public let stability: Double
    public let difficulty: Double
    public let reps: Int
    public let lapses: Int
    public let learningSteps: Int
    public let scheduledDays: Int
    public let lastReviewAt: String?
    public let dueAt: String
    public let suspendedAt: String?
}

public struct ExportReviewLog: Codable, Equatable, Sendable {
    public let id: String
    public let cardID: String
    public let mode: String
    public let rating: Int
    public let stateBefore: String
    public let stabilityBefore: Double
    public let difficultyBefore: Double
    public let learningStepsBefore: Int
    public let dueBefore: String
    public let elapsedDays: Int
    public let scheduledDays: Int
    public let reviewedAt: String
}

// MARK: - TSV builder (Anki-compatible)

/// 7 cột TSV — Anki import qua `#separator:tab`. Không thêm cột thứ 8.
///
/// TS fragment: escape `#`, thay tab/newline trong field bằng space (NOCASE không liên quan TSV).
/// Header: `term\tpos\tipa\tmeaning_vi\tcefr\texample\tcollection`
public enum TSVBuilder {
    public static let header = "term\tpos\tipa\tmeaning_vi\tcefr\texample\tcollection"

    /// Sanitize một field cho TSV: bỏ tab/newline, giữ nội dung nhìn thấy.
    public static func escape(_ value: String) -> String {
        // Giữ tiếng Việt nguyên vẹn; chỉ thay control char làm vỡ cột/dòng.
        var s = value
        s = s.replacingOccurrences(of: "\r", with: " ")
        s = s.replacingOccurrences(of: "\n", with: " ")
        s = s.replacingOccurrences(of: "\t", with: " ")
        return s
    }

    public static func build(rows: [ExportRow]) -> String {
        var lines: [String] = [header]
        for r in rows {
            let fields = [
                escape(r.term),
                escape(r.pos),
                escape(r.ipa),
                escape(r.meaningVI),
                escape(r.cefr),
                escape(r.example),
                escape(r.collectionName),
            ]
            lines.append(fields.joined(separator: "\t"))
        }
        // Kết thúc bằng newline theo POSIX (Anki/Numbers tolerante nhưng chuẩn nên có).
        return lines.joined(separator: "\n") + "\n"
    }
}

// MARK: - DB → ExportRow / Bundle

public enum ExportService {

    // MARK: TSV (FR-16 #1 + #2 — theo collection, Anki-compatible)

    /// Đọc các dòng export theo phạm vi.
    /// `collectionIDs == nil` → toàn bộ máy; empty array → không có dòng (nhưng header vẫn có);
    /// non-empty → lọc vocab_items.collection_id IN (...)
    public static func fetchRows(
        on db: SQLiteDatabase,
        collectionIDs: [String]?
    ) throws -> [ExportRow] {
        // Validate collectionIDs nếu có — không throw nếu không tồn tại, chỉ trả rỗng.
        if let ids = collectionIDs, ids.isEmpty {
            return []
        }
        let whereClause: String
        var params: [SQLValue] = []
        if let ids = collectionIDs {
            let ph = ids.map { _ in "?" }.joined(separator: ",")
            whereClause = "WHERE v.collection_id IN (\(ph))"
            params = ids.map { .text($0) }
        } else {
            whereClause = ""
        }
        let sql = """
            SELECT v.term, v.pos, IFNULL(v.ipa,''), v.meaning_vi,
                   IFNULL(v.cefr,''), v.example, c.name
            FROM vocab_items v
            JOIN collections c ON c.id = v.collection_id
            \(whereClause)
            ORDER BY c.name COLLATE NOCASE, v.created_at, v.id;
            """
        let rows = try db.rows(sql, params)
        return rows.compactMap { r in
            guard r.count >= 7 else { return nil }
            return ExportRow(
                term: r[0].textValue ?? "",
                pos: r[1].textValue ?? "",
                ipa: r[2].textValue ?? "",
                meaningVI: r[3].textValue ?? "",
                cefr: r[4].textValue ?? "",
                example: r[5].textValue ?? "",
                collectionName: r[6].textValue ?? ""
            )
        }
    }

    /// Build TSV string cho phạm vi (gọi fetchRows rồi build).
    public static func buildTSV(
        on db: SQLiteDatabase,
        collectionIDs: [String]?
    ) throws -> String {
        let rows = try fetchRows(on: db, collectionIDs: collectionIDs)
        return TSVBuilder.build(rows: rows)
    }

    // MARK: JSON backup (FR-16 #3 — toàn bộ máy, không lọc collection; R1 không nhập JSON)

    /// Đọc toàn bộ bundle JSON cho backup máy (không lọc collection theo J-R1-D #4).
    /// `scopeIDs == nil` → scope = toàn bộ; non-nil → ghi scope như đã lọc (để UI đánh dấu),
    /// nhưng **dữ liệu bên trong vẫn luôn là toàn bộ máy** (backup không lọc).
    public static func fetchBundle(
        on db: SQLiteDatabase,
        scopeIDs: [String]? = nil,
        now: Date = Date()
    ) throws -> ExportBundle {
        // Collections
        let collRows = try db.rows(
            "SELECT id, name, is_default, created_at FROM collections ORDER BY name COLLATE NOCASE;")
        let collections: [ExportCollection] = try collRows.map { r in
            guard r.count >= 4 else { throw DatabaseError.failed("thiếu cột collections", statement: nil) }
            return ExportCollection(
                id: r[0].textValue ?? "",
                name: r[1].textValue ?? "",
                isDefault: (r[2].intValue ?? 0) != 0,
                createdAt: r[3].textValue ?? ""
            )
        }

        // VocabItems
        let vocabRows = try db.rows(
            "SELECT id, collection_id, term, term_normalized, pos, ipa, meaning_vi, example, cefr, created_at FROM vocab_items ORDER BY created_at, id;")
        let vocabItems: [ExportVocabItem] = vocabRows.compactMap { r in
            guard r.count >= 10 else { return nil }
            return ExportVocabItem(
                id: r[0].textValue ?? "",
                collectionID: r[1].textValue ?? "",
                term: r[2].textValue ?? "",
                termNormalized: r[3].textValue ?? "",
                pos: r[4].textValue ?? "",
                ipa: r[5].textValue,
                meaningVI: r[6].textValue ?? "",
                example: r[7].textValue ?? "",
                cefr: r[8].textValue,
                createdAt: r[9].textValue ?? ""
            )
        }

        // Cards
        let cardRows = try db.rows(
            "SELECT id, vocab_item_id, direction, state, stability, difficulty, reps, lapses, learning_steps, scheduled_days, last_review_at, due_at, suspended_at FROM cards ORDER BY due_at, id;")
        let cards: [ExportCard] = cardRows.compactMap { r in
            guard r.count >= 13 else { return nil }
            return ExportCard(
                id: r[0].textValue ?? "",
                vocabItemID: r[1].textValue ?? "",
                direction: r[2].textValue ?? "receptive",
                state: r[3].textValue ?? "new",
                stability: r[4].doubleValue ?? 0,
                difficulty: r[5].doubleValue ?? 0,
                reps: Int(r[6].intValue ?? 0),
                lapses: Int(r[7].intValue ?? 0),
                learningSteps: Int(r[8].intValue ?? 0),
                scheduledDays: Int(r[9].intValue ?? 0),
                lastReviewAt: r[10].textValue,
                dueAt: r[11].textValue ?? "",
                suspendedAt: r[12].textValue
            )
        }

        // ReviewLogs — snapshot TRƯỚC khi chấm (FR-12)
        let logRows = try db.rows(
            "SELECT id, card_id, mode, rating, state_before, stability_before, difficulty_before, learning_steps_before, due_before, elapsed_days, scheduled_days, reviewed_at FROM review_logs ORDER BY reviewed_at, id;")
        let reviewLogs: [ExportReviewLog] = logRows.compactMap { r in
            guard r.count >= 12 else { return nil }
            return ExportReviewLog(
                id: r[0].textValue ?? "",
                cardID: r[1].textValue ?? "",
                mode: r[2].textValue ?? "srs",
                rating: Int(r[3].intValue ?? 1),
                stateBefore: r[4].textValue ?? "new",
                stabilityBefore: r[5].doubleValue ?? 0,
                difficultyBefore: r[6].doubleValue ?? 0,
                learningStepsBefore: Int(r[7].intValue ?? 0),
                dueBefore: r[8].textValue ?? "",
                elapsedDays: Int(r[9].intValue ?? 0),
                scheduledDays: Int(r[10].intValue ?? 0),
                reviewedAt: r[11].textValue ?? ""
            )
        }

        // Settings — whitelist, KHÔNG xuất key (NFR-07)
        let settings = try fetchExportSettings(on: db)

        let scopeNames: [String]? = {
            guard let ids = scopeIDs, !ids.isEmpty else { return nil }
            let byID = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0.name) })
            return ids.compactMap { byID[$0] }
        }()

        return ExportBundle(
            format: "reado-export",
            version: 1,
            exportedAt: ISOTimestamp.string(from: now),
            scope: ExportScope(collectionIDs: scopeIDs, collectionNames: scopeNames),
            counts: ExportCounts(
                collections: collections.count,
                vocabItems: vocabItems.count,
                cards: cards.count,
                reviewLogs: reviewLogs.count
            ),
            settings: settings,
            collections: collections,
            vocabItems: vocabItems,
            cards: cards,
            reviewLogs: reviewLogs
        )
    }

    /// Encode bundle thành JSON pretty-printed (máy đọc được).
    public static func buildJSON(
        on db: SQLiteDatabase,
        scopeIDs: [String]? = nil,
        now: Date = Date()
    ) throws -> Data {
        let bundle = try fetchBundle(on: db, scopeIDs: scopeIDs, now: now)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try enc.encode(bundle)
    }

    // MARK: - private

    static func fetchExportSettings(on db: SQLiteDatabase) throws -> ExportSettings {
        guard let row = try db.rows(
            "SELECT cefr_level, daily_new_limit, request_retention, maximum_interval, enable_fuzz, day_cutoff_hour, timezone, enable_short_term, fsrs_version, fsrs_params FROM settings WHERE id = 1;"
        ).first, row.count == 10 else {
            throw DatabaseError.failed("settings id=1 chưa seed", statement: nil)
        }
        let fsrsParams: [Double]? = {
            guard let raw = row[9].textValue else { return nil }
            guard let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Double].self, from: data) else {
                return nil
            }
            return decoded
        }()
        return ExportSettings(
            cefrLevel: row[0].textValue ?? "B2",
            dailyNewLimit: Int(row[1].intValue ?? 10),
            requestRetention: row[2].doubleValue ?? 0.9,
            maximumInterval: Int(row[3].intValue ?? 36500),
            enableFuzz: (row[4].intValue ?? 1) != 0,
            dayCutoffHour: Int(row[5].intValue ?? 4),
            timezone: row[6].textValue ?? "UTC",
            enableShortTerm: (row[7].intValue ?? 1) != 0,
            fsrsVersion: row[8].textValue,
            fsrsParams: fsrsParams
        )
    }
}
