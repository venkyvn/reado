import FSRS
import Foundation

/// Bản chụp các núm lịch ôn từ bảng `settings` — nguồn dựng `FSRSParameters`.
public struct SchedulingSettings: Equatable, Sendable {
    public var requestRetention: Double
    public var maximumInterval: Double
    public var enableFuzz: Bool
    /// Đã decode từ settings.fsrs_params (JSON array); nil = default thư viện.
    public var fsrsParams: [Double]?
    /// settings.fsrs_version — phải là 'fsrs-6' khi fsrsParams != nil.
    public var fsrsVersion: String?

    public init(
        requestRetention: Double,
        maximumInterval: Double,
        enableFuzz: Bool,
        fsrsParams: [Double]?,
        fsrsVersion: String?
    ) {
        self.requestRetention = requestRetention
        self.maximumInterval = maximumInterval
        self.enableFuzz = enableFuzz
        self.fsrsParams = fsrsParams
        self.fsrsVersion = fsrsVersion
    }
}

public enum ReviewSchedulerError: Error, LocalizedError, Equatable {
    /// fsrs_params có nhưng version không khớp hoặc w không phải 21 phần tử —
    /// tech-stack mục 3.1: nâng thư viện không đổi mảng = silent breakage.
    case unsupportedParamsVersion(String)
    case invalidParamsJSON(String)
    /// cards.state ngoài bốn giá trị chốt (rulebook mục 5).
    case invalidCardStateCode(String)

    public var errorDescription: String? {
        switch self {
        case let .unsupportedParamsVersion(version):
            "fsrs_params đi kèm fsrs_version không khớp: \(version)"
        case let .invalidParamsJSON(reason):
            "fsrs_params không parse được JSON array: \(reason)"
        case let .invalidCardStateCode(code):
            "cards.state ngoài bốn giá trị chốt: \(code)"
        }
    }
}

/// Mức chấm Reado — KHÔNG để kiểu thư viện ngoài lọt vào API công khai.
/// Map 1:1 với review_logs.rating (db.md CHECK 1–4) và vuốt ADR-025:
/// TRÁI = again(1), PHẢI = good(3); hard(2)/easy(4) là nút.
public enum ReadoRating: Int, CaseIterable, Sendable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var fsrsRating: Rating {
        switch self {
        case .again: .again
        case .hard: .hard
        case .good: .good
        case .easy: .easy
        }
    }
}

/// Kết quả một lần chấm — toàn kiểu của ReadoKit, không rò kiểu FSRS.
public struct ReviewOutcome: Equatable, Sendable {
    /// cards.state SAU chấm (mã DB: new/learning/review/relearning).
    public let state: String
    public let due: Date
    public let stability: Double
    public let difficulty: Double
    public let reps: Int
    public let lapses: Int
    public let learningSteps: Int
    /// Lịch cách ngày — làm tròn từ double của FSRS.
    public let scheduledDays: Int
    /// 1–4; .manual không bao giờ là kết quả chấm.
    public let rating: Int
    public let elapsedDaysRounded: Int

    public init(
        state: String,
        due: Date,
        stability: Double,
        difficulty: Double,
        reps: Int,
        lapses: Int,
        learningSteps: Int,
        scheduledDays: Int,
        rating: Int,
        elapsedDaysRounded: Int
    ) {
        self.state = state
        self.due = due
        self.stability = stability
        self.difficulty = difficulty
        self.reps = reps
        self.lapses = lapses
        self.learningSteps = learningSteps
        self.scheduledDays = scheduledDays
        self.rating = rating
        self.elapsedDaysRounded = elapsedDaysRounded
    }
}

/// Cầu nối settings ↔ swift-fsrs. CHỐT (ROADMAP mục 1, AGENTS mục 3.2):
/// — `defaultWv6` (21 trọng số, FSRS-6); cấm constructor không tham số (FSRS-5)
/// — Q-12: `enableShortTerm = false`, learning/relearning steps RỖNG
public enum ReadoFSRS {
    /// Giá trị duy nhất cột `settings.fsrs_version` ở R1.
    public static let fsrsVersion = "fsrs-6"

    /// defaultWv6 (21 trọng số) — che kiểu thư viện ngoài, để test/app
    /// không phải import swift-fsrs.
    public static var defaultWeights: [Double] { FSRSDefaults.defaultWv6 }

    public static func parameters(from settings: SchedulingSettings) throws
        -> FSRSParameters
    {
        var weights = FSRSDefaults.defaultWv6
        if let custom = settings.fsrsParams {
            guard settings.fsrsVersion == fsrsVersion, custom.count == 21 else {
                throw ReviewSchedulerError.unsupportedParamsVersion(
                    settings.fsrsVersion ?? "<nil>")
            }
            weights = custom
        }
        return FSRSParameters(
            requestRetention: settings.requestRetention,
            maximumInterval: settings.maximumInterval,
            w: weights,
            enableFuzz: settings.enableFuzz,
            enableShortTerm: false,
            learningSteps: [],
            relearningSteps: []
        )
    }

    public static func defaultSettings() -> SchedulingSettings {
        SchedulingSettings(
            requestRetention: 0.9,
            maximumInterval: 36_500,
            enableFuzz: true,
            fsrsParams: nil,
            fsrsVersion: nil)
    }

    /// Đọc settings từ DB (id = 1) và chuyển thành SchedulingSettings.
    public static func readSettings(on db: SQLiteDatabase) throws
        -> SchedulingSettings
    {
        guard
            let row = try db.rows(
                """
                SELECT request_retention, maximum_interval, enable_fuzz,
                       fsrs_params, fsrs_version
                FROM settings WHERE id = 1;
                """
            ).first,
            row.count == 5
        else {
            throw DatabaseError.failed(
                "settings id=1 chưa seed", statement: "SELECT settings")
        }
        let params: [Double]?
        if let raw = row[3].textValue {
            guard
                let data = raw.data(using: .utf8),
                let decoded = try? JSONDecoder().decode([Double].self, from: data)
            else {
                throw ReviewSchedulerError.invalidParamsJSON(raw)
            }
            params = decoded
        } else {
            params = nil
        }
        return SchedulingSettings(
            requestRetention: row[0].doubleValue ?? 0.9,
            maximumInterval: Double(row[1].intValue ?? 36_500),
            enableFuzz: (row[2].intValue ?? 1) != 0,
            fsrsParams: params,
            fsrsVersion: row[4].textValue)
    }
}

public final class ReviewScheduler: @unchecked Sendable {
    /// Engine swift-fsrs — public cho ai muốn dùng trực tiếp; API product
    /// của Reado đi qua `grade(...)` bên dưới.
    public let engine: FSRS
    public let parameters: FSRSParameters

    /// True = engine đang chạy FSRS-6 (21 trọng số) — guard chống FSRS-5
    /// ngấm vào thầm lặng (tech-stack mục 3.1).
    public var isV6: Bool { engine.version == .v6 }

    public init(settings: SchedulingSettings) throws {
        let parameters = try ReadoFSRS.parameters(from: settings)
        self.parameters = parameters
        self.engine = FSRS(parameters: parameters)
    }

    /// Chấm bằng Card của thư viện (dùng nội bộ / nâng cao).
    public func grade(_ rating: ReadoRating, card: Card, now: Date) throws
        -> ReviewOutcome
    {
        let item = try engine.next(
            card: card, now: now, grade: rating.fsrsRating)
        return Self.makeOutcome(item)
    }

    /// Chấm thẳng từ snapshot trong DB (đường dùng chính của app).
    public func grade(
        _ rating: ReadoRating, snapshot: CardSnapshot, now: Date
    ) throws -> ReviewOutcome {
        let card = try snapshot.schedulerCard(now: now)
        return try grade(rating, card: card, now: now)
    }

    static func makeOutcome(_ item: RecordLogItem) -> ReviewOutcome {
        ReviewOutcome(
            state: CardStateCode.from(item.card.state),
            due: item.card.due,
            stability: item.card.stability,
            difficulty: item.card.difficulty,
            reps: item.card.reps,
            lapses: item.card.lapses,
            learningSteps: item.card.learningSteps,
            // Nhịp MỚI sau lần chấm này (item.card) — log của lib ghi nhịp CŨ
            // (last.scheduledDays = 0 ở lần chấm đầu), không dùng cho cột này.
            scheduledDays: Int(item.card.scheduledDays.rounded()),
            rating: item.log.rating.rawValue,
            elapsedDaysRounded: Int(item.log.elapsedDays.rounded())
        )
    }
}

/// Danh sách state ĐÓNG — đúng CHECK trong cards.state.
/// Bốn giá trị, không gộp learning/relearning (rulebook mục 5).
public enum CardStateCode {
    public static var allCodes: [String] {
        ["new", "learning", "review", "relearning"]
    }

    public static func from(_ state: CardState) -> String {
        state.stringValue
    }

    public static func toState(_ code: String) -> CardState? {
        switch code {
        case "new": .new
        case "learning": .learning
        case "review": .review
        case "relearning": .relearning
        default: nil
        }
    }
}