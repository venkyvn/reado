import ReadoKit
import SwiftUI

/// FR-15 — J-R1-S: núm học tập (CEFR, hạn mức thẻ mới, giờ chuyển ngày) +
/// 3.12 nhắc ôn tập (toggle + giờ). `request_retention` + núm FSRS còn lại
/// chỉ-đọc (R1 không mở user — tránh tự bắn chân). Quản lý shortcut (FR-17)
/// và chọn agent (FR-21) là task sau.
struct SettingsView: View {
    @Environment(AppModel.self) private var model

    /// Chủ đề màu nhấn — đổi ngay (UserDefaults), KHÔNG nằm trong luồng "Lưu".
    @AppStorage("appTheme") private var appTheme = AppTheme.system.rawValue

    @State private var cefrLevels: [CEFRLevel] = [.b2]
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
            themeSection
            agentSection
            fsrsSection
            if let message = saveError {
                Section {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.danger)
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
        .onChange(of: cefrLevels) { saved = false }
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
            // CEFR đa level (port UI lab §8) — target cho lần phân tích trang KẾ
            // TIẾP (FR-15). Tối thiểu 1 level (không bỏ chip cuối cùng).
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Trình độ")
                    Spacer()
                    Text("\(cefrLevels.count)/4")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(CEFRLevel.allCases) { level in
                        levelChip(level)
                    }
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
                    Label("Giờ chuyển ngày", systemImage: "bed.double")
                    Spacer()
                    Text(Self.hourLabel(dayCutoffHour))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Label("Học tập", systemImage: "book.closed")
        } footer: {
            if saved {
                Text("Đã lưu · có hiệu lực từ lần chụp / ôn kế tiếp.")
            }
        }
    }

    /// Chip CEFR — bật/tắt; level đang chọn tô accent. Giữ tối thiểu 1 level.
    private func levelChip(_ level: CEFRLevel) -> some View {
        let isSelected = cefrLevels.contains(level)
        return Button {
            toggleLevel(level)
        } label: {
            Text(level.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(
                        isSelected ? Color.accentColor : Theme.surfaceStrong))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Trình độ \(level.rawValue)")
        .accessibilityValue(isSelected ? "đang chọn" : "bỏ chọn")
    }

    private func toggleLevel(_ level: CEFRLevel) {
        if cefrLevels.contains(level) {
            guard cefrLevels.count > 1 else { return }  // giữ tối thiểu 1
            cefrLevels.removeAll { $0 == level }
        } else {
            cefrLevels.append(level)
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
            Label("Nhắc ôn tập", systemImage: "bell")
        } footer: {
            Text(reminderEnabled
                 ? "Nhận thông báo mỗi ngày lúc \(ReminderService.describe(minutes: reminderMinutes))."
                 : "Bật để nhận lời nhắc ôn từ vựng hằng ngày.")
        }
    }

    // MARK: — Agent phân tích (FR-21 stub)

    /// FR-21 (port UI lab §8): chọn agent/BYOK là task sau — R1 luôn đi proxy mặc
    /// định. Đây là stub chỉ-đọc để không bỏ trống mục này.
    private var agentSection: some View {
        Section {
            LabeledContent("Đang dùng", value: "Proxy mặc định")
        } header: {
            Label("Agent phân tích", systemImage: "sparkles")
        } footer: {
            Label("Mang key riêng (BYOK, OpenAI-compat) sẽ mở ở bản sau.",
                  systemImage: "lock")
        }
    }

    // MARK: — Chủ đề (màu nhấn)

    private var themeSection: some View {
        Section {
            Picker("Chủ đề", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Label(theme.title, systemImage: theme.icon)
                        .tag(theme.rawValue)
                }
            }
        } header: {
            Label("Chủ đề", systemImage: "paintpalette")
        } footer: {
            Text("Màu nhấn toàn app — áp ngay, không cần bấm Lưu.")
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
            Label("Thuật toán ôn tập", systemImage: "function")
        } footer: {
            Label("R1 dùng tham số mặc định — các núm này chưa mở để tránh lệch lịch.",
                  systemImage: "lock")
        }
    }

    // MARK: — Load / save

    private func load() {
        guard let database = model.database else { return }
        if let settings = try? SettingsService.load(on: database) {
            cefrLevels = settings.cefrLevels
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
                cefrLevels: cefrLevels,
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