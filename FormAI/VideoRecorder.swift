import AVFoundation
import Combine

class VideoRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var formattedDuration: String = "0:00"
    @Published var isFrontCamera = true

    var onAutoStop: ((URL?) -> Void)?
    private let maxRecordingDuration: TimeInterval = 10

    let session = AVCaptureSession()
    private var movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "video.recorder.session")
    private var durationTimer: Timer?
    private var completionHandler: ((URL?) -> Void)?
    private var currentVideoInput: AVCaptureDeviceInput?

    func setup() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            session.beginConfiguration()
            session.sessionPreset = .high

            // Video input — default front camera
            guard
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                session.canAddInput(videoInput)
            else {
                session.commitConfiguration()
                return
            }
            session.addInput(videoInput)
            currentVideoInput = videoInput

            // Audio input
            if let audioDevice = AVCaptureDevice.default(for: .audio),
               let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
               session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }

            // Movie output
            if session.canAddOutput(movieOutput) {
                session.addOutput(movieOutput)
            }

            // Portrait orientation
            if let connection = movieOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }

            session.commitConfiguration()
            session.startRunning()
        }
    }

    func flipCamera() {
        guard !isRecording else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let newPosition: AVCaptureDevice.Position = isFrontCamera ? .back : .front
            guard
                let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition),
                let newInput = try? AVCaptureDeviceInput(device: newDevice)
            else { return }

            session.beginConfiguration()
            if let current = currentVideoInput {
                session.removeInput(current)
            }
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentVideoInput = newInput
            }
            if let connection = movieOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            session.commitConfiguration()

            DispatchQueue.main.async { self.isFrontCamera.toggle() }
        }
    }

    func teardown() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
        durationTimer?.invalidate()
    }

    func startRecording() {
        guard !isRecording else { return }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mov")

        movieOutput.startRecording(to: outputURL, recordingDelegate: self)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            isRecording = true
            duration = 0
            durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self else { return }
                duration += 1
                let mins = Int(duration) / 60
                let secs = Int(duration) % 60
                formattedDuration = String(format: "%d:%02d", mins, secs)
                if duration >= maxRecordingDuration {
                    stopRecording(completion: onAutoStop ?? { _ in })
                }
            }
        }
    }

    func stopRecording(completion: @escaping (URL?) -> Void) {
        guard isRecording else { return }
        completionHandler = completion
        movieOutput.stopRecording()
        durationTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.duration = 0
            self?.formattedDuration = "0:00"
        }
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        if error != nil {
            completionHandler?(nil)
        } else {
            completionHandler?(outputFileURL)
        }
        completionHandler = nil
    }
}
