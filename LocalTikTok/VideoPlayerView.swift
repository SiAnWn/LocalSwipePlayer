import SwiftUI
import AVKit
import MediaPlayer

struct VideoPlayerView: View {
    let videoURL: URL
    let fileName: String
    @EnvironmentObject var videoModel: VideoModel
    
    @State private var player: AVPlayer?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isPlaying = false
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
                            // 如果是当前活跃的视频（与全局索引比较），则播放
                            if videoModel.currentIndex == (videoModel.videos.firstIndex(of: videoURL) ?? -1) {
                                player.play()
                                isPlaying = true
                                // 跳转到记忆位置
                                let saved = videoModel.currentTime
                                if saved > 0 && saved < duration {
                                    player.seek(to: CMTime(seconds: saved, preferredTimescale: 600))
                                }
                            } else {
                                player.pause()
                                isPlaying = false
                            }
                        }
                        .onDisappear {
                            removeTimeObserver()
                            if videoModel.currentIndex == (videoModel.videos.firstIndex(of: videoURL) ?? -1) {
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
                
                // 进度条（单击显示，2秒后隐藏）
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
                // 单击显示/隐藏进度条
                hideControlsWorkItem?.cancel()
                withAnimation { showControls = true }
                let work = DispatchWorkItem {
                    withAnimation { showControls = false }
                }
                hideControlsWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
            }
        }
        // 监听全局索引变化，自动播放/暂停
        .onReceive(videoModel.$currentIndex) { newIndex in
            let isCurrent = newIndex == (videoModel.videos.firstIndex(of: videoURL) ?? -1)
            if isCurrent {
                // 当前视频变为活跃，开始播放
                if let player = player {
                    player.play()
                    isPlaying = true
                }
            } else {
                // 不再是活跃视频，暂停
                player?.pause()
                isPlaying = false
            }
        }
    }
    
    private func setupPlayer() {
        // 从预加载缓存获取，如果没有则新建
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
            // 只有当前视频才重播
            if videoModel.currentIndex == (videoModel.videos.firstIndex(of: videoURL) ?? -1) {
                player?.seek(to: .zero)
                player?.play()
            }
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
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
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
