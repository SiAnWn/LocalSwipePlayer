import UIKit
import SwiftUI
import AVFoundation

struct VideoPageViewController: UIViewControllerRepresentable {
    let videos: [URL]
    @Binding var currentIndex: Int
    
    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .vertical, options: nil)
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        
        // 初始化第一个页面
        if let firstVC = context.coordinator.viewController(at: currentIndex) {
            pageVC.setViewControllers([firstVC], direction: .forward, animated: false)
        }
        
        return pageVC
    }
    
    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        // 当外部 currentIndex 改变时，手动切换页面
        if let currentVC = pageVC.viewControllers?.first as? VideoHostingController,
           let currentVCIndex = videos.firstIndex(of: currentVC.videoURL),
           currentVCIndex != currentIndex {
            let direction: UIPageViewController.NavigationDirection = currentIndex > currentVCIndex ? .forward : .reverse
            if let newVC = context.coordinator.viewController(at: currentIndex) {
                pageVC.setViewControllers([newVC], direction: direction, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VideoPageViewController
        
        init(_ parent: VideoPageViewController) {
            self.parent = parent
        }
        
        func viewController(at index: Int) -> VideoHostingController? {
            guard index >= 0 && index < parent.videos.count else { return nil }
            let url = parent.videos[index]
            let vc = VideoHostingController(videoURL: url)
            vc.index = index
            return vc
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? VideoHostingController else { return nil }
            let index = vc.index - 1
            return viewController(at: index)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let vc = viewController as? VideoHostingController else { return nil }
            let index = vc.index + 1
            return viewController(at: index)
        }
        
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed, let currentVC = pageViewController.viewControllers?.first as? VideoHostingController {
                parent.currentIndex = currentVC.index
                // 更新播放器加载新视频
                VideoPlayerManager.shared.loadVideo(url: currentVC.videoURL, autoPlay: true)
            }
        }
    }
}

// 每个页面的视图控制器，承载播放器 layer
class VideoHostingController: UIViewController {
    let videoURL: URL
    var index: Int = 0
    
    init(videoURL: URL) {
        self.videoURL = videoURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 将播放器 layer 添加到当前视图
        if let playerLayer = VideoPlayerManager.shared.getPlayerLayer() {
            playerLayer.frame = view.bounds
            view.layer.addSublayer(playerLayer)
        }
        // 确保当前视频被加载（如果 URL 匹配则自动播放，否则切换）
        if VideoPlayerManager.shared.currentURL != videoURL {
            VideoPlayerManager.shared.loadVideo(url: videoURL, autoPlay: true)
        } else {
            VideoPlayerManager.shared.play()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 页面消失时，不需要暂停播放器，因为其他页面会接管
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        VideoPlayerManager.shared.getPlayerLayer()?.frame = view.bounds
    }
}
