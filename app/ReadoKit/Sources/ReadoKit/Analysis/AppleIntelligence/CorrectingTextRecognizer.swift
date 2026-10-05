import Foundation

/// apple-ai-r1 T3 (ADR-061) — bọc OCR gốc, soát bằng Apple Intelligence. KHÔNG
/// BAO GIỜ ném lỗi mới: corrector lỗi/timeout/text rỗng → trả nguyên kết quả
/// OCR gốc, lỗi gốc của `base` (ảnh đọc không được) vẫn ném như cũ.
public struct CorrectingTextRecognizer: PageTextRecognizer {
    private let base: PageTextRecognizer
    private let corrector: OCRCorrector
    private let timeout: Duration

    public init(base: PageTextRecognizer, corrector: OCRCorrector, timeout: Duration = .seconds(8)) {
        self.base = base
        self.corrector = corrector
        self.timeout = timeout
    }

    public func recognize(imageData: Data) async throws -> String {
        try await recognizeDetailed(imageData: imageData).text
    }

    public func recognizeDetailed(imageData: Data) async throws -> PageOCR.OCRResult {
        let raw = try await base.recognizeDetailed(imageData: imageData)
        guard !raw.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return raw }

        let clock = ContinuousClock()
        let start = clock.now
        do {
            let fixes = try await TimeoutRunner.run(timeout) {
                try await corrector.proposeFixes(for: raw.text)
            }
            let outcome = OCRFixApplier.apply(fixes, to: raw.text)
            return raw.corrected(
                text: outcome.text,
                fixes: outcome.applied,
                rejectedCount: outcome.rejected.count,
                ms: Self.milliseconds(since: start, clock: clock))
        } catch {
            return raw.corrected(
                text: raw.text,
                fixes: [],
                rejectedCount: 0,
                ms: Self.milliseconds(since: start, clock: clock),
                error: String(describing: error))
        }
    }

    private static func milliseconds(since start: ContinuousClock.Instant, clock: ContinuousClock) -> Int {
        let components = (clock.now - start).components
        return Int(components.seconds * 1000 + components.attoseconds / 1_000_000_000_000_000)
    }
}

/// apple-ai-r1 T3 — timeout cho một `async throws` closure bất kỳ. KHÔNG dùng
/// `withThrowingTaskGroup` (group chờ MỌI task con xong — nếu model lờ cancel
/// thì timeout vô nghĩa). Continuation + "resume đúng một lần" qua actor.
public struct TimeoutError: Error, Equatable, Sendable {}

public enum TimeoutRunner {
    public static func run<T: Sendable>(
        _ limit: Duration, _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            let once = ResumeOnce(continuation)
            let work = Task {
                do {
                    let value = try await operation()
                    await once.resume(.success(value))
                } catch {
                    await once.resume(.failure(error))
                }
            }
            Task {
                try? await Task.sleep(for: limit)
                work.cancel()
                await once.resume(.failure(TimeoutError()))
            }
        }
    }

    /// Đảm bảo continuation chỉ resume một lần dù hai Task trên đụng nhau —
    /// actor isolation thay cho lock tay.
    private actor ResumeOnce<T: Sendable> {
        private var continuation: CheckedContinuation<T, Error>?

        init(_ continuation: CheckedContinuation<T, Error>) {
            self.continuation = continuation
        }

        func resume(_ result: Result<T, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            continuation.resume(with: result)
        }
    }
}
