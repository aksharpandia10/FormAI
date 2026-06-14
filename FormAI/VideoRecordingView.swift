import SwiftUI
import PhotosUI
import Photos
import AVFoundation

struct VideoRecordingView: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VideoRecorder()
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var isAnalyzing = false
    @State private var formCheckResult: FormCheckResult? = nil
    @State private var showResult = false
    @State private var errorMessage: String? = nil
    @State private var loadingTipIndex = 0
    @State private var analysisProgress: Double = 0
    @State private var lastVideoURL: URL? = nil

    private let analysisService = FormAnalysisService()

    private let tips = [
        "Reviewing your frames...",
        "Checking joint alignment...",
        "Analysing bar path...",
        "Reading your movement...",
        "Almost there...",
    ]

    var body: some View {
        ZStack {
            if isAnalyzing {
                loadingScreen.transition(.opacity)
            } else {
                cameraScreen.transition(.opacity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { recorder.setup() }
        .onDisappear { recorder.teardown() }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                guard let url = try? await loadVideoURL(from: item) else {
                    await MainActor.run {
                        errorMessage = "Could not load video from library."
                    }
                    return
                }
                withAnimation { isAnalyzing = true }
                await analyze(videoURL: url)
            }
        }
        .navigationDestination(isPresented: $showResult) {
            if let result = formCheckResult {
                FormCheckResultView(result: result) {
                    showResult = false
                    formCheckResult = nil
                    pickerItem = nil
                    dismiss()
                }
            }
        }
    }

    // MARK: - Camera Screen

    private var cameraScreen: some View {
        ZStack {
            CameraPreviewView(session: recorder.session).ignoresSafeArea()

            VStack {
                // Top bar
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(exercise.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(recorder.isRecording ? "Recording..." : "\(exercise.cameraAngle.rawValue.lowercased()) view")
                            .font(.caption)
                            .foregroundStyle(recorder.isRecording ? .red : .white.opacity(0.75))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    if recorder.isRecording {
                        Text(recorder.formattedDuration)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.85))
                            .clipShape(Capsule())
                    } else {
                        Button { recorder.flipCamera() } label: {
                            Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                                .font(.title3).foregroundStyle(.white)
                                .padding(10).background(.ultraThinMaterial).clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                Spacer()

                // Bottom controls
                VStack(spacing: 20) {
                    Button {
                        if recorder.isRecording {
                            recorder.stopRecording { url in
                                guard let url else { return }
                                saveVideoToLibrary(url)
                                Task { await analyze(videoURL: url) }
                            }
                        } else {
                            recorder.startRecording()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 3)
                                .frame(width: 76, height: 76)
                            RoundedRectangle(cornerRadius: recorder.isRecording ? 8 : 34)
                                .fill(recorder.isRecording ? Color.red : Color.white)
                                .frame(width: recorder.isRecording ? 30 : 60, height: recorder.isRecording ? 30 : 60)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: recorder.isRecording)
                        }
                    }

                    if !recorder.isRecording {
                        PhotosPicker(selection: $pickerItem, matching: .videos) {
                            Label("Choose from Library", systemImage: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.bottom, 52)

                if let errorMessage {
                    VStack(spacing: 10) {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                        HStack(spacing: 10) {
                            if let url = lastVideoURL {
                                Button("Retry") {
                                    self.errorMessage = nil
                                    Task { await analyze(videoURL: url) }
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(Theme.accent.opacity(0.8)).clipShape(Capsule())
                            }
                            Button("Dismiss") { self.errorMessage = nil }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20).padding(.vertical, 8)
                                .background(Color.white.opacity(0.2)).clipShape(Capsule())
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }

    // MARK: - Loading Screen

    private var loadingScreen: some View {
        ZStack(alignment: .topLeading) {
            Theme.primary.ignoresSafeArea()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.15))
                    .clipShape(Circle())
            }
            .padding(.leading, 16)
            .padding(.top, 16)

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 20) {
                    // Percentage
                    Text("\(Int(analysisProgress * 100))%")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: analysisProgress)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.2))
                                .frame(height: 6)
                            Capsule()
                                .fill(.white)
                                .frame(width: geo.size.width * analysisProgress, height: 6)
                                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: analysisProgress)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 40)

                    Text(tips[loadingTipIndex])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .animation(.easeInOut, value: loadingTipIndex)
                }

                Spacer()
            }
        }
        .task {
            while isAnalyzing {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                if isAnalyzing {
                    loadingTipIndex = (loadingTipIndex + 1) % tips.count
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadVideoURL(from item: PhotosPickerItem) async throws -> URL? {
        guard let movie = try? await item.loadTransferable(type: VideoTransferable.self) else { return nil }
        return movie.url
    }

    private func saveVideoToLibrary(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else { return }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            }
        }
    }

    private func analyze(videoURL: URL) async {
        isAnalyzing = true
        errorMessage = nil
        lastVideoURL = videoURL
        analysisProgress = 0
        AnalyticsService.formCheckStarted(exerciseId: exercise.id, exerciseName: exercise.name)
        do {
            let (entry, frames) = try await analysisService.analyzeFormStructured(
                videoURL: videoURL,
                exercise: exercise
            ) { p in
                Task { @MainActor in analysisProgress = p }
            }
            await MainActor.run {
                AnalyticsService.formCheckCompleted(exerciseId: exercise.id, exerciseName: exercise.name, score: entry.score)
                analysisProgress = 1
                formCheckResult = FormCheckResult(exercise: exercise, entry: entry, frames: frames)
                isAnalyzing = false
                showResult = true
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Recording Tip Interstitial

struct RecordingTipView: View {
    let exercise: Exercise
    let onStart: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                VStack(spacing: 10) {
                    Text("For best results")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Follow these tips before recording")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer().frame(height: 36)

                VStack(spacing: 0) {
                    TipRow(icon: "timer", text: "Record 1–3 complete reps")
                    Divider().background(.white.opacity(0.1))
                    TipRow(icon: "arrow.triangle.2.circlepath", text: "Show 1–2 complete reps")
                    Divider().background(.white.opacity(0.1))
                    TipRow(icon: "video.fill", text: "Film from \(exercise.cameraAngle.rawValue.lowercased()) view")
                    Divider().background(.white.opacity(0.1))
                    TipRow(icon: "figure.stand", text: "Keep your full body in frame")
                }
                .background(.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)

                Spacer()

                Button(action: onStart) {
                    Text("Start Recording")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 52)
            }
        }
    }
}

private struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct VideoTransferable: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { SentTransferredFile($0.url) } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoTransferable(url: dest)
        }
    }
}
