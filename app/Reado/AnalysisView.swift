import SwiftUI
import ReadoKit

/// FR-02 — màn hình kết quả phân tích + retry khi lỗi. Walking skeleton chạy
/// mock analyzer (proxy 0.7 chưa deploy) để proof flow UI. Segments/summary chỉ
/// hiển thị (FR-05/06), vocabulary là phần được lưu (FR-02).
struct AnalysisView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var saveAlert: SaveAlert?

    private enum SaveAlert: Identifiable {
        case success(Int)
        case failure(String)

        var id: String {
            switch self {
            case let .success(count): "ok-\(count)"
            case .failure: "fail"
            }
        }
    }

    var body: some View {
        Group {
            if let error = model.analysisError {
                // FR-02: hiển thị lỗi + cho retry — không lưu bản ghi hỏng.
                ContentUnavailableView {
                    Label("Không phân tích được trang", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Thử lại") {
                        Task { await model.analyzeCurrentImage() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if model.isAnalyzing {
                // FR-02: progress rõ — màn hình không đứng im.
                ProgressView("Đang phân tích trang sách...")
                    .padding()
                    .frame(maxWidth: .infinity)
            } else if let result = model.analysisResult {
                resultList(result)
            } else {
                ContentUnavailableView(
                    "Chưa có trang để phân tích",
                    systemImage: "photo.on.rectangle.angled")
            }
        }
        .navigationTitle("Phân tích trang")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.analysisResult != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lưu") { save() }
                        .disabled(model.analysisResult?.vocabulary.isEmpty ?? true)
                }
            }
        }
        .alert(item: $saveAlert) { alert in
            switch alert {
            case let .success(count):
                return Alert(
                    title: Text("Đã lưu"),
                    message: Text("\(count) từ đã vào kho từ vựng."),
                    dismissButton: .default(Text("OK")) { dismiss() })
            case let .failure(message):
                return Alert(
                    title: Text("Không lưu được"),
                    message: Text(message),
                    dismissButton: .default(Text("OK")))
            }
        }
    }

    private func save() {
        do {
            let saved = try model.saveAnalysis(collectionID: nil)
            saveAlert = .success(saved)
        } catch {
            saveAlert = .failure(error.localizedDescription)
        }
    }

    private func resultList(_ result: PageAnalysis) -> some View {
        List {
            // FR-05 (ADR-007): song ngữ xen kẽ theo đoạn — chỉ hiển thị, không lưu.
            if !result.segments.isEmpty {
                Section("Song ngữ Anh – Việt") {
                    ForEach(Array(result.segments.enumerated()), id: \.offset) { _, seg in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(seg.sourceEN)
                                .font(.callout)
                            Text(seg.translationVI)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // FR-02: vocabulary — nhóm duy nhất được lưu.
            if !result.vocabulary.isEmpty {
                Section("Từ vựng (\(result.vocabulary.count))") {
                    ForEach(Array(result.vocabulary.enumerated()), id: \.offset) { _, item in
                        vocabularyRow(item)
                    }
                }
            }

            if !result.summaryVI.isEmpty {
                Section("Ý chính") {
                    Text(result.summaryVI)
                }
            }
        }
    }

    private func vocabularyRow(_ item: PageAnalysis.VocabularyItemIn) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.term)
                    .font(.headline)
                if let ipa = item.ipa, !ipa.isEmpty {
                    Text(ipa)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text("\(item.pos) · \(item.meaningVI)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(item.example)
                    .font(.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            // FR-02: trạng thái xác minh hiện rõ — unverified không bị giấu.
            verificationBadge(item.verification)
        }
        .padding(.vertical, 2)
    }

    private func verificationBadge(_ status: PageAnalysis.VerificationStatus) -> some View {
        Group {
            switch status {
            case .verified:
                Label("Đã kiểm", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .suspect:
                Label("Cần xem", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            case .unverified:
                Label("Chưa xác minh", systemImage: "questionmark.circle")
                    .foregroundStyle(.red)
            }
        }
        .font(.caption2)
    }
}