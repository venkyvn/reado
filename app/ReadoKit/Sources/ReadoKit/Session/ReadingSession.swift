import Foundation

/// Phiên đọc song ngữ (FR-05/06 + Q-10/ADR-029): bản thu ghi tối đa 10 phiên
/// của MỘT collection có tên. `segments` là JSON mảng cặp
/// `{source_en, translation_vi}` (NFR-04: không lưu ảnh, chỉ văn bản tách đoạn).
public struct ReadingSession: Equatable, Sendable, Identifiable {
    public let id: String
    public let collectionID: String
    public let createdAt: Date
    public let segments: [PageAnalysis.Segment]
    public let summary: String?

    public init(
        id: String,
        collectionID: String,
        createdAt: Date,
        segments: [PageAnalysis.Segment],
        summary: String?
    ) {
        self.id = id
        self.collectionID = collectionID
        self.createdAt = createdAt
        self.segments = segments
        self.summary = summary
    }
}

/// Hình dạng JSON lưu trong cột `segments` — key snake_case khớp dialect docs/db.md.
private struct SegmentDTO: Codable {
    let source_en: String
    let translation_vi: String
}

public enum ReadingSessionRepository {
    /// Q-10/ADR-029: một collection có tên giữ tối đa 10 phiên; phiên thứ 11 cắt
    /// bỏ phiên cũ nhất.
    public static let maxSessionsPerCollection = 10

    /// Mã hoá các đoạn → chuỗi JSON. Không throw với dữ liệu chuỗi hợp lệ.
    public static func encodeSegments(_ segments: [PageAnalysis.Segment]) throws
        -> String
    {
        let dtos = segments.map {
            SegmentDTO(source_en: $0.sourceEN, translation_vi: $0.translationVI)
        }
        let data = try JSONEncoder().encode(dtos)
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    /// Giải mã chuỗi JSON → đoạn. JSON hỏng → mảng rỗng (không ném — dữ liệu
    /// cũ/ngoại lai không được phá vỡ màn đọc).
    public static func decodeSegments(_ json: String) -> [PageAnalysis.Segment] {
        guard let data = json.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([SegmentDTO].self, from: data)
        else {
            return []
        }
        return dtos.map {
            PageAnalysis.Segment(sourceEN: $0.source_en, translationVI: $0.translation_vi)
        }
    }

    /// Danh sách phiên của một collection, mới nhất trước (id làm tie-break cho
    /// trùng `created_at`).
    public static func listSessions(
        on db: SQLiteDatabase, collectionID: String
    ) throws -> [ReadingSession] {
        let rows = try db.rows(
            """
            SELECT id, collection_id, created_at, segments, summary
            FROM reading_sessions
            WHERE collection_id = ?
            ORDER BY created_at DESC, id DESC;
            """, [.text(collectionID)])
        return rows.map { row in
            ReadingSession(
                id: row[0].textValue ?? "",
                collectionID: row[1].textValue ?? "",
                createdAt: ISOTimestamp.date(from: row[2].textValue ?? "") ?? Date(),
                segments: decodeSegments(row[3].textValue ?? ""),
                summary: row[4].textValue)
        }
    }

    /// Chèn MỘT phiên + cắt gọn về tối đa `maxSessionsPerCollection` phiên mới
    /// nhất. KHÔNG mở transaction riêng — gọi bên trong transaction của
    /// `saveCapture` (SD §6 khối #5, `inTransaction` không nest được). `summary`
    /// nil → NULL.
    public static func insertInsideTransaction(
        on db: SQLiteDatabase,
        collectionID: String,
        createdAt: Date,
        segments: [PageAnalysis.Segment],
        summary: String?
    ) throws {
        try db.run(
            """
            INSERT INTO reading_sessions (id, collection_id, created_at, segments, summary)
            VALUES (?, ?, ?, ?, ?);
            """,
            [
                .text(Identifier.uuid()),
                .text(collectionID),
                .text(ISOTimestamp.string(from: createdAt)),
                .text(try encodeSegments(segments)),
                summary.map { .text($0) } ?? .null,
            ])
        try db.run(
            """
            DELETE FROM reading_sessions
            WHERE collection_id = ?
              AND id NOT IN (
                  SELECT id FROM reading_sessions
                  WHERE collection_id = ?
                  ORDER BY created_at DESC, id DESC
                  LIMIT \(maxSessionsPerCollection)
              );
            """, [.text(collectionID), .text(collectionID)])
    }
}