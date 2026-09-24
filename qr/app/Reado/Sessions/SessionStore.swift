import Foundation

struct ReadingSession: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var collectionId: String
    var title: String
    var capturedAt: String
    var summaryVi: String
    var summarySnippet: String
    var segments: [AnalysisSegment]
    var vocabIds: [String]
}

final class SessionStore {
    private let url: URL
    private let limit = 10

    init(fileManager: FileManager = .default, url: URL? = nil) {
        if let url {
            self.url = url
            return
        }
        let folder = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Reado", isDirectory: true))
            ?? fileManager.temporaryDirectory
        try? fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        self.url = folder.appendingPathComponent("sessions.json")
    }

    func load() -> [ReadingSession] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([ReadingSession].self, from: data)) ?? []
    }

    func save(_ sessions: [ReadingSession]) {
        let clipped = Array(sessions.prefix(limit))
        guard let data = try? JSONEncoder().encode(clipped) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func prepend(_ session: ReadingSession) -> [ReadingSession] {
        var next = load().filter { $0.id != session.id }
        next.insert(session, at: 0)
        next = Array(next.prefix(limit))
        save(next)
        return next
    }
}
