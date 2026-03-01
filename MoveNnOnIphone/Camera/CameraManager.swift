import AVFoundation
import UIKit

final class CameraManager: NSObject, ObservableObject {
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.aivision.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.aivision.videoOutputQueue")

    @Published var isSessionRunning = false
    @Published var permissionGranted = false
    @Published var videoSize: CGSize = CGSize(width: 1280, height: 720)

    var onFrameCaptured: ((CVPixelBuffer) -> Void)?
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    override init() {
        super.init()
    }

    // MARK: - Permission

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.configure()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }

    // MARK: - Session Configuration

    func configure() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        // Camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        // Video data output for real-time frame processing
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }

        // Set video orientation to portrait
        if let connection = videoDataOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        // Get actual video dimensions
        if let formatDescription = camera.activeFormat.formatDescription as CMFormatDescription? {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            DispatchQueue.main.async { [weak self] in
                // Swapped because portrait
                self?.videoSize = CGSize(width: CGFloat(dimensions.height), height: CGFloat(dimensions.width))
            }
        }

        session.commitConfiguration()
    }

    // MARK: - Start / Stop

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
            }
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    // MARK: - Photo Capture

    func takePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            self.photoContinuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrameCaptured?(pixelBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoContinuation?.resume(returning: nil)
            photoContinuation = nil
            return
        }
        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}
