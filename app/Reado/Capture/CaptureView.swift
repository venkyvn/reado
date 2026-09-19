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
                Button("Đóng") { dismiss() }
            }
        }
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
        .onChange(of: croppedImage) {
            if let img = croppedImage {
                processImage(img)
            }
        }
    }

    private var captureButtons: some View {
        VStack(spacing: 24) {
            Button {
                showCamera = true
            } label: {
                Label("Chụp ảnh", systemImage: "camera.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                showPhotoLibrary = true
            } label: {
                Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
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
