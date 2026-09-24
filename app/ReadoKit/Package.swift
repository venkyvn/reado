// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadoKit",
    platforms: [
        // iOS 17 cho @Observable + Observation (skill swiftui stack: "Observation APIs iOS 17+").
        // macOS 13 để chạy được `swift test` ngay trên máy (Command Line Tools) không cần Simulator.
        .iOS(.v17),
        .macOS(.v13),
    ],
    products: [
        .library(name: "ReadoKit", targets: ["ReadoKit"]),
    ],
    dependencies: [
        // Chốt (ROADMAP mục 1, AGENTS mục 3.2): swift-fsrs + FSRSDefaults.defaultWv6 (21 trọng số).
        // BẪY: tag release mới nhất (v5.0.0) KHÔNG có defaultWv6 — chỉ có 19 weights FSRS-5.
        // defaultWv6 hiện chỉ nằm trên nhánh main (chưa release) → pin đúng commit.
        .package(
            url: "https://github.com/open-spaced-repetition/swift-fsrs.git",
            revision: "4fbaf20184d62f82a9f44f343337c61a2c5483e9"
        ),
    ],
    targets: [
        // SQLite C API hệ thống — KHÔNG thêm dependency bên ngoài (AGENTS mục 3.6:
        // không thêm dependencies mới nếu không thực sự cần). libsqlite3 nằm sẵn
        // trong iOS/macOS SDK. shim.h + module.modulemap ở Sources/CSQLite/.
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/CSQLite",
            providers: [.apt(["libsqlite3-dev"]), .brew(["sqlite3"])]
        ),
        .target(
            name: "ReadoKit",
            dependencies: [
                "CSQLite",
                .product(name: "FSRS", package: "swift-fsrs"),
            ],
            linkerSettings: [
                .linkedFramework("Vision"),
                .linkedFramework("ImageIO"),
                .linkedFramework("CoreGraphics"),
            ]
        ),
        .testTarget(
            name: "ReadoKitTests",
            dependencies: ["ReadoKit"]
        ),
    ]
)