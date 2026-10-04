import PDFKit

/// FR-23/ADR-059 (pdf-nav-r1) — logic thuần cho điều hướng trang trong PDF
/// reader (slider/◀▶/gõ số trang/Mục lục). Không giữ state — view gọi vào
/// đây, tự lưu kết quả.
public enum PDFNavigation {
    /// Kẹp `index` vào `0...pageCount-1`. `pageCount <= 0` → 0.
    public static func clamp(_ index: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(index, 0), pageCount - 1)
    }

    /// Người dùng gõ số trang 1-based (ví dụ "42" → trang index 41). Trim
    /// khoảng trắng. Rỗng / không phải số nguyên / ngoài `1...pageCount` → nil
    /// (không nhảy, không kẹp — gõ sai phải báo lỗi, không tự "sửa giùm").
    public static func pageIndex(fromInput text: String, pageCount: Int) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 1, value <= pageCount else { return nil }
        return value - 1
    }

    public struct OutlineEntry: Equatable, Sendable, Identifiable {
        public let id: Int
        public let label: String
        public let depth: Int
        public let pageIndex: Int?

        public init(id: Int, label: String, depth: Int, pageIndex: Int?) {
            self.id = id
            self.label = label
            self.depth = depth
            self.pageIndex = pageIndex
        }
    }

    /// Duyệt sâu theo thứ tự tài liệu, bỏ `outlineRoot` khỏi kết quả. Không có
    /// outline → `[]`. Mục nhãn rỗng (sau trim) bị bỏ khỏi danh sách nhưng
    /// con của nó vẫn được duyệt, lên cùng `depth` với mục rỗng (không lồng
    /// thêm một cấp cho một mục không hiện ra).
    public static func outlineEntries(in document: PDFDocument) -> [OutlineEntry] {
        guard let root = document.outlineRoot else { return [] }
        var entries: [OutlineEntry] = []
        var nextID = 0

        func visit(_ outline: PDFOutline, depth: Int) {
            for i in 0 ..< outline.numberOfChildren {
                guard let child = outline.child(at: i) else { continue }
                let label = (child.label ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if label.isEmpty {
                    visit(child, depth: depth)
                    continue
                }
                let page = destinationPageIndex(for: child, in: document)
                entries.append(OutlineEntry(id: nextID, label: label, depth: depth, pageIndex: page))
                nextID += 1
                visit(child, depth: depth + 1)
            }
        }
        visit(root, depth: 0)
        return entries
    }

    /// PDF xuất từ EPUB hay gắn đích tới trang qua `/A GoTo` (action) thay vì
    /// `/Dest` (destination) — thử destination trước, action sau.
    private static func destinationPageIndex(
        for outline: PDFOutline, in document: PDFDocument
    ) -> Int? {
        if let page = outline.destination?.page {
            return document.index(for: page)
        }
        if let action = outline.action as? PDFActionGoTo, let page = action.destination.page {
            return document.index(for: page)
        }
        return nil
    }

    /// Mục "đang đọc": mục có `pageIndex` lớn nhất `<= pageIndex` hiện tại;
    /// hoà nhau thì lấy mục đứng SAU trong danh sách (cụ thể hơn — ví dụ mục
    /// con vừa mở ra ở cùng trang với mục cha). Trang hiện tại đứng trước mục
    /// đầu tiên có trang → nil.
    public static func currentEntryID(in entries: [OutlineEntry], pageIndex: Int) -> Int? {
        var bestID: Int?
        var bestPage = -1
        for entry in entries {
            guard let entryPage = entry.pageIndex, entryPage <= pageIndex else { continue }
            if entryPage >= bestPage {
                bestPage = entryPage
                bestID = entry.id
            }
        }
        return bestID
    }
}
