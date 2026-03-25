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
        // 当外部 currentIndex 改变时（如删除视频或随机跳转），同步滚动
        if let currentVC = pageVC.viewControllers?.first as? VideoPageViewController,
           currentVC.videoURL != videoURLs[currentIndex] {
            let newVC = VideoPageViewController(videoURL: videoURLs[currentIndex])
            // 根据方向决定动画方向，但为了平滑，统一使用 .forward 并禁用动画（避免闪烁）
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
            return VideoPageViewController(videoURL: parent.videoURLs[index + 1])
        }
        
        // 向上滑动：返回上一个视频（作为过渡，实际在 didFinishAnimating 中会随机跳转）
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index - 1 >= 0 else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index - 1])
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
                // 通过修改 currentIndex 触发 updateUIViewController 跳转，避免手动调用 setViewControllers 导致冲突
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

// MARK: - 视频页面视图控制器（与你之前版本完全相同）
class VideoPageViewController: UIViewController {
    let videoURL: URL
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
    }
}
