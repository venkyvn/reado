import Foundation

/// verify-nav-r1 — parse launch argument của bản DEBUG để agent mở thẳng một
/// màn trên simulator (không chạm tay). Hàm thuần, không `#if DEBUG` ở đây để
/// test được bằng `scripts/test.sh kit`; call site ở app (`ReadoApp`/`RootView`)
/// mới bọc `#if DEBUG` — bản Release không đọc argument nào.
///
/// Cú pháp: cặp `-Key value`, ví dụ `-ReadoScreen review-extra -ReadoTheme forest`.
/// Giá trị lạ hoặc thiếu không crash — rơi vào `problems` để app hiện alert,
/// không bao giờ âm thầm mở sai màn.
public struct DebugLaunch: Equatable, Sendable {
    public var screen: Screen?
    /// Chuỗi thô — app tự validate bằng `AppTheme(rawValue:)` (AppTheme ở app,
    /// ReadoKit không biết theme nào tồn tại).
    public var theme: String?
    public var seed: Seed?
    public var alert: Alert?
    public var problems: [String]

    public init(
        screen: Screen? = nil,
        theme: String? = nil,
        seed: Seed? = nil,
        alert: Alert? = nil,
        problems: [String] = []
    ) {
        self.screen = screen
        self.theme = theme
        self.seed = seed
        self.alert = alert
        self.problems = problems
    }

    public enum Screen: Equatable, Sendable {
        case home
        /// Tab Thư viện (ux-redesign-r1 T1b). Chuỗi cũ `kho` vẫn parse về đây để không phá script cũ.
        case library
        case review
        case reviewExtra
        case collection(String)
        case settings
        case streak
        case data
        case capture
        case analysisFixture
        /// ux-redesign-r1 T5b — như `analysisFixture` nhưng mở thẳng tab "Trang" (song ngữ hiện sẵn).
        case analysisFixturePage
        case encounterSheet
        /// prompt-v6 T3 — như `analysisFixturePage` nhưng sáng sẵn cụm EN↔VI đầu tiên của trang,
        /// để chụp được trạng thái "đã chạm" không cần thao tác tay.
        case phraseHighlight
        /// q13-sense-filter-r1 T2 — như `analysisFixture` nhưng mở sẵn nhóm gập "Đã thuộc" (Q-13
        /// phương án B), để chụp trạng thái mở không cần thao tác tay (simulator không có cách tap).
        case analysisFixtureMature
        /// ux-redesign-r1 T2 — banner "Đã lưu … · Xem" mẫu (`ShellBanner`) trên Home, chưa cần luồng lưu thật.
        case saveBanner
        /// home-eevas-r1 T3 — màn "Từ hay quên" (FR-19), danh sách card leech.
        case leeches
        /// home-eevas-r1 T4 — màn "Tìm từ" (FR-08), tìm xuyên mọi collection.
        case search
        /// pdf-reader-r1 T3 (FR-23/ADR-058) — gắn PDF demo vào bộ đầu tiên rồi
        /// mở thẳng reader, để chụp màn không cần tay gắn file trên simulator.
        case pdfReader
        /// pdf-nav-r1 (FR-23/ADR-059) — như `pdfReader` nhưng mở sẵn sheet Mục
        /// lục, để chụp màn không cần chạm nút toolbar.
        case pdfReaderTOC
        /// pdf-nav-r1 — như `pdfReader` nhưng mở sẵn alert "Đi tới trang".
        case pdfReaderGoTo
        /// engagement-r1 T2 (FR-24) — mở màn Dữ liệu kèm sheet "Gộp từ trùng"; dùng với
        /// `-ReadoSeed demo-dups` để kho có nhóm trùng mà chụp.
        case duplicateMerge
        /// engagement-r1 — mở phiên ôn với MẶT SAU của thẻ đầu đã lật sẵn (simctl không chạm được để lật), dùng
        /// với `-ReadoSeed demo-streak` để thấy dòng "Gặp lần đầu N ngày trước".
        case reviewBack
        /// engagement-r1 T5 — màn "Xong phiên nhanh" với tally mẫu (không cần chấm 3 thẻ bằng tay).
        case quickDone
    }

    public enum Seed: String, Equatable, Sendable {
        case demo
        case demoReviewed = "demo-reviewed"
        /// engagement-r1 T2 — demo + vài dòng trùng `term+pos` ở bộ khác (`DevSeed.addDuplicates`).
        case demoDups = "demo-dups"
        /// engagement-r1 — demo + lịch sử ôn vài ngày liền KHÔNG có hôm nay (streak > 0, còn thẻ đến hạn) và từ lưu
        /// cách đây 40 ngày: để chụp dòng "Tuần này ôn N/7 ngày" ở hero và "Gặp lần đầu N ngày trước" ở mặt sau thẻ.
        case demoStreak = "demo-streak"
        case empty
    }

    public enum Alert: String, Equatable, Sendable {
        case dupName = "dup-name"
        case pinLimit = "pin-limit"
    }

    private static let screenKey = "-ReadoScreen"
    private static let themeKey = "-ReadoTheme"
    private static let seedKey = "-ReadoSeed"
    private static let alertKey = "-ReadoAlert"

    /// Đọc `ProcessInfo.processInfo.arguments` — chuỗi nào không phải 4 key
    /// trên (kể cả `arguments[0]` là đường dẫn binary, hay cờ hệ thống như
    /// `-AppleLanguages`) bị bỏ qua từng phần tử một, không bị hiểu nhầm thành
    /// value của key trước. Key lặp lại → giá trị CUỐI thắng.
    public static func parse(_ arguments: [String]) -> DebugLaunch {
        var result = DebugLaunch()
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard Self.isKnownKey(key) else {
                index += 1
                continue
            }
            let valueIndex = index + 1
            guard valueIndex < arguments.count else {
                result.problems.append("\(key) thiếu value")
                break
            }
            let value = arguments[valueIndex]
            apply(key: key, value: value, into: &result)
            index = valueIndex + 1
        }
        return result
    }

    private static func isKnownKey(_ key: String) -> Bool {
        key == screenKey || key == themeKey || key == seedKey || key == alertKey
    }

    private static func apply(key: String, value: String, into result: inout DebugLaunch) {
        switch key {
        case screenKey:
            if let screen = parseScreen(value) {
                result.screen = screen
            } else {
                result.problems.append("\(screenKey) lạ: \(value)")
            }
        case themeKey:
            result.theme = value
        case seedKey:
            if let seed = Seed(rawValue: value) {
                result.seed = seed
            } else {
                result.problems.append("\(seedKey) lạ: \(value)")
            }
        case alertKey:
            if let alert = Alert(rawValue: value) {
                result.alert = alert
            } else {
                result.problems.append("\(alertKey) lạ: \(value)")
            }
        default:
            break
        }
    }

    private static func parseScreen(_ value: String) -> Screen? {
        if value.hasPrefix("collection:") {
            let id = String(value.dropFirst("collection:".count))
            return id.isEmpty ? nil : .collection(id)
        }
        switch value {
        case "home": return .home
        case "kho", "library": return .library
        case "review": return .review
        case "review-extra": return .reviewExtra
        case "settings": return .settings
        case "streak": return .streak
        case "data": return .data
        case "capture": return .capture
        case "analysis-fixture": return .analysisFixture
        case "analysis-fixture-page": return .analysisFixturePage
        case "encounter-sheet": return .encounterSheet
        case "phrase-highlight": return .phraseHighlight
        case "analysis-fixture-mature": return .analysisFixtureMature
        case "save-banner": return .saveBanner
        case "leeches": return .leeches
        case "search": return .search
        case "pdf-reader": return .pdfReader
        case "pdf-reader-toc": return .pdfReaderTOC
        case "pdf-reader-goto": return .pdfReaderGoTo
        case "dup-merge": return .duplicateMerge
        case "review-back": return .reviewBack
        case "quick-done": return .quickDone
        default: return nil
        }
    }
}
