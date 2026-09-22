import ReadoKit
import SwiftUI

/// FR-15 — J-R1-S: núm học tập (CEFR, hạn mức thẻ mới, giờ chuyển ngày) +
/// 3.12 nhắc ôn tập (toggle + giờ). `request_retention` + núm FSRS còn lại
/// chỉ-đọc (R1 không mở user — tránh tự bắn chân). Quản lý shortcut (FR-17)
/// và chọn agent (FR-21) là task sau.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    @State private var cefrLevel: CEFRLevel = .b2
    @State private var dailyNewLimit = 10
    @State private var dayCutoffHour = 4
    // 3.12 — nhắc ôn tập (local notification), default TẮT + 20:00.
    @State private var reminderEnabled = false
    @State private var reminderMinutes = 20 * 60
    @State private var didLoad = false
    @State private var saveError: String?
    @State private var saved = false
    /// Nhóm FSRS chỉ-đọc — đọc qua ReadoFSRS để hiện mà không cho sửa.
    @State private var fsrs: SchedulingSettings?

    var body: some View {
        List {
            learningSection
            reminderSection
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
        .onChange(of: reminderEnabled) { saved = false }
        .onChange(of: reminderMinutes) { saved = false }
    }

    /// Giờ nhắc chọn được — bước 15' từ 00:00 tới 23:45 (khớp `reminderMinutes`).
    private static let reminderOptions = Array(stride(from: 0, to: 24 * 60, by: 15))

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

    // MARK: — Nhắc ôn tập (3.12)

    private var reminderSection: some View {
        Section {
            Toggle("Bật nhắc ôn tập", isOn: $reminderEnabled)
            if reminderEnabled {
                Picker("Giờ nhắc", selection: $reminderMinutes) {
                    ForEach(Self.reminderOptions, id: \.self) { minutes in
                        Text(ReminderService.describe(minutes: minutes)).tag(minutes)
                    }
                }
                .pickerStyle(.wheel)
            }
        } header: {
            Text("Nhắc ôn tập")
        } footer: {
            Text(reminderEnabled
                 ? "Nhận thông báo mỗi ngày lúc \(ReminderService.describe(minutes: reminderMinutes))."
                 : "Bật để nhận lời nhắc ôn từ vựng hằng ngày.")
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
            reminderEnabled = settings.reminderEnabled
            reminderMinutes = settings.reminderMinutes
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
                dayCutoffHour: dayCutoffHour,
                reminderEnabled: reminderEnabled,
                reminderMinutes: reminderMinutes)
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