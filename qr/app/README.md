# Reado iOS

SwiftUI app (iOS 18+). IA/copy theo prototype `web/`, persistence SQLite + `swift-fsrs` FSRS-6.

Analysis hiện **mock** (`MockAnalysisClient`) — chưa gọi proxy Gemini. Không dùng kết quả này làm bằng chứng A-02.

```bash
open Reado.xcodeproj
```

Scheme **Reado** → Simulator → Run.

```bash
xcodebuild -scheme Reado -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Nếu `xcodegen` có trên máy: `xcodegen generate` từ folder này (cùng `project.yml`).
