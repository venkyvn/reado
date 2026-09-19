import Foundation

/// Migration DDL — dialect SQLite R1 đúng từng dòng của docs/db.md tầng A.
/// KHÔNG unique trên vocab_items(collection_id, term_normalized) (AGENTS mục 3.1).
/// Bảy bảng + index; seed nằm ở Seeder chứ không phải migration.
public enum Migration {
    public static let currentVersion: Int64 = 1

    public enum MigrationError: Error, Equatable {
        /// user_version lớn hơn bản app hỗ trợ (DB từ phiên bản tương lai).
        case unsupportedUserVersion(Int64)
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
            default:
                throw MigrationError.unsupportedUserVersion(version)
            }
            version = try db.scalarInt64("PRAGMA user_version;") ?? version + 1
        }
    }
}