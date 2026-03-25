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
        
        // 初始页
        if videoURLs.indices.contains(currentIndex) {
            let initialVC = VideoPageViewController(videoURL: videoURLs[currentIndex])
            pageVC.setViewControllers([initialVC], direction: .forward, animated: false)
        }
        return pageVC
    }
    
    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        // 如果外部索引改变，手动切换
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
        
        // 返回下一页
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index + 1 < parent.videoURLs.count else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index + 1])
        }
        
        // 返回上一页
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL),
                  index - 1 >= 0 else { return nil }
            return VideoPageViewController(videoURL: parent.videoURLs[index - 1])
        }
        
        // 页面切换完成时更新 currentIndex
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed,
                  let currentVC = pageViewController.viewControllers?.first as? VideoPageViewController,
                  let index = parent.videoURLs.firstIndex(of: currentVC.videoURL) else { return }
            parent.currentIndex = index
            lastIndex = index
        }
    }
}

// 每个页面的视图控制器
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
        // 页面将要显示时，确保播放
        player?.play()
        isPlaying = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 页面消失时暂停
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
        playerVC.showsPlaybackControls = true  // 显示系统自带控件（包含进度条、暂停/播放）
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
        
        // 添加单击手势显示/隐藏控件（系统控件默认点击显示/隐藏，但为了更好的体验，我们不做额外处理，因为 AVPlayerViewController 自带）
        // 如果需要自定义控制栏，可以添加，但为了简化，使用系统控件足够。
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
        }
    }
}
