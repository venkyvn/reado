import ReadoKit
import XCTest

/// verify-nav-r1 — parse launch argument `-ReadoScreen`/`-ReadoTheme`/
/// `-ReadoSeed`/`-ReadoAlert`. Chạy bằng `scripts/test.sh kit`.
final class DebugLaunchTests: XCTestCase {

    func testNoArgumentsIsAllNil() {
        let launch = DebugLaunch.parse([])
        XCTAssertNil(launch.screen)
        XCTAssertNil(launch.theme)
        XCTAssertNil(launch.seed)
        XCTAssertNil(launch.alert)
        XCTAssertTrue(launch.problems.isEmpty)
    }

    func testEachScreenParses() {
        let cases: [(String, DebugLaunch.Screen)] = [
            ("home", .home),
            ("kho", .library),
            ("library", .library),
            ("review", .review),
            ("review-extra", .reviewExtra),
            ("settings", .settings),
            ("streak", .streak),
            ("data", .data),
            ("capture", .capture),
            ("analysis-fixture", .analysisFixture),
            ("analysis-fixture-page", .analysisFixturePage),
            ("encounter-sheet", .encounterSheet),
            ("phrase-highlight", .phraseHighlight),
            ("analysis-fixture-mature", .analysisFixtureMature),
            ("save-banner", .saveBanner),
            ("leeches", .leeches),
            ("search", .search),
            ("pdf-reader", .pdfReader),
        ]
        for (raw, expected) in cases {
            let launch = DebugLaunch.parse(["-ReadoScreen", raw])
            XCTAssertEqual(launch.screen, expected, "màn \(raw)")
            XCTAssertTrue(launch.problems.isEmpty, "màn \(raw)")
        }
    }

    func testCollectionScreenCarriesID() {
        let launch = DebugLaunch.parse(["-ReadoScreen", "collection:abc-123"])
        XCTAssertEqual(launch.screen, .collection("abc-123"))
        XCTAssertTrue(launch.problems.isEmpty)
    }

    func testCollectionScreenEmptyIDIsProblem() {
        let launch = DebugLaunch.parse(["-ReadoScreen", "collection:"])
        XCTAssertNil(launch.screen)
        XCTAssertEqual(launch.problems.count, 1)
    }

    func testUnknownScreenIsProblemNotCrash() {
        let launch = DebugLaunch.parse(["-ReadoScreen", "nonsense"])
        XCTAssertNil(launch.screen)
        XCTAssertEqual(launch.problems, ["-ReadoScreen lạ: nonsense"])
    }

    func testThemePassesThroughRaw() {
        let launch = DebugLaunch.parse(["-ReadoTheme", "forest"])
        XCTAssertEqual(launch.theme, "forest")
        XCTAssertTrue(launch.problems.isEmpty)
    }

    func testSeedAndAlertParse() {
        let launch = DebugLaunch.parse(["-ReadoSeed", "demo-reviewed", "-ReadoAlert", "pin-limit"])
        XCTAssertEqual(launch.seed, .demoReviewed)
        XCTAssertEqual(launch.alert, .pinLimit)
        XCTAssertTrue(launch.problems.isEmpty)
    }

    func testUnknownSeedAndAlertAreProblems() {
        let launch = DebugLaunch.parse(["-ReadoSeed", "nope", "-ReadoAlert", "nope"])
        XCTAssertNil(launch.seed)
        XCTAssertNil(launch.alert)
        XCTAssertEqual(launch.problems.count, 2)
    }

    func testRepeatedKeyLastValueWins() {
        let launch = DebugLaunch.parse(["-ReadoScreen", "home", "-ReadoScreen", "kho"])
        XCTAssertEqual(launch.screen, .library)
    }

    func testMissingValueIsProblemNotCrash() {
        let launch = DebugLaunch.parse(["-ReadoScreen"])
        XCTAssertNil(launch.screen)
        XCTAssertEqual(launch.problems, ["-ReadoScreen thiếu value"])
    }

    func testSystemArgumentsAreIgnored() {
        let launch = DebugLaunch.parse([
            "/path/to/Reado.app/Reado",
            "-NSDoubleLocalizedStrings", "YES",
            "-ReadoScreen", "home",
            "-AppleLanguages", "(en)",
        ])
        XCTAssertEqual(launch.screen, .home)
        XCTAssertTrue(launch.problems.isEmpty)
    }

    func testMixedValidAndUnknownKeysOnlyUnknownValuesAreProblems() {
        let launch = DebugLaunch.parse([
            "-ReadoScreen", "review",
            "-ReadoTheme", "sepia",
            "-ReadoSeed", "empty",
        ])
        XCTAssertEqual(launch.screen, .review)
        XCTAssertEqual(launch.theme, "sepia")
        XCTAssertEqual(launch.seed, .empty)
        XCTAssertTrue(launch.problems.isEmpty)
    }
}
