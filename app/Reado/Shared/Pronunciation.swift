import AVFoundation
import SwiftUI

/// ADR-040: đọc một từ bằng giọng on-device — không luyện nói, không chấm,
/// không ghi âm, không nội dung nghe. Chỉ giúp biết cách phát âm từ đã trích.
@MainActor
enum Pronunciation {
    private static let synthesizer = AVSpeechSynthesizer()

    static func speak(_ term: String) {
        guard !term.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        // .playback + .spokenAudio: vẫn nghe khi gạt im lặng — user chủ động bấm loa.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: term)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        synthesizer.speak(utterance)
    }
}

/// Nút loa dùng chung (thẻ ôn + card duyệt) — icon outline theo
/// visual-redesign-plan.md §1 (hành động phụ, không phải CTA chính).
struct SpeakButton: View {
    let term: String

    var body: some View {
        Button {
            Pronunciation.speak(term)
            Haptics.selection()
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(.title3)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel("Đọc từ \(term)")
    }
}
