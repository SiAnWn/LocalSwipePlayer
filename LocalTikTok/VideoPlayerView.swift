import SwiftUI
import AVKit
import Photos
import MediaPlayer

struct VideoPlayerView: View {
    let videoURL: URL
    let fileName: String
    let isActive: Bool
    @EnvironmentObject var videoModel: VideoModel

    @State private var player: AVPlayer?
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var showControls = false
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var showFileName = false
    @State private var fileNameWorkItem: DispatchWorkItem?
    @State private var showSpeedMenu = false
    @State private var speed: Float = 1.0
    @State private var timeObserver: Any?
    @State private var loopEnabled = true
    @State private var playerReady = false

    // 手势相关
    @State private var isAdjustingBrightness = false
    @State private var isAdjustingVolume = false
    @State private var startBrightness: CGFloat = UIScreen.main.brightness
    @State private var startVolume: Float = AVAudioSession.sharedInstance().outputVolume

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let player = player {
                    VideoPlayerController(player: player)
                        .onAppear {
                            startTimeObserver()
                            if isActive {
                                // 当前激活时，尝试跳转到记忆位置
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

                // 控制层
                if showControls {
                    ControlBarView(currentTime: $currentTime, duration: duration)
                        .transition(.opacity)
                }
                if showFileName {
                    FileNameOverlayView(fileName: fileName)
                        .transition(.opacity)
                }
                if showSpeedMenu {
                    SpeedMenuView(speed: $speed, player: player, isPresented: $showSpeedMenu)
                        .transition(.scale)
                }
            }
            .ignoresSafeArea()
            .onTapGesture(count: 2) { captureScreenshot() }
            .onLongPressGesture(minimumDuration: 0.5) { showSpeedMenu = true }
            .gesture(dragGesture(geometry: geometry))
            .onTapGesture {
                toggleControls()
                showFileNameBriefly()
            }
        }
        .onChange(of: isActive) { newValue in
            // 当激活状态变化时，控制播放/暂停
            if playerReady {
                if newValue {
                    player?.play()
                    if let player = player, player.rate != speed {
                        player.rate = speed
                    }
                } else {
                    player?.pause()
                }
            }
        }
    }

    private func setupPlayer() {
        if let preloadedItem = videoModel.preloadItem(for: videoURL) {
            player = AVPlayer(playerItem: preloadedItem)
        } else {
            let asset = AVURLAsset(url: videoURL)
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 5.0
            player = AVPlayer(playerItem: item)
        }
        playerReady = true

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            if loopEnabled {
                player?.seek(to: .zero)
                if isActive {
                    player?.play()
                }
            }
        }

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

    private func showFileNameBriefly() {
        fileNameWorkItem?.cancel()
        withAnimation { showFileName = true }
        let work = DispatchWorkItem { withAnimation { showFileName = false } }
        fileNameWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func captureScreenshot() {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let asset = player.currentItem?.asset as? AVURLAsset
        guard let url = asset?.url else { return }
        let generator = AVAssetImageGenerator(asset: AVAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        do {
            let cgImage = try generator.copyCGImage(at: currentTime, actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            let alert = UIAlertController(title: nil, message: "截图已保存", preferredStyle: .alert)
            if let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow })?.rootViewController {
                rootVC.present(alert, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { alert.dismiss(animated: true) }
            }
        } catch {
            print("截图失败: \(error)")
        }
    }

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let screenWidth = geometry.size.width
                let isLeft = value.startLocation.x < screenWidth / 2
                let deltaY = value.translation.height / screenWidth
                if !isAdjustingBrightness && !isAdjustingVolume {
                    if isLeft {
                        isAdjustingBrightness = true
                        startBrightness = UIScreen.main.brightness
                    } else {
                        isAdjustingVolume = true
                        startVolume = AVAudioSession.sharedInstance().outputVolume
                    }
                }
                if isAdjustingBrightness {
                    let new = startBrightness - deltaY
                    UIScreen.main.brightness = min(max(new, 0), 1)
                } else if isAdjustingVolume {
                    let new = startVolume - Float(deltaY)
                    let volumeView = MPVolumeView()
                    if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                        slider.value = min(max(new, 0), 1)
                    }
                }
            }
            .onEnded { _ in
                isAdjustingBrightness = false
                isAdjustingVolume = false
            }
    }
}

struct ControlBarView: View {
    @Binding var currentTime: TimeInterval
    let duration: TimeInterval
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                Slider(value: Binding(get: { currentTime }, set: { currentTime = $0 }), in: 0...max(duration, 1))
                    .accentColor(.white)
                HStack {
                    Text(formatTime(currentTime)).font(.caption).foregroundColor(.white)
                    Spacer()
                    Text(formatTime(duration)).font(.caption).foregroundColor(.white)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
            .background(Color.black.opacity(0.5))
        }
    }
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

struct FileNameOverlayView: View {
    let fileName: String
    var body: some View {
        VStack {
            Text(fileName)
                .font(.caption)
                .padding(8)
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                .foregroundColor(.white)
                .padding(.top, 50)
            Spacer()
        }
    }
}

struct SpeedMenuView: View {
    @Binding var speed: Float
    let player: AVPlayer?
    @Binding var isPresented: Bool
    let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    var body: some View {
        VStack(spacing: 12) {
            ForEach(speeds, id: \.self) { sp in
                Button(action: {
                    speed = sp
                    player?.rate = speed
                    isPresented = false
                }) {
                    Text("\(sp)x")
                        .foregroundColor(.white)
                        .padding(.vertical, 8)
                        .frame(width: 80)
                        .background(speed == sp ? Color.blue : Color.black.opacity(0.7))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation { isPresented = false }
            }
        }
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
