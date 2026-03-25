import UIKit
import SwiftUI

class VideoPageViewController: UIViewController, UIScrollViewDelegate {
    private let videoModel: VideoModel
    private let onPageChanged: (Int) -> Void
    private var pageViews: [UIView] = []
    private var scrollView: UIScrollView!
    private var currentIndex = 0
    private var isRandomJumping = false
    private var lastOffsetY: CGFloat = 0
    
    init(videoModel: VideoModel, onPageChanged: @escaping (Int) -> Void) {
        self.videoModel = videoModel
        self.onPageChanged = onPageChanged
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupScrollView()
        setupPages()
        // 初始加载第一个视频
        if let firstURL = videoModel.videos.first {
            VideoPlayerManager.shared.loadVideo(url: firstURL, autoPlay: true)
        }
    }
    
    private func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.delegate = self
        scrollView.backgroundColor = .black
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupPages() {
        let screenSize = UIScreen.main.bounds.size
        for (index, url) in videoModel.videos.enumerated() {
            let containerView = VideoPlayerContainerView()
            containerView.videoURL = url
            containerView.videoModel = videoModel
            containerView.frame = CGRect(x: 0, y: CGFloat(index) * screenSize.height, width: screenSize.width, height: screenSize.height)
            scrollView.addSubview(containerView)
            pageViews.append(containerView)
        }
        scrollView.contentSize = CGSize(width: screenSize.width, height: screenSize.height * CGFloat(videoModel.videos.count))
        // 跳转到记忆位置
        if videoModel.videos.indices.contains(videoModel.currentIndex) {
            scrollToPage(videoModel.currentIndex, animated: false)
        }
    }
    
    func scrollToPage(_ page: Int, animated: Bool) {
        guard page >= 0 && page < pageViews.count else { return }
        let offsetY = CGFloat(page) * scrollView.bounds.height
        scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: animated)
        currentIndex = page
        // 加载视频
        let url = videoModel.videos[page]
        VideoPlayerManager.shared.loadVideo(url: url, autoPlay: true)
        // 预加载相邻视频
        _ = videoModel.preloadItem(for: url)
        if page > 0 { _ = videoModel.preloadItem(for: videoModel.videos[page-1]) }
        if page < videoModel.videos.count - 1 { _ = videoModel.preloadItem(for: videoModel.videos[page+1]) }
        videoModel.cleanupItems(except: url)
        videoModel.currentIndex = page
        videoModel.savePosition()
        onPageChanged(page)
    }
    
    // MARK: - UIScrollViewDelegate
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        lastOffsetY = scrollView.contentOffset.y
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
        if page != currentIndex {
            // 判断是否为向上滑动（新页码 < 旧页码）
            let isSwipeUp = page < currentIndex
            if isSwipeUp && videoModel.videos.count > 1 && !isRandomJumping {
                var randomPage = Int.random(in: 0..<videoModel.videos.count)
                while randomPage == page {
                    randomPage = Int.random(in: 0..<videoModel.videos.count)
                }
                isRandomJumping = true
                scrollToPage(randomPage, animated: true)
                // 重置标志
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isRandomJumping = false
                }
            } else {
                scrollToPage(page, animated: false)
            }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
            if page != currentIndex {
                let isSwipeUp = page < currentIndex
                if isSwipeUp && videoModel.videos.count > 1 && !isRandomJumping {
                    var randomPage = Int.random(in: 0..<videoModel.videos.count)
                    while randomPage == page {
                        randomPage = Int.random(in: 0..<videoModel.videos.count)
                    }
                    isRandomJumping = true
                    scrollToPage(randomPage, animated: true)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isRandomJumping = false
                    }
                } else {
                    scrollToPage(page, animated: false)
                }
            }
        }
    }
}

// MARK: - 视频容器视图（每个页面）
class VideoPlayerContainerView: UIView {
    var videoURL: URL!
    weak var videoModel: VideoModel!
    private var playerLayer: AVPlayerLayer?
    private var fileNameLabel: UILabel?
    private var controlsView: UIView?
    private var progressSlider: UISlider?
    private var currentTimeLabel: UILabel?
    private var durationLabel: UILabel?
    private var speedMenu: UIStackView?
    private var hideControlsTimer: Timer?
    private var hideFileNameTimer: Timer?
    private var isActive = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        // 当视图添加到父视图时，如果当前播放器的 URL 匹配，则添加 layer
        if let superview = superview {
            isActive = true
            if VideoPlayerManager.shared.currentURL != videoURL {
                VideoPlayerManager.shared.loadVideo(url: videoURL, autoPlay: true)
            } else {
                if !VideoPlayerManager.shared.isPlaying {
                    VideoPlayerManager.shared.play()
                }
            }
            // 添加 player layer
            if playerLayer == nil {
                if let layer = VideoPlayerManager.shared.getPlayerLayer() {
                    layer.frame = bounds
                    layer.removeFromSuperlayer()
                    layer.backgroundColor = UIColor.black.cgColor
                    layer.videoGravity = .resizeAspectFill
                    self.layer.insertSublayer(layer, at: 0)
                    playerLayer = layer
                }
            }
        } else {
            isActive = false
            VideoPlayerManager.shared.pause()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
    
    private func setupUI() {
        backgroundColor = .black
        
        fileNameLabel = UILabel()
        fileNameLabel?.textColor = .white
        fileNameLabel?.font = .systemFont(ofSize: 12)
        fileNameLabel?.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        fileNameLabel?.textAlignment = .center
        fileNameLabel?.layer.cornerRadius = 8
        fileNameLabel?.clipsToBounds = true
        fileNameLabel?.alpha = 0
        addSubview(fileNameLabel!)
        fileNameLabel?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            fileNameLabel!.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            fileNameLabel!.centerXAnchor.constraint(equalTo: centerXAnchor),
            fileNameLabel!.heightAnchor.constraint(equalToConstant: 30),
            fileNameLabel!.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
        
        controlsView = UIView()
        controlsView?.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        controlsView?.alpha = 0
        addSubview(controlsView!)
        controlsView?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            controlsView!.leadingAnchor.constraint(equalTo: leadingAnchor),
            controlsView!.trailingAnchor.constraint(equalTo: trailingAnchor),
            controlsView!.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor),
            controlsView!.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        progressSlider = UISlider()
        progressSlider?.minimumTrackTintColor = .white
        progressSlider?.maximumTrackTintColor = .gray
        progressSlider?.thumbTintColor = .white
        controlsView?.addSubview(progressSlider!)
        progressSlider?.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressSlider!.leadingAnchor.constraint(equalTo: controlsView!.leadingAnchor, constant: 20),
            progressSlider!.trailingAnchor.constraint(equalTo: controlsView!.trailingAnchor, constant: -20),
            progressSlider!.topAnchor.constraint(equalTo: controlsView!.topAnchor, constant: 15)
        ])
        
        currentTimeLabel = UILabel()
        currentTimeLabel?.textColor = .white
        currentTimeLabel?.font = .systemFont(ofSize: 12)
        durationLabel = UILabel()
        durationLabel?.textColor = .white
        durationLabel?.font = .systemFont(ofSize: 12)
        let timeStack = UIStackView(arrangedSubviews: [currentTimeLabel!, durationLabel!])
        timeStack.axis = .horizontal
        timeStack.distribution = .equalSpacing
        controlsView?.addSubview(timeStack)
        timeStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timeStack.leadingAnchor.constraint(equalTo: controlsView!.leadingAnchor, constant: 20),
            timeStack.trailingAnchor.constraint(equalTo: controlsView!.trailingAnchor, constant: -20),
            timeStack.topAnchor.constraint(equalTo: progressSlider!.bottomAnchor, constant: 8)
        ])
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, self.isActive else { return }
            self.progressSlider?.value = Float(VideoPlayerManager.shared.currentTime)
            self.durationLabel?.text = self.formatTime(VideoPlayerManager.shared.duration)
            self.currentTimeLabel?.text = self.formatTime(VideoPlayerManager.shared.currentTime)
        }
        
        progressSlider?.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
    }
    
    @objc private func sliderChanged() {
        let newTime = TimeInterval(progressSlider?.value ?? 0)
        VideoPlayerManager.shared.seek(to: newTime)
    }
    
    private func setupGestures() {
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        singleTap.numberOfTapsRequired = 1
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        addGestureRecognizer(singleTap)
        addGestureRecognizer(doubleTap)
        addGestureRecognizer(longPress)
        singleTap.require(toFail: doubleTap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        addGestureRecognizer(pan)
    }
    
    @objc private func handleTap() {
        showFileNameTemporarily()
        showControlsTemporarily()
    }
    
    @objc private func handleDoubleTap() {
        captureScreenshot()
    }
    
    @objc private func handleLongPress() {
        showSpeedMenu()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        let deltaY = translation.y / bounds.height
        let location = gesture.location(in: self)
        let isLeft = location.x < bounds.width / 2
        
        if gesture.state == .changed {
            if isLeft {
                let newBrightness = UIScreen.main.brightness - deltaY
                UIScreen.main.brightness = min(max(newBrightness, 0), 1)
            } else {
                let volumeView = MPVolumeView()
                if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                    let newVolume = slider.value - Float(deltaY)
                    slider.value = min(max(newVolume, 0), 1)
                }
            }
        }
        gesture.setTranslation(.zero, in: self)
    }
    
    private func showFileNameTemporarily() {
        fileNameLabel?.text = videoURL.lastPathComponent
        UIView.animate(withDuration: 0.2) {
            self.fileNameLabel?.alpha = 1
        }
        hideFileNameTimer?.invalidate()
        hideFileNameTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            UIView.animate(withDuration: 0.2) {
                self.fileNameLabel?.alpha = 0
            }
        }
    }
    
    private func showControlsTemporarily() {
        UIView.animate(withDuration: 0.2) {
            self.controlsView?.alpha = 1
        }
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { _ in
            UIView.animate(withDuration: 0.2) {
                self.controlsView?.alpha = 0
            }
        }
    }
    
    private func showSpeedMenu() {
        if speedMenu == nil {
            speedMenu = UIStackView()
            speedMenu?.axis = .vertical
            speedMenu?.spacing = 8
            speedMenu?.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            speedMenu?.layer.cornerRadius = 12
            speedMenu?.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
            speedMenu?.isLayoutMarginsRelativeArrangement = true
            addSubview(speedMenu!)
            speedMenu?.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                speedMenu!.centerXAnchor.constraint(equalTo: centerXAnchor),
                speedMenu!.centerYAnchor.constraint(equalTo: centerYAnchor),
                speedMenu!.widthAnchor.constraint(equalToConstant: 100)
            ])
            
            for sp in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
                let button = UIButton(type: .system)
                button.setTitle("\(sp)x", for: .normal)
                button.setTitleColor(.white, for: .normal)
                button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                button.layer.cornerRadius = 8
                button.tag = Int(sp * 100)
                button.addTarget(self, action: #selector(speedSelected(_:)), for: .touchUpInside)
                speedMenu?.addArrangedSubview(button)
                button.heightAnchor.constraint(equalToConstant: 40).isActive = true
            }
        }
        speedMenu?.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.speedMenu?.isHidden = true
        }
    }
    
    @objc private func speedSelected(_ sender: UIButton) {
        let speed = Float(sender.tag) / 100.0
        VideoPlayerManager.shared.setRate(speed)
        speedMenu?.isHidden = true
    }
    
    private func captureScreenshot() {
        let time = VideoPlayerManager.shared.currentTime
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        do {
            let cgImage = try generator.copyCGImage(at: CMTime(seconds: time, preferredTimescale: 600), actualTime: nil)
            let image = UIImage(cgImage: cgImage)
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            let alert = UIAlertController(title: nil, message: "截图已保存", preferredStyle: .alert)
            if let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first?.windows
                .first(where: { $0.isKeyWindow })?.rootViewController {
                rootVC.present(alert, animated: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    alert.dismiss(animated: true)
                }
            }
        } catch {
            print("截图失败: \(error)")
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        if seconds.isNaN || seconds.isInfinite { return "00:00" }
        let total = Int(seconds)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
