import AVFoundation
import UIKit

class VideoPlayerManager: ObservableObject {
    static let shared = VideoPlayerManager()
    private var player: AVPlayer?
    private var currentURL: URL?
    private var timeObserver: Any?
    
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isPlaying: Bool = false
    @Published var rate: Float = 1.0
    
    // 公开获取 player 的 layer
    var playerLayer: AVPlayerLayer? {
        return player?.layer as? AVPlayerLayer
    }
    
    private init() {
        setupPlayer()
    }
    
    private func setupPlayer() {
        player = AVPlayer()
        player?.rate = rate
        addTimeObserver()
        
        // 监听播放结束，实现循环
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let url = self.currentURL else { return }
            self.seek(to: 0)
            self.play()
        }
    }
    
    private func addTimeObserver() {
        removeTimeObserver()
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
            if let duration = self?.player?.currentItem?.duration, duration.isNumeric && !duration.isIndefinite {
                self?.duration = duration.seconds
            }
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    func loadVideo(url: URL, autoPlay: Bool = true) {
        guard currentURL != url else {
            if autoPlay && !isPlaying { play() }
            return
        }
        currentURL = url
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 5.0
        player?.replaceCurrentItem(with: item)
        if autoPlay {
            play()
        }
    }
    
    func play() {
        player?.play()
        isPlaying = true
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func seek(to time: TimeInterval) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
    }
    
    func setRate(_ newRate: Float) {
        rate = newRate
        player?.rate = rate
    }
}
