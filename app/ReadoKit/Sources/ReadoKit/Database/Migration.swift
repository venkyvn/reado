import Foundation

/// Migration DDL — dialect SQLite R1 đúng từng dòng của docs/db.md tầng A.
/// KHÔNG unique trên vocab_items(collection_id, term_normalized) (AGENTS mục 3.1).
/// Bảy bảng v1 + `encounters` (v4) + `pdf_sources` (v5) + index; seed nằm ở Seeder
/// chứ không phải migration.
public enum Migration {
    public static let currentVersion: Int64 = 5

    public enum MigrationError: Error, Equatable {
        /// user_version lớn hơn bản app hỗ trợ (DB từ phiên bản tương lai).
        case unsupportedUserVersion(Int64)
    }

    /// 3.12 — nhắc ôn tập: 2 cột mới trên `settings` (default TẮT + 20:00).
    /// SQLite ALTER TABLE thêm tối đa 1 cột/lệnh → tách 2 lệnh.
    static let v2Statements: [String] = [
        "ALTER TABLE settings ADD COLUMN reminder_enabled INTEGER NOT NULL DEFAULT 0;",
        "ALTER TABLE settings ADD COLUMN reminder_minutes INTEGER NOT NULL DEFAULT 1200;",
    ]

    /// 3.15 — port UI lab (2026-09-23): CEFR đa level, pin Home 5, scope ôn nhanh.
    /// Mỗi ALTER thêm tối đa 1 cột; cột cũ `cefr_level` giữ nguyên (deprecate).
    /// `home_shortcut_1/2` được copy sang `home_pin_ids` JSON rồi NULL hoá (xem
    /// `migrateLegacyHomePins`) — không lazy đọc để tránh resurrect pin cũ khi user
    /// sau này bỏ ghim hết.
    static let v3Statements: [String] = [
        "ALTER TABLE settings ADD COLUMN cefr_levels TEXT NOT NULL DEFAULT '[\"B2\"]';",
        "ALTER TABLE settings ADD COLUMN home_pin_ids TEXT NOT NULL DEFAULT '[]';",
        "ALTER TABLE settings ADD COLUMN review_priority_ids TEXT NOT NULL DEFAULT '[]';",
        "ALTER TABLE settings ADD COLUMN review_all INTEGER NOT NULL DEFAULT 0;",
    ]

    /// reencounter-r1 T1 (FR-22, ADR-048) — gặp lại từ cũ khi đọc. Bảng RIÊNG, không
    /// dùng `review_logs` (CHECK `mode`, bắt buộc `rating` + snapshot FSRS): lần
    /// "thấy"/"nhận ra" khi đọc KHÔNG đổi lịch ôn. Khoá theo `vocab_item_id` nên
    /// chuyển collection giữ nguyên, xoá vocab thì cascade.
    static let v4Statements: [String] = [
        """
        CREATE TABLE encounters (
          id            TEXT NOT NULL PRIMARY KEY,
          vocab_item_id TEXT NOT NULL REFERENCES vocab_items(id) ON DELETE CASCADE,
          kind          TEXT NOT NULL CHECK (kind IN ('seen', 'recognized')),
          created_at    TEXT NOT NULL
        );
        """,
        "CREATE INDEX idx_encounters_item ON encounters (vocab_item_id, kind);",
    ]

    /// pdf-reader-r1 T1 (FR-23, ADR-058) — đọc PDF trong Reado. PK là
    /// `collection_id` (không id riêng) → mỗi collection gắn tối đa 1 PDF; attach
    /// lần 2 là UPSERT ghi đè, không INSERT dòng mới. Không CHECK chặn kho tạm —
    /// app-rule (db.md A.2.2), vì SQLite không có cách CHECK liên-bảng gọn.
    static let v5Statements: [String] = [
        """
        CREATE TABLE pdf_sources (
          collection_id TEXT NOT NULL PRIMARY KEY
                          REFERENCES collections(id) ON DELETE CASCADE,
          display_name  TEXT NOT NULL,
          bookmark      TEXT NOT NULL,
          page_index    INTEGER NOT NULL DEFAULT 0,
          page_count    INTEGER NOT NULL DEFAULT 0,
          updated_at    TEXT NOT NULL
        );
        """,
    ]

    /// v2 → v3: chuyển 2 slot ghim cũ (`home_shortcut_1/2`) sang JSON `home_pin_ids`,
    /// rồi xoá 2 cột cũ (NULL) để `HomePinService.ids` không bao giờ đọc lại slot
    /// đã bỏ ghim — JSON giữ thứ tự slot 1 → 2.
    static func migrateLegacyHomePins(_ db: SQLiteDatabase) throws {
        guard
            let row = try db.rows(
                """
                SELECT home_shortcut_1_id, home_shortcut_2_id
                FROM settings WHERE id = 1;
                """
            ).first
        else { return }
        let legacy = [row["home_shortcut_1_id"].textValue, row["home_shortcut_2_id"].textValue]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        guard !legacy.isEmpty else { return }
        let json = JSONStringArray.encode(legacy)
        try db.run(
            "UPDATE settings SET home_pin_ids = ?, home_shortcut_1_id = NULL, home_shortcut_2_id = NULL WHERE id = 1;",
            [.text(json)])
    }

    static let v1Statements: [String] = [
        // -- PRAGMA foreign_keys = ON; // bật cho MỌI connection ở SQLiteDatabase.init

        """
        CREATE TABLE collections (
          id          TEXT NOT NULL PRIMARY KEY,
          name        TEXT NOT NULL,
          is_default  INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0, 1)),
          created_at  TEXT NOT NULL
        );
        """,
        """
        CREATE UNIQUE INDEX idx_collections_inbox
          ON collections (is_default) WHERE is_default = 1;
        """,
        """
        CREATE UNIQUE INDEX idx_collections_name
          ON collections (name COLLATE NOCASE);
        """,
        """
        CREATE TABLE vocab_items (
          id               TEXT NOT NULL PRIMARY KEY,
          collection_id    TEXT NOT NULL REFERENCES collections(id) ON DELETE RESTRICT,
          term             TEXT NOT NULL,
          term_normalized  TEXT NOT NULL,
          pos              TEXT NOT NULL,
          ipa              TEXT,
          meaning_vi       TEXT NOT NULL,
          example          TEXT NOT NULL,
          cefr             TEXT,
          created_at       TEXT NOT NULL
        );
        """,
        "CREATE INDEX idx_vocab_collection ON vocab_items (collection_id);",
        "CREATE INDEX idx_vocab_term      ON vocab_items (term_normalized);",
        "CREATE INDEX idx_vocab_inbox_time ON vocab_items (collection_id, created_at);",
        """
        CREATE TABLE cards (
          id              TEXT NOT NULL PRIMARY KEY,
          vocab_item_id   TEXT NOT NULL REFERENCES vocab_items(id) ON DELETE CASCADE,
          direction       TEXT NOT NULL DEFAULT 'receptive'
                            CHECK (direction IN ('receptive', 'productive')),
          state           TEXT NOT NULL DEFAULT 'new'
                            CHECK (state IN ('new', 'learning', 'review', 'relearning')),
          stability       REAL NOT NULL DEFAULT 0,
          difficulty      REAL NOT NULL DEFAULT 0,
          reps            INTEGER NOT NULL DEFAULT 0,
          lapses          INTEGER NOT NULL DEFAULT 0,
          learning_steps  INTEGER NOT NULL DEFAULT 0,
          scheduled_days  INTEGER NOT NULL DEFAULT 0,
          last_review_at  TEXT,
          due_at          TEXT NOT NULL,
          suspended_at    TEXT,
          UNIQUE (vocab_item_id, direction)
        );
        """,
        "CREATE INDEX idx_cards_due ON cards (due_at) WHERE suspended_at IS NULL;",
        """
        CREATE TABLE review_logs (
          id                     TEXT NOT NULL PRIMARY KEY,
          card_id                TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
          mode                   TEXT NOT NULL
                                   CHECK (mode IN ('srs', 'cram', 'distinguish', 'recall')),
          rating                 INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 4),
          state_before           TEXT NOT NULL,
          stability_before       REAL NOT NULL,
          difficulty_before      REAL NOT NULL,
          learning_steps_before  INTEGER NOT NULL,
          due_before             TEXT NOT NULL,
          elapsed_days           INTEGER NOT NULL,
          scheduled_days         INTEGER NOT NULL,
          reviewed_at            TEXT NOT NULL
        );
        """,
        "CREATE INDEX idx_logs_card ON review_logs (card_id, reviewed_at);",
        """
        CREATE TABLE analysis_agents (
          id          TEXT NOT NULL PRIMARY KEY,
          kind        TEXT NOT NULL CHECK (kind IN ('reado_proxy', 'openai_compat')),
          name        TEXT NOT NULL,
          base_url    TEXT,
          model       TEXT,
          created_at  TEXT NOT NULL
        );
        """,
        """
        CREATE TABLE reading_sessions (
          id            TEXT NOT NULL PRIMARY KEY,
          collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
          created_at    TEXT NOT NULL,
          segments      TEXT NOT NULL,
          summary       TEXT
        );
        """,
        "CREATE INDEX idx_sessions_collection ON reading_sessions (collection_id, created_at DESC);",
        """
        CREATE TABLE settings (
          id                 INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
          cefr_level         TEXT NOT NULL DEFAULT 'B2',
          daily_new_limit    INTEGER NOT NULL DEFAULT 10,
          request_retention  REAL NOT NULL DEFAULT 0.9
                               CHECK (request_retention BETWEEN 0.7 AND 0.99),
          maximum_interval   INTEGER NOT NULL DEFAULT 36500,
          enable_fuzz        INTEGER NOT NULL DEFAULT 1 CHECK (enable_fuzz IN (0, 1)),
          day_cutoff_hour    INTEGER NOT NULL DEFAULT 4
                               CHECK (day_cutoff_hour BETWEEN 0 AND 23),
          timezone           TEXT NOT NULL,
          enable_short_term  INTEGER NOT NULL DEFAULT 0 CHECK (enable_short_term IN (0, 1)),
          known_stability    REAL,
          leech_lapses       INTEGER,
          fsrs_params        TEXT,
          fsrs_version       TEXT,
          home_shortcut_1_id TEXT REFERENCES collections(id) ON DELETE SET NULL,
          home_shortcut_2_id TEXT REFERENCES collections(id) ON DELETE SET NULL,
          active_agent_id    TEXT NOT NULL REFERENCES analysis_agents(id)
        );
        """,
    ]

    public static func run(on db: SQLiteDatabase) throws {
        var version = try db.scalarInt64("PRAGMA user_version;") ?? 0
        guard version <= currentVersion else {
            throw MigrationError.unsupportedUserVersion(version)
        }
        while version < currentVersion {
            switch version {
            case 0:
                try db.inTransaction {
                    for statement in v1Statements {
                        try db.exec(statement)
                    }
                    try db.exec("PRAGMA user_version = 1;")
                }
            case 1:
                try db.inTransaction {
                    for statement in v2Statements {
                        try db.exec(statement)
                    }
                    try db.exec("PRAGMA user_version = 2;")
                }
            case 2:
                try db.inTransaction {
                    for statement in v3Statements {
                        try db.exec(statement)
                    }
                    try migrateLegacyHomePins(db)
                    try db.exec("PRAGMA user_version = 3;")
                }
            case 3:
                try db.inTransaction {
                    for statement in v4Statements {
                        try db.exec(statement)
                    }
                    try db.exec("PRAGMA user_version = 4;")
                }
            case 4:
                try db.inTransaction {
                    for statement in v5Statements {
                        try db.exec(statement)
                    }
                    try db.exec("PRAGMA user_version = 5;")
                }
            default:
                throw MigrationError.unsupportedUserVersion(version)
            }
            version = try db.scalarInt64("PRAGMA user_version;") ?? version + 1
        }
    }
}