import Foundation
import FSRS

enum FSRSEngine {
    static func make(settings: SettingsRecord) -> FSRS {
        let weights: [Double]
        if let raw = settings.fsrsParams,
           let data = raw.data(using: .utf8),
           let parsed = try? JSONDecoder().decode([Double].self, from: data),
           parsed.count == 21 {
            weights = parsed
        } else {
            weights = FSRSDefaults.defaultWv6
        }
        return FSRS(parameters: FSRSParameters(
            requestRetention: settings.requestRetention,
            maximumInterval: Double(settings.maximumInterval),
            w: weights,
            enableFuzz: settings.enableFuzz,
            enableShortTerm: settings.enableShortTerm,
            learningSteps: [],
            relearningSteps: []
        ))
    }

    static func toFSRS(_ row: CardRecord) -> Card {
        Card(
            due: ISO8601UTC.date(from: row.dueAt) ?? Date(),
            stability: row.stability,
            difficulty: row.difficulty,
            elapsedDays: 0,
            scheduledDays: Double(row.scheduledDays),
            learningSteps: row.learningSteps,
            reps: row.reps,
            lapses: row.lapses,
            state: cardState(row.state),
            lastReview: row.lastReviewAt.flatMap(ISO8601UTC.date(from:))
        )
    }

    static func apply(_ card: Card, onto row: CardRecord) -> CardRecord {
        var next = row
        next.state = card.state.stringValue
        next.stability = card.stability
        next.difficulty = card.difficulty
        next.reps = card.reps
        next.lapses = card.lapses
        next.learningSteps = card.learningSteps
        next.scheduledDays = Int(card.scheduledDays.rounded())
        next.dueAt = ISO8601UTC.string(from: card.due)
        next.lastReviewAt = card.lastReview.map(ISO8601UTC.string(from:))
        return next
    }

    static func rating(_ value: Int) -> Rating {
        Rating(rawValue: value) ?? .good
    }

    private static func cardState(_ raw: String) -> CardState {
        switch raw {
        case "learning": return .learning
        case "review": return .review
        case "relearning": return .relearning
        default: return .new
        }
    }
}
