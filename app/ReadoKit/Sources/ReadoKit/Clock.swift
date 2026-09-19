import Foundation

/// Đồng hồ inject được (tech-stack mục 10.3 "Injectable clock trên iOS").
/// Mọi timestamp app-side đều đi qua `Clock` — không gọi `Date()` trần trong logic,
/// để test FR-11/FR-14 (day cutoff, streak) lặp lại được.
public protocol Clock: Sendable {
    var now: Date { get }
}

public struct SystemClock: Clock {
    public init() {}
    public var now: Date { Date() }
}

/// Đồng hồ cố định cho test / preview.
public struct FixedClock: Clock {
    public let date: Date
    public init(_ date: Date) { self.date = date }
    public var now: Date { date }
}