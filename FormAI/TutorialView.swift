import SwiftUI
import WebKit
import AVFoundation

struct TutorialView: View {
    let exerciseName: String

    @State private var videoID: String? = nil
    @State private var isLoading = true
    @State private var failed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView().tint(.white)
                    Text("Finding tutorial…")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.6))
                }
            } else if failed || videoID == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(.white.opacity(0.5))
                    Text("No tutorial found")
                        .foregroundStyle(.white.opacity(0.7))
                    Button("Go Back") { dismiss() }
                        .foregroundStyle(.white)
                }
            } else if let videoID {
                YouTubePlayerView(videoID: videoID)
                    .ignoresSafeArea()
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(radius: 4)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 56)
                }
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task { await fetchVideoID() }
    }

    private func fetchVideoID() async {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
        try? AVAudioSession.sharedInstance().setActive(true)

        let query = "\(exerciseName) form #shorts"
        let proxyURL = "https://formai-proxy.formai.workers.dev/youtube-search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        guard let url = URL(string: proxyURL) else { failed = true; isLoading = false; return }
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("formai-sk-2026", forHTTPHeaderField: "X-Service-Key")

        do {
            let (data, _) = try await URLSession.shared.data(for: urlRequest)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let items = json?["items"] as? [[String: Any]] ?? []
            let candidateIDs = items.compactMap { ($0["id"] as? [String: Any])?["videoId"] as? String }

            // Confirm which are actual Shorts via redirect check — all in parallel
            let checks = await withTaskGroup(of: (Int, Bool).self) { group in
                for (i, id) in candidateIDs.enumerated() {
                    group.addTask { (i, await self.isActualShort(id)) }
                }
                var out = [(Int, Bool)]()
                for await r in group { out.append(r) }
                return out
            }

            // Pick first confirmed Short by original search rank, fall back to first candidate
            let result = checks
                .filter { $0.1 }
                .sorted { $0.0 < $1.0 }
                .map { candidateIDs[$0.0] }
                .first ?? candidateIDs.first
            videoID = result
            failed = result == nil
        } catch {
            failed = true
        }
        isLoading = false
    }

    private func isActualShort(_ videoID: String) async -> Bool {
        guard let url = URL(string: "https://www.youtube.com/shorts/\(videoID)") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        // 200 = confirmed Short, 303/301 = redirects away, not a Short
        return http.statusCode == 200
    }
}

// MARK: - YouTube player (loads Shorts page directly — no embed restrictions)

struct YouTubePlayerView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        webView.backgroundColor = .black
        webView.isOpaque = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/shorts/\(videoID)") else { return }
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Hide YouTube header/footer UI and center the video
            let js = """
                var style = document.createElement('style');
                style.innerHTML = `
                    * { box-sizing: border-box; }
                    body, html { margin: 0; padding: 0; background: black !important; overflow: hidden; }
                    ytd-masthead, #masthead-container, #masthead,
                    ytd-page-manager > ytd-browse,
                    #below, #comments, #related,
                    ytd-reel-shelf-renderer,
                    ytd-shorts .navigation-container,
                    ytd-shorts .reel-player-header-renderer,
                    ytd-shorts .reel-player-overlay-renderer,
                    .ytd-shorts-player-controls,
                    ytd-shorts-player-controls-renderer,
                    .navigation-container,
                    #shorts-inner-container > div:not([class*="reel-video"]),
                    ytd-button-renderer, yt-icon-button,
                    .overlay-button-group { display: none !important; }
                    ytd-shorts, #shorts-inner-container,
                    ytd-reel-video-renderer,
                    ytd-reel-video-renderer video {
                        height: 100vh !important;
                        width: 100vw !important;
                        background: black !important;
                    }
                    video { object-fit: cover !important; }
                `;
                document.head.appendChild(style);
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }
}
