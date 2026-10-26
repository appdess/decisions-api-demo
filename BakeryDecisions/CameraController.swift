import AVFoundation
import UIKit
import SwiftUI

final class CameraController: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label:"bakery.camera")
    private let output = AVCapturePhotoOutput()
    private var configured = false
    private var wantsRunning = false
    @Published var running = false
    @Published var capturing = false
    @Published var message: String?
    var onPhoto: ((UIImage) -> Void)?

    func start() {
        #if targetEnvironment(simulator)
        message = "Camera is available on iPhone. Use Photos or the illustrative fixture in the simulator."
        return
        #else
        queue.async { self.wantsRunning = true }
        switch AVCaptureDevice.authorizationStatus(for:.video) {
        case .authorized: configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for:.video) { allowed in
                if allowed { self.configureAndStart() }
                else { DispatchQueue.main.async { self.message = "Camera permission was denied. Enable it in iPhone Settings or choose a photo." } }
            }
        default: message = "Camera permission is off. Enable it in iPhone Settings or choose a photo."
        }
        #endif
    }
    private func configureAndStart() {
        queue.async {
            guard self.wantsRunning else { return }
            do {
                if !self.configured {
                    self.session.beginConfiguration()
                    guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,for:.video,position:.back) else { self.session.commitConfiguration(); throw DemoError.message("No rear camera is available.") }
                    let input: AVCaptureDeviceInput
                    do { input = try AVCaptureDeviceInput(device:device) }
                    catch { self.session.commitConfiguration(); throw error }
                    guard self.session.canAddInput(input), self.session.canAddOutput(self.output) else { self.session.commitConfiguration(); throw DemoError.message("Camera setup failed. Choose a photo instead.") }
                    self.session.addInput(input); self.session.addOutput(self.output)
                    self.output.maxPhotoQualityPrioritization = .speed
                    if self.session.canSetSessionPreset(.vga640x480) { self.session.sessionPreset = .vga640x480 }
                    self.session.commitConfiguration()
                    // Match a hardware-supported still size; never invent unsupported dimensions.
                    if let smallest = device.activeFormat.supportedMaxPhotoDimensions.min(by: {
                        Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
                    }) { self.output.maxPhotoDimensions = smallest }
                    self.configured = true
                }
                if !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { self.running = self.session.isRunning; self.message = self.running ? nil : "Camera unavailable. Choose a photo instead." }
            } catch { DispatchQueue.main.async { self.message = "Camera unavailable. Choose a photo instead." } }
        }
    }
    func stop() {
        queue.async {
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.running = false }
        }
    }
    func capture() {
        guard running, !capturing else { return }
        capturing = true
        queue.async {
            if let connection = self.output.connection(with:.video), connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .speed
            settings.maxPhotoDimensions = self.output.maxPhotoDimensions
            self.output.capturePhoto(with:settings,delegate:self)
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data:$0) }
        DispatchQueue.main.async {
            self.capturing = false
            guard error == nil, let image else { self.message = "Capture failed. Please try again."; return }
            self.onPhoto?(image)
        }
    }
}
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        if let c = previewLayer.connection, c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
    }
}
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context:Context) -> PreviewView { let v = PreviewView(); v.previewLayer.session = session; v.previewLayer.videoGravity = .resizeAspectFill; return v }
    func updateUIView(_ view:PreviewView,context:Context) {}
}
