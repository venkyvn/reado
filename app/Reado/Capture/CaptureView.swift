import SwiftUI
import UIKit
import PhotosUI
import ReadoKit
import TOCropViewController

/// FR-01: Chụp ảnh hoặc chọn từ thư viện.
/// J1: ≤3 thao tác từ mở app tới chụp — không chọn collection, đích = kho tạm.
struct CaptureView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var croppedImage: UIImage?
    @State private var showCrop = false
    @State private var sourceImage: UIImage?
    @State private var isProcessing = false
    @State private var showProcessingError = false
    // J2/port UI lab: đích lưu chọn NGAY lúc chụp (không chọn lại lúc duyệt từ).
    // nil = kho tạm; mở từ Hub → prefill sẵn tên bộ. `initialDest` để "quên" đích
    // khi hủy phiên chụp mà không chụp gì.
    @State private var initialDest: String?
    @State private var showDestPicker = false
    @State private var showNewCollection = false
    @State private var newCollectionName = ""
    // Sheet chọn/tạo bộ BÊN TRONG fullScreenCover camera (overlay gọi). Sheet của
    // destBar không mở được qua camera nên cần state riêng, gắn vào cover.
    @State private var showDestOnCamera = false
    @State private var showCreateOnCamera = false

    var body: some View {
        ZStack {
            if isProcessing {
                ProgressView("Đang xử lý ảnh...")
                    .transition(.opacity)
            } else {
                captureButtons
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Motion.reveal, value: isProcessing)
        .navigationTitle("Chụp trang")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Không xử lý được ảnh", isPresented: $showProcessingError) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text("Hãy thử chụp lại hoặc chọn một ảnh khác.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Đóng") {
                    // Hủy chụp → đích vừa chọn bị "quên", về đích mặc khi màn chụp mở.
                    model.analysisTargetCollectionID = initialDest
                    dismiss()
                }
            }
        }
        .onAppear { initialDest = model.analysisTargetCollectionID }
        .confirmationDialog("Chọn ảnh", isPresented: $showSourcePicker) {
            Button("Chụp ảnh") { showCamera = true }
            Button("Chọn từ thư viện") { showPhotoLibrary = true }
            Button("Hủy", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(
                image: $sourceImage,
                destName: destName,
                isInbox: cameraDestIsInbox,
                onPickDest: { showDestOnCamera = true },
                onCreate: { newCollectionName = ""; showCreateOnCamera = true },
                onLibrary: {
                    // Tắt camera, mở lại thư viện đã có (tránh sheet trùng transition).
                    showCamera = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showPhotoLibrary = true
                    }
                })
                .onDisappear {
                    if let img = sourceImage {
                        croppedImage = img
                        showCrop = true
                    }
                }
                .sheet(isPresented: $showDestOnCamera) {
                    destPickerSheet(close: { showDestOnCamera = false })
                }
                .sheet(isPresented: $showCreateOnCamera) {
                    newCollectionSheet(close: { showCreateOnCamera = false })
                }
        }
        .sheet(isPresented: $showPhotoLibrary) {
            PhotoLibraryView(image: $sourceImage)
                .onDisappear {
                    if let img = sourceImage {
                        croppedImage = img
                        showCrop = true
                    }
                }
        }
        .sheet(isPresented: $showCrop) {
            if let img = croppedImage {
                CropView(image: img, croppedImage: $croppedImage)
            }
        }
        .sheet(isPresented: $showDestPicker) {
            destPickerSheet(close: { showDestPicker = false })
        }
        .sheet(isPresented: $showNewCollection) {
            newCollectionSheet(close: { showNewCollection = false })
        }
        .onChange(of: croppedImage) {
            if let img = croppedImage {
                processImage(img)
            }
        }
    }

    private var captureButtons: some View {
        VStack(spacing: 16) {
            destBar

            Button {
                showCamera = true
            } label: {
                Label("Chụp ảnh", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showPhotoLibrary = true
            } label: {
                Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    /// Thanh đích lưu — tên bộ hiện tại + `+` tạo bộ mới (port UI lab §4).
    /// Tap tên → sheet chọn collection; `+` → sheet tạo tên mới.
    private var destBar: some View {
        HStack(spacing: 10) {
            Button {
                showDestPicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Lưu vào")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(destName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(
                    Theme.surfaceStrong,
                    in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Đổi collection lưu, hiện \(destName)")

            Button {
                newCollectionName = ""
                showNewCollection = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityLabel("Tạo collection mới")
        }
    }

    /// Tên đích hiện tại cho thanh dest (nil = kho tạm).
    private var destName: String {
        if let id = model.analysisTargetCollectionID,
           let c = model.collections.first(where: { $0.id == id }) {
            return c.name
        }
        return "Kho tạm"
    }

    /// Đích hiện tại có phải kho tạm không — để overlay camera chọn dòng gợi ý
    /// ("Không chọn → kho tạm" vs "Trang này vào bộ này").
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
    /// Dùng chung cho destBar (trước camera) và overlay camera — `close` đóng
    /// đúng nguồn đang mở (showDestPicker hoặc showDestOnCamera).
    private func destPickerSheet(close: @escaping () -> Void) -> some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectDest(nil)
                        close()
                    } label: {
                        HStack {
                            Label("Kho tạm (mặc định)", systemImage: "tray")
                                .foregroundStyle(.primary)
                            Spacer()
                            if model.analysisTargetCollectionID == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }

                Section("Collection") {
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
                TextField("Tên collection", text: $newCollectionName)
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
            .navigationTitle("Tạo collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Huỷ") { close() }
                }
            }
        }
    }

    private func processImage(_ image: UIImage) {
        isProcessing = true
        if let data = ImageCompressor.compress(image) {
            let captured = CapturedImage(imageData: data)
            model.handleCapturedImage(captured)
            dismiss()
        } else {
            isProcessing = false
            showProcessingError = true
            Haptics.error()
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    /// Tên đích lưu hiện tại (overlay hiển thị); `isInbox` chọn dòng gợi ý.
    let destName: String
    let isInbox: Bool
    let onPickDest: () -> Void
    let onCreate: () -> Void
    let onLibrary: () -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            context.coordinator.attachOverlay(to: picker)
        } else {
            // Simulator / thiết bị không camera → thư viện, không gắn overlay.
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateOverlay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: CameraView
        private var hosting: UIHostingController<CameraOverlayContent>?

        init(_ parent: CameraView) {
            self.parent = parent
        }

        /// Gắn overlay SwiftUI lên camera — chip tên bộ + tạo mới + thư viện.
        func attachOverlay(to picker: UIImagePickerController) {
            let overlay = CameraOverlayView()
            overlay.frame = UIScreen.main.bounds
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            picker.cameraOverlayView = overlay

            let hosting = UIHostingController(rootView: contentView)
            hosting.view.backgroundColor = .clear
            hosting.view.frame = overlay.bounds
            hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            picker.addChild(hosting)
            overlay.addSubview(hosting.view)
            hosting.didMove(toParent: picker)
            self.hosting = hosting
        }

        /// Cập nhật lại nội dung overlay khi tên đích đổi.
        func updateOverlay() {
            hosting?.rootView = contentView
        }

        private var contentView: CameraOverlayContent {
            CameraOverlayContent(
                destName: parent.destName,
                isInbox: parent.isInbox,
                onPickDest: parent.onPickDest,
                onCreate: parent.onCreate,
                onLibrary: parent.onLibrary)
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Overlay camera — pass-through: tap vùng trống rơi xuống picker (nút chụp hệ
/// thống, tap-to-focus); chỉ các nút SwiftUI thật mới ăn tap.
private final class CameraOverlayView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

/// Nội dung overlay camera — chip tên bộ + tạo mới + thư viện (port UI lab §4).
private struct CameraOverlayContent: View {
    let destName: String
    let isInbox: Bool
    let onPickDest: () -> Void
    let onCreate: () -> Void
    let onLibrary: () -> Void

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Button(action: onPickDest) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lưu vào")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.75))
                            Text(destName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(isInbox ? "Không chọn → kho tạm" : "Trang này vào bộ này")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Đổi collection lưu, hiện \(destName)")

                    Spacer()

                    Button(action: onCreate) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Tạo collection mới")
                }
                Spacer()
                HStack {
                    Button(action: onLibrary) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3)
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Chọn từ thư viện")
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }
}

// MARK: - Photo Library View

struct PhotoLibraryView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryView

        init(_ parent: PhotoLibraryView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                  didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Crop View

struct CropView: UIViewControllerRepresentable {
    let image: UIImage
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> TOCropViewController {
        let controller = TOCropViewController(croppingStyle: .default, image: image)
        controller.delegate = context.coordinator
        controller.toolbar.rotateClockwiseButtonHidden = false
        controller.toolbar.resetButtonHidden = true
        return controller
    }

    func updateUIViewController(_ uiViewController: TOCropViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, TOCropViewControllerDelegate {
        let parent: CropView

        init(_ parent: CropView) {
            self.parent = parent
        }

        func cropViewController(_ cropViewController: TOCropViewController,
                               didCropTo croppedImage: UIImage,
                               with cropRect: CGRect,
                               angle: Int) {
            parent.croppedImage = croppedImage
            parent.dismiss()
        }

        func cropViewController(_ cropViewController: TOCropViewController,
                               didFinishCancelled cancelled: Bool) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaptureView()
            .environment(AppModel())
    }
}
