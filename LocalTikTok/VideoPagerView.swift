import SwiftUI
import UIKit
import AVKit

struct VideoPagerView: UIViewControllerRepresentable {
    let videoURLs: [URL]
    @Binding var currentIndex: Int
    let videoModel: VideoModel

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: nil
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        
        if videoURLs.indices.contains(currentIndex) {
            let initialVC = VideoPageViewController(videoURL: videoURLs[currentIndex], videoModel: videoModel)
            pageVC.setViewControllers([initialVC], direction: .forward, animated: false)
        }
        return pageVC
    }
    
    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        // 当外部 currentIndex 改变时（如删除视频或外部直接设置），同步滚动
        if let currentVC = pageVC.viewControllers?.first as? VideoPageViewController,
           currentVC.videoURL != videoURLs[currentIndex] {
            let newVC = VideoPageViewController(videoURL: videoURLs[currentIndex], videoModel: videoModel)
            pageVC.setViewControllers([newVC], direction: .forward, animated: false)
            context.coordinator.lastIndex = currentIndex
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VideoPagerView
        var lastIndex: Int = 0
        private var isRandomJumping = false
        
        init(_ parent: VideoPagerView) {
            self.parent = parent
        }
        
        // 向下滑动：返回下一个视频
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index + 1 < parent.videoURLs.count else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index + 1], videoModel: parent.videoModel)
        }
        
        // 向上滑动：返回上一个视频（作为过渡）
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index - 1 >= 0 else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index - 1], videoModel: parent.videoModel)
        }
        
        // 滑动开始时记录当前页索引
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            if let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController,
               let index = parent.videoURLs.firstIndex(of: currentVC.videoURL) {
                lastIndex = index
            }
        }
        
        // 滑动完成后处理
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed,
                  let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController,
                  let newIndex = parent.videoURLs.firstIndex(of: currentVC.videoURL) else { return }
            
            // 避免递归
            guard !isRandomJumping else { return }
            
            // 判断向上滑动（新索引 < 旧索引）
            if newIndex < lastIndex && parent.videoURLs.count > 1 {
                // 随机选择一个不等于新索引的索引
                var randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                while randomIndex == newIndex {
                    randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                }
                isRandomJumping = true
                // 直接在当前视图控制器上替换视频，不替换视图控制器本身，无闪烁
                let randomURL = parent.videoURLs[randomIndex]
                currentVC.replaceVideo(with: randomURL)
                parent.currentIndex = randomIndex
                isRandomJumping = false
            } else {
                // 向下滑动或未变，正常更新 currentIndex
                parent.currentIndex = newIndex
            }
            lastIndex = parent.currentIndex
        }
    }
}

// MARK: - 视频页面视图控制器（支持动态更换视频，消除闪烁）
class VideoPageViewController: UIViewController {
    private(set) var videoURL: URL
    private let videoModel: VideoModel
    private var playerViewController: AVPlayerViewController?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var isPlaying = false
    
    init(videoURL: URL, videoModel: VideoModel) {
        self.videoURL = videoURL
        self.videoModel = videoModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlayer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        player?.play()
        isPlaying = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        player?.pause()
        isPlaying = false
        // 保存当前进度
        if let currentTime = player?.currentTime().seconds {
            videoModel.currentTime = currentTime
            videoModel.savePosition()
        }
    }
    
    private func setupPlayer() {
        let asset = AVURLAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 5.0
        player = AVPlayer(playerItem: playerItem)
        
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.showsPlaybackControls = true
        playerVC.videoGravity = .resizeAspectFill
        playerVC.view.frame = view.bounds
        playerVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        addChild(playerVC)
        view.addSubview(playerVC.view)
        playerVC.didMove(toParent: self)
        self.playerViewController = playerVC
        
        // 监听播放结束，自动循环
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        
        // 添加时间观察者，保存进度（可选）
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            if self?.isPlaying == true {
                self?.videoModel.currentTime = time.seconds
                self?.videoModel.savePosition()
            }
        }
    }
    
    // 动态更换视频，不重建视图控制器，避免闪烁
    func replaceVideo(with newURL: URL) {
        guard videoURL != newURL else { return }
        videoURL = newURL
        
        // 移除旧的观察者
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        
        // 创建新的播放项
        let asset = AVURLAsset(url: newURL)
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 5.0
        
        // 替换播放器的当前项
        player?.replaceCurrentItem(with: playerItem)
        
        // 重新添加循环播放观察者
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }
        
        // 如果当前页面可见，自动播放
        if isPlaying {
            player?.play()
        }
        
        // 跳转到记忆位置（如果有）
        if videoModel.currentIndex == videoModel.videos.firstIndex(of: newURL) {
            let savedTime = videoModel.currentTime
            if savedTime > 0 && savedTime < (player?.currentItem?.duration.seconds ?? 0) {
                player?.seek(to: CMTime(seconds: savedTime, preferredTimescale: 600))
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
    }
}
