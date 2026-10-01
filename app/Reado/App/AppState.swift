import Foundation
import ReadoKit

// Chia state của `AppModel` theo chức năng (refactor-r3 #3). `AppModel` còn giữ
// kết nối DB, overview Home/Kho, cài đặt và các hàm tải/lưu; mỗi nhóm state dưới
// đây là một `@Observable` riêng — view đọc `model.review.items`,
// `model.capture.analysisResult`… và chỉ vẽ lại khi ĐÚNG nhóm đó đổi, thay vì mọi
// thay đổi trên một đối tượng ~40 thuộc tính.

/// Hàng đợi ôn (FR-11/12/18, Ôn thêm extra-review-r1 — đảo ADR-011/043).
@MainActor
@Observable
final class ReviewState {
    var isLoading = false
    var error: String?
    var items: [ReviewQueue.ReviewItem] = []
    var snapshots: [String: CardSnapshot] = [:]
    var currentSnapshot: CardSnapshot?
    /// Lịch 4 nút của thẻ đang hiện — `grade` dùng lại để nhãn == lịch ghi
    /// (T2 fsrs-queue-fix-r1). Chỉ cache nội bộ, UI không quan sát.
    @ObservationIgnored var gradePreview: GradePreview?

    // FR-18: phạm vi ôn hiện tại (nil = tất cả collection) + nợ due ngoài phạm
    // vi (phải nhìn thấy — research/vocabulary.md 4.2).
    var scope: Set<String>? = nil
    var dueOutsideScope = 0
    /// Số thẻ Ôn thêm lấy được trong phạm vi hiện tại (mới + ôn sớm, không bị
    /// `extraBatchSize` của MỘT lượt) — quyết định CTA "Ôn thêm N thẻ".
    var extraAvailableCount = 0
}

/// Chụp (FR-01) + phân tích (FR-02/04) một trang — vòng đời từ ảnh tới kết quả.
@MainActor
@Observable
final class CaptureFlow {
    // FR-01: capture state
    var lastCapturedImage: CapturedImage?
    var captureError: String?

    // FR-02: analysis state
    var isAnalyzing = false
    var analysisResult: PageAnalysis?
    /// FR-04: giữ nguyên loại lỗi để UI chọn CTA đúng (chụp lại vs thử lại).
    var analysisFailure: AnalysisError?
    /// Chuỗi hiển thị cho lỗi phân tích — chỉ để UI đọc, không lưu.
    var analysisError: String? { analysisFailure?.errorDescription }
    /// Tiến độ agent đang gọi (đọc trang/chờ/suy nghĩ/viết) — chỉ `openai_compat`
    /// (stream) phát ra; AnalysisView đổi dòng chữ theo đây thay vì đứng im.
    var analysisProgress: AnalysisProgress?

    // FR-04: yêu cầu mở lại CaptureView sau khi dọn state (ảnh mờ / sai ngôn ngữ).
    var pendingRecapture = false

    // J2: đích collection chọn sẵn cho lần capture từ Collection Hub (nil = kho
    // tạm). AnalysisView đọc làm collection ban đầu rồi dọn sạch sau khi lưu.
    var analysisTargetCollectionID: String?
}

/// Kết quả một lần Lưu thành công — `AnalysisView` đóng rồi `RootView` đọc để hiện banner
/// "Đã lưu N từ vào X · Xem" (ADR-053; thay alert chặn + ép đổi tab).
struct SaveConfirmation: Equatable {
    let count: Int
    /// Bộ đã lưu vào (kho tạm cũng có id) — nút "Xem" đẩy Hub này.
    let collectionID: String
    let collectionName: String
}

/// Tín hiệu điều hướng/chrome giữa các màn (RootView tiêu thụ rồi dọn sạch).
@MainActor
@Observable
final class ShellSignals {
    /// FR-21: lỗi agent (BYOK 401/timeout/...) → nút "Mở Cài đặt" bật cờ này;
    /// RootView tiêu thụ ở onDismiss của sheet phân tích rồi dọn sạch.
    var pendingSettingsNavigation = false

    /// ux-redesign-r1 T5a: sau Lưu → RootView hiện banner, KHÔNG đổi tab/push Hub (thay
    /// cơ chế push Hub của port UI lab §5.7). Set ở `saveSelection` thành công, dọn ở
    /// `handleCapturedImage` (lần chụp kế tiếp) + sau khi RootView tiêu thụ.
    var saveConfirmation: SaveConfirmation?

    /// port UI lab §6: Hub (CollectionDetailView) đang mở set id này để nút chụp trong thanh tab
    /// prefill đích chụp; rời Hub → nil (chụp từ root Hôm nay/Thư viện = kho tạm).
    var shutterTargetCollectionID: String?

    /// Phiên đọc đang mở (push trong Hub, không vào ShellRoute) → ẩn nút chụp trong thanh tab
    /// (port UI lab §10). ReadingSessionView bật/tắt ở onAppear/onDisappear.
    var suppressFloatShutter = false

    #if DEBUG
    /// verify-nav-r1 T2 — `-ReadoScreen encounter-sheet` bật cờ này; AnalysisView
    /// đọc ở `.task` để tự mở `EncounterSheet` của match đầu tiên (demo gạch chân
    /// chấm) rồi dọn sạch, giống các cờ `pending*` khác ở trên.
    var debugOpenFirstEncounter = false
    /// ux-redesign-r1 T5b — `-ReadoScreen analysis-fixture-page` bật cờ này; AnalysisView đọc ở
    /// `onAppear` để mở thẳng tab "Trang" rồi dọn sạch.
    var debugShowAnalysisPage = false
    #endif
}

/// Dữ liệu của collection đang xem ở Hub (một Hub mở một lúc nên một bộ biến là đủ).
@MainActor
@Observable
final class LibraryState {
    /// FR-08/FR-17: danh sách từ.
    var vocabulary: [VocabRepository.VocabularyListEntry] = []
    /// FR-05/06: các phiên đọc song ngữ (J2 hub).
    var sessions: [ReadingSession] = []
    /// Lần ôn kế tiếp (header, cram-collection-r1).
    var collectionNextDue: VocabRepository.NextDue?
}
