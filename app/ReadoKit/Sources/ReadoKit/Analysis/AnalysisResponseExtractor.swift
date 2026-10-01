import Foundation

/// Bóc JSON phân tích ra khỏi phản hồi của provider OpenAI-compatible. Tách từ
/// `OpenAICompatClient` (refactor-r2): hàm thuần, không I/O — logic giữ nguyên.
enum AnalysisResponseExtractor {
    /// Đường cũ (không-stream): toàn bộ envelope OpenAI Chat Completions trong
    /// một `Data`. Dùng khi server lờ `stream: true`.
    static func messageContent(from data: Data) throws -> String {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let choice = choices.first
        else {
            throw AnalysisError.schemaViolation("thiếu choices[0]")
        }
        if let message = choice["message"] as? [String: Any] {
            if let text = message["content"] as? String, !text.isEmpty {
                return try extractAnalysisJSON(from: text)
            }
            if let parts = message["content"] as? [[String: Any]] {
                let text = parts.compactMap { $0["text"] as? String }.joined()
                if !text.isEmpty { return try extractAnalysisJSON(from: text) }
            }
            if let content = message["content"],
               JSONSerialization.isValidJSONObject(content)
            {
                let bytes = try JSONSerialization.data(withJSONObject: content)
                return try extractAnalysisJSON(from: String(decoding: bytes, as: UTF8.self))
            }
        }
        if let text = choice["text"] as? String, !text.isEmpty {
            return try extractAnalysisJSON(from: text)
        }
        throw AnalysisError.schemaViolation("message.content rỗng")
    }

    /// OpenAI-compatible providers do not agree on structured output: some ignore
    /// `response_format`, wrap JSON in Markdown, or prepend a `<think>` block.
    /// Accept those transport wrappers while still requiring Reado's root shape.
    static func extractAnalysisJSON(from raw: String) throws -> String {
        let text = removingThinkBlocks(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = text.data(using: .utf8),
           isAnalysisObject(data)
        {
            return text
        }

        for candidate in objectCandidates(in: text) {
            guard let data = candidate.data(using: .utf8) else { continue }
            if isAnalysisObject(data) {
                return candidate
            }
        }
        throw AnalysisError.schemaViolation(
            "message.content không chứa JSON object có segments/vocabulary")
    }

    private static func removingThinkBlocks(from raw: String) -> String {
        raw.replacingOccurrences(
            of: #"<think\b[^>]*>[\s\S]*?</think>"#,
            with: "",
            options: [.regularExpression, .caseInsensitive])
    }

    private static func isAnalysisObject(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any]
        else { return false }
        return root["segments"] != nil || root["vocabulary"] != nil
    }

    /// Return balanced `{...}` candidates, respecting braces and escapes inside strings.
    private static func objectCandidates(in text: String) -> [String] {
        let characters = Array(text)
        var candidates: [String] = []
        for start in characters.indices where characters[start] == "{" {
            var depth = 0
            var inString = false
            var escaped = false
            for index in start..<characters.endIndex {
                let character = characters[index]
                if inString {
                    if escaped {
                        escaped = false
                    } else if character == "\\" {
                        escaped = true
                    } else if character == "\"" {
                        inString = false
                    }
                    continue
                }
                if character == "\"" {
                    inString = true
                } else if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 {
                        candidates.append(String(characters[start...index]))
                        break
                    }
                }
            }
        }
        return candidates
    }
}
