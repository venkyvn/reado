import Foundation

/// Decode + validate response JSON theo output schema (prompt-spec #4).
/// FR-02: "AI trả về dữ liệu không đúng schema → hiển thị lỗi + cho retry, KHÔNG lưu
/// bản ghi hỏng". Decoder này thi hành ràng buộc đó.
public enum AnalysisResponseDecoder {

    /// Decode data → PageAnalysis. Throws AnalysisError cho mọi loại sai schema.
    public static func decode(_ data: Data) throws -> PageAnalysis {
        let raw: RawResponse
        do {
            raw = try JSONDecoder().decode(RawResponse.self, from: data)
        } catch {
            throw AnalysisError.schemaViolation("JSON parse failed: \(error.localizedDescription)")
        }

        // Validate segments
        let segments = try raw.segments.map { seg in
            guard !seg.source_en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !seg.translation_vi.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw AnalysisError.schemaViolation("segment source_en/translation_vi empty")
            }
            return PageAnalysis.Segment(
                sourceEN: seg.source_en,
                translationVI: seg.translation_vi)
        }

        // Validate vocabulary
        let validPOS: Set<String> = ["noun", "verb", "adj", "adv", "phrase", "other"]
        let validCEFR: Set<String> = ["A2", "B1", "B2", "C1"]

        let vocabulary = try raw.vocabulary.map { item in
            let term = item.term.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !term.isEmpty else {
                throw AnalysisError.schemaViolation("vocabulary term empty")
            }
            let pos = item.pos.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard validPOS.contains(pos) else {
                throw AnalysisError.schemaViolation("vocabulary pos '\(pos)' not in enum")
            }
            let meaningVi = item.meaning_vi.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !meaningVi.isEmpty else {
                throw AnalysisError.schemaViolation("vocabulary meaning_vi empty")
            }
            let example = item.example.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !example.isEmpty else {
                throw AnalysisError.schemaViolation("vocabulary example empty")
            }
            let cefr: String?
            if let rawCefr = item.cefr {
                let normalized = rawCefr.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                guard validCEFR.contains(normalized) else {
                    throw AnalysisError.schemaViolation("vocabulary cefr '\(rawCefr)' not in [A2,B1,B2,C1]")
                }
                cefr = normalized
            } else {
                cefr = nil
            }
            // Proxy có thể gửi kèm `verification` (SD 4.1). Nếu thiếu (BYOK,
            // openai_compat) → VerifyEngine cục bộ (SD 7.3). KHÔNG verify hai lần.
            let verification: PageAnalysis.VerificationStatus
            if let rawStatus = item.verification,
               let parsed = PageAnalysis.VerificationStatus(rawValue: rawStatus) {
                verification = parsed
            } else {
                let pageFromSegments = raw.segments.map(\.source_en).joined(separator: " ")
                verification = VerifyEngine.verify(
                    term: term,
                    example: example,
                    pageText: pageFromSegments)
            }
            return PageAnalysis.VocabularyItemIn(
                term: term,
                pos: pos,
                ipa: item.ipa,
                meaningVI: meaningVi,
                cefr: cefr,
                example: example,
                verification: verification)
        }

        return PageAnalysis(
            segments: segments,
            vocabulary: vocabulary,
            summaryVI: raw.summary_vi ?? "",
            meta: .init(imageHash: "", model: "", promptVersion: Prompt.version))
    }

    // MARK: - Raw JSON shapes (theo prompt-spec #4)

    /// Envelope lỗi proxy nằm ở ReadoProxyClient (SD 4.1) — chỗ này chỉ parse
    /// thành công. `verification` optional: proxy gửi kèm thì giữ nguyên,
    /// thiếu thì VerifyEngine cục bộ (SD 7.3, không verify hai lần).
    struct RawResponse: Decodable {
        let segments: [RawSegment]
        let vocabulary: [RawVocabulary]
        let summary_vi: String?
    }

    struct RawSegment: Decodable {
        let source_en: String
        let translation_vi: String
    }

    struct RawVocabulary: Decodable {
        let term: String
        let pos: String
        let ipa: String?
        let meaning_vi: String
        let cefr: String?
        let example: String
        let verification: String?
    }
}
