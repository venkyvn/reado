import Foundation

struct VocabCsvRow: Equatable {
    var term: String
    var pos: String
    var ipa: String
    var meaningVi: String
    var cefr: String
    var example: String
    var collection: String
}

enum VocabCSV {
    static let headers = ["term", "pos", "ipa", "meaning_vi", "cefr", "example", "collection"]

    static func serialize(_ rows: [VocabCsvRow]) -> String {
        let lines = [headers.joined(separator: ",")] + rows.map { row in
            [
                row.term, row.pos, row.ipa, row.meaningVi, row.cefr, row.example, row.collection,
            ].map(escape).joined(separator: ",")
        }
        return "\u{FEFF}" + lines.joined(separator: "\n")
    }

    static func parse(_ text: String) -> Result<[VocabCsvRow], AppError> {
        let table = split(text)
        guard let headerRow = table.first else {
            return .failure(.csv("File trống hoặc không đọc được header."))
        }
        let header = headerRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let missing = headers.filter { !header.contains($0) }
        if !missing.isEmpty {
            return .failure(.csv("Header sai — thiếu cột \(missing.joined(separator: ", ")). Cần: \(headers.joined(separator: ", "))."))
        }
        func index(_ name: String) -> Int { header.firstIndex(of: name) ?? -1 }
        var rows: [VocabCsvRow] = []
        for cells in table.dropFirst() {
            if cells.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) { continue }
            rows.append(VocabCsvRow(
                term: at(cells, index("term")),
                pos: at(cells, index("pos")),
                ipa: at(cells, index("ipa")),
                meaningVi: at(cells, index("meaning_vi")),
                cefr: at(cells, index("cefr")),
                example: at(cells, index("example")),
                collection: at(cells, index("collection"))
            ))
        }
        return .success(rows)
    }

    private static func at(_ cells: [String], _ i: Int) -> String {
        guard i >= 0, i < cells.count else { return "" }
        return cells[i].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(where: { $0 == "\"" || $0 == "," || $0 == "\n" || $0 == "\r" }) {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func split(_ text: String) -> [[String]] {
        var src = text
        if src.hasPrefix("\u{FEFF}") { src.removeFirst() }
        src = src.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var i = src.startIndex
        while i < src.endIndex {
            let c = src[i]
            if quoted {
                if c == "\"" {
                    let next = src.index(after: i)
                    if next < src.endIndex, src[next] == "\"" {
                        field.append("\"")
                        i = next
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(c)
                }
            } else if c == "\"" {
                quoted = true
            } else if c == "," {
                row.append(field)
                field = ""
            } else if c == "\n" {
                row.append(field)
                field = ""
                rows.append(row)
                row = []
            } else {
                field.append(c)
            }
            i = src.index(after: i)
        }
        row.append(field)
        if row.count > 1 || row[0] != "" || src.hasSuffix(",") {
            rows.append(row)
        } else if rows.isEmpty && !field.isEmpty {
            rows.append(row)
        }
        while let last = rows.last, last.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rows.removeLast()
        }
        return rows
    }
}
