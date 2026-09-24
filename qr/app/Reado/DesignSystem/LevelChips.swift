import SwiftUI

struct LevelChips: View {
    var selected: [String]
    var onToggle: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CefrLevel.allCases) { level in
                Chip(title: level.rawValue, on: selected.contains(level.rawValue)) {
                    onToggle(level.rawValue)
                }
            }
        }
    }
}
