import SwiftUI
import AVKit
import Combine
import UIKit
import Photos
import MediaPlayer

struct VideoPlayerView: View {
    let videoURL: URL
    let playerItem: AVPlayerItem?
    let fileName: String
    @EnvironmentObject var videoModel: VideoModel
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var showControls = false
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var showFileName = false
    @State private var fileNameWorkItem: DispatchWorkItem?
    
    @State private var startLocation: CGPoint = .zero
    @State private var startBrightness: CGFloat = UIScreen.main.brightness
    @State private var startVolume: Float = AVAudioSession.sharedInstance().outputVolume
    @State private var isAdjustingBrightness = false
    @State private var isAdjustingVolume = false
    
    @State private var speed: Float = 1.0
    @State private var showSpeedMenu = false
    
    @State private var timeObserver: Any?
    @State private var loopEnabled = true
    
    init(videoURL: URL, playerItem: AVPlayerItem?, fileName: String) {
        self.videoURL = videoURL
        self.playerItem = playerItem
        self.fileName = fileName
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                PlayerLayerView(player: player)
                    .onAppear {
                        if player == nil {
                            setupPlayer()
                        }
                        player?.play()
                        isPlaying = true
                        startTimeObserver()
                        if videoModel.currentIndex == (videoModel.videos.firstIndex(of: videoURL) ?? -1) {
                            let savedTime = videoModel.currentTime
                            if savedTime > 0 && savedTime < duration {
                                player?.seek(to: CMTime(seconds: savedTime, preferredTimescale: 600))
                            }
                        }
                    }
                    .onDisappear {
                        player?.pause()
                        isPlaying = false
                        removeTimeObserver()
                        videoModel.currentTime = currentTime
                        videoModel.savePosition()
                    }
                
                ControlsOverlayView(
                    showControls: $showControls,
                    currentTime: currentTime,
                    duration: duration,
                    onSeek: { seek(to: $0) }
                )
                
                FileNameOverlayView(showFileName: $showFileName, fileName: fileName)
                
                SpeedMenuView(showSpeedMenu: $showSpeedMenu, currentSpeed: speed, onSpeedSelected: { setSpeed($0) })
            }
            .ignoresSafeArea()
            .onTapGesture(count: 2) {
                captureScreenshot()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation {
                    showSpeedMenu.toggle()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSpeedMenu = false
                    }
                }
            }
            .gesture(
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
                            let newBrightness = startBrightness - deltaY
                            UIScreen.main.brightness = min(max(newBrightness, 0), 1)
                        } else if isAdjustingVolume {
                            let newVolume = startVolume - Float(deltaY)
                            let volumeView = MPVolumeView()
                            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                                slider.value = min(max(newVolume, 0), 1)
                            }
                        }
                    }
                    .onEnded { _ in
                        isAdjustingBrightness = false
                        isAdjustingVolume = false
                    }
            )
            .onTapGesture {
                toggleControls()
                showFileNameBriefly()
            }
        }
    }
    
    // MARK: - 播放器逻辑
    private func setupPlayer() {
        if let item = playerItem {
            player = AVPlayer(playerItem: item)
        } else {
            let asset = AVURLAsset(url: videoURL)
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 5.0
            player = AVPlayer(playerItem: item)
        }
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { _ in
            if loopEnabled {
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
            if let duration = player.currentItem?.duration, duration.isNumeric && !duration.isIndefinite {
                self.duration = duration.seconds
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    private func setSpeed(_ newSpeed: Float) {
        speed = newSpeed
        player?.rate = speed
    }
    
    // MARK: - 控制栏显示/隐藏
    private func toggleControls() {
        hideControlsWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = false
            }
        }
        hideControlsWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
    
    private func showFileNameBriefly() {
        fileNameWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showFileName = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.2)) {
                showFileName = false
            }
        }
        fileNameWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }
    
    // MARK: - 截图
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
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(alert, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    alert.dismiss(animated: true)
                }
            }
        } catch {
            print("截图失败: \(error)")
        }
    }
}

// MARK: - 播放器层子视图
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer?
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        if let player = player {
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.videoGravity = .resizeAspectFill
            playerLayer.frame = view.bounds
            playerLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.layer.addSublayer(playerLayer)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let player = player, let playerLayer = uiView.layer.sublayers?.first as? AVPlayerLayer {
            playerLayer.player = player
            playerLayer.frame = uiView.bounds
        }
    }
}

// MARK: - 控制栏子视图
struct ControlsOverlayView: View {
    @Binding var showControls: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    let onSeek: (TimeInterval) -> Void
    
    var body: some View {
        if showControls {
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { currentTime },
                        set: { onSeek($0) }
                    ), in: 0...max(duration, 1))
                    .accentColor(.white)
                    .padding(.horizontal, 20)
                    
                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption)
                            .foregroundColor(.white)
                        Spacer()
                        Text(formatTime(duration))
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 30)
                .background(Color.black.opacity(0.5))
            }
            .transition(.opacity)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - 文件名子视图
struct FileNameOverlayView: View {
    @Binding var showFileName: Bool
    let fileName: String
    
    var body: some View {
        if showFileName {
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
            .transition(.opacity)
        }
    }
}

// MARK: - 倍速菜单子视图
struct SpeedMenuView: View {
    @Binding var showSpeedMenu: Bool
    let currentSpeed: Float
    let onSpeedSelected: (Float) -> Void
    
    var body: some View {
        if showSpeedMenu {
            VStack(spacing: 12) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { sp in
                    Button(action: {
                        onSpeedSelected(sp)
                        showSpeedMenu = false
                    }) {
                        Text("\(sp)x")
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .frame(width: 80)
                            .background(currentSpeed == sp ? Color.blue : Color.black.opacity(0.7))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.8))
            .cornerRadius(12)
            .transition(.scale)
        }
    }
}

// MARK: - AVPlayerViewController 封装（备用，可能未用）
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
