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
        // 如果外部索引改变（如删除视频后），手动切换
        if let currentVC = pageVC.viewControllers?.first as? VideoPageViewController,
           currentVC.videoURL != videoURLs[currentIndex] {
            let newVC = VideoPageViewController(videoURL: videoURLs[currentIndex])
            let direction: UIPageViewController.NavigationDirection = currentIndex > context.coordinator.lastIndex ? .forward : .reverse
            pageVC.setViewControllers([newVC], direction: direction, animated: true)
            context.coordinator.lastIndex = currentIndex
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VideoPagerView
        var lastIndex: Int = 0
        
        init(_ parent: VideoPagerView) {
            self.parent = parent
        }
        
        // 返回下一页（向下滑动）
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index + 1 < parent.videoURLs.count else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index + 1])
        }
        
        // 返回上一页（向上滑动）—— 保持顺序返回，以便在 didFinishAnimating 中做随机跳转
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index - 1 >= 0 else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index - 1])
        }
        
        // 记录滑动开始前的索引
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            if let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController,
               let currentIndex = parent.videoURLs.firstIndex(of: currentVC.videoURL) {
                lastIndex = currentIndex
            }
        }
        
        // 滑动完成后，判断方向并决定是否随机跳转
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed,
                  let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController,
                  let newIndex = parent.videoURLs.firstIndex(of: currentVC.videoURL) else { return }
            
            // 更新 currentIndex
            parent.currentIndex = newIndex
            
            // 判断是否向上滑动（新索引 < 旧索引）
            if newIndex < lastIndex && parent.videoURLs.count > 1 {
                // 随机选择一个不等于新索引的索引
                var randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                while randomIndex == newIndex {
                    randomIndex = Int.random(in: 0..<parent.videoURLs.count)
                }
                // 跳转到随机页
                let randomVC = VideoPageViewController(videoURL: parent.videoURLs[randomIndex])
                // 使用动画，方向为向前（避免方向冲突）
                pageViewController.setViewControllers([randomVC], direction: .forward, animated: true) { [weak self] _ in
                    // 更新外部索引
                    self?.parent.currentIndex = randomIndex
                    self?.lastIndex = randomIndex
                }
            } else {
                // 正常更新 lastIndex
                lastIndex = newIndex
            }
        }
    }
}

// 每个页面的视图控制器（保持不变）
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
