import SwiftUI
import UIKit
import AVKit

struct VideoPagerView: UIViewControllerRepresentable {
    let videoURLs: [URL]
    @Binding var currentIndex: Int
    let videoModel: VideoModel  // 新增，用于预加载

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
            
            guard !isRandomJumping else { return }
            
            // 判断向上滑动
            if newIndex < lastIndex && parent.videoURLs.count > 1 {
                // 随机选择一个不等于 newIndex 的索引
                var randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                while randomIndex == newIndex {
                    randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                }
                isRandomJumping = true
                // 直接在当前视图控制器上替换视频，使用预加载的 item
                let randomURL = parent.videoURLs[randomIndex]
                currentVC.replaceVideo(with: randomURL, using: parent.videoModel)
                // 更新外部索引
                parent.currentIndex = randomIndex
                // 重置 lastIndex 为随机后的索引
                lastIndex = randomIndex
                isRandomJumping = false
            } else {
                parent.currentIndex = newIndex
                lastIndex = newIndex
            }
        }
    }
}

// MARK: - 视频页面视图控制器（支持预加载和动态更换视频）
class VideoPageViewController: UIViewController {
    private(set) var videoURL: URL
    private var playerViewController: AVPlayerViewController?
    private var player: AVPlayer?
    private var isPlaying = false
    private let videoModel: VideoModel
    
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
    }
    
    private func setupPlayer() {
        // 使用预加载的 item（如果有）
        let playerItem = videoModel.preloadItem(for: videoURL) ?? AVPlayerItem(asset: AVURLAsset(url: videoURL))
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
    
    // 动态更换视频，使用预加载的 item 减少黑屏
    func replaceVideo(with newURL: URL, using videoModel: VideoModel) {
        guard videoURL != newURL else { return }
        videoURL = newURL
        
        // 移除旧的观察者
        if let currentItem = player?.currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        }
        
        // 获取预加载的 item
        let playerItem = videoModel.preloadItem(for: newURL) ?? AVPlayerItem(asset: AVURLAsset(url: newURL))
        playerItem.preferredForwardBufferDuration = 5.0
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
        if let player = player {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
    }
}
