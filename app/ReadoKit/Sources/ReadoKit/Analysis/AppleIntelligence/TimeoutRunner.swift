import Foundation

/// apple-ai-r1 T3 — timeout cho một `async throws` closure bất kỳ. KHÔNG dùng
/// `withThrowingTaskGroup` (group chờ MỌI task con xong — nếu model lờ cancel
/// thì timeout vô nghĩa). Continuation + "resume đúng một lần" qua actor.
///
/// ocr-quality-r1 T7 (ADR-065) — tách khỏi `CorrectingTextRecognizer.swift`
/// (đã xoá cùng toàn bộ nhánh sửa OCR bằng LLM): `TimeoutRunner` dùng chung,
/// `AppleIntelligenceAnalyzer` vẫn cần nó để giới hạn thời gian gọi model AI.
public struct TimeoutError: Error, Equatable, Sendable {
    public init() {}
}

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
