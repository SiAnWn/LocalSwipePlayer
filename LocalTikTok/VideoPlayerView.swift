import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let videoURL: URL
    let isActive: Bool
    @EnvironmentObject var videoModel: VideoModel

    @State private var player: AVPlayer?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var showControls = false
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var timeObserver: Any?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let player = player {
                    VideoPlayerController(player: player)
                        .onAppear {
                            startTimeObserver()
                            if isActive {
                                // 跳转到记忆位置（仅当是当前视频）
                                if videoModel.currentIndex == (videoModel.videos.firstIndex(of: videoURL) ?? -1) {
                                    let saved = videoModel.currentTime
                                    if saved > 0 && saved < duration {
                                        player.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
                                    }
                                }
                                player.play()
                            }
                        }
                        .onDisappear {
                            player.pause()
                            removeTimeObserver()
                            if isActive {
                                videoModel.currentTime = currentTime
                                videoModel.savePosition()
                            }
                        }
                } else {
                    Color.black
                        .onAppear {
                            setupPlayer()
                        }
                }

                // 进度条控制层
                if showControls {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentTime },
                                set: { newValue in
                                    player?.seek(to: CMTime(seconds: newValue, preferredTimescale: 600))
                                }
                            ), in: 0...max(duration, 1))
                            .accentColor(.white)

                            HStack {
                                Text(formatTime(currentTime))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                Spacer()
                                Text(formatTime(duration))
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        .background(Color.black.opacity(0.5))
                    }
                    .transition(.opacity)
                }
            }
            .ignoresSafeArea()
            .onTapGesture {
                toggleControls()
            }
        }
        .onChange(of: isActive) { newValue in
            if let player = player {
                if newValue {
                    // 激活时播放，并确保播放速率（默认1.0）
                    player.rate = 1.0
                    player.play()
                } else {
                    player.pause()
                }
            }
        }
    }

    private func setupPlayer() {
        // 优先使用预加载的 PlayerItem
        if let preloadedItem = videoModel.preloadItem(for: videoURL) {
            player = AVPlayer(playerItem: preloadedItem)
        } else {
            let asset = AVURLAsset(url: videoURL)
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 5.0
            player = AVPlayer(playerItem: item)
        }

        // 循环播放
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            player?.seek(to: .zero)
            if isActive {
                player?.play()
            }
        }

        // 如果当前激活，立即播放
        if isActive {
            player?.play()
        }
    }

    private func startTimeObserver() {
        guard let player = player else { return }
        removeTimeObserver()
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { time in
            self.currentTime = time.seconds
            if let dur = player.currentItem?.duration, dur.isNumeric && !dur.isIndefinite {
                self.duration = dur.seconds
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func toggleControls() {
        hideControlsWorkItem?.cancel()
        withAnimation { showControls = true }
        let work = DispatchWorkItem { withAnimation { showControls = false } }
        hideControlsWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

struct VideoPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
