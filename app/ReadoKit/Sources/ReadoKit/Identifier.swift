import Foundation

/// uuid TEXT chữ thường có gạch nối — client sinh lúc insert (db.md A.1).
/// Không BLOB, không 32-hex — FR-16 export phải đọc được bằng mắt.
public enum Identifier {
    public static func uuid() -> String {
        UUID().uuidString.lowercased()
    }
}