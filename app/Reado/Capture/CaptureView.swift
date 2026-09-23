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

    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var croppedImage: UIImage?
    @State private var showCrop = false
    @State private var sourceImage: UIImage?
    @State private var isProcessing = false
    // J2/port UI lab: đích lưu chọn NGAY lúc chụp (không chọn lại lúc duyệt từ).
    // nil = kho tạm; mở từ Hub → prefill sẵn tên bộ. `initialDest` để "quên" đích
    // khi hủy phiên chụp mà không chụp gì.
    @State private var initialDest: String?
    @State private var showDestPicker = false
    @State private var showNewCollection = false
    @State private var newCollectionName = ""

    var body: some View {
        ZStack {
            if isProcessing {
                ProgressView("Đang xử lý ảnh...")
            } else {
                captureButtons
            }
        }
        .navigationTitle("Chụp trang")
        .navigationBarTitleDisplayMode(.inline)
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
            CameraView(image: $sourceImage)
                .onDisappear {
                    if let img = sourceImage {
                        croppedImage = img
                        showCrop = true
                    }
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
            destPickerSheet
        }
        .sheet(isPresented: $showNewCollection) {
            newCollectionSheet
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

    /// Chọn đích + haptic (port UI lab §9: `.selection` lúc đổi dest).
    private func selectDest(_ id: String?) {
        UISelectionFeedbackGenerator().selectionChanged()
        model.analysisTargetCollectionID = id
    }

    /// Sheet chọn collection lưu — radio, kho tạm ghi "mặc định" (port UI lab §4.3).
    private var destPickerSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectDest(nil)
                        showDestPicker = false
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
                            showDestPicker = false
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
                    Button("Xong") { showDestPicker = false }
                }
            }
        }
    }

    /// Sheet tạo collection mới — nhập tên, tạo xong chọn luôn làm đích (port §4.2).
    private var newCollectionSheet: some View {
        NavigationStack {
            Form {
                TextField("Tên collection", text: $newCollectionName)
                Button {
                    let name = newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let id = try? model.createCollection(name: name) {
                        selectDest(id)
                    }
                    showNewCollection = false
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
                    Button("Huỷ") { showNewCollection = false }
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
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
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
