import ReadoKit
import SwiftUI

/// FR-15 — J-R1-S: núm học tập (CEFR, hạn mức thẻ mới, giờ chuyển ngày).
/// `request_retention` + núm FSRS còn lại chỉ-đọc (R1 không mở user — tránh
/// tự bắn chân). Quản lý shortcut (FR-17) và chọn agent (FR-21) là task sau.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var cefrLevel: CEFRLevel = .b2
    @State private var dailyNewLimit = 10
    @State private var dayCutoffHour = 4
    @State private var didLoad = false
    @State private var saveError: String?
    @State private var saved = false
    /// Nhóm FSRS chỉ-đọc — đọc qua ReadoFSRS để hiện mà không cho sửa.
    @State private var fsrs: SchedulingSettings?

    var body: some View {
        List {
            learningSection
            fsrsSection
            if let message = saveError {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Cài đặt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Lưu") { save() }
                    .disabled(!didLoad)
            }
        }
        .onAppear { load() }
        .onChange(of: cefrLevel) { saved = false }
        .onChange(of: dailyNewLimit) { saved = false }
        .onChange(of: dayCutoffHour) { saved = false }
    }

    // MARK: — Học tập (editable)

    private var learningSection: some View {
        Section {
            // CEFR — target cho lần phân tích trang KẾ TIẾP (FR-15).
            Picker("Trình độ", selection: $cefrLevel) {
                ForEach(CEFRLevel.allCases) { level in
                    Text(level.rawValue).tag(level)
                }
            }

            // Hạn mức thẻ mới/ngày (FR-11) — 0 hợp lệ (D-lim-0), trần 999.
            Stepper(value: $dailyNewLimit, in: 0...999) {
                HStack {
                    Text("Thẻ mới mỗi ngày")
                    Spacer()
                    Text("\(dailyNewLimit)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            // Giờ chuyển ngày (FR-11/14) — streak & hạn mức quy theo giờ này.
            Stepper(value: $dayCutoffHour, in: 0...23) {
                HStack {
                    Text("Giờ chuyển ngày")
                    Spacer()
                    Text(Self.hourLabel(dayCutoffHour))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Học tập")
        } footer: {
            if saved {
                Text("Đã lưu · có hiệu lực từ lần chụp / ôn kế tiếp.")
            }
        }
    }

    // MARK: — Thuật toán ôn tập (chỉ-đọc)

    private var fsrsSection: some View {
        Section {
            if let fsrs {
                LabeledContent(
                    "Mục tiêu nhớ",
                    value: Self.retentionLabel(fsrs.requestRetention))
                LabeledContent(
                    "Khoảng cách tối đa",
                    value: "\(Int(fsrs.maximumInterval)) ngày")
                LabeledContent(
                    "Tham số FSRS",
                    value: fsrs.fsrsVersion ?? "mặc định (fsrs-6)")
            }
        } header: {
            Text("Thuật toán ôn tập")
        } footer: {
            Text("R1 dùng tham số mặc định — các núm này chưa mở để tránh lệch lịch.")
        }
    }

    // MARK: — Load / save

    private func load() {
        guard let database = model.database else { return }
        if let settings = try? SettingsService.load(on: database) {
            cefrLevel = settings.cefrLevel
            dailyNewLimit = settings.dailyNewLimit
            dayCutoffHour = settings.dayCutoffHour
            didLoad = true
        }
        fsrs = try? ReadoFSRS.readSettings(on: database)
    }

    private func save() {
        saveError = nil
        do {
            try model.saveLearningSettings(
                cefrLevel: cefrLevel,
                dailyNewLimit: dailyNewLimit,
                dayCutoffHour: dayCutoffHour)
            saved = true
        } catch {
            saveError =
                (error as? LocalizedError)?.errorDescription
                ?? String(describing: error)
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }

    private static func retentionLabel(_ retention: Double) -> String {
        String(format: "%.0f%%", retention * 100)
    }
}