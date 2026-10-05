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
    /// FR-22 (schema v4): lần "thấy"/"nhận ra" từ cũ khi đọc. Thêm khoá, `version` giữ 1.
    public let encounters: [ExportEncounter]
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
    public let encounters: Int
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

public struct ExportEncounter: Codable, Equatable, Sendable {
    public let id: String
    public let vocabItemID: String
    /// `seen` | `recognized`.
    public let kind: String
    public let createdAt: String
    /// Câu chứa từ lúc gặp (v7); nil với dòng cũ / `recognized`.
    public let sentence: String?
    /// Collection đang lưu lúc gặp (v7); nil với dòng cũ hoặc collection đã xoá.
    public let collectionID: String?
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
            SELECT v.term AS term, v.pos AS pos, IFNULL(v.ipa,'') AS ipa,
                   v.meaning_vi AS meaning_vi, IFNULL(v.cefr,'') AS cefr,
                   v.example AS example, c.name AS collection_name
            FROM vocab_items v
            JOIN collections c ON c.id = v.collection_id
            \(whereClause)
            ORDER BY c.name COLLATE NOCASE, v.created_at, v.id;
            """
        let rows = try db.rows(sql, params)
        return rows.map { r in
            ExportRow(
                term: r["term"].textValue ?? "",
                pos: r["pos"].textValue ?? "",
                ipa: r["ipa"].textValue ?? "",
                meaningVI: r["meaning_vi"].textValue ?? "",
                cefr: r["cefr"].textValue ?? "",
                example: r["example"].textValue ?? "",
                collectionName: r["collection_name"].textValue ?? ""
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
        let collections: [ExportCollection] = collRows.map { r in
            ExportCollection(
                id: r["id"].textValue ?? "",
                name: r["name"].textValue ?? "",
                isDefault: (r["is_default"].intValue ?? 0) != 0,
                createdAt: r["created_at"].textValue ?? ""
            )
        }

        // VocabItems
        let vocabRows = try db.rows(
            "SELECT id, collection_id, term, term_normalized, pos, ipa, meaning_vi, example, cefr, created_at FROM vocab_items ORDER BY created_at, id;")
        let vocabItems: [ExportVocabItem] = vocabRows.map { r in
            ExportVocabItem(
                id: r["id"].textValue ?? "",
                collectionID: r["collection_id"].textValue ?? "",
                term: r["term"].textValue ?? "",
                termNormalized: r["term_normalized"].textValue ?? "",
                pos: r["pos"].textValue ?? "",
                ipa: r["ipa"].textValue,
                meaningVI: r["meaning_vi"].textValue ?? "",
                example: r["example"].textValue ?? "",
                cefr: r["cefr"].textValue,
                createdAt: r["created_at"].textValue ?? ""
            )
        }

        // Cards
        let cardRows = try db.rows(
            "SELECT id, vocab_item_id, direction, state, stability, difficulty, reps, lapses, learning_steps, scheduled_days, last_review_at, due_at, suspended_at FROM cards ORDER BY due_at, id;")
        let cards: [ExportCard] = cardRows.map { r in
            ExportCard(
                id: r["id"].textValue ?? "",
                vocabItemID: r["vocab_item_id"].textValue ?? "",
                direction: r["direction"].textValue ?? "receptive",
                state: r["state"].textValue ?? "new",
                stability: r["stability"].doubleValue ?? 0,
                difficulty: r["difficulty"].doubleValue ?? 0,
                reps: Int(r["reps"].intValue ?? 0),
                lapses: Int(r["lapses"].intValue ?? 0),
                learningSteps: Int(r["learning_steps"].intValue ?? 0),
                scheduledDays: Int(r["scheduled_days"].intValue ?? 0),
                lastReviewAt: r["last_review_at"].textValue,
                dueAt: r["due_at"].textValue ?? "",
                suspendedAt: r["suspended_at"].textValue
            )
        }

        // ReviewLogs — snapshot TRƯỚC khi chấm (FR-12)
        let logRows = try db.rows(
            "SELECT id, card_id, mode, rating, state_before, stability_before, difficulty_before, learning_steps_before, due_before, elapsed_days, scheduled_days, reviewed_at FROM review_logs ORDER BY reviewed_at, id;")
        let reviewLogs: [ExportReviewLog] = logRows.map { r in
            ExportReviewLog(
                id: r["id"].textValue ?? "",
                cardID: r["card_id"].textValue ?? "",
                mode: r["mode"].textValue ?? "srs",
                rating: Int(r["rating"].intValue ?? 1),
                stateBefore: r["state_before"].textValue ?? "new",
                stabilityBefore: r["stability_before"].doubleValue ?? 0,
                difficultyBefore: r["difficulty_before"].doubleValue ?? 0,
                learningStepsBefore: Int(r["learning_steps_before"].intValue ?? 0),
                dueBefore: r["due_before"].textValue ?? "",
                elapsedDays: Int(r["elapsed_days"].intValue ?? 0),
                scheduledDays: Int(r["scheduled_days"].intValue ?? 0),
                reviewedAt: r["reviewed_at"].textValue ?? ""
            )
        }

        // Encounters (FR-22) — gặp lại từ cũ khi đọc, ngoài FSRS
        let encounterRows = try db.rows(
            "SELECT id, vocab_item_id, kind, created_at, sentence, collection_id FROM encounters ORDER BY created_at, id;")
        let encounters: [ExportEncounter] = encounterRows.map { r in
            ExportEncounter(
                id: r["id"].textValue ?? "",
                vocabItemID: r["vocab_item_id"].textValue ?? "",
                kind: r["kind"].textValue ?? "seen",
                createdAt: r["created_at"].textValue ?? "",
                sentence: r["sentence"].textValue,
                collectionID: r["collection_id"].textValue
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
                reviewLogs: reviewLogs.count,
                encounters: encounters.count
            ),
            settings: settings,
            collections: collections,
            vocabItems: vocabItems,
            cards: cards,
            reviewLogs: reviewLogs,
            encounters: encounters
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
        ).first else {
            throw DatabaseError.failed("settings id=1 chưa seed", statement: nil)
        }
        let fsrsParams: [Double]? = {
            guard let raw = row["fsrs_params"].textValue else { return nil }
            guard let data = raw.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([Double].self, from: data) else {
                return nil
            }
            return decoded
        }()
        return ExportSettings(
            cefrLevel: row["cefr_level"].textValue ?? "B2",
            dailyNewLimit: Int(row["daily_new_limit"].intValue ?? 10),
            requestRetention: row["request_retention"].doubleValue ?? 0.9,
            maximumInterval: Int(row["maximum_interval"].intValue ?? 36500),
            enableFuzz: (row["enable_fuzz"].intValue ?? 1) != 0,
            dayCutoffHour: Int(row["day_cutoff_hour"].intValue ?? 4),
            timezone: row["timezone"].textValue ?? "UTC",
            enableShortTerm: (row["enable_short_term"].intValue ?? 1) != 0,
            fsrsVersion: row["fsrs_version"].textValue,
            fsrsParams: fsrsParams
        )
    }
}
