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
    
    // 手势相关
    @State private var startLocation: CGPoint = .zero
    @State private var startBrightness: CGFloat = UIScreen.main.brightness
    @State private var startVolume: Float = AVAudioSession.sharedInstance().outputVolume
    @State private var isAdjustingBrightness = false
    @State private var isAdjustingVolume = false
    
    // 倍速相关
    @State private var speed: Float = 1.0
    @State private var showSpeedMenu = false
    
    // 用于监听播放时间
    @State private var timeObserver: Any?
    // 循环播放标志
    @State private var loopEnabled = true
    
    init(videoURL: URL, playerItem: AVPlayerItem?, fileName: String) {
        self.videoURL = videoURL
        self.playerItem = playerItem
        self.fileName = fileName
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 播放器层
                if let player = player {
                    VideoPlayerController(player: player)
                        .onAppear {
                            player.play()
                            isPlaying = true
                            startTimeObserver()
                            // 尝试跳转到记忆位置
                            if videoModel.currentIndex == (videoModel.videos.firstIndex(of: videoURL) ?? -1) {
                                let savedTime = videoModel.currentTime
                                if savedTime > 0 && savedTime < duration {
                                    player.seek(to: CMTime(seconds: savedTime, preferredTimescale: 600))
                                }
                            }
                        }
                        .onDisappear {
                            player.pause()
                            isPlaying = false
                            removeTimeObserver()
                            // 保存当前进度
                            videoModel.currentTime = currentTime
                            videoModel.savePosition()
                        }
                } else {
                    Color.black
                        .onAppear {
                            setupPlayer()
                        }
                }
                
                // 控制层（进度条、时间）
                if showControls {
                    VStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Slider(value: Binding(
                                get: { currentTime },
                                set: { newValue in
                                    seek(to: newValue)
                                }
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
                
                // 文件名短暂显示
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
                
                // 倍速菜单
                if showSpeedMenu {
                    VStack(spacing: 12) {
                        ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { sp in
                            Button(action: {
                                setSpeed(sp)
                                showSpeedMenu = false
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
                    .transition(.scale)
                }
            }
            .ignoresSafeArea()
            // 双击截图
            .onTapGesture(count: 2) {
                captureScreenshot()
            }
            // 长按显示倍速菜单
            .onLongPressGesture(minimumDuration: 0.5) {
                withAnimation {
                    showSpeedMenu.toggle()
                }
                // 2秒后自动关闭菜单
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSpeedMenu = false
                    }
                }
            }
            // 单指拖拽调节亮度/音量
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        let screenWidth = geometry.size.width
                        let isLeft = value.startLocation.x < screenWidth / 2
                        let deltaY = value.translation.height / screenWidth // 归一化
                        
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
            // 单击显示/隐藏进度条和文件名
            .onTapGesture {
                toggleControls()
                showFileNameBriefly()
            }
        }
    }
    
    // MARK: - 播放器设置
    private func setupPlayer() {
        if let item = playerItem {
            player = AVPlayer(playerItem: item)
        } else {
            let asset = AVURLAsset(url: videoURL)
            let item = AVPlayerItem(asset: asset)
            item.preferredForwardBufferDuration = 5.0
            player = AVPlayer(playerItem: item)
        }
        // 监听循环播放
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
        startTimeObserver()
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
    
    // MARK: - 控制栏
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
            // 简单提示
            let alert = UIAlertController(title: nil, message: "截图已保存", preferredStyle: .alert)
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                alert.dismiss(animated: true)
            }
        } catch {
            print("截图失败: \(error)")
        }
    }
    
    // MARK: - 时间格式化
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

// MARK: - AVPlayerViewController 封装
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
