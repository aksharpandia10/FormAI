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

        let count = min(10, max(1, Int(totalSeconds * 1.0)))

        var base64Frames: [String] = []
        var images: [UIImage] = []
        for i in 0..<count {
            let t = totalSeconds * Double(i) / Double(count - 1)
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
        guard frameData.durationSeconds <= 15 else { throw FormAnalysisError.videoTooLong }

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
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip any markdown code fences (```json ... ``` or ``` ... ```)
        if cleaned.hasPrefix("```") {
            let lines = cleaned.components(separatedBy: "\n")
            cleaned = lines.dropFirst().dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Extract the first JSON object if there's surrounding text
        if !cleaned.hasPrefix("{"),
           let start = cleaned.firstIndex(of: "{"),
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

    private static let exerciseCues: [String: String] = [
        "back squat": "depth (hip crease at or below knee), heels flat, knees tracking over toes, torso angle, hips and shoulders rising at the same rate out of the hole, bar position on back",
        "front squat": "elbow height throughout, torso uprightness, depth, knees tracking over toes, elbows not dropping",
        "bulgarian split squat": "front shin vertical at the bottom, front heel staying grounded, torso upright, rear knee descending toward floor",
        "goblet squat": "torso uprightness, heels flat, depth, elbows inside knees at the bottom",
        "deadlift": "spine neutral from setup to lockout, hips and shoulders rising at the same rate off the floor, bar staying close to body, standing tall at lockout without leaning back",
        "conventional deadlift": "spine neutral from setup to lockout, hips and shoulders rising at the same rate off the floor, bar staying close to body, standing tall at lockout without leaning back",
        "sumo deadlift": "knees pushing out over toes throughout, spine neutral, hips and shoulders rising together, upright torso at lockout",
        "rdl": "knees staying at a fixed slight bend throughout — not bending more on the way down, hips hinging back not down, bar staying close to legs, full hip extension with glute squeeze at the top",
        "romanian deadlift": "knees staying at a fixed slight bend throughout — not bending more on the way down, hips hinging back not down, bar staying close to legs, full hip extension with glute squeeze at the top",
        "bench press": "bar touching mid-chest, elbows at 45-75 degrees not flared to 90, feet planted, butt on bench, full lockout at top",
        "incline bench press": "elbows at 45-60 degrees not flared to 90, bar touching upper chest, scapular retraction, butt on bench",
        "dumbbell bench press": "elbows at 45-75 degrees, full ROM at bottom, dumbbells nearly touching at top, butt on bench",
        "overhead press": "glutes and core braced throughout, bar traveling vertically, no excessive lower back arch, full lockout with ears in front of arms",
        "dips": "full lockout at top, controlled descent to parallel, elbows tracking back not flared wide, no kipping",
        "pull-up": "full dead hang at the bottom with arms completely extended, initiating pull with lats not arms or shoulders, chin clearing the bar, no kipping or leg swing, controlled descent",
        "chin-up": "full dead hang at the bottom with arms completely extended, initiating pull with lats not arms or shoulders, chin clearing the bar, no kipping or leg swing, controlled descent",
        "lat pulldown": "full arm extension at the top, bar pulling to upper chest, elbows driving down and back, scapular depression before pulling, no excessive lean back",
        "row": "torso angle consistent throughout, full arm extension at the bottom, pulling to lower chest or belly button, scapular retraction at the top, no body english or torso rising",
        "hip thrust": "full hip extension at the top with glutes squeezed hard, bar over hip crease not stomach, shins vertical at the top, chin tucked",
        "lateral raise": "arms raising directly out to the sides, leading with elbows not wrists, raising to shoulder height, controlled lowering, no torso swing",
        "leg press": "depth at least to 90 degrees, back and glutes flat against pad throughout, knees tracking over toes, controlled descent",
        "lunge": "front shin vertical at the bottom, front heel staying grounded, torso upright, rear knee descending toward floor",
        "curl": "elbows pinned to sides throughout — not swinging forward, full extension at the bottom, no body swing or momentum",
        "push-up": "rigid plank from head to heels with no hip sag or pike, elbows at roughly 45 degrees from torso, chest lowering to near the floor, full lockout at top, head neutral",
        "plank": "straight line from head to heels, no hip sag or pike, core and glutes engaged, hips level",
    ]

    private func cueFor(exercise: Exercise) -> String {
        let name = exercise.name.lowercased()
        for (key, cue) in Self.exerciseCues {
            if name.contains(key) || key.contains(name) {
                return "\nKey things to assess: \(cue)."
            }
        }
        return ""
    }

    private func systemPrompt(exercise: Exercise, context: String) -> String {
        let contextLine = context.isEmpty ? "" : "\nClient context: \(context)\n"
        return """
        Look at all these frames from a workout video of \(exercise.name) and analyze the form.\(contextLine)
        What is the person doing well? What should they improve? Give a score from 0 to 100.

        Return ONLY this JSON — no markdown, no explanation:
        {
          "score": <integer 0-100>,
          "didWell": [{"observation": "<what they did well>", "confidence": "<high|medium|low>"}],
          "improve": [{"cue": "<one coaching fix>", "confidence": "<high|medium|low>"}],
          "summary": "<one sentence summing it up>"
        }
        """
    }

    enum FormAnalysisError: LocalizedError {
        case noFrames
        case videoTooLong
        case apiError(String)
        case parseError

        var errorDescription: String? {
            switch self {
            case .noFrames:          return "Could not extract frames from video."
            case .videoTooLong:      return "Video is too long. Keep it under 15 seconds — just 1–2 reps is ideal."
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
