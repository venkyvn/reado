import SwiftUI
import TOCropViewController
import UIKit

// MARK: - Crop View

/// Full màn, không `.sheet` (khác bản cũ) — nên không còn đè tab bar/toolbar.
/// Không tự `dismiss()`: `onAccepted`/`onCancel` do CaptureView điều khiển
/// `step`, vì crop giờ là một nhánh trong cùng ZStack chứ không phải modal.
struct CropView: UIViewControllerRepresentable {
    let image: UIImage
    let onAccepted: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> TOCropViewController {
        let controller = TOCropViewController(croppingStyle: .default, image: image)
        controller.delegate = context.coordinator
        controller.toolbar.rotateClockwiseButtonHidden = false
        controller.toolbar.resetButtonHidden = true
        return controller
    }

    func updateUIViewController(_: TOCropViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, TOCropViewControllerDelegate {
        let parent: CropView

        init(_ parent: CropView) {
            self.parent = parent
        }

        func cropViewController(
            _: TOCropViewController,
            didCropTo croppedImage: UIImage,
            with _: CGRect,
            angle _: Int
        ) {
            parent.onAccepted(croppedImage)
        }

        func cropViewController(_: TOCropViewController, didFinishCancelled _: Bool) {
            parent.onCancel()
        }
    }
}
