import AVFoundation
import UIKit

private struct RawFormResult: Codable {
    let score: Int
    let didWell: [String]
    let improve: [String]
    let summary: String
}

class FormAnalysisService {
    private let proxyEndpoint = "https://formai-proxy.formai.workers.dev/analyze"
    private let serviceKey = "formai-sk-2026"

    // MARK: - Frame extraction

    struct FrameData {
        let base64Frames: [String]
        let images: [UIImage]
        let durationSeconds: Double
    }

    func extractFrames(from videoURL: URL, onProgress: ((Double) -> Void)? = nil) async -> FrameData {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.2, preferredTimescale: 600)

        guard let duration = try? await asset.load(.duration) else {
            return FrameData(base64Frames: [], images: [], durationSeconds: 0)
        }
        let totalSeconds = CMTimeGetSeconds(duration)
        guard totalSeconds > 0 else { return FrameData(base64Frames: [], images: [], durationSeconds: 0) }

        let cappedSeconds = min(totalSeconds, 15.0)
        let count = min(15, max(1, Int(cappedSeconds * 1.0)))

        var base64Frames: [String] = []
        var images: [UIImage] = []
        for i in 0..<count {
            let t = cappedSeconds * Double(i) / Double(max(count - 1, 1))
            let time = CMTime(seconds: t, preferredTimescale: 600)
            if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                let resized = UIImage(cgImage: cgImage).resized(toWidth: 512)
                if let jpeg = resized.jpegData(compressionQuality: 0.7) {
                    base64Frames.append(jpeg.base64EncodedString())
                    images.append(resized)
                }
            }
            onProgress?(Double(i + 1) / Double(count))
        }
        return FrameData(base64Frames: base64Frames, images: images, durationSeconds: totalSeconds)
    }

    // MARK: - Structured analysis

    func analyzeFormStructured(videoURL: URL, exercise: Exercise, onProgress: ((Double) -> Void)? = nil) async throws -> (entry: FormCheckEntry, frames: [UIImage]) {
        // Phase 1: frame extraction — 0% → 50%
        let frameData = await extractFrames(from: videoURL) { p in
            onProgress?(p * 0.5)
        }
        guard !frameData.base64Frames.isEmpty else { throw FormAnalysisError.noFrames }

        let coachingContext = UserDefaults.standard.string(forKey: "ob_coachingContext") ?? ""
        let frameInterval = frameData.durationSeconds / Double(max(frameData.base64Frames.count - 1, 1))
        let userText = "The \(frameData.base64Frames.count) images above are frames numbered 1–\(frameData.base64Frames.count), evenly sampled from a \(String(format: "%.1f", frameData.durationSeconds))-second video (one frame every \(String(format: "%.2f", frameInterval))s). When referencing an observation, cite the frame number(s) where you see it."

        let body: [String: Any] = [
            "frames": frameData.base64Frames,
            "systemPrompt": systemPrompt(exercise: exercise, context: coachingContext),
            "userText": userText
        ]

        var request = URLRequest(url: URL(string: proxyEndpoint)!, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(serviceKey, forHTTPHeaderField: "X-Service-Key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Phase 2: API call — 50% → 92% (simulated, faster early then slows near cap)
        onProgress?(0.5)
        let progressTask = Task {
            var current = 0.5
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 400_000_000)
                current += (0.92 - current) * 0.08
                onProgress?(current)
            }
        }
        defer { progressTask.cancel() }

        let (data, response) = try await URLSession.shared.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw FormAnalysisError.apiError(msg)
        }

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let text = json["text"] as? String
        else { throw FormAnalysisError.parseError }

        return (try parseResult(text, exercise: exercise), frameData.images)
    }

    private func parseResult(_ text: String, exercise: Exercise) throws -> FormCheckEntry {
        #if DEBUG
        print("[FormAnalysis] Raw response:\n\(text)")
        #endif

        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences — find closing ``` explicitly
        if cleaned.hasPrefix("```") {
            let afterFence = cleaned.drop(while: { !$0.isNewline }).dropFirst()
            if let closeRange = afterFence.range(of: "```") {
                cleaned = String(afterFence[afterFence.startIndex..<closeRange.lowerBound])
            } else {
                cleaned = String(afterFence)
            }
            cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract first complete JSON object
        if let start = cleaned.firstIndex(of: "{"),
           let end = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[start...end])
        }

        guard let jsonData = cleaned.data(using: .utf8) else { throw FormAnalysisError.parseError }

        do {
            let raw = try JSONDecoder().decode(RawFormResult.self, from: jsonData)
            return FormCheckEntry(
                exerciseId: exercise.id,
                exerciseName: exercise.name,
                score: max(0, min(100, raw.score)),
                didWell: raw.didWell.map(stripFrameRefs),
                improve: raw.improve.map(stripFrameRefs),
                summary: raw.summary
            )
        } catch {
            #if DEBUG
            print("[FormAnalysis] Decode error: \(error)\nCleaned JSON: \(cleaned)")
            #endif
            throw FormAnalysisError.parseError
        }
    }

    private func stripFrameRefs(_ text: String) -> String {
        var result = text
        // Remove patterns like (frame 4), (frames 4-6), (frame 4, 5), (frames 3–7)
        let pattern = #"\s*\(frames?\s[\d,\s\-–]+\)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        // Replace em dashes with a regular hyphen
        result = result.replacingOccurrences(of: "—", with: "-")
        return result.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - System prompt

    private func systemPrompt(exercise: Exercise, context: String) -> String {
        let contextLine = context.isEmpty ? "" : "\nClient context: \(context)\n"
        return """
        Look at all these frames from a workout video of \(exercise.name) and analyze the form.\(contextLine)
        What is the person doing well? What should they improve? Give a score from 0 to 100.

        Return ONLY this JSON — no markdown, no explanation:
        {
          "score": <integer 0-100>,
          "didWell": ["<observation 1>", "<observation 2>"],
          "improve": ["<coaching cue 1>", "<coaching cue 2>"],
          "summary": "<one sentence summing it up>"
        }
        """
    }


    enum FormAnalysisError: LocalizedError {
        case noFrames
        case apiError(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .noFrames:          return "Could not extract frames from video."
            case .apiError(let m):   return friendlyError(m)
            case .parseError:        return "Could not read AI response."
            }
        }

        private func friendlyError(_ raw: String) -> String {
            let l = raw.lowercased()
            if l.contains("overloaded") || l.contains("529")          { return "The AI is overloaded. Wait a moment and try again." }
            if l.contains("offline") || l.contains("hostname")        { return "No internet connection." }
            if l.contains("timeout")                                   { return "Request timed out. Try again." }
            if l.contains("401") || l.contains("authentication") || l.contains("invalid x-api-key") { return "API key issue. Please contact support." }
            if l.contains("429") || l.contains("rate limit") || l.contains("too many requests") { return "You've done a lot of form checks today. Take a breather and try again in an hour." }
            if l.contains("413") || l.contains("too large")           { return "Video is too large to analyse. Try a shorter clip." }
            if l.contains("400") || l.contains("bad request")         { return "Could not process the video. Try recording again." }
            return "Something went wrong (\(raw.prefix(80))). Please try again."
        }
    }
}

private extension UIImage {
    func resized(toWidth width: CGFloat) -> UIImage {
        let aspect = size.height / size.width
        let newSize = CGSize(width: width, height: width * aspect)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
