import Foundation

/// apple-ai-r1 T3 (ADR-063) — seam cho test; live là `FoundationModelsOCRCorrector`.
public protocol OCRCorrector: Sendable {
    func proposeFixes(for text: String) async throws -> [OCRFix]
}
