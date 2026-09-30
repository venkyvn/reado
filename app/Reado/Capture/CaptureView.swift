import AVFoundation
import PhotosUI
import ReadoKit
import SwiftUI
import TOCropViewController
import UIKit

/// FR-01: Chụp ảnh hoặc chọn từ thư viện.
/// J1: ≤3 thao tác từ mở app tới chụp — không chọn collection, đích = kho tạm.
///
/// ADR-036: camera tự vẽ bằng AVFoundation (`CameraController`) thay
/// `UIImagePickerController` — picker cũ gắn overlay SwiftUI qua `addChild`
/// lên trên chính preview + nút hệ thống, gây màn đen và mất nút thoát (xem
/// doc `CameraController.swift`). Thư viện chuyển sang `PhotosPicker` (chạy
/// out-of-process, không dính bệnh đen của `UIImagePickerController` trong
/// sheet lồng sheet). Crop hiển thị NGAY trong ZStack (không `.sheet`) nên
/// full màn, không còn đè tab bar/toolbar.
struct CaptureView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case camera
        case crop(UIImage)
    }

    @State private var step: Step = .camera
    @State private var camera = CameraController()
    @State private var pickerItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isProcessing = false
    @State private var showProcessingError = false
    // J2/port UI lab: đích lưu chọn NGAY lúc chụp (không chọn lại lúc duyệt từ).
    // nil = kho tạm; mở từ Hub → prefill sẵn tên bộ. `initialDest` để "quên" đích
    // khi hủy phiên chụp mà không chụp gì.
    @State private var initialDest: String?
    @State private var showDestPicker = false
    @State private var showNewCollection = false
    @State private var newCollectionName = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch step {
            case .camera:
                cameraScreen
            case let .crop(image):
                CropView(
                    image: image,
                    onAccepted: { processImage($0) },
                    onCancel: {
                        step = .camera
                        Task { await camera.start() }
                    })
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            if let busyMessage {
                VStack(spacing: 12) {
                    ProgressView().tint(.white)
                    Text(busyMessage).foregroundStyle(.white)
                }
                .padding(20)
                .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .statusBarHidden()
        .alert("Không xử lý được ảnh", isPresented: $showProcessingError) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text("Hãy thử chụp lại hoặc chọn một ảnh khác.")
        }
        .onAppear { initialDest = model.analysisTargetCollectionID }
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            isLoadingPhoto = true
            Task {
                defer {
                    isLoadingPhoto = false
                    pickerItem = nil
                }
                guard let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else {
                    DebugTrace.event("capture", "libraryLoadFailed")
                    showProcessingError = true
                    return
                }
                DebugTrace.event("capture", "librarySelected", [
                    "width": Int(image.size.width), "height": Int(image.size.height),
                ])
                camera.stop()
                step = .crop(image)
            }
        }
        .sheet(isPresented: $showDestPicker) {
            destPickerSheet(close: { showDestPicker = false })
        }
        .sheet(isPresented: $showNewCollection) {
            newCollectionSheet(close: { showNewCollection = false })
        }
    }

    private var busyMessage: String? {
        if isProcessing { return "Đang xử lý ảnh…" }
        if isLoadingPhoto { return "Đang tải ảnh…" }
        return nil
    }

    // MARK: - Màn camera

    @ViewBuilder
    private var cameraScreen: some View {
        ZStack {
            if camera.status == .running {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
                framingGuide
            }
            switch camera.status {
            case .idle:
                ProgressView().tint(.white)
            case .denied:
                deniedView
            case .unavailable:
                unavailableView
            case .running:
                EmptyView()
            }
            VStack(spacing: 0) {
                topBar
                Spacer()
                bottomBar
            }
        }
    }

    /// Khung gợi ý tỉ lệ trang sách (~3:4) — chỉ trang trí, không bắt tap.
    private var framingGuide: some View {
        VStack {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.7), lineWidth: 1.5)
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .padding(.horizontal, 28)
            Text("Căn trang sách vào khung")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 10)
        }
        .allowsHitTesting(false)
    }

    private var deniedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.85))
            Text("Chưa có quyền camera")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Bật Camera cho Reado trong Cài đặt → Reado, rồi quay lại đây.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            Button("Mở Cài đặt") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var unavailableView: some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.slash")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.85))
            Text("Máy này không có camera")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Chọn ảnh từ thư viện ở nút bên dưới.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
    }

    /// X đóng + chip đích lưu + tạo bộ mới (port UI lab §4, chuyển từ overlay
    /// camera cũ sang chrome SwiftUI thật — luôn có nút thoát, kể cả lúc đen).
    private var topBar: some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                model.analysisTargetCollectionID = initialDest
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Đóng")

            destChip

            Spacer()

            Button {
                newCollectionName = ""
                showNewCollection = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Tạo bộ mới")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var destChip: some View {
        Button {
            showDestPicker = true
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("Lưu vào")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
                Text(destName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(cameraDestIsInbox ? "Không chọn → kho tạm" : "Trang này vào bộ này")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Đổi bộ lưu, hiện \(destName)")
    }

    /// Thư viện + shutter + flash (port UI lab §4, thay overlay camera cũ).
    private var bottomBar: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .accessibilityLabel("Chọn từ thư viện")

            Spacer()

            Button {
                captureTapped()
            } label: {
                ShutterButtonLabel()
            }
            .buttonStyle(ShutterPressStyle())
            .disabled(camera.status != .running || isProcessing)
            .accessibilityLabel("Chụp trang")

            Spacer()

            Button {
                camera.flashOn.toggle()
            } label: {
                Image(systemName: camera.flashOn ? "bolt.fill" : "bolt.slash.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.45), in: Circle())
            }
            .disabled(camera.status != .running)
            .accessibilityLabel(camera.flashOn ? "Tắt đèn flash" : "Bật đèn flash")
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 24)
    }

    /// Tên đích hiện tại cho chip (nil = kho tạm).
    private var destName: String {
        if let id = model.analysisTargetCollectionID,
           let c = model.collections.first(where: { $0.id == id }) {
            return c.name
        }
        return "Kho tạm"
    }

    /// Đích hiện tại có phải kho tạm không — chọn dòng gợi ý dưới chip.
    private var cameraDestIsInbox: Bool {
        if let id = model.analysisTargetCollectionID,
           let c = model.collections.first(where: { $0.id == id }) {
            return c.isDefault
        }
        return true
    }

    /// Chọn đích + haptic (port UI lab §9: `.selection` lúc đổi dest).
    private func selectDest(_ id: String?) {
        UISelectionFeedbackGenerator().selectionChanged()
        model.analysisTargetCollectionID = id
    }

    /// Sheet chọn collection lưu — radio, kho tạm ghi "mặc định" (port UI lab §4.3).
    private func destPickerSheet(close: @escaping () -> Void) -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectDest(nil)
                        close()
                    } label: {
                        HStack {
                            Label("Kho tạm", systemImage: "tray")
                                .foregroundStyle(.primary)
                            Spacer()
                            if model.analysisTargetCollectionID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                Section("Bộ") {
                    ForEach(model.collections.filter { !$0.isDefault }) { c in
                        Button {
                            selectDest(c.id)
                            close()
                        } label: {
                            HStack {
                                Text(c.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if model.analysisTargetCollectionID == c.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lưu vào đâu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Xong") { close() }
                }
            }
        }
    }

    /// Sheet tạo collection mới — nhập tên, tạo xong chọn luôn làm đích (port §4.2).
    private func newCollectionSheet(close: @escaping () -> Void) -> some View {
        NavigationStack {
            Form {
                TextField("Tên bộ", text: $newCollectionName)
                Button {
                    let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let id = try? model.createCollection(name: name) {
                        selectDest(id)
                    }
                    close()
                } label: {
                    Text("Tạo và chọn làm đích")
                        .frame(maxWidth: .infinity)
                }
                .disabled(newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .navigationTitle("Tạo bộ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Huỷ") { close() }
                }
            }
        }
    }

    private func captureTapped() {
        guard !isProcessing else { return }
        Haptics.action()
        Task {
            do {
                let image = try await camera.capture()
                camera.stop()
                step = .crop(image)
            } catch {
                DebugTrace.event("capture", "captureTappedFailed", ["error": String(describing: error)])
                Haptics.error()
                showProcessingError = true
            }
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        Task.detached(priority: .userInitiated) {
            let data = ImageCompressor.compress(image)
            await MainActor.run {
                if let data {
                    DebugTrace.event("capture", "processed", ["bytes": data.count])
                    let captured = CapturedImage(imageData: data)
                    model.handleCapturedImage(captured)
                    dismiss()
                } else {
                    DebugTrace.event("capture", "compressFailed")
                    isProcessing = false
                    showProcessingError = true
                    Haptics.error()
                }
            }
        }
    }
}

/// Vòng trắng + lõi trắng — chỉ nút này dùng hình shutter tròn (máy ảnh thật
/// = hệ thống), khớp `FloatShutter` ở RootView nhưng to hơn cho màn full-bleed.
private struct ShutterButtonLabel: View {
    var body: some View {
        Circle()
            .strokeBorder(.white, lineWidth: 4)
            .frame(width: 72, height: 72)
            .overlay(Circle().fill(.white).padding(7))
    }
}

/// port UI lab §9: shutter thu nhỏ nhẹ khi nhấn, bật trở lại bằng spring.
private struct ShutterPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(
                .spring(response: 0.32, dampingFraction: 0.86),
                value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    CaptureView()
        .environment(AppModel())
}
