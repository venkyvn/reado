import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    var destName: String
    var isInbox: Bool
    var onPickDest: () -> Void
    var onCreate: () -> Void
    var onLibrary: () -> Void
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        if picker.sourceType == .camera {
            picker.cameraOverlayView = context.coordinator.makeOverlay()
        }
        context.coordinator.parent = self
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.refreshOverlay()
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        var parent: CameraPicker
        private var host: UIHostingController<CameraDestOverlay>?

        init(parent: CameraPicker) { self.parent = parent }

        func makeOverlay() -> UIView {
            let host = UIHostingController(rootView: overlayView)
            host.view.backgroundColor = .clear
            let root = OverlayRoot()
            root.backgroundColor = .clear
            host.view.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview(host.view)
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: root.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: root.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: root.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            ])
            root.frame = UIScreen.main.bounds
            self.host = host
            return root
        }

        func refreshOverlay() {
            host?.rootView = overlayView
        }

        private var overlayView: CameraDestOverlay {
            CameraDestOverlay(
                destName: parent.destName,
                isInbox: parent.isInbox,
                onPick: parent.onPickDest,
                onCreate: parent.onCreate,
                onLibrary: parent.onLibrary
            )
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            } else {
                parent.onCancel()
            }
        }
    }
}

final class OverlayRoot: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

struct CameraDestOverlay: View {
    var destName: String
    var isInbox: Bool
    var onPick: () -> Void
    var onCreate: () -> Void
    var onLibrary: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Button(action: onPick) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(destName).font(.headline)
                        Text(isInbox ? "Không chọn → kho tạm" : "Trang này vào bộ này")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.black.opacity(0.45))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button(action: onCreate) {
                    Image(systemName: "plus")
                        .frame(width: 44, height: 44)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.45))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("Tạo collection")
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            Spacer()
            HStack {
                Button(action: onLibrary) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(0.25))
                        .frame(width: 44, height: 44)
                        .overlay {
                            Image(systemName: "photo.on.rectangle").foregroundStyle(.white)
                        }
                }
                .accessibilityLabel("Thư viện")
                .padding(.leading, 24)
                .padding(.bottom, 36)
                Spacer()
            }
        }
    }
}
