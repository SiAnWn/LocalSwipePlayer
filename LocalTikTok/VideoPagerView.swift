import SwiftUI
import UIKit
import AVKit

struct VideoPagerView: UIViewControllerRepresentable {
    let videoURLs: [URL]
    @Binding var currentIndex: Int

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: nil
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        
        if videoURLs.indices.contains(currentIndex) {
            let initialVC = VideoPageViewController(videoURL: videoURLs[currentIndex])
            pageVC.setViewControllers([initialVC], direction: .forward, animated: false)
        }
        return pageVC
    }
    
    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        // 当外部 currentIndex 改变时（如删除视频或外部直接设置），同步滚动
        if let currentVC = pageVC.viewControllers?.first as? VideoPageViewController,
           currentVC.videoURL != videoURLs[currentIndex] {
            let newVC = VideoPageViewController(videoURL: videoURLs[currentIndex])
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
        private var isSwipingUpWithNoPrevious = false
        
        init(_ parent: VideoPagerView) {
            self.parent = parent
        }
        
        // 向下滑动：返回下一个视频
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index + 1 < parent.videoURLs.count else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index + 1])
        }
        
        // 向上滑动：返回 nil，避免系统创建上一个视频的视图控制器（消除中间视频闪现）
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            // 直接返回 nil，向上滑动时不显示任何页面，当前页保持不变
            // 这样滑动过程中用户不会看到上一个视频，我们将在滑动结束时直接随机跳转
            return nil
        }
        
        // 滑动开始时记录当前页索引，并判断是否有上一页（这里总是无，因为 viewControllerBefore 返回 nil）
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            if let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController,
               let index = parent.videoURLs.firstIndex(of: currentVC.videoURL) {
                lastIndex = index
            }
            // 如果 pendingViewControllers 为空，说明向上滑动且没有可用的前一页，标记以便在结束时处理随机跳转
            isSwipingUpWithNoPrevious = pendingViewControllers.isEmpty
        }
        
        // 滑动完成后处理
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard !isRandomJumping else { return }
            
            // 如果是因为向上滑动且没有可用的前一页（即 isSwipingUpWithNoPrevious == true），则直接随机跳转
            if isSwipingUpWithNoPrevious && parent.videoURLs.count > 1 {
                // 随机选择一个不等于当前索引的索引
                var randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                while randomIndex == lastIndex {
                    randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                }
                isRandomJumping = true
                // 直接在当前视图控制器上替换视频，无闪烁
                if let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController {
                    let randomURL = parent.videoURLs[randomIndex]
                    currentVC.replaceVideo(with: randomURL)
                    parent.currentIndex = randomIndex
                }
                isRandomJumping = false
                isSwipingUpWithNoPrevious = false
                return
            }
            
            // 向下滑动：正常更新索引（由于向上滑动不会完成过渡，所以这里只会处理向下滑动）
            if completed,
               let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController,
               let newIndex = parent.videoURLs.firstIndex(of: currentVC.videoURL) {
                parent.currentIndex = newIndex
                lastIndex = newIndex
            }
            isSwipingUpWithNoPrevious = false
        }
    }
}

// MARK: - 视频页面视图控制器（支持动态更换视频，消除闪烁）
class VideoPageViewController: UIViewController {
    private(set) var videoURL: URL
    private var playerViewController: AVPlayerViewController?
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var isPlaying = false
    
    init(videoURL: URL) {
        self.videoURL = videoURL
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
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
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
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
    }
}
