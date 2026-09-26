import AVFoundation
import SwiftUI
import UIKit

/// Điều khiển camera (ADR-036) — thay `UIImagePickerController`.
///
/// Nguyên nhân bỏ picker cũ: `picker.addChild(hosting)` gắn overlay SwiftUI
/// làm con của `UIImagePickerController` (bản chất là `UINavigationController`)
/// → hosting view (nền trong nhưng vẫn chiếm layer) đẩy LÊN TRÊN preview camera
/// và che luôn nút Cancel/chụp hệ thống → màn đen + không có đường thoát. Viện
/// AVFoundation tự vẽ preview + chrome SwiftUI thật (không addChild) tránh hẳn
/// lớp che đó.
///
/// Session luôn `startRunning`/`stopRunning` trên `sessionQueue`, KHÔNG bao giờ
/// trên main — start trên main là một nguồn màn đen khác (đợi frame đầu chặn
/// main thread, SwiftUI không kịp vẽ preview).
@Observable
final class CameraController: NSObject {
    enum Status: Equatable {
        case idle
        case running
        /// Từ chối quyền camera — CaptureView hiện nút "Mở Cài đặt".
        case denied
        /// Simulator hoặc máy không có camera sau — CaptureView chỉ còn thư viện.
        case unavailable
    }

    private(set) var status: Status = .idle
    var flashOn = false

    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "app.reado.camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private var captureContinuation: CheckedContinuation<UIImage, Error>?

    /// Xin quyền (nếu chưa hỏi) → configure session một lần → start trên
    /// `sessionQueue`. Gọi lại (ví dụ quay lại từ crop) chỉ start lại.
    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .video) else {
                status = .denied
                return
            }
        default:
            status = .denied
            return
        }

        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
        else {
            status = .unavailable
            return
        }

        if !configured {
            configureSession()
            guard configured else {
                status = .unavailable
                return
            }
        }
        status = .running
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return }

        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        session.addOutput(photoOutput)
        session.commitConfiguration()

        if (try? device.lockForConfiguration()) != nil {
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            device.unlockForConfiguration()
        }
        configured = true
    }

    /// Chụp một ảnh. Không gọi chồng lần hai khi đang chờ — CaptureView tự
    /// disable nút chụp lúc `isProcessing` để tránh mất continuation trước đó.
    func capture() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation
            let settings = AVCapturePhotoSettings()
            if photoOutput.supportedFlashModes.contains(flashOn ? .on : .off) {
                settings.flashMode = flashOn ? .on : .off
            }
            sessionQueue.async { [photoOutput] in
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let continuation = captureContinuation
        captureContinuation = nil
        if let error {
            continuation?.resume(throwing: error)
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            continuation?.resume(throwing: CameraCaptureError.noImageData)
            return
        }
        continuation?.resume(returning: image)
    }
}

enum CameraCaptureError: Error {
    case noImageData
}

/// Preview full-bleed — `AVCaptureVideoPreviewLayer` trực tiếp, không qua
/// `UIImagePickerController` (nguồn màn đen cũ, xem doc `CameraController`).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context _: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_: PreviewView, context _: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
